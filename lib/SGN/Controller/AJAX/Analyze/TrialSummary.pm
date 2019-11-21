

package SGN::Controller::AJAX::Analyze::TrialSummary;

use Moose;

use strict;
use warnings;
use Data::Dumper;
use SGN::Controller::AJAX::List;
use CXGN::List::Transform;
use CXGN::Phenotypes::SearchFactory;

BEGIN { extends 'Catalyst::Controller::REST'; };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );

#
# AJAX CONTROLLER: /ajax/analyze/trial_trait_summary
# 
# Summarize trial for a specified list of Trials and Traits.
#
# Query Params:
#   trials_list_id = List ID for a list of trials
#   trait_id = each of the Trait IDs to include in the summary
#
# Returns:
#
sub summarize_trials_by_traits : Path('/ajax/analyze/trial_trait_summary') Args(0) {
  my $self = shift;
  my $c = shift;
  
  my $trials_list_id = $c->req->param("trials_list_id");
  my @trait_ids = $c->req->param("trait_id");
  my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");

  # Get List Info
  my $trial_data;
  if ($trials_list_id) {
    $trial_data = SGN::Controller::AJAX::List->retrieve_list($c, $trials_list_id);
  }

  # Get Trial IDs
  my @trial_list = map { $_->[1] } @$trial_data;
  my $t = CXGN::List::Transform->new();
  my $trial_t = $t->can_transform("trials", "trial_ids");
  my $trial_id_hash = $t->transform($schema, $trial_t, \@trial_list);
  my @trial_ids = @{$trial_id_hash->{transform}};

  # Get phenotype plot data for the matching Trials and Traits
  my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
    'MaterializedViewTable',
    {
      bcs_schema=>$schema,
      data_level=>"plot",
      trait_list=>\@trait_ids,
      trial_list=>\@trial_ids
    }
  );
  my @data = $phenotypes_search->search();
  my $results = $data[0];

  # Parse the phenotype results into a 2D array of rows
  my $rows = plot_data_to_rows($results, \@trait_ids);

  # Write the rows to a CSV tempfile
  my ($src_file, $out_dir) = $self->write_rows_to_tempfile($c, $rows);

  # Run the R script
  system("R CMD BATCH --no-save --no-restore '--args src=\"$src_file\" out=\"$out_dir\"' \"" . $c->config->{basepath} . "/R/summarize_trials_lsm.R\" \"$out_dir/output.txt\"");

  # Get the output files
  $c->stash->{rest} = {
    lsmeans => $self->csv_to_JSON($out_dir . "/lsmeans.csv"),
    lsmeans_metadata => $self->csv_to_JSON($out_dir . "/lsmeans.metadata.csv")
  };

  return;
}


# 
# Parse the phenotype plot data into a 2D array 
# The first Array is the header names (trait, trial, accession, value)
# Each following Array is the data from a single plot observation
#
# Params:
#   $results = results from phenotype search
#   $trait_ids = arrayref to list of trait ids
#
# Returns: a 2D array of plot data from the phenotype search
#
sub plot_data_to_rows {
  my $results = shift;
  my $trait_ids = shift;

  # Set up csv data with headers
  my @rows = ();
  my @h = ("trait", "trial", "accession", "value");
  push(@rows, \@h);

  # Parse each plot data item into rows
  foreach my $plot (@$results) {
    my $trial = $plot->{trial_name};
    my $accession = $plot->{germplasm_uniquename};
    my $observations = $plot->{observations};

    # Add each trait value to the row
    foreach my $trait_id (@$trait_ids) {
      
      # Start array for current row
      my @r = ();
      my $f = 0;

      foreach my $observation (@$observations) {
        if ( $observation->{trait_id} == $trait_id ) {
          push(@r, $trait_id);
          push(@r, $trial);
          push(@r, $accession);
          push(@r, $observation->{value});
          $f = 1;
        }
      }
      if ( $f == 0 ) {
        push(@r, $trait_id);
        push(@r, $trial);
        push(@r, $accession);
        push(@r, "");
      }

      # Add Row to Array of rows
      push(@rows, \@r);

    }
  }

  # Return the array of rows
  return \@rows;
}



#
# Write a 2D Array to a tempfile as a CSV file (comma separated, quote escaped)
# - the first index in the array is the line in the CSV file
# - the second index in the array is the cell contents for that line
#
# Params:
#   $c = Catalyst context
#   $rows = Arrayref to 2D array of rows and cell contents
#
# Returns: (
#   full path to tempfile,
#   full path to output directory
# )
#
sub write_rows_to_tempfile {
  my $self = shift;
  my $c = shift;
  my $rows = shift;

  # Get Tempfile to write CSV to
  my $dir = $c->tempfiles_subdir('data_export');
  my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"data_export/trial_summary_XXXXX");
  my $file_path = $c->config->{basepath}."/".$tempfile;
  
  # Set output directory
  my $out_dir = $c->config->{basepath} . "/" . $tempfile . "_results";
  mkdir $out_dir, 0777;
  
  # Print each row to the tempfile
  foreach my $r (@$rows) {
    print $fh "\"" . join("\",\"", @$r) . "\"";
    print $fh "\n";
  }

  close($fh);
  return ($file_path, $out_dir);
}


sub csv_to_JSON {
  my $self = shift;
  my $path = shift;

  my @headers = ();
  my @rows = ();
  open(my $in, "<:encoding(utf8)", $path) or die "$path: $!";
  while ( my $line = <$in> ) {
    chomp $line;
    my @f = split(",", $line);
    my @fields = ();
    foreach my $i (@f) {
      $i =~ s/^"(.*)"$/$1/;
      push(@fields, $i);
    }

    if ( !@headers ) {
      @headers = @fields;
    }
    else {
      my %r;
      for my $i ( 0 .. $#headers ) {
        my $h = $headers[$i];
        my $v = $fields[$i];
        $r{$h} = $v;
      }
      push(@rows, \%r);
    }
  }

  return(\@rows);
}

1;

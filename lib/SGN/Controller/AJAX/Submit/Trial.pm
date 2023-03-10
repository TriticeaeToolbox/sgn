package SGN::Controller::AJAX::Submit::Trial;

use Moose;
use CXGN::Trial;
use CXGN::BreedersToolbox::Projects;
use CXGN::Stock::Accession;
use CXGN::Trial::TrialLayoutDownload;
use CXGN::Contact;
use Spreadsheet::WriteExcel;

use JSON;
use POSIX qw(strftime);
use File::Path qw(mkpath rmtree);

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);

#
# Function to export all of the accessions (grouped by offset and limit params)
#
sub export_accessions : Path('/ajax/submit/accessions') : ActionClass('REST') { }
sub export_accessions_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $dbh = $schema->storage->dbh();

    my $offset = $c->req->param("offset") || 0;
    my $limit = $c->req->param("limit") || 1000;

    print STDERR "==> GENERATING ACCESSIONS: $limit (from $offset)\n";

    # Get stock ids to query
    my $q = "SELECT stock_id FROM public.stock WHERE type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'accession') ORDER BY uniquename LIMIT ? OFFSET ?;";
    my $s = $dbh->prepare($q);
    $s->execute($limit, $offset);
    my @stock_ids;
    while (my ($stock_id) = $s->fetchrow_array()) {
        push(@stock_ids, $stock_id);
    }

    # Get stock data
    my @rows = ();
    foreach my $stock_id ( @stock_ids ) {
        my $r = $self->generate_accession_row($c, $stock_id);
        push(@rows, $r);
    }

    # Write to File
    my $submission_path = $c->config->{submission_path};
    my $dir = $submission_path . "/bi_accessions";
    unless (-d $dir) {
        mkpath($dir) or die "Couldn't mkdir $dir: $!";
    }
    my $file = $dir . "/accessions_$offset.xls";
    $self->write_accessions_file($file, \@rows);

    print STDERR "    Wrote accessions to: $file\n";

    $c->stash->{rest} = {status => "success", file => "$file"};
}


# 
# Function to export all of the trials with the specified name prefix
#
sub export_trials : Path('/ajax/submit/trials') : ActionClass('REST') { }
sub export_trials_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $dbh = $schema->storage->dbh();

    my $trial_prefix = $c->req->param("prefix") || "";

    print STDERR "==> GENERATING TRIALS: $trial_prefix...\n";

    # Set output directory
    my $submission_path = $c->config->{submission_path};
    my $dir = $submission_path . "/bi_trials/" . $trial_prefix;
    unless (-d $dir) {
        mkpath($dir) or die "Couldn't mkdir $dir: $!";
    }

    # Get trial ids to query
    my $q = "SELECT project_id, name FROM public.project WHERE name LIKE ? ORDER BY name;";
    my $s = $dbh->prepare($q);
    $s->execute($trial_prefix . '%');
    
    # Parse each trial
    while (my ($trial_id, $trial_name) = $s->fetchrow_array()) {
        my $trial_dir = $dir . "/" . strftime("%Y%m%d_%H%M%S", localtime time) . "_" . $trial_id;
        unless (-d $trial_dir) {
            mkpath($trial_dir) or die "Couldn't mkdir $trial_dir: $!";
        }

        my $trial = undef;
        eval {
            $trial = new CXGN::Trial({bcs_schema => $schema, trial_id => $trial_id});
            1;    
        } or do {
            $self->submit_error($c, undef, "The requested Trial ($trial_id) could not be found");
        };

        $self->generate_location_file($c, $trial_dir, $trial);
        $self->generate_trial_layout_file($c, $trial_dir, $trial);
        $self->generate_trial_observations_file($c, $trial_dir, $trial);
    }

    $c->stash->{rest} = {status => "success"};
}


#
# SUBMIT AN ENTIRE TRIAL FOR CURATION
# Generate the upload templates to submit the trial to a production website
# Query/Body Params:
#   trial_id = Phenotype Trial ID (or a comma-separated list of Trial IDs)
#   comments = Comments for curators
# 
sub submit_trial_data : Path('/ajax/submit/trial') : ActionClass('REST') { }

sub submit_trial_data_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    $self->submit_trial_data_POST($c);
}

sub submit_trial_data_POST : Args(0) {
    my ($self, $c) = @_;
    my $trial_id_str = $c->req->param("trial_id");
    my $comments = $c->req->param("comments");

    my $user = $c->user();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $allow_trial_submissions = $c->config->{allow_trial_submissions};
    my $submission_path = $c->config->{submission_path};
    my $submission_email = $c->config->{submission_email};
    my $main_production_site_url = $c->config->{main_production_site_url};

    # Trial Submissions have to be enabled
    if ( !$allow_trial_submissions ) {
        $self->submit_error($c, undef, "Trial Submissions are not enabled");
    }

    # User must be logged in
    if ( !$user ) {
        $self->submit_error($c, undef, "You must be logged in to submit a trial");
    }

    # Trial ID is required
    if ( !$trial_id_str || $trial_id_str eq "" ) {
        $self->submit_error($c, undef, "Trial ID(s) required");
    }

    # Split Multiple Trial IDs
    my @trial_ids = split(/, ?/, $trial_id_str);

    # Export each trial separately
    my %info;    # Hash of trial_id->{dir, trial_dir, name}
    my @names;   # List of trial names
    my $ts = strftime "%Y%m%d_%H%M%S", localtime;               # Timestamp to use in directory name
    my $user_id = $user->get_object()->get_sp_person_id();      # User ID to use in directory name
    for my $trial_id (@trial_ids) {

        # Get Trial by ID
        my $trial = undef;
        eval {
            $trial = new CXGN::Trial({bcs_schema => $schema, trial_id => $trial_id});
            1;
        } or do {
            $self->submit_error($c, undef, "The requested Trial could not be found");
        };

        # Set file directory
        my $trial_dir = $ts . "_" . $trial_id;
        my $dir = $submission_path . "/" . $user_id . '/' . $trial_dir;
        unless (-d $dir) {
            mkpath($dir) or die "Couldn't mkdir $dir: $!";
        }
        $info{$trial_id} = {
            'name' => $trial->get_name(),
            'dir' => $dir,
            'trial_dir' => $trial_dir
        };
        push(@names, $trial->get_name());
        print STDERR "==> Writing Trial $trial_id templates to: $dir\n";

        # Write Individual Files
        $self->generate_submission_file($c, $dir, $comments);
        $self->generate_breeding_program_file($c, $dir, $trial);
        $self->generate_location_file($c, $dir, $trial);
        $self->generate_trial_details_file($c, $dir, $trial);
        $self->generate_accessions_file($c, $dir, $trial);
        $self->generate_trial_layout_file($c, $dir, $trial);
        $self->generate_trial_observations_file($c, $dir, $trial);

    }

    # Send email notification
    if ( $submission_email ) {
        my $subject = "[Trial Submission] " . scalar(@names) . " Trial(s) Submitted";

        my $body = "TRIAL SUBMISSION\n";
        $body .= "================\n\n";
        $body .= "Phenotyping trial(s) " . join(', ', @names) . " have been submitted for curation.\n\n";
        if ( $comments ) {
            $body .= $comments . "\n\n";
        }
        $body .= "User: " . $user->get_first_name() . " " . $user->get_last_name() . " <" . $user->get_private_email() . ">\n";
        $body .= "Site: " . $main_production_site_url . "\n\n";

        $body .= "Trials:\n";
        while ( my($k, $v) = each %info ) {
            $body .= " - " . $v->{'name'} . " (" . $k . ")\n";
            $body .= "   Directory: " . $v->{'dir'} . "\n";
            $body .= "   View Files: " . $main_production_site_url . "/submit/view/" . $user_id . "/" . $v->{'trial_dir'} . "\n";
        }

        CXGN::Contact::send_email($subject, $body, $submission_email, $user->get_private_email());
    }

    # Return success
    $c->stash->{rest} = {status => "success", message => "Trial submitted"};
}



##
## INDIVIDUAL FILE FUNCTIONS
##

sub generate_submission_file :Private {
    my $self = shift;
    my $c = shift;
    my $dir = shift;
    my $comments = shift;

    my $user = $c->user();

    my $sub_file = $dir . "/submission.txt";
    my $sub_contents = "Name: " . $user->get_first_name() . " " . $user->get_last_name() . "\n";
    $sub_contents .= "Username: " . $user->get_username() . "\n";
    $sub_contents .= "Email: " . $user->get_private_email() . "\n";
    $sub_contents .= "Comments: $comments\n";
    $self->write_text_file($sub_file, $sub_contents);
}

sub generate_breeding_program_file :Private {
    my $self = shift;
    my $c = shift;
    my $dir = shift;
    my $trial = shift;

    my $bp_file = $dir . "/breeding_program.txt";
    my $bps = $trial->get_breeding_programs();
    if ( !$bps || @$bps eq 0 ) {
        $self->submit_error($c, $dir, "Trial does not have a breeding program assigned to it");
    }
    my $bp_contents = "Name: " . $bps->[0]->[1] . "\n";
    $bp_contents .= "Description: " . $bps->[0]->[2] . "\n";
    $self->write_text_file($bp_file, $bp_contents);
}

sub generate_location_file :Private {
    my $self = shift;
    my $c = shift;
    my $dir = shift;
    my $trial = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $location_file = $dir . "/locations.xls";
    my $location = $trial->get_location();
    if ( !$location || @$location eq 0 ) {
        $self->submit_error($c, $dir, "Trial does not have a location assigned to it");
    }
    my $location_id = $location->[0];
    
    my $btp = CXGN::BreedersToolbox::Projects->new( { schema => $schema });
    my $locations = $btp->get_location_geojson_data();
    my $location_properties;

    foreach my $l ( @$locations ) { 
        my $p = $l->{properties};
        if ( $p->{Id} eq $location_id ) {
            $location_properties = $p;
        }
    }
    my @location_info = ([
        $location_properties->{Name},
        $location_properties->{Abbreviation},
        $location_properties->{Code},
        $location_properties->{Country},
        $location_properties->{Program},
        $location_properties->{Type},
        $location_properties->{Latitude},
        $location_properties->{Longitude},
        $location_properties->{Altitude},
        $location_properties->{NOAAStationID}
    ]);
    $self->write_locations_file($location_file, \@location_info);
}

sub generate_trial_details_file :Private {
    my $self = shift;
    my $c = shift;
    my $dir = shift;
    my $trial = shift;
    
    my $details_file = $dir . "/trial_details.txt";
    my $details_contents = "Trial ID: " . $trial->get_trial_id() . "\n";
    $details_contents .= "Trial Name: " . $trial->get_name() . "\n";
    $details_contents .= "Breeding Program: " . $trial->get_breeding_programs()->[0]->[1] . "\n";
    $details_contents .= "Trial Location: " . $trial->get_location()->[1] . "\n";
    $details_contents .= "Year: " . $trial->get_year() . "\n";
    $details_contents .= "Stock Type: " . $trial->get_trial_stock_type() . "\n";
    $details_contents .= "Trial Type: " . $trial->get_project_type()->[1] . "\n";
    $details_contents .= "Planting Date: " . $trial->get_planting_date() . "\n";
    $details_contents .= "Harvest Date: " . $trial->get_harvest_date() . "\n";
    $details_contents .= "Description: " . $trial->get_description() . "\n";
    $details_contents .= "Field Size: " . $trial->get_field_size() . "\n";
    $details_contents .= "Plot Width: " . $trial->get_plot_width() . "\n";
    $details_contents .= "Plot Length: " . $trial->get_plot_length() . "\n";
    $details_contents .= "Trial will be genotyped: " . $trial->get_field_trial_is_planned_to_be_genotyped() . "\n";
    $details_contents .= "Trial will be crossed: " . $trial->get_field_trial_is_planned_to_cross() . "\n";
    $self->write_text_file($details_file, $details_contents);
}

sub generate_accessions_file :Private {
    my $self = shift;
    my $c = shift;
    my $dir = shift;
    my $trial = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    
    my $accessions_file = $dir . "/accessions.xls";
    my @accession_rows = ();
    my $accession_info = $trial->get_accessions();
    foreach my $ai ( @$accession_info ) {
        my $stock_id = $ai->{stock_id};
        my $r = $self->generate_accession_row($c, $stock_id);
        push(@accession_rows, $r);
    }
    $self->write_accessions_file($accessions_file, \@accession_rows);
}

sub generate_trial_layout_file :Private {
    my $self = shift;
    my $c = shift;
    my $dir = shift;
    my $trial = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    # Trial Plot-level data
    my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
        schema => $schema,
        trial_id => $trial->get_trial_id(),
        data_level => 'plots',
        selected_columns => {
            "plot_name" => 1,
            "accession_name" => 1,
            "plot_number" => 1,
            "block_number" => 1,
            "is_a_control" => 1,
            "rep_number" => 1,
            "range_number" => 1,
            "row_number" => 1,
            "col_number" => 1,
            "seedlot_name" => 1,
            "num_seed_per_plot" => 1
        }
    });
    my $output = $trial_layout_download->get_layout_output()->{output};
    my $tld_header = shift @$output;

    # Trial layout file info
    my $trial_layout_file = $dir . "/trial_layout.xls";
    my @trial_layout_rows = ();
    my $bps = $trial->get_breeding_programs();

    # Get trial-level properties
    my $trial_name = $trial->get_name();
    my $breeding_program = $trial->get_breeding_programs()->[0]->[1];
    my $location = $trial->get_location()->[1];
    my $year = $trial->get_year();
    my $design_type = $trial->get_design_type();
    my $description = $trial->get_description();
    my $trial_type = defined($trial->get_project_type()) ? $trial->get_project_type()->[1] : "";
    my $plot_width = $trial->get_plot_width();
    my $plot_length = $trial->get_plot_length();
    my $field_size = $trial->get_field_size();
    my $planting_date = $trial->get_planting_date();
    my $harvest_date = $trial->get_harvest_date();

    # Parse the trial plots
    foreach my $p (@$output) {
        
        # layout row
        my @lr = (
            $trial_name,
            $breeding_program,
            $location,
            $year,
            $design_type,
            $description,
            $trial_type,
            $plot_width,
            $plot_length,
            $field_size,
            $planting_date,
            $harvest_date,
            $p->[0],
            $p->[1],
            $p->[2],
            $p->[3],
            $p->[4],
            $p->[5],
            $p->[6],
            $p->[7],
            $p->[8],
            $p->[9],
            $p->[10]
        );
        push(@trial_layout_rows, \@lr);

    }

    $self->write_trial_layout_file($trial_layout_file, \@trial_layout_rows);
}

sub generate_trial_observations_file :Private {
    my $self = shift;
    my $c = shift;
    my $dir = shift;
    my $trial = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    # Trial observations file info
    my $trial_observations_file = $dir . "/trial_observations.xls";
    my $plugin = 'TrialPhenotypeExcel';
    my @trial_list = ( $trial->get_trial_id() );

    # Create File
    my $download = CXGN::Trial::Download->new({
        bcs_schema => $schema,
        trial_list => \@trial_list,
        filename => $trial_observations_file,
        format => $plugin,
        data_level => "plot",
        search_type => 'Native'
    });
    my $error = $download->download();
}



##
## HELPER FUNCTIONS
##

#
# WRITE ACCESSIONS FILE
# Write an accessions template to the specified file using the specified rows
# Arguments:
#   file = file path to write the excel file
#   rows = 2D-arrayref of accession properties
#
sub write_accessions_file {
    my $self = shift;
    my $file = shift;
    my $rows = shift;

    my @headers = ("accession_name", "species_name", "population_name", "organization_name(s)", "synonym(s)", "location_code(s)", "ploidy_level(s)", "genome_structure(s)", "variety(s)", "donor(s)", "donor_institute(s)", "donor_PUI(s)", "country_of_origin(s)", "state(s)", "institute_code(s)", "institute_name(s)", "biological_status_of_accession_code(s)", "notes(s)", "accession_number(s)", "PUI(s)", "seed_source(s)", "type_of_germplasm_storage_code(s)", "acquisition_date(s)", "transgenic", "introgression_parent", "introgression_backcross_parent", "introgression_map_version", "introgression_chromosome", "introgression_start_position_bp", "introgression_end_position_bp", "purdy_pedigree", "filial_generation");
    $self->write_excel_file($file, \@headers, $rows);
}

#
# WRITE LOCATIONS FILE
# Write a locations template to the specified file using the specified rows
# Arguments:
#   file = file path to write the excel file
#   rows = 2D-arrayref of location properties
#
sub write_locations_file {
    my $self = shift;
    my $file = shift;
    my $rows = shift;

    my @headers = ("Name", "Abbreviation", "Country Code", "Country Name", "Program", "Type", "Latitude", "Longitude", "Altitude", "NOAA Station ID");
    $self->write_excel_file($file, \@headers, $rows);
}

#
# WRITE TRIAL LAYOUT FILE
# Write a trial layout template to the specified file using the specified rows
# Arguments:
#   file = file path to write the excel file
#   rows = 2D-arrayref of location properties
#
sub write_trial_layout_file {
    my $self = shift;
    my $file = shift;
    my $rows = shift;

    my @headers = ("trial_name", "breeding_program", "location", "year", "design_type", "description", "trial_type", "plot_width", "plot_length", "field_size", "planting_date", "harvest_date", "plot_name", "accession_name", "plot_number", "block_number", "is_a_control", "rep_number", "range_number", "row_number", "col_number", "seedlot_name", "num_seed_per_plot", "weight_gram_seed_per_plot");
    $self->write_excel_file($file, \@headers, $rows);
}

#
# WRITE TRIAL OBSERVATIONS FILE
# Write a trial observations template to the specified file using the specified traits and rows
# Arguments:
#   file = file path to write the excel file
#   traits = arrayref of trait headers
#   rows = 2D-arrayref of location properties
#
sub write_trial_observations_file {
    my $self = shift;
    my $file = shift;
    my $traits = shift;
    my $rows = shift;

    my @headers = ("observationunit_name");
    push(@headers, @$traits);
    $self->write_excel_file($file, \@headers, $rows);
}


##
## PRIVATE FUNCTIONS
## 

#
# GENERATE ACCESSION ROW
# Generate an array of accession properties to be used in the accession
# template for the specified accession
# Arguments:
#   c = catalyst context
#   stock_id = id of the accession
# Returns: an arrayref of accession properties
#
sub generate_accession_row :Private {
  my $self = shift;
  my $c = shift;
  my $stock_id = shift;
  my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");

  my $a = new CXGN::Stock::Accession({ schema => $schema, stock_id => $stock_id});
  my @r = (
      ref($a->uniquename()) eq 'ARRAY' ? join(',', @{$a->uniquename()}) : $a->uniquename(),
      ref($a->get_species()) eq 'ARRAY' ? join(',', @{$a->get_species()}) : $a->get_species(),
      ref($a->population_name()) eq 'ARRAY' ? join(',', @{$a->population_name()}) : $a->population_name(),
      ref($a->organization_name()) eq 'ARRAY' ? join(',', @{$a->organization_name()}) : $a->organization_name(),
      ref($a->synonyms()) eq 'ARRAY' ? join(',', @{$a->synonyms()}) : $a->synonyms(),
      ref($a->locationCode()) eq 'ARRAY' ? join(',', @{$a->locationCode()}) : $a->locationCode(),
      ref($a->ploidyLevel()) eq 'ARRAY' ? join(',', @{$a->ploidyLevel()}) : $a->ploidyLevel(),
      ref($a->genomeStructure()) eq 'ARRAY' ? join(',', @{$a->genomeStructure()}) : $a->genomeStructure(),
      ref($a->variety()) eq 'ARRAY' ? join(',', @{$a->variety()}) : $a->variety(),
      ref($a->donors()) eq 'ARRAY' ? join(',', @{$a->donors()}) : $a->donors(),
      ref($a->_retrieve_stockprop('donor institute')) eq 'ARRAY' ? join(',', @{$a->_retrieve_stockprop('donor institute')}) : $a->_retrieve_stockprop('donor institute'),
      ref($a->_retrieve_stockprop('donor PUI')) eq 'ARRAY' ? join(',', @{$a->_retrieve_stockprop('donor PUI')}) : $a->_retrieve_stockprop('donor PUI'),
      ref($a->countryOfOriginCode()) eq 'ARRAY' ? join(',', @{$a->countryOfOriginCode()}) : $a->countryOfOriginCode(),
      ref($a->state()) eq 'ARRAY' ? join(',', @{$a->state()}) : $a->state(),
      ref($a->instituteCode()) eq 'ARRAY' ? join(',', @{$a->instituteCode()}) : $a->instituteCode(),
      ref($a->instituteName()) eq 'ARRAY' ? join(',', @{$a->instituteName()}) : $a->instituteName(),
      ref($a->biologicalStatusOfAccessionCode()) eq 'ARRAY' ? join(',', @{$a->biologicalStatusOfAccessionCode()}) : $a->biologicalStatusOfAccessionCode(),
      ref($a->notes()) eq 'ARRAY' ? join(',', @{$a->notes()}) : $a->notes(),
      ref($a->accessionNumber()) eq 'ARRAY' ? join(',', @{$a->accessionNumber()}) : $a->accessionNumber(),
      "",
      ref($a->germplasmSeedSource()) eq 'ARRAY' ? join(',', @{$a->germplasmSeedSource()}) : $a->germplasmSeedSource(),
      ref($a->typeOfGermplasmStorageCode()) eq 'ARRAY' ? join(',', @{$a->typeOfGermplasmStorageCode()}) : $a->typeOfGermplasmStorageCode(),
      ref($a->acquisitionDate()) eq 'ARRAY' ? join(',', @{$a->acquisitionDate()}) : $a->acquisitionDate(),
      ref($a->transgenic()) eq 'ARRAY' ? join(',', @{$a->transgenic()}) : $a->transgenic(),
      ref($a->introgression_parent()) eq 'ARRAY' ? join(',', @{$a->introgression_parent()}) : $a->introgression_parent(),
      ref($a->introgression_backcross_parent()) eq 'ARRAY' ? join(',', @{$a->introgression_backcross_parent()}) : $a->introgression_backcross_parent(),
      ref($a->introgression_map_version()) eq 'ARRAY' ? join(',', @{$a->introgression_map_version()}) : $a->introgression_map_version(),
      ref($a->introgression_chromosome()) eq 'ARRAY' ? join(',', @{$a->introgression_chromosome()}) : $a->introgression_chromosome(),
      ref($a->introgression_start_position_bp()) eq 'ARRAY' ? join(',', @{$a->introgression_start_position_bp()}) : $a->introgression_start_position_bp(),
      ref($a->introgression_end_position_bp()) eq 'ARRAY' ? join(',', @{$a->introgression_end_position_bp()}) : $a->introgression_end_position_bp(),
      ref($a->purdyPedigree()) eq 'ARRAY' ? join(',', @{$a->purdyPedigree()}) : $a->purdyPedigree(),
      ref($a->filialGeneration()) eq 'ARRAY' ? join(',', @{$a->filialGeneration()}) : $a->filialGeneration()
  );

  return \@r;
}

# 
# SUBMIT ERROR
# Delete the submission directory and return an error message when the 
# trial submission fails
# Arguments:
#   c = catalyst context
#   dir = submission directory
#   message = error message to return
#
sub submit_error :Private {
    my $self = shift;
    my $c = shift;
    my $dir = shift;
    my $message = shift;

    if ( $dir ) {
        rmtree($dir)
    }

    $c->stash->{rest} = {status => "error", message => $message};
    $c->detach();
}


#
# WRITE TEXT FILE
# Write the contents to a text file
# Arguments:
#   file = file path
#   contents = file contents
#
sub write_text_file :Private {
    my $self = shift;
    my $file = shift;
    my $contents = shift;

    open(FH, '>', $file) or die $!;
    print FH $contents;
    close(FH);
}


#
# WRITE EXCEL FILE
# Write the headers and rows to an Excel file
# Arguments
#   file = Excel file path
#   headers = arrayref of header names
#   rows = arrayref of 2D array of row contents
#
sub write_excel_file :Private {
    my $self = shift;
    my $file = shift;
    my $headers = shift;
    my $rows = shift;

    print STDERR "WRITING EXCEL FILE: $file\n";

    my $workbook = Spreadsheet::WriteExcel->new($file);
    my $worksheet = $workbook->add_worksheet();

    $worksheet->write_row(0, 0, $headers);
    for ( my $i = 0; $i <= $#$rows; $i++ ) {
        $worksheet->write_row($i+1, 0, $rows->[$i]);
    }   
    
    $workbook->close();
}


1;
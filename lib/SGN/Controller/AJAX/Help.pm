package SGN::Controller::AJAX::Help;

use Moose;
use File::Spec::Functions qw / catfile /;
use File::Path qw / mkpath /;
use File::Basename qw / basename /;
use File::Slurp qw / read_file /;
use List::Util qw /shuffle /;
use SGN::Controller::AJAX::Submit::Trial;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
);

#
# DOWNLOAD SAMPLE TEMPLATE
# Generate and download a sample upload template for the specified data type
# Query Params:
#   type = accessions,locations,trials,observations
#   prefix = unique prefix to prepend to unique names
#
sub download_sample_template: Path('/ajax/help/sample_templates') : {
    my $self = shift;
    my $c = shift;
    my $type = $c->req->param('type');
    my $prefix = $c->req->param('prefix');
    my $dbh = $c->dbc->dbh();

    # Set file path
    my $tmp_dir      = catfile($c->config->{tempfiles_subdir}, 'sample_templates');
    my $base_tmp_dir = catfile($c->config->{basepath}, $tmp_dir);
    if ( ! -d $base_tmp_dir ) {
        mkpath ([$base_tmp_dir], 0, 0755) or die "ERROR: Could not create temp directory [$base_tmp_dir]!";
    }
    my $file = catfile($base_tmp_dir, $prefix . "_" . $type . ".xls");

    # Generate the specific template type
    if ( ! -s $file ) {
        if ( lc($type) eq 'accessions' ) {
            $self->generate_accessions($dbh, $prefix, $file);
        }
        elsif ( lc($type) eq 'locations') {
            $self->generate_locations($dbh, $prefix, $file);
        }
        elsif ( lc($type) eq 'trials' ) {
            $self->generate_trials($dbh, $prefix, $file);
        }
        elsif ( lc($type) eq 'observations' ) {
            $self->generate_observations($dbh, $prefix, $file);
        }
        else {
            $c->stash->{rest} = { error => "Unknown template type [$type]" };
            $c->detach();
        }
    }

    # Return the file
    if ( -s $file ) {
        $c->res->content_type("application/vnd.ms-excel");
        $c->res->header("Content-Disposition", "attachment; filename=" . basename($file));
        my $output = read_file($file);
        $c->res->body($output);
    }
    else {
        $c->stash->{rest} = { error => "The template file does not exist [$file]" };
        $c->detach();
    }
}



##
## Generate the individual sample templates
##

sub generate_accessions :Private {
    my $self = shift;
    my $dbh = shift;
    my $prefix = shift;
    my $file = shift;

    # Generate accession names
    my $names = $self->get_accession_names($prefix);
    
    # Generate accession properties
    my @rows;
    my $species = $self->get_species($dbh);
    foreach my $name (@$names) {
        my @r = (
            $name,
            $species,
            "",
            "Cornell University",
            $name =~ /-1000$/ ? $prefix . "SYNA," . $prefix . "SYNB" : "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            $name =~ /-1000$/ ? "Any additional comments" : "",
            $name =~ /-1000$/ ? "PI 1234" : "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            $name =~ /-1000$/ ? "FEMALE_PARENT/MALE_PARENT" : ""
        );
        push(@rows, \@r);
    }

    # Write the accession file
    SGN::Controller::AJAX::Submit::Trial->write_accessions_file($file, \@rows);
}

sub generate_locations :Private {
    my $self = shift;
    my $dbh = shift;
    my $prefix = shift;
    my $file = shift;

    # Generate the location properties
    my @rows = (
        [
            "Example, NY - " . uc($prefix),
            "EXANY-" . uc($prefix),
            "USA",
            "United States of America",
            "Cornell University",
            "Field",
            $self->random_range(42.25080, 43.00354),
            $self->random_range(76.08824, 77.75458) * -1,
            "289",
            "GHCND:USC00304174"
        ],
        [
            "Sample, NY - " . uc($prefix),
            "SAMNY-" . uc($prefix),
            "USA",
            "United States of America",
            "Cornell University",
            "Field",
            $self->random_range(42.25080, 43.00354),
            $self->random_range(76.08824, 77.75458) * -1,
            "289",
            "GHCND:USC00304174"
        ]
    );

    # Write the accession file
    SGN::Controller::AJAX::Submit::Trial->write_locations_file($file, \@rows);
}

sub generate_trials :Private {
    my $self = shift;
    my $dbh = shift;
    my $prefix = shift;
    my $file = shift;

    my @location_names = ("Example, NY - " . $prefix, "Sample, NY - " . $prefix);
    my @reps = (1..3);
    my $accession_names = $self->get_accession_names($prefix);

    # Generate the plots
    my @rows;
    foreach my $location_name (@location_names) {
        my $loc_code = $location_name =~ /^Example/ ? "EXANY" : "SAMNY";
        foreach my $rep (@reps) {
            my @randomized_accessions = shuffle(@$accession_names);
            my $plot_index = 0;
            foreach my $accession_name (@randomized_accessions) {
                my $trial_name = "SAMPLE_" . $loc_code . "_" . $prefix . "_2022";
                my $plot_number = $rep . "0" . $plot_index;
                my $plot_name = $trial_name . "-PLOT_" . $plot_number;
                my @r = (
                    $trial_name,
                    "Cornell University",
                    $location_name,
                    "2022",
                    "RCBD",
                    "Sample trial @ $location_name",
                    "phenotyping_trial",
                    "",
                    "",
                    "",
                    "2022-05-06",
                    "2022-07-19",
                    $plot_name,
                    $accession_name,
                    $plot_number,
                    $rep,
                    $accession_name =~ /-1000$/ ? "1" : "",
                    $rep,
                    "",
                    $rep,
                    $plot_index+1,
                    "",
                    "",
                    ""
                );
                push(@rows, \@r);
                $plot_index++;
            }
        }
    }

    # Write the trial layout file
    SGN::Controller::AJAX::Submit::Trial->write_trial_layout_file($file, \@rows);
}

sub generate_observations :Private {
    my $self = shift;
    my $dbh = shift;
    my $prefix = shift;
    my $file = shift;

    # Get traits to populate and their info
    my $traits = $self->get_traits($dbh);

    # Generate headers
    my @headers;
    foreach (@$traits) {
        push(@headers, $_->{header});
    }

    # Build each plot
    my @rows;
    foreach my $loc (("EXANY", "SAMNY")) {
        foreach my $rep ((1..3)) {
            foreach my $plot ((0..9)) {
                my $plot_number = $rep . "0" . $plot;
                my $plot_name = "SAMPLE_" . $loc . "_" . $prefix . "_2022-PLOT_" . $plot_number;
                my @r = ($plot_name);
                foreach my $trait (@$traits) {
                    my $value = $self->random_normal($trait->{mean}, $trait->{sd});
                    push(@r, $value);
                }
                push(@rows, \@r);
            }
        }
    }

    # Write the trial observations file
    SGN::Controller::AJAX::Submit::Trial->write_trial_observations_file($file, \@headers, \@rows);
}


##
## Database queries
##

#
# Generate 10 accession names using the specified prefix
#
sub get_accession_names :Private {
    my $self = shift;
    my $prefix = shift;

    my @names;
    for ((0..9)) {
        push(@names, $prefix . "22-100" . $_);
    }

    return \@names;
}

#
# Get the most commonly used (by accessions) organism species name
#
sub get_species :Private {
    my $self = shift;
    my $dbh = shift;

    my $query = "SELECT stock.organism_id, organism.species, COUNT(*) 
                FROM stock 
                LEFT JOIN public.organism USING (organism_id)
                WHERE type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'accession') 
                GROUP BY stock.organism_id, organism.species
                ORDER BY count DESC 
                LIMIT 1;";
    my $h = $dbh->prepare($query);
    $h->execute();
    my ($organism_id, $organism_species) = $h->fetchrow_array();

    return $organism_species;
}

#
# Get the top 3 most used traits (and their means and SDs)
#
sub get_traits :Private {
    my $self = shift;
    my $dbh = shift;

    my @traits;
    my $query = "SELECT t.trait_id, cvterm.name AS trait_name, dbxref.accession AS trait_db_id, db.name AS trait_db_name, t.count
                FROM (
                    SELECT trait_id, COUNT(*)
                    FROM materialized_phenoview
                    WHERE trait_id IS NOT NULL
                    GROUP BY trait_id
                    ORDER BY count DESC
                    LIMIT 3
                ) AS t
                LEFT JOIN public.cvterm ON (cvterm_id = trait_id)
                LEFT JOIN public.dbxref USING (dbxref_id)
                LEFT JOIN public.db USING (db_id);";
    my $h = $dbh->prepare($query);
    $h->execute();
    while (my ($trait_id, $trait_name, $trait_db_id, $trait_db_name) = $h->fetchrow_array()) {
        my $header = $trait_name . "|" . $trait_db_name . ":" . $trait_db_id;
        my $stats = $self->get_trait_stats($dbh, $trait_id);

        my %trait_info = (
            cvterm_id => $trait_id,
            name => $trait_name,
            db_id => $trait_db_id,
            db_name => $trait_db_name,
            header => $header,
            mean => $stats->{mean},
            sd => $stats->{sd}
        );
        push(@traits, \%trait_info);
    }

    return \@traits;
}

#
# Get the mean and SD of the specified trait
#
sub get_trait_stats :Private {
    my $self = shift;
    my $dbh = shift;
    my $cvterm_id = shift;

    my $query = "SELECT AVG(value::float) AS mean, STDDEV(value::float) AS sd
                FROM public.phenotype
                WHERE cvalue_id = ?
                AND value ~ '[0-9].+'";
    my $h = $dbh->prepare($query);
    $h->execute($cvterm_id);
    my ($mean, $sd) = $h->fetchrow_array();
    
    my %stats = (
        mean => $mean,
        sd => $sd
    );
    return \%stats;
}

#
# Generate a random float between the min and max values
#
sub random_range :Private {
    my $self = shift;
    my $min = shift;
    my $max = shift;
    return $min + rand($max - $min);
}

#
# Generate a random number from a normal distribution,
# with the specified mean and standard deviation
# Source: Perl Cookbok / Generating Biased Random Numbers
# https://www.cs.ait.ac.th/~on/O/oreilly/perl/cookbook/ch02_11.htm
#
sub random_normal :Private {
    my $self = shift;
    my $mean = shift;
    my $sd = shift;

    my ($u1, $u2);  # uniformly distributed random numbers
    my $w;          # variance, then a weight
    my ($g1, $g2);  # gaussian-distributed numbers

    do {
        $u1 = 2 * rand( ) - 1;
        $u2 = 2 * rand( ) - 1;
        $w = $u1*$u1 + $u2*$u2;
    } while ($w >= 1);

    $w = sqrt((-2 * log($w)) / $w);
    $g2 = $u1 * $w;
    $g1 = $u2 * $w;
    
    return $g1 * $sd + $mean;
}

1;
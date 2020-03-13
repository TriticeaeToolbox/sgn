package SGN::Controller::AJAX::Submit;

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
# SUBMIT AN ENTIRE TRIAL FOR CURATION
# Generate the upload templates to submit the trial to a production website
# Query/Body Params:
#   trial_id = Phenotype Trial ID
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
    my $trial_id = $c->req->param("trial_id");
    my $comments = $c->req->param("comments");

    my $user = $c->user();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $submission_dir = $c->config->{submission_path};
    my $allow_trial_submissions = $c->config->{allow_trial_submissions};
    my $submission_contact_email = $c->config->{submission_contact_email};
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
    if ( !$trial_id || $trial_id eq "" ) {
        $self->submit_error($c, undef, "Trial ID is required");
    }

    # Get Trial by ID
    my $trial = undef;
    eval {
        $trial = new CXGN::Trial({bcs_schema => $schema, trial_id => $trial_id});
        1;    
    } or do {
        $self->submit_error($c, undef, "The requested Trial could not be found");
    };

    # Set file directory
    my $ts = strftime "%Y%m%d_%H%M%S", localtime;
    my $dir = $submission_dir . "/" . $user->get_object()->get_sp_person_id(). '/' . $ts . "_" . $trial_id;
    unless (-d $dir) {
        mkpath($dir) or die "Couldn't mkdir $dir: $!";
    }
    print STDERR "==> Writing Trial $trial_id templates to: $dir\n";

    # Write Individual Files
    $self->write_submission_file($c, $dir, $comments);
    $self->write_breeding_program_file($c, $dir, $trial);
    $self->write_location_file($c, $dir, $trial);
    $self->write_trial_details_file($c, $dir, $trial);
    $self->write_accessions_file($c, $dir, $trial);
    $self->write_trial_layout_and_observations_files($c, $dir, $trial);

    # Send email notification
    if ( $submission_contact_email ) {
        my $subject = "[Trial Submission] " . $trial->get_name();

        my $body = "TRIAL SUBMISSION\n";
        $body .= "================\n\n";
        $body .= "Phenotyping trial " . $trial->get_name() . " has been submitted.\n\n";
        if ( $comments ) {
            $body .= $comments . "\n\n";
        }
        $body .= "Trial: " . $trial->get_name() . " (" . $trial_id . ")\n";
        $body .= "User: " . $user->get_first_name() . " " . $user->get_last_name() . " <" . $user->get_private_email() . ">\n";
        $body .= "Site: " . $main_production_site_url . "\n";
        $body .= "Directory: " . $dir . "\n";

        CXGN::Contact::send_email($subject, $body, $submission_contact_email, $user->get_private_email());
    }

    # Return success
    $c->stash->{rest} = {status => "success", message => "Trial submitted"};
}



##
## INDIVIDUAL FILE FUNCTIONS
##

sub write_submission_file :Private {
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

sub write_breeding_program_file :Private {
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

sub write_location_file :Private {
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
    my $locations_json = $btp->get_location_geojson();
    my $locations = decode_json ($locations_json);
    my $location_properties;

    foreach my $l ( @$locations ) { 
        my $p = $l->{properties};
        if ( $p->{Id} eq $location_id ) {
            $location_properties = $p;
        }
    }
    my @location_headers = ("Name", "Abbreviation", "Country Code", "Country Name", "Program", "Type", "Latitude", "Longitude", "Altitude");
    my @location_info = ([
        $location_properties->{Name},
        $location_properties->{Abbreviation},
        $location_properties->{Code},
        $location_properties->{Country},
        $location_properties->{Program},
        $location_properties->{Type},
        $location_properties->{Latitude},
        $location_properties->{Longitude},
        $location_properties->{Altitude}
    ]);
    $self->write_excel_file($location_file, \@location_headers, \@location_info);
}

sub write_trial_details_file :Private {
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

sub write_accessions_file :Private {
    my $self = shift;
    my $c = shift;
    my $dir = shift;
    my $trial = shift;

    # TODO: Only add supported/enabled stock props

    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    
    my $accessions_file = $dir . "/accessions.xls";
    my @accession_headers = ("accession_name", "species_name", "population_name", "organization_name(s)", "synonym(s)", "location_code(s)", "ploidy_level(s)", "genome_structure(s)", "variety(s)", "donor(s)", "donor_institute(s)", "donor_PUI(s)", "country_of_origin(s)", "state(s)", "institute_code(s)", "institute_name(s)", "biological_status_of_accession_code(s)", "notes(s)", "accession_number(s)", "PUI(s)", "seed_source(s)", "type_of_germplasm_storage_code(s)", "acquisition_date(s)", "transgenic", "introgression_parent", "introgression_backcross_parent", "introgression_map_version", "introgression_chromosome", "introgression_start_position_bp", "introgression_end_position_bp", "purdy_pedigree", "filial_generation");
    my @accession_rows = ();

    my $accession_info = $trial->get_accessions();
    foreach my $ai ( @$accession_info ) {
        my $stock_id = $ai->{stock_id};
        my $a = new CXGN::Stock::Accession({ schema => $schema, stock_id => $stock_id});
        my @r = (
            $a->uniquename(),
            $a->get_species(),
            $a->population_name(),
            $a->organization_name(),
            $a->synonyms(),
            $a->locationCode(),
            $a->ploidyLevel(),
            $a->genomeStructure(),
            $a->variety(),
            $a->donors(),
            $a->_retrieve_stockprop('donor institute'),
            $a->_retrieve_stockprop('donor PUI'),
            $a->countryOfOriginCode(),
            $a->state(),
            $a->instituteCode(),
            $a->instituteName(),
            $a->biologicalStatusOfAccessionCode(),
            $a->notes(),
            $a->accessionNumber(),
            $a->germplasmPUI(),
            $a->germplasmSeedSource(),
            $a->typeOfGermplasmStorageCode(),
            $a->acquisitionDate(),
            $a->transgenic(),
            $a->introgression_parent(),
            $a->introgression_backcross_parent(),
            $a->introgression_map_version(),
            $a->introgression_chromosome(),
            $a->introgression_start_position_bp(),
            $a->introgression_end_position_bp(),
            $a->purdyPedigree(),
            $a->filialGeneration()
        );
        push(@accession_rows, \@r);
    }
    $self->write_excel_file($accessions_file, \@accession_headers, \@accession_rows);
}

sub write_trial_layout_and_observations_files :Private {
    my $self = shift;
    my $c = shift;
    my $dir = shift;
    my $trial = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    # Trial Plot-level data
    my $trait_offset = 11;
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
    my @traits = @$tld_header[$trait_offset .. @$tld_header-1];

    # Trial layout file info
    my $trial_layout_file = $dir . "/trial_layout.xls";
    my @trial_layout_headers = ("trial_name", "breeding_program", "location", "year", "design_type", "description", "trial_type", "plot_width", "plot_length", "field_size", "planting_date", "harvest_date", "plot_name", "accession_name", "plot_number", "block_number", "is_a_control", "rep_number", "range_number", "row_number", "col_number", "seedlot_name", "num_seed_per_plot", "weight_gram_seed_per_plot");
    my @trial_layout_rows = ();
    my $bps = $trial->get_breeding_programs();

    # Trial observations file info
    my $trial_observations_file = $dir . "/trial_observations.xls";
    my @trial_observations_headers = ("observationunit_name", @traits);
    my @trial_observations_rows = ();

    # Get trial-level properties
    my $trial_name = $trial->get_name();
    my $breeding_program = $trial->get_breeding_programs()->[0]->[1];
    my $location = $trial->get_location()->[1];
    my $year = $trial->get_year();
    my $design_type = $trial->get_design_type();
    my $description = $trial->get_description();
    my $trial_type = $trial->get_project_type()->[1];
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

        # observations row
        my @or = (
            $p->[0]
        );
        for ( my $i = 0; $i <= $#traits; $i++ ) {
            my $v = $p->[$i+$trait_offset];
            push(@or, $v);
        }
        push(@trial_observations_rows, \@or);

    }
    $self->write_excel_file($trial_layout_file, \@trial_layout_headers, \@trial_layout_rows);
    $self->write_excel_file($trial_observations_file, \@trial_observations_headers, \@trial_observations_rows);
}



##
## PRIVATE FUNCTIONS
## 


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

    my $workbook = Spreadsheet::WriteExcel->new($file);
    my $worksheet = $workbook->add_worksheet();

    $worksheet->write_row(0, 0, $headers);
    for ( my $i = 0; $i <= $#$rows; $i++ ) {
        $worksheet->write_row($i+1, 0, $rows->[$i]);
    }   
    
    $workbook->close();
}


1;
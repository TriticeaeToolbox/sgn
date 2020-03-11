package SGN::Controller::AJAX::Submit;

use Moose;
use CXGN::Trial;
use CXGN::BreedersToolbox::Projects;
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


    # SUBMISSION FILE
    my $sub_file = $dir . "/submission.txt";
    my $sub_contents = "Name: " . $user->get_first_name() . " " . $user->get_last_name() . "\n";
    $sub_contents .= "Username: " . $user->get_username() . "\n";
    $sub_contents .= "Email: " . $user->get_private_email() . "\n";
    $sub_contents .= "Comments: $comments\n";
    $self->write_text_file($sub_file, $sub_contents);
    

    # BREEDING PROGRAM
    my $bp_file = $dir . "/breeding_program.txt";
    my $bps = $trial->get_breeding_programs();
    if ( !$bps || @$bps eq 0 ) {
        $self->submit_error($c, $dir, "Trial does not have a breeding program assigned to it");
    }
    my $bp_contents = "Name: " . $bps->[0]->[1] . "\n";
    $bp_contents .= "Description: " . $bps->[0]->[2] . "\n";
    $self->write_text_file($bp_file, $bp_contents);


    # LOCATION
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
    use Data::Dumper;
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


    # TRIAL DETAILS
    my $details_file = $dir . "/trial_details.txt";
    my $details_contents = "Trial ID: $trial_id\n";
    $details_contents .= "Trial Name: " . $trial->get_name() . "\n";
    $details_contents .= "Breeding Program: " . $bps->[0]->[1] . "\n";
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



    use Data::Dumper;

    # Return success
    $c->stash->{rest} = {status => "success", message => "Trial submitted"};
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
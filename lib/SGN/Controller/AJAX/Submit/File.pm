package SGN::Controller::AJAX::Submit::File;

use Moose;
use CXGN::Contact;

use JSON;
use POSIX qw(strftime);
use File::Path qw(mkpath);
use File::Copy qw(copy);
use Digest::SHA qw(sha256_hex);

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);


#
# SUBMIT ONE OR MORE FILES FOR CURATION
# Save the uploaded files to the submission directory
# 
sub submit_trial_file : Path('/ajax/submit/file') : ActionClass('REST') { }

sub submit_trial_file_POST : Args(0) {
    my ($self, $c) = @_;

    my $name = $c->req->param("name");
    my $email = $c->req->param("email");
    my $breeding_program = $c->req->param("breeding-program");
    my $comments = $c->req->param("comments");
    my $uploads = $c->req->uploads->{"files"};

    my $user = $c->user();
    my $allow_file_submissions = $c->config->{allow_file_submissions};
    my $submission_path = $c->config->{submission_path};
    my $submission_email = $c->config->{submission_email};
    my $main_production_site_url = $c->config->{main_production_site_url};

    # File Submissions have to be enabled
    if ( !$allow_file_submissions ) {
        $self->submit_error($c, "File Submissions are not enabled");
    }

    # Parse the breeding program
    my $breeding_program_name;
    my $breeding_program_contact_name;
    my $breeding_program_contact_email;
    if ( $breeding_program eq "other" ) {
        $breeding_program_name = $c->req->param("breeding-program-other");
    }
    elsif ( $breeding_program =~ m/^\d+$/ ) {
        my $projects = CXGN::BreedersToolbox::Projects->new({ schema=> $c->dbic_schema("Bio::Chado::Schema") });
        my $breeding_programs = $projects->get_breeding_programs([$breeding_program]);
        if ( scalar(@$breeding_programs) == 1 ) {
            $breeding_program_name = $breeding_programs->[0]->[1];
            my $breeding_program_contact_alert = $breeding_programs->[0]->[6];
            if ( $breeding_program_contact_alert ) {
                $breeding_program_contact_name = $breeding_programs->[0]->[4];
                $breeding_program_contact_email = $breeding_programs->[0]->[5];
                if ( $breeding_program_contact_email && $breeding_program_contact_email ne '' ) {
                    $submission_email .= ", $breeding_program_contact_email";
                }
            }
        }
    }

    # Check the form data
    if ( !$name ) {
        $self->submit_error($c, "Name is required");
    }
    if ( !$email ) {
        $self->submit_error($c, "Email is required");
    }
    if ( !$breeding_program_name ) {
        $self->submit_error($c, "Breeding Program is required");
    }
    if ( !$uploads ) {
        $self->submit_error($c, "One or more files are required");
    }
    $uploads = [ $uploads ]   if ref($uploads) ne 'ARRAY';

    # Set directory path
    my $ts = strftime "%Y%m%d_%H%M%S", localtime;
    my $user_id = "ANON";
    if ( $user ) {
        $user_id = $user->get_object()->get_sp_person_id();
    }
    my $file_dir = $ts . "_files";
    my $dir = $submission_path . "/" . $user_id . "/" . $file_dir;
    unless (-d $dir) {
        mkpath($dir) or die "Couldn't mkdir $dir: $!";
    }

    # Write Files
    $self->write_submission_file($c, $dir, $name, $email, $breeding_program_name, $comments);
    $self->copy_upload_files($c, $dir, $uploads);

    # Send email notification
    if ( $submission_email ) {
        my $subject = "[File Submission] Phenotype Data Submitted";

        # Generate the URL to view the files
        my $path = $user_id . "/" . $file_dir;
        my $url = $main_production_site_url . "/submit/view/" . $path;
        $url =~ s{(?<!:)/{2,}}{/}g;

        # Generate and add a token to the URL
        my $secret = $c->config->{file_submission_token_key};
        my $token = sha256_hex($path . $secret);
        $url .= "?token=$token";

        # Build the body of the email
        my $body = "FILE SUBMISSION\n";
        $body .= "===============\n\n";
        $body .= "Phenotype data have been submitted for curation.\n\n";
        if ( $comments ) {
            $body .= $comments . "\n\n";
        }
        $body .= "User: $name\n";
        $body .= "Email: $email\n";
        $body .= "Site: " . $main_production_site_url . "\n";
        $body .= "Breeding Program: " . $breeding_program_name . "\n";
        if ( $breeding_program_contact_email && $breeding_program_contact_email ne '' ) {
            $body .= "Breeding Program Contact: ";
            $body .= "$breeding_program_contact_name " if $breeding_program_contact_name && $breeding_program_contact_name ne '';
            $body .= "<$breeding_program_contact_email>\n";
        }
        $body .= "Directory: " . $dir . "\n";
        $body .= "View Files: " . $url;

        # Send the Email
        CXGN::Contact::send_email($subject, $body, $submission_email, $email);
    }


    # Return success
    $c->stash->{rest} = {status => "success", message => "Trial submitted"};
}


##
## INDIVIDUAL FILE FUNCTIONS
##

#
# WRITE SUBMISSION FILE
# Write the submission file with the submitter's 
# name, email and comments
# 
sub write_submission_file :Private {
    my $self = shift;
    my $c = shift;
    my $dir = shift;
    my $name = shift;
    my $email = shift;
    my $breeding_program = shift;
    my $comments = shift;

    my $sub_file = $dir . "/submission.txt";
    my $sub_contents = "Name: $name\n";
    $sub_contents .= "Email: $email\n";
    $sub_contents .= "Breeding Program: $breeding_program\n";
    $sub_contents .= "Comments: $comments\n";

    open(FH, '>', $sub_file) or die $!;
    print FH $sub_contents;
    close(FH);
}


sub copy_upload_files :Private {
    my $self = shift;
    my $c = shift;
    my $dir = shift;
    my $uploads = shift;

    foreach my $upload (@$uploads) {
        copy $upload->tempname, $dir . '/' . $upload->filename;
    }
}


##
## PRIVATE FUNCTIONS
##

#
# SUBMIT ERROR
# Return an error message as the Response
# Arguments:
#   message = error message to return
# 
sub submit_error :Private {
    my $self = shift;
    my $c = shift;
    my $message = shift;

    $c->stash->{rest} = {status => "error", message => $message};
    $c->detach();
}



1;
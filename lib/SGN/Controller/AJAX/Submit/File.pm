package SGN::Controller::AJAX::Submit::File;

use Moose;
use CXGN::Contact;

use JSON;
use POSIX qw(strftime);
use File::Path qw(mkpath);
use File::Copy qw(copy);

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
    my $breeding_program = $c->req->param("breeding-program") eq 'other' ? $c->req->param("breeding-program-other") : $c->req->param("breeding-program");
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

    # Check the form data
    if ( !$name ) {
        $self->submit_error($c, "Name is required");
    }
    if ( !$email ) {
        $self->submit_error($c, "Email is required");
    }
    if ( !$breeding_program ) {
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
    $self->write_submission_file($c, $dir, $name, $email, $breeding_program, $comments);
    $self->copy_upload_files($c, $dir, $uploads);

    # Send email notification
    if ( $submission_email ) {
        my $subject = "[File Submission] Phenotype Data Submitted";
        my $url = $main_production_site_url . "/submit/view/" . $user_id . "/" . $file_dir;
        $url =~ s{(?<!:)/{2,}}{/}g;

        my $body = "FILE SUBMISSION\n";
        $body .= "===============\n\n";
        $body .= "Phenotype data have been submitted for curation.\n\n";
        if ( $comments ) {
            $body .= $comments . "\n\n";
        }
        $body .= "User: $name\n";
        $body .= "Email: $email\n";
        $body .= "Site: " . $main_production_site_url . "\n";
        $body .= "Breeding Program: " . $breeding_program . "\n";
        $body .= "Directory: " . $dir . "\n";
        $body .= "View Files: " . $url;

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
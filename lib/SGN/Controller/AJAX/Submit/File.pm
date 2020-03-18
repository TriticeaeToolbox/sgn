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
    my $data_type = $c->req->param("data-type");
    my $comments = $c->req->param("comments");
    my $uploads = undef;

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
        $self->submit_error($c, "Comments are required");
    }
    if ( !$data_type ) {
        $self->submit_error($c, "Data type not specified");
    }
    if ( $data_type eq "Locations" ) {
        $uploads = $c->req->uploads->{'locations-file'};
        if ( !$uploads ) {
            $self->submit_error($c, "Locations file not specified");
        }
    }
    if ( $data_type eq "Accessions" ) {
        $uploads = $c->req->uploads->{'accessions-file'};
        if ( !$uploads ) {
            $self->submit_error($c, "Accessions file not specified");
        }
    }
    if ( $data_type eq "Trials" ) {
        $uploads = $c->req->uploads->{'trials-file'};
        if ( !$uploads ) {
            $self->submit_error($c, "Trials file(s) not specified");
        }
    }
    if ( $data_type eq "Phenotype Observations" ) {
        $uploads = $c->req->uploads->{'phenotype-observations-file'};
        if ( !$uploads ) {
            $self->submit_error($c, "Phenotype Observations file(s) not specified");
        }
    }
    if ( $data_type eq "Multiple Files" ) {
        $uploads = $c->req->uploads->{"multiple-files-file"};
        if ( !$uploads ) {
            $self->submit_error($c, "Upload file(s) not specified");
        }
    }

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
    $self->write_submission_file($c, $dir, $name, $email, $comments);
    $self->copy_upload_files($c, $dir, $uploads);

    # Send email notification
    if ( $submission_email ) {
        my $subject = "[File Submission] $data_type Submitted";

        my $body = "FILE SUBMISSION\n";
        $body .= "===============\n\n";
        $body .= "$data_type have been submitted for curation.\n\n";
        if ( $comments ) {
            $body .= $comments . "\n\n";
        }
        $body .= "User: $name\n";
        $body .= "Email: $email\n";
        $body .= "Site: " . $main_production_site_url . "\n";
        $body .= "Directory: " . $dir . "\n";
        $body .= "View Files: " . $main_production_site_url . "/submit/view/" . $user_id . "/" . $file_dir;

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
    my $comments = shift;

    my $sub_file = $dir . "/submission.txt";
    my $sub_contents = "Name: $name\n";
    $sub_contents .= "Email: $email\n";
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
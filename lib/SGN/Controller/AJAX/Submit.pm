package SGN::Controller::AJAX::Submit;

use Moose;
use CXGN::Trial;
use POSIX qw(strftime);
use File::Path qw(mkpath);

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);


#
# SUBMIT AN ENTIRE TRIAL FOR CURATION
# Query/Body Params:
#   trial_id = Phenotype Trial ID
#   comments = Comments for curators
# This will generate the upload templates to submit the trial to a production website
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

    print STDERR "\n\n\n\n========> SUBMIT TRIAL DATA <========\n";
    print STDERR "Trial ID: $trial_id\n";
    print STDERR "Comments: $comments\n";

    # Trial Submissions have to be enabled
    if ( !$allow_trial_submissions ) {
        $self->submit_error($c, undef, "Trial Submissions are not enabled");
    }

    # Trial ID is required
    if ( !$trial_id || $trial_id eq "" ) {
        $self->submit_error($c, undef, "Trial ID is required");
    }

    # Get Trial by ID
    my $trial = new CXGN::Trial({bcs_schema => $schema, trial_id => $trial_id});

    # Set file directory
    my $ts = strftime "%Y%m%d_%H%M%S", localtime;
    my $dir = $submission_dir . "/" . $ts . "_" . $trial_id;
    unless (-d $dir) {
        mkpath($dir) or die "Couldn't mkdir $dir: $!";
    }

    print STDERR "DIR: $dir\n";

    # SUBMISSION FILE
    my $sub_file = $dir . "/submission.txt";
    my $sub_contents = "Comments: $comments\n";
    $self->write_text_file($sub_file, $sub_contents);

    # TODO: Add user infor to submission file

    # BREEDING PROGRAM
    my $bp_file = $dir . "/breeding_program.txt";
    my $bps = $trial->get_breeding_programs();
    if ( @$bps eq 0 ) {
        $self->submit_error($c, $dir, "Trial does not have a breeding program assigned to it");
    }
    if ( @$bps > 1 ) {
        $self->submit_error($c, $dir, "Trial has more than 1 breeding program");
    }
    my $bp_contents = "Name: " . $bps->[0]->[1] . "\nDescription: " . $bps->[0]->[2] . "\n";
    $self->write_text_file($bp_file, $bp_contents);


    # LOCATION
    my $location = $trial->get_location();

    use Data::Dumper;
    print STDERR Dumper $location;


    my %result = (status => "success", message => "Trial submitted");
    $c->stash->{rest} = \%result;
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

    # TODO: Remove directory and contents

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


1;
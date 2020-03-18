package SGN::Controller::Submit;

use Moose;

BEGIN { extends "Catalyst::Controller"; }


sub phenotype_upload_workflow : Path('/submit/pheno') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/submit/pheno.mas';
}


sub view_submission_files : Path('/submit/view') Args(2) {
    my $self = shift;
    my $c = shift;
    my $user_id = shift;
    my $sub_dir = shift;

    my $submission_path = $c->config->{submission_path};

    # redirect to login page if not logged in
    if (! $c->user()) { 
        $c->res->redirect('/user/login?goto_url=' . $c->req->uri->path_query);
        return;
    }

    # Build directory path
    my $dir = $submission_path . "/" . $user_id . "/" . $sub_dir;

    # Check directory exists
    if ( !-d $dir ) {
        $c->stash->{template} = 'generic_message.mas';
        $c->stash->{message} = "<p><strong>Submission Not Found</strong></p><p>The directory <code>$dir</code> could not be found on this server.</p>";
        return;
    }

    # List files
    my @files = ();
    opendir (DIR, $dir) or die $!;
    while (my $file = readdir(DIR)) {
        push @files, $file if $file !~ /^\./;
    }
    @files = sort @files;

    $c->stash->{user_id} = $user_id;
    $c->stash->{sub_dir} = $sub_dir;
    $c->stash->{dir} = $dir;
    $c->stash->{files} = \@files;
    $c->stash->{template} = '/submit/view.mas';
}

1;
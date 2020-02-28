package SGN::Controller::Submit;

use Moose;

BEGIN { extends "Catalyst::Controller"; }


sub phenotype_upload_workflow : Path('/submit/pheno') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/submit/pheno.mas';
}

1;
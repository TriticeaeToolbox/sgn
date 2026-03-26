
package SGN::Controller::Imputation;

use Moose;
use Data::Dumper;

BEGIN { extends "Catalyst::Controller"; }



sub status : Path('/imputation') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $dbh = $c->dbc->dbh();
    my $h;

    $c->stash->{template} = '/about/sgn/imputation.mas';
}

1;

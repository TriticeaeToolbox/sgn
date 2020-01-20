
package SGN::Controller::Link;

use Moose;

use CXGN::Phenome::Schema;
use CXGN::Stock;

BEGIN { extends "Catalyst::Controller"; }


#
# Handle incoming external links by redirecting the
# user to the detail page of the queried resource
#
sub link : Path('/link') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $type = $c->request->query_parameters->{type};
    my $q = $c->request->query_parameters->{q};
    my $id = undef;
    my $url = undef;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');


    # TYPE: Accessions
    if ( lc($type) eq 'accession' ) {
        my $stock = $schema->resultset("Stock::Stock")->find({
            'UPPER(me.uniquename)' => uc($q)
        });
        if ( defined $stock ) {
            $id = $stock->stock_id;
            $url = "/stock/$id/view";
        }
    }


    # Redirect, if URL created
    if ( defined $url ) {
        $c->res->redirect($url, 301);
    }

    # No URL created, return error page
    else {
        $c->stash->{type} = $type;
        $c->stash->{q} = $q;
        $c->stash->{template} = '/link/error.mas';
    }
}


1;

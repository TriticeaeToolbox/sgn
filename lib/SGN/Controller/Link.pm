
package SGN::Controller::Link;

use Moose;

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
    my $url = undef;

    # DB handle for queries
    my $dbh = $c->dbc->dbh();

    # TYPE: Accessions
    if ( lc($type) eq 'accession' ) {
        my $h = $dbh->prepare("SELECT stock_id FROM public.stock WHERE UPPER(uniquename) = ?;");
        $h->execute(uc($q));
        my ($stock_id) = $h->fetchrow_array() and $h->finish();
        if ( defined $stock_id ) {
            $url = "/stock/$stock_id/view";
        }
    }

    # TYPE: Markers
    elsif ( lc($type) eq 'marker' ) {
        my $h = $dbh->prepare("SELECT marker_id FROM sgn.marker_alias WHERE UPPER(alias) = ?");
        $h->execute(uc($q));
        my ($marker_id) = $h->fetchrow_array() and $h->finish();
        if ( defined $marker_id ) {
            $url = "/marker/SGN-M$marker_id/details";
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

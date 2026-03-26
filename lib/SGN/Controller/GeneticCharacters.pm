package SGN::Controller::GeneticCharacters;

use Moose;

use URI::FromHash 'uri';


BEGIN { extends 'Catalyst::Controller'; }


sub manage_genetic_characters :Path("/breeders/genetic_characters") Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
	    $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
	    return;
    }

    $c->stash->{template} = '/breeders_toolbox/manage_genetic_characters.mas';
}

1;
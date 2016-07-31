
package SGN::Controller::Ontology;

use CXGN::Chado::Cvterm;

use Moose;

BEGIN { extends 'Catalyst::Controller' };
with 'Catalyst::Component::ApplicationAttribute';



sub onto_browser : Path('/tools/onto') :Args(0) { 
    my $self = shift;
    my $c = shift;

    my $root_nodes = $c->config->{onto_root_namespaces};
    my @namespaces = split ",", $root_nodes;
    foreach my $n (@namespaces) { 
	$n =~ s/\s*(\w+)\s*\(.*\)/$1/g;
	print STDERR "Adding node $n\n";
    }
    #$c->stash->{root_nodes} = $c->req->param("root_nodes");
    $c->stash->{root_nodes} = join " ", @namespaces;
    $c->stash->{db_name} = $c->req->param("db_name");
    $c->stash->{expand} = $c->req->param("expand");

    $c->stash->{template} = '/ontology/standalone.mas';

}

1;

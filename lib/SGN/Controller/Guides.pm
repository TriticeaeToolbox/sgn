
package SGN::Controller::Guides;

use Moose;

BEGIN { extends "Catalyst::Controller"; }

#
# Generic controller for crop-specific user guides
#
# This will display the matching mason component for the specified guide
# Ex: /guides/lists will display the component /guides/lists.mas in the 
# crop's mason directory.  
#
# An error message is displayed if no matching mason component is found.
# 
sub guide : Path('/guides') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $guide = shift;
    if ($c->view('Mason')->component_exists("/guides/$guide.mas")) { 
        $c->stash->{template} = "/guides/$guide.mas";
    }
    else {
        $c->stash->{template} = '/generic_message.mas';
        $c->stash->{message} = 'The requested guide does not exist.';
    }
}

1;
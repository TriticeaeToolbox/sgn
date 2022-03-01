
package SGN::Controller::Help;

use Moose;
use CXGN::People::Person;

BEGIN { extends "Catalyst::Controller"; }



sub help : Path('/help') Args(0) { 
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/help/index.mas';
}

sub help_section : Path('/help') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $section = shift;
    $section =~ s/\.\.//g; # prevent shenanigans

    
    my $component = '/help/'.$section.".mas";
    if ($c->view("Mason")->interp->comp_exists($component)) { 
	$c->stash->{basepath} = $c->config->{basepath};
	$c->stash->{documents_subdir} = $c->config->{documents_subdir};
	$c->stash->{template} = '/help/'.$section.".mas";

	
    }
    else { 
    	$c->stash->{template} = '/generic_message.mas';
	$c->stash->{message}  = 'The requested page could not be found. <br /><a href="/help">Help page</a>';
    }
}

sub help_generate_sample_tempaltes : Path('/help/sample_templates') Args(0) {
    my $self = shift;
    my $c = shift;

    # Set intials, if logge in
    if ($c->user()) {
        my $logged_in_person_id = $c->user()->get_sp_person_id();
        my $logged_in_user = CXGN::People::Person->new($c->dbc->dbh(), $logged_in_person_id);
        my $initials = substr($logged_in_user->get_first_name(), 0, 1) . substr($logged_in_user->get_last_name(), 0, 1);
        $c->stash->{prefix} = $initials;
    }

    $c->stash->{template} = '/help/sample_templates.mas';
}

1;

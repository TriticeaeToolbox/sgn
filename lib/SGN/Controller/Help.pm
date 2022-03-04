
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


sub phenotype_upload_workflow : Path('/help/phenotype_upload_workflow') Args(0) {
    my $self = shift;
    my $c = shift;

    my $user_roles_str = "not logged in";
    if ( $c->user() ) {
        my %hash   = map { $_ => 1 } $c->user->roles();
        my @unique_user_roles = keys %hash;
        $user_roles_str = join(", ", @unique_user_roles);
    }

    $c->stash->{user_roles} = $user_roles_str;
    $c->stash->{template} = '/help/phenotype_upload_workflow.mas';
}


sub phenotype_quick_start : Path('/help/phenotype_quick_start') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    # Get Breeding Programs
    my $projects = CXGN::BreedersToolbox::Projects->new( { schema=> $schema } );
    my $breeding_programs = $projects->get_breeding_programs();
    $c->stash->{breeding_programs} = $breeding_programs;

    # Get Locations
    my $locations = $projects->get_location_geojson_data();
    $c->stash->{locations} = $locations;

    $c->stash->{template} = '/help/phenotype_quick_start.mas';
}


sub help_generate_sample_templates : Path('/help/sample_templates') Args(0) {
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

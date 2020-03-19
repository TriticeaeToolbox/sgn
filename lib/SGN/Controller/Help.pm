
package SGN::Controller::Help;

use Moose;

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

1;


package SGN::Controller::BreedersToolbox::Trial::TrialSummary;

use Moose;
use URI::FromHash 'uri';


BEGIN { extends 'Catalyst::Controller'; }


sub trial_summary_input :Path('/tools/trial/summary/list') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->user) {
	   $c->res->redirect(uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
	   return;
    }
    $c->stash->{template} = '/tools/trial_summary/index.mas';
}

sub trial_summary_results :Path('/tools/trial/summary/results') Args(0) {
    my $self = shift;
    my $c = shift;

    my $trials_list_id = $c->req->param("trials_list_id");
    my @trait_ids = $c->req->param("trait_id");

    if (! $c->user) {
       $c->res->redirect(uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
       return;
    }

    $c->stash->{trials_list_id} = $trials_list_id;
    $c->stash->{trait_ids} = \@trait_ids;
    $c->stash->{template} = '/tools/trial_summary/results.mas';
}

1;

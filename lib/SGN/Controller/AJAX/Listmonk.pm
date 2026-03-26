package SGN::Controller::AJAX::Listmonk;

use Moose;
use MIME::Base64 qw | encode_base64 |;
use HTTP::Request;
use LWP::UserAgent;
use JSON::XS;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);


#
# Check if the Listmonk Integration is enabled
#   Returns:
#       enabled = 1 if the Listmonk integration is enabled
#
sub enabled : Path('/ajax/listmonk/enabled') : Args(0) {
    my $self = shift;
    my $c = shift;
    my $props = _listmonk_properties($c);

    $c->stash->{rest} = {
        enabled => $props->{'enabled'} eq 1 ? 1 : 0
    };
}


#
# Check if the specified email address is already subscribed to the Listmonk List
#   Query Params:
#       email = email address to check
#   Returns:
#       subscribed = 1 if email address is registered and subscribed
#
sub subscribed : Path('/ajax/listmonk/subscribed') : Args(0) {
    my $self = shift;
    my $c = shift;
    my $email = $c->req->param("email");
    my $props = _listmonk_properties($c);
    my $status;

    # Only check if Listmonk is enabled...
    if ( $props->{'enabled'} eq 1 ) {

        # Build Request
        my $headers = ['Authorization' => "token " . $props->{'user'} . ":" . $props->{'pass'}, 'Accepts' => 'application/json'];
        my $url = $props->{'host'} . "/api/subscribers?list_id=" . $props->{'list'} . "&query=subscribers.email='$email'";
        my $r = HTTP::Request->new("GET", $url, $headers);

        # Send Request
        my $ua = LWP::UserAgent->new();
        my $res = $ua->request($r);

        # Parse Response
        my $resp;
        eval {
	    $resp = decode_json($res->content);
	};
	if ($@) {
	    print STDERR "Failed to exract status: $@";
	}
        $status = $resp->{'data'}->{'results'}[0]->{'status'};
    }

    $c->stash->{rest} = {
        subscribed => $status eq "enabled" ? 1 : 0
    };
}


#
# Register the email address and name with Listmonk and subscribe to the list
#   Query Params:
#       email = email address to register
#       name = user's first and last name
#   Returns:
#       registered = status message ("enabled" if properly registered and subscribed)
#
sub register : Path('/ajax/listmonk/register') : Args(0) {
    my $self = shift;
    my $c = shift;
    my $email = $c->req->param("email");
    my $name = $c->req->param("name");
    my $props = _listmonk_properties($c);
    my $status = "Did not register";

    # Only register if Listmonk is enabled...
    if ( $props->{'enabled'} eq 1 ) {

        # Build Request
        my $headers = ['Authorization' => "token " . $props->{'user'} . ":" . $props->{'pass'}, 'Content-Type' => 'application/json', 'Accepts' => 'application/json'];
        my $data = {
            email => $email,
            name => $name,
            status => "enabled",
            lists => [ int($props->{'list'}) ]
        };
        my $url = $props->{'host'} . "/api/subscribers";
        my $r = HTTP::Request->new("POST", $url, $headers, encode_json($data));

        # Send Request
        my $ua = LWP::UserAgent->new();
        my $res = $ua->request($r);

        # Parse Response
        my $resp;
        eval {
	    $resp = decode_json($res->content);
	};
	if ($@) {
	    print STDERR "Failed to decode JSON: $@";
	}
        $status = $resp->{'data'}->{'status'} || $resp->{'message'};

    }

    $c->stash->{rest} = {
        registered => $status
    };
}


#
# Get the Listmonk campaigns for the configured list
#   Returns:
#       campaigns = a list of campaign data
#
sub campaigns : Path('/ajax/listmonk/campaigns') : Args(0) {
    my $self = shift;
    my $c = shift;
    my $props = _listmonk_properties($c);
    my $data = ();

    # Only fetch if Listmonk is enabled...
    if ( $props->{'enabled'} eq 1 ) {

        # Build Request
        my $headers = ['Authorization' => "token " . $props->{'user'} . ":" . $props->{'pass'}, 'Accepts' => 'application/json'];
        my $url = $props->{'host'} . "/api/campaigns?list_id=" . $props->{'list'} . "&order_by=created_at&order=DESC&per_page=2";
        my $r = HTTP::Request->new("GET", $url, $headers);

        # Send Request
        my $ua = LWP::UserAgent->new();
        my $res = $ua->request($r);

        # Parse Response
        my $resp;
        eval {
	    $resp = decode_json($res->content);
	};
	if ($@) {
	    print STDERR "Failed to decode JSON: $@\n";
	}
        $data = $resp->{'data'}->{'results'};

    }

    $c->stash->{rest} = {
        campaigns => $data
    };
}


#
# Redirect to the Listmonk sign up form
#
sub signup : Path('/ajax/listmonk/signup') : Args(0) {
    my $self = shift;
    my $c = shift;
    my $props = _listmonk_properties($c);

    $c->res->redirect($props->{'host'} . "/subscription/form");
}


#
# Redirect to the Listmonk Archive
#   Query Params:
#       uuid = the UUID of the campaign to display
#
sub archive : Path('/ajax/listmonk/archive') : Args(0) {
    my $self = shift;
    my $c = shift;
    my $uuid = $c->req->param("uuid");
    my $props = _listmonk_properties($c);

    if ( defined $uuid ) {
        $c->res->redirect($props->{'host'} . "/archive/$uuid");
    }
    else {
        $c->res->redirect($props->{'host'} . "/archive");
    }
}


#
# Get the Listmonk properties from the config file
# Set the 'enabled' property when all of the config variables are set
#
sub _listmonk_properties {
    my $c = shift;
    my %props = (
        host => $c->config->{listmonk_host},
        user => $c->config->{listmonk_api_user},
        pass => $c->config->{listmonk_api_key},
        list => $c->config->{listmonk_list}
    );
    $props{'enabled'} = defined($props{'host'}) && defined($props{'user'}) && defined($props{'pass'}) && defined($props{'list'});
    return \%props;
}

1;

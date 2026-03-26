
=head1 NAME

SGN::Controller::AJAX::Contact - a REST controller class to provide the
functions for posting the contact form as an issue on github

=head1 DESCRIPTION

When the contact form is submitted it is posted as an issue to github

=head1 AUTHOR

Nicolas Morales <nm529@cornell.edu>

=cut

package SGN::Controller::T3::ContactSMTPSubmit;

use Moose;
use Data::Dumper;
use LWP::UserAgent;
use JSON;
use Mail::Sendmail;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub submit_contact_form : Path('/ajax/contact_smtp/submit') : ActionClass('REST') { }

sub submit_contact_form_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $contact_name = $c->req->param('name');
    my $contact_email = $c->req->param('email');
    my $contact_subject = $c->req->param('subject');
    my $contact_body = $c->req->param('body');

    # Read Config Vars
    my $contact_to = $c->config->{contact_email};
    my $smtp_server = $c->config->{smtp_server};
    my $smtp_port = $c->config->{smtp_port};
    my $smtp_user = $c->config->{smtp_login};
    my $smtp_pass = $c->config->{smtp_pass};
    my $smtp_from = $c->config->{smtp_from};

    # Build Body of Message
    my $body = "BreeDBase Contact Form Submission\nSite: " . $c->config->{main_production_site_url} . "\nSender: $contact_name <$contact_email>\n\n";
    $body = $body . $contact_body;

    # Build the message
    my %mail = (
        To          => $contact_to,
        From        => $smtp_from,
        "Reply-To"  => $contact_email,
        Subject     => "[Contact Us] " . $contact_subject,
        Body        => $body
    );

    # Set the SMTP Server and Auth
    $mail{'server'} = $smtp_server . ":" . $smtp_port;
    $mail{'auth'} = {
        user     => $smtp_user,
        password => $smtp_pass,
        method   => 'DIGEST-MD5 CRAM-MD5 PLAIN LOGIN'
    };

    # Try to send the message
    if ( sendmail(%mail) ) {
        $c->stash->{rest} = {success => 1};
    }
    else {
        $c->stash->{rest} = {error => 'The message could not be sent. Please try again later.<br /><br />'};
    }

}

1;

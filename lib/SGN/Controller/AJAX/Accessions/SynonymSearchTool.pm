package SGN::Controller::AJAX::Accessions::SynonymSearchTool;

use Moose;
use URI::SmartURI;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
  default   => 'application/json',
  stash_key => 'rest',
  map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
);

sub synonym_search_tool_properties : Path('/ajax/synonym_search_tool/properties') Args(0)  {
  my $self = shift;
  my $c = shift;

  # Get properties from config
  my $host = $c->config->{synonym_search_tool_host};
  my $database = $c->config->{synonym_search_tool_db_address};

  # The synonym search tool host is not defined in the server config!
  if ( !defined($host) || $host eq '' ) {
    $c->stash->{rest} = { error => 'Synonym search tool host is not defined' };
    return;
  }

  # If the database is not defined, try to infer it from from referer
  if ( !defined($database) || $database eq '' ) {
    my $ref = $c->req->referer;

    # Parse the referer into 'scheme://host:port/brapi/v1'
    if ( defined($ref) ) {
      my $scheme = $ref->scheme;
      my $host = $ref->host;
      my $port = $ref->port;
      $database = "$scheme://$host";
      if ( $port ne '80' ) {
        $database = "$database:$port";
      }
      $database = "$database/brapi/v1";
    }

    # Referer is not set, cannot determine the database address to use!
    else {
      $c->stash->{rest} = { error => 'Synonym search tool database address is not defined and could not be inferred by the referer' };
      return;
    }
  }

  # Return the host and database address
  $c->stash->{rest} = {
    host => $host,
    database => $database
  }
}

1;

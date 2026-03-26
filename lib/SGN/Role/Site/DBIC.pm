package SGN::Role::Site::DBIC;
use 5.10.0;

use Moose::Role;
use namespace::autoclean;

use Carp;
use Class::Load ':all';

requires 'dbc_profile', 'ensure_dbh_search_path_is_set';

=head2 dbic_schema

  Usage: my $schema = $c->dbic_schema( 'Schema::Package', 'connection_name' );
  Desc : get a L<DBIx::Class::Schema> with the proper connection
         parameters for the given connection name
  Args : L<DBIx::Class> schema package name,
         (optional) connection name to use
  Ret  : schema object
  Side Effects: dies on failure

=cut

sub dbic_schema {
    my ( $class, $schema_name, $profile_name, $sp_person_id) = @_;
    $class = ref $class if ref $class;
    $schema_name or croak "must provide a schema package name to dbic_schema";
    load_class( $schema_name );
    state %schema_cache;
    
    return $schema_cache{$class}{$profile_name || ''}{$schema_name} ||= do {
        my $profile = $class->dbc_profile( $profile_name );
            $schema_name->connect(
                @{$profile}{qw| dsn user password attributes |},
                { on_connect_call => sub {
		    my $dbh = shift->dbh;
                    $class->ensure_dbh_search_path_is_set($dbh); 
		    if ($sp_person_id) {
                      print STDERR "sp_person_id passed to DBIC Schema: $sp_person_id \n";
                      my $q = "CREATE temporary table IF NOT EXISTS logged_in_user (sp_person_id bigint)";
                      $dbh -> do($q) or die($dbh->errstr);
                      my $insert_query = "INSERT INTO logged_in_user (sp_person_id) VALUES (?)";
                      my $insert_handle = $dbh -> prepare($insert_query) or die($dbh->errstr);
                      $insert_handle -> execute($sp_person_id) or die($dbh->errstr);
                    }
                },
            }
        );
    };
}

1;

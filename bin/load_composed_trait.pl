#! /usr/bin/env perl

=head1

load_composed_trait.pl

=head1 SYNOPSIS

load_composed_trait.pl -H [dbhost] -D [dbname] -t [trait name] -d [trait description] -c [trait components]

=head1 COMMAND-LINE OPTIONS

 -H  host name
 -D  database name
 -t  trait name
 -d  (optional) trait description
 -c  (optional) components as a comma-separated string of cvterm ids

=head2 DESCRIPTION

Add a trait into the composed trait ontology.  If component cvterms are provided, the trait will be 
linked to the cvterms.  Otherwise, it will be not connected to any existing ontology terms.

=head2 AUTHOR

David Waring <djw64@cornell.edu>

=cut

use strict;
use warnings;
use Data::Dumper;
use Getopt::Std;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use CXGN::DB::Connection;
use CXGN::Onto;
use Try::Tiny;

our ( $opt_H, $opt_D, $opt_t, $opt_d, $opt_c );
getopts('H:D:t:d:c:');

sub print_help {
    print STDERR
"A script to load a trait into the composed trait ontology\nUsage: load_composed_trait.pl -H [dbhost] -D [dbname] -t [trait name] -d [trait description] -c [trait components] \n";
}

if ( !$opt_D || !$opt_H || !$opt_t ) {
    print_help();
    die("Exiting: -H [dbhost] or -D [dbname] or -t [trait name] options missing\n");
}

my $dbh = CXGN::DB::InsertDBH->new(
    {
        dbname => $opt_D,
        dbhost => $opt_H,
        dbargs => {
            AutoCommit => 1,
            RaiseError => 1
        },
    }
);

my $schema = Bio::Chado::Schema->connect( sub { $dbh->get_actual_dbh() } );
$dbh->do('SET search_path TO public,sgn');

my $coderef = sub {
    my $onto = CXGN::Onto->new({ schema => $schema });
    if ( $opt_c ) {
        my %t;
        $t{$opt_t} = $opt_c;
        $onto->store_composed_term(\%t);
    }
    else {
        $onto->store_breeder_term($opt_t, $opt_d);
    }
};

try {
    $schema->txn_do($coderef);
}
catch {
    die "Load failed! " . $_ . "\n";
};

print "You're done!\n";

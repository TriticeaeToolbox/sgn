#! /usr/bin/env perl

=head1

load_composed_trait.pl

=head1 SYNOPSIS

load_composed_trait.pl -H [dbhost] -D [dbname] -t [trait name] -d [trait description]

=head1 COMMAND-LINE OPTIONS

 -H  host name
 -D  database name
 -t  trait name
 -d  (optional) trait description

=head2 DESCRIPTION

Add a free-text trait (not connected to any other ontology terms) into the composed trait ontology

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

our ( $opt_H, $opt_D, $opt_t, $opt_d );
getopts('H:D:t:d:');

sub print_help {
    print STDERR
"A script to load a free-text trait into the composed trait ontology\nUsage: load_composed_trait.pl -H [dbhost] -D [dbname] -T [trait name] \n";
}

if ( !$opt_D || !$opt_H || !$opt_t ) {
    print_help();
    die("Exiting: -H [dbhost] or -D [dbname] or -T [trait name] options missing\n");
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

my $coderef = sub {
    my $onto = CXGN::Onto->new({ schema => $schema });
    $onto->store_breeder_term($opt_t, $opt_d);
};

try {
    $schema->txn_do($coderef);
}
catch {
    die "Load failed! " . $_ . "\n";
};

print "You're done!\n";

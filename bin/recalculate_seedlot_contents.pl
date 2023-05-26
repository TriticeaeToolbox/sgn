#!/usr/bin/perl

=head1

recalculate_seedlot_contents.pl - a script to recalculate the current seedlot contents
(seed count and seed weight) based on the currently stored transactions in the database

=head1 SYNOPSIS

recalculate_seedlot_contents.pl -H [dbhost] -D [dbname] -i [infile] -t

=head1 COMMAND-LINE OPTIONS

 -H  host name
 -D  database name
 -i  infile
 -t  test run

=head1 DESCRIPTION

This script will recalculate the stock props for the current seedlot seed count and 
seed weight based on the currently stored seed transactions in the database.  This is 
useful if seed transactions were manually removed from the database and the current 
counts and weights are no longer correct.

File format for infile:
One seedlot name per line (no header)

=head1 AUTHORS

David Waring (djw64@cornell.edu)

=cut

use strict;
use warnings;
use Getopt::Std;
use Getopt::Long;
use JSON::Any;
use Scalar::Util qw(looks_like_number);

use Bio::Chado::Schema;
use SGN::Model::Cvterm;
use CXGN::DB::InsertDBH;

my ( $dbhost, $dbname, $file, $test );
GetOptions(
  'i=s'        => \$file,
  'dbname|D=s' => \$dbname,
  'dbhost|H=s' => \$dbhost,
  't'          => \$test
);


# Connect to the database
my $dbh = CXGN::DB::InsertDBH->new({ 
  dbhost=>$dbhost,
  dbname=>$dbname,
  dbargs => {AutoCommit => 1, RaiseError => 1}
});
my $schema = Bio::Chado::Schema->connect(
  sub { $dbh->get_actual_dbh() },
  { on_connect_do => ['SET search_path TO public;'] }
);


# Do everything in a transaction...
my $coderef= sub {

  # Get cvterms
  my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
  my $transaction_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seed transaction', 'stock_relationship')->cvterm_id();
  my $current_weight_gram_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'current_weight_gram', 'stock_property')->cvterm_id();
  my $current_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'current_count', 'stock_property')->cvterm_id();

  # Read the input file to get the seedlot names
  open my $seedlots, $file or die "Could not open $file: $!";
  while( my $seedlot = <$seedlots>)  {
    $seedlot =~ s/^\s+|\s+$//g;
    chomp $seedlot;
    print "==> Updating Seedlot: $seedlot\n";

    my $stock_rs = $schema->resultset('Stock::Stock')->find({ uniquename => $seedlot, type_id => $seedlot_cvterm_id });
    my $additions = $schema->resultset('Stock::StockRelationship')->search({ subject_id => $stock_rs->stock_id(), type_id => $transaction_cvterm_id });
    my $subtractions = $schema->resultset('Stock::StockRelationship')->search({ object_id => $stock_rs->stock_id(), type_id => $transaction_cvterm_id });
    my $current_weight_gram = $schema->resultset('Stock::Stockprop')->search({ stock_id => $stock_rs->stock_id(), type_id => $current_weight_gram_cvterm_id })->first()->value();
    my $current_count = $schema->resultset('Stock::Stockprop')->search({ stock_id => $stock_rs->stock_id(), type_id => $current_count_cvterm_id })->first()->value();

    my $count = 0;
    my $weight = 0;

    while (my $a = $additions->next()) {
      my $av = JSON::Any->decode($a->get_column('value'));
      my $c = $av->{'amount'};
      my $w = $av->{'weight_gram'};

      if ( looks_like_number($c) ) {
        $count = $count + $c;
      }
      if ( looks_like_number($w) ) {
        $weight = $weight + $w;
      }
    }

    while (my $s = $subtractions->next()) {
      my $sv = JSON::Any->decode($s->get_column('value'));
      my $c = $sv->{'amount'};
      my $w = $sv->{'weight_gram'};

      if ( looks_like_number($c) ) {
        $count = $count - $c;
      }
      if ( looks_like_number($w) ) {
        $weight = $weight - $w;
      }
    }

    print STDERR "Count: $current_count --> $count\n";
    print STDERR "New Weight: $current_weight_gram --> $weight\n";

    # $schema->resultset("Stock::Stockprop")->update({
    #   stock_id => $stock_rs->stock_id(),
    #   value => $count,
    #   type_id => $current_count_cvterm_id,
    #   rank => 0
    # }, { key=>'stockprop_c1' });
    # $schema->resultset("Stock::Stockprop")->update({
    #   stock_id => $stock_rs->stock_id(),
    #   value => $weight,
    #   type_id => $current_weight_gram_cvterm_id,
    #   rank => 0
    # }, { key=>'stockprop_c1' });
    my $count_update = $schema->resultset('Stock::Stockprop')->update_or_create(
      {
        type_id => $current_count_cvterm_id,
        stock_id => $stock_rs->stock_id(),
        rank => 0,
        value => $count
      },
      {
        key => 'stockprop_c1'
      }
    );
    my $weight_update = $schema->resultset('Stock::Stockprop')->update_or_create(
      {
        type_id => $current_weight_gram_cvterm_id,
        stock_id => $stock_rs->stock_id(),
        rank => 0,
        value => $weight
      },
      {
        key => 'stockprop_c1'
      }
    );
  }

  # Close the input file
  close $seedlots;

  if ($test) {
    die "TEST RUN! rolling back\n";
  }
};

# Commit the changes...
try {
  $schema->txn_do($coderef);
  print "Transaction succeeded! Seedlot contents updated!\n\n";
} 
catch {
  die "An error occured! Rolling back and reseting changes!\n";
};

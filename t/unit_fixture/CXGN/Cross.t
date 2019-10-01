
use strict;

use Test::More qw | no_plan |;

use lib 't/lib';
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::Cross;

my $f = SGN::Test::Fixture->new();


#my $cross_id = 38845;
my $cross_id = 41264;
#my $cross_id = 9999999;

my $cross = CXGN::Cross->new( { schema => $f->bcs_schema(),
				 cross_stock_id => $cross_id });


my %before = get_counts();

my $progenies = $cross->progenies();

print STDERR "PROGENIES...\n";
print STDERR Dumper($progenies);

is($cross->cross_stock_id(), $cross_id);
is($cross->female_parent(), "TestAccession1", "female parent");
is($cross->male_parent(), "TestAccession2", "male parent");

print STDERR Dumper($cross->progenies());

$cross->delete();

my %after = get_counts();

is($before{stock} -1, $after{stock}, "stock test");
is($before{stock_owner}-1, $after{stock_owner}, "stock owner test");
is($before{project}, $after{project}, "project test");
is($before{nd_experiment}-1, $after{nd_experiment}, "nd_experiment_test");

#my $cross2 = CXGN::Cross->new( { schema => $f->bcs_schema(),
#				 cross_stock_id => $cross_id });

done_testing();


sub get_counts { 

    my %qs = ( stock_owner => "SELECT count(*) FROM phenome.stock_owner", stock => "SELECT count(*) FROM stock", project => "SELECT count(*) FROM project", nd_experiment => "SELECT count(*) fROM nd_experiment");
    
    my %counts = ();
    foreach my $q (keys %qs) { 
	my $h = $f->dbh()->prepare($qs{$q});
	$h->execute();
	my ($count) = $h->fetchrow_array();
	$counts{$q} = $count;
    }

    print STDERR "counts: ".Dumper(\%counts);

    return %counts;
}
    

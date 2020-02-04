use strict;
use warnings;

use Getopt::Std;
use CXGN::DB::Connection;

my $base;
my $ext;
my $cmd;

our ($opt_p);

getopts('p:');

my $dbhost = 'breedbase_db';
my $dbname = 'cxgn_triticum';
my $dbuser = "postgres";

my $dbpass = $opt_p;

my $dbh = CXGN::DB::Connection->new( { dbhost=>$dbhost,
	dbname=>$dbname,
	dbpass=>$dbpass,
	dbuser=>$dbuser,
	dbargs=>{AutoCommit => 1,
	RaiseError => 1}
	}	
);

my $filename = '/home/production/public/trial_list.txt';
open(my $fh, $filename) or die "Could not open file '$filename'";

while (my $trial_name = <$fh>) {
    chomp $trial_name;
    my $q = "SELECT project_id from project where name = '$trial_name'";
    my $h = $dbh->prepare($q);
    $h->execute();
    my ($trial_id) = $h->fetchrow_array();
    if ($trial_id) {
        $cmd = 'perl t3_delete_trials.pl -H breedbase_db -D cxgn_triticum -P ' . $dbpass . ' -U postgres -i ' . $trial_id . ' -b /home/production/archive';
	print STDERR "$trial_name $cmd\n";
       system($cmd);
   } else {
       print STDERR "Trial name $trial_name not valid\n";
   }
}

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

my $dir;
opendir($dir, "/home/production/public/upload_pheno") or die "Cannot open directory $dir";
#my $filename = '/home/production/public/trials_to_delete.csv';
#open(my $fh, $filename) or die "Could not open file '$filename'";

my $trial_name;
#while (my $trial_name = <$fh>) {
while (readdir $dir) {
    #my @fields = split ",", $line;
    #my $trial_name = $fields[1];
    #chomp $trial_name;
    if (/([^\.]+)\.([a-z]+)/) {
	$trial_name = $1;
	$ext = $2;
	if ($ext eq "xls") {
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
   }
}

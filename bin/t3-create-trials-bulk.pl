use strict;
use warnings;

use Getopt::Std;

my $base;
my $ext;
my $cmd;

our ($opt_p);

getopts('p:');

my $dbpass = $opt_p;

#opendir(my $dir, "/home/cbirkett/t3-transfer") or die "Cannot open directory $!";
opendir(my $dir, "/home/production/public/upload_new") or die "Cannot open directory $!";
#opendir(my $dir, "/home/production/public/upload_pheno") or die "Cannot open directory $!";
while (readdir $dir) {
    if (/([^\.]+)\.([a-z]+)/) {
        $base = $1;
        $ext = $2;
        if ($ext eq "xls") {
            print "$base $ext\n";
	    #$cmd = 'perl t3-create-trials.pl -H localhost -D cxgn_triticum -p ' . $dbpass . ' -N ' . $base . ' -U cbirkett -i /home/cbirkett/t3-transfer/';
	    $cmd = 'perl t3-create-trials.pl -H breedbase_db -D cxgn_triticum -p ' . $dbpass . ' -N ' . $base . ' -U cbirkett -i /home/production/public/upload_new/';
	    #$cmd = 'perl t3-create-trials.pl -H breedbase_db -D cxgn_triticum -p ' . $dbpass . ' -N ' . $base . ' -U cbirkett -i /home/production/public/upload_pheno/';
            system($cmd);
        }
    }
}
closedir $dir

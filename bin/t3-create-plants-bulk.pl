use strict;
use warnings;

use Getopt::Std;

my $base;
my $ext;
my $cmd;

our ($opt_p);

getopts('p:');

my $dbpass = $opt_p;

opendir(my $dir, "/home/production/public/upload_pheno_data_plant") or die "Cannot open directory $!";
while (readdir $dir) {
    if (/([^\.]+)_plant\.([a-z]+)/) {
        $base = $1;
        $ext = $2;
        if ($ext eq "xls") {
            print "$base $ext\n";
            $cmd = 'perl bin/t3-upload-plants.pl -H breedbase_db -D cxgn_triticum -U cbirkett -p ' . $dbpass . ' -N ' . $base . ' -i /home/production/public/upload_pheno_data_plant/';
	    system($cmd);
        }
    }
}
closedir $dir

use strict;
use warnings;

use Getopt::Std;

my $base;
my $ext;
my $cmd;

our ($opt_p);

getopts('p:');

my $dbpass = $opt_p;

#opendir(my $dir, "/home/production/public/upload_pheno_data_plant") or die "Cannot open directory $!";
opendir(my $dir, "/home/production/public/upload_pheno_data_plot") or die "Cannot open directory $!";
while (readdir $dir) {
    if (/([^\.]+)_plot\.([a-z]+)/) {
        $base = $1;
        $ext = $2;
        if ($ext eq "xls") {
            print "$base $ext\n";
            $cmd = 'perl bin/t3-load-phenotypes.pl -H breedbase_db -D cxgn_triticum -U postgres -u cbirkett -P ' . $dbpass . ' -N ' . $base . ' -i /home/production/public/upload_pheno_data_plot/ -d plot';
	    system($cmd);
        }
    }
}
closedir $dir

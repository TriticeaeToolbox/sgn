
=head1 NAME
 load-genome-features.pl - load genome features from gff3 file

=head1 SYNOPSYS

load-genome-features.pl -p [password] -H [hostname] -D [database name] file

=head1 AUTHOR

Clay Birkett <clb34@cornell.edu>

=cut

#if entries already exist in db then it will be skipped
#to update entries they should be cleared with truncate table feature CASCADE
#this script is needed because some features do not have sequence

use strict;
use warnings;

use Getopt::Std;
use CXGN::DB::InsertDBH;
use CXGN::Chado::Dbxref;

our ($opt_H, $opt_D, $opt_p, $opt_f);
getopts('p:H:D:');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dbpass = $opt_p;
my $in_file = $opt_f || "/home/production/public/Triticum_aestivum.IWGSC.46.gff3.clean";;
my $dbuser = "postgres";

my $dbh = CXGN::DB::Connection->new( { dbhost=>$dbhost,
    dbname=>$dbname,
    dbpass=>$dbpass,
    dbuser=>$dbuser,
    dbargs=> {AutoCommit => 1,
    RaiseError => 1}
});

my @row;
my $sth;
my $name;
my %cvlist;
my %featurelist;

print STDERR "reading in cvterms\n";
my $q = "SELECT cvterm_id, name from cvterm";
$sth = $dbh->prepare($q);
$sth->execute();
while (@row = $sth->fetchrow_array) {
    $name = $row[1];
    $cvlist{$name} = $row[0]
}

print STDERR "reading in features\n";
$q = "SELECT name from feature";
$sth = $dbh->prepare($q);
$sth->execute();
while (@row = $sth->fetchrow_array) {
    $name = $row[0];
    $featurelist{$name} = 1;
}

my $organism_id = 38385; # T.aestivum   | Triticum               | Triticum aestivum  
my $type;
my $type_id;
my $seqlen = 0;
my $count_dup = 0;

open (GFFIN, "<$in_file") or die "couldn't open $in_file for reading: $!";
print STDERR "reading file $in_file\n";
while (<GFFIN>) {
    my @la = split /\t/;
    $name = $la[0];
    $type = $la[2];
    $seqlen = $la[5] = $la[4];
    if (defined($featurelist{$name})) {
        $count_dup++;
    } elsif ($name =~ /^#/) {
    } else {
	if (defined $cvlist{$type}) {
		$type_id = $cvlist{$type};
	} else {
		die("Error: $type not defined");
	}
        $q = "INSERT into feature (organism_id, name, uniquename, seqlen, type_id) values ($organism_id, '$name', '$name', $seqlen, $type_id)";
        print STDERR "$q\n";
        $sth = $dbh->prepare($q);
        $sth->execute();
        $featurelist{$name} = 1;
    }
}
print STDERR  "count duplicate $count_dup\n";


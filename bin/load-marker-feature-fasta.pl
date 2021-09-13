
=head1 NAME
 load-marker-features-assembly.pl - load markers from csv file

=head1 SYNOPSYS

load-marker-features.pl -p [password] -H [hostname] -D [database name]

=head1 AUTHOR

Clay Birkett <clb34@cornell.edu>

=cut

#this script add flanking sequence from FASTA file for a given assembly
#if entries already exist in db then it will be skipped
#to update entries, the table should be cleared with truncate table feature CASCADE
#get featureloc from materialized_markerview
#the features (chromosomes) for reference genome should have been loaded
#the program code should be modified for each run with the correct reference_genome_name, organism_id, and blast database

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
my $in_file;
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
my $species;
my %cvlist;
my %organismlist;
my %featurelist;

print STDERR "reading in cvterms\n";
my $q = "SELECT cvterm_id, name from cvterm";
$sth = $dbh->prepare($q);
$sth->execute();
while (@row = $sth->fetchrow_array) {
    $name = $row[1];
    $cvlist{$name} = $row[0]
}
print STDERR "reading in organisms\n";
$q = "SELECT organism_id, species from public.organism";
$sth = $dbh->prepare($q);
$sth->execute();
while (@row = $sth->fetchrow_array) {
    $name = $row[1];
    $organismlist{$name} = $row[0];
}

my $desTypeId;
my $markerTypeId;
my $alleleTypeId;
my $flankingTypeId;
if (defined $cvlist{"description"}) {
    $desTypeId = $cvlist{"description"};
} else {
    die("Error: description not defined\n");
}
if (defined $cvlist{"markers"}) {
    $markerTypeId = $cvlist{"markers"};
} else {
    die("Error: markers not defined\n");
}
if (defined $cvlist{"allele"}) {
    $alleleTypeId = $cvlist{"allele"};
} else {
    die("Error: allele not defined\n");
}
if (defined $cvlist{"flanking_region"}) {
    $flankingTypeId = $cvlist{"flanking_region"};
} else {
    die("Error: allele not defined\n");
}


print STDERR "reading in genotyping results\n";
my $count = 0;
my %locChrList;
my %locPosList;
my %locRefList;
my %locSpecList;
my %locAlleleList;
$q = "SELECT species_name, marker_name, chrom, pos, ref, alt from materialized_markerview where reference_genome_name = 'Morex v2'";
$sth = $dbh->prepare($q);
$sth->execute();
while (@row = $sth->fetchrow_array) {
    if ($row[2] =~ /[0-9][A-Z]/) {
    $count++;
    $name = $row[1];
    $locChrList{$name} = $row[2];
    $locPosList{$name} = $row[3];
    $locSpecList{$name} = $row[0];
    $locAlleleList{$name} = "$row[4]/$row[5]";
    }
}
print "$count from materialized_markerview\n";

print STDERR "reading in features\n";
$q = "SELECT feature_id, name from feature";
$sth = $dbh->prepare($q);
$sth->execute();
while (@row = $sth->fetchrow_array) {
    $name = $row[1];
    $featurelist{$name} = $row[0];
}

#my $organism_id = 38385; # T.aestivum   | Triticum               | Triticum aestivum  
#my $organism_id = 34452; # T.aestivum   | Triticum               | Triticum durum
my $organism_id = 105101; # H.vulgare   | Hordeum       | Hordeum vulgare
my $type = 'SNP';
my $chrom;
my $seq;
my $fmin;
my $fmax;
my $cmd;
my $allele;
my $seqtrim;
my $reference;
my $seqlen = 0;
my $count_dup = 0;
my $feature_id;
my $srcfeature_id;
my $start;
my $stop;
my $a_allele;
my $b_allele;
my $flankL;
my $flankR;

print STDERR "processing marker materialized view\n";
foreach $name (keys %locChrList) {
	    $feature_id = $featurelist{$name};
            $chrom = $locChrList{$name};
	    $fmin = $locPosList{$name};
	    $fmax = $locPosList{$name} + 1;
	    $species = $locSpecList{$name};
	    $allele = $locAlleleList{$name};
	    #$chrom =~ s/chr//;
	    #$chrom =~ s/UN/Un/;
	    if ($chrom =~ /chr/) {
	    } else {
		$chrom = "chr" . $chrom;
	    }
	    if (defined($featurelist{$name})) {
		next;
	    }
	    if ($allele =~ /([A-Z]+)\/([A-Z]+)/) {
		$a_allele = $1;
		$b_allele = $2;
	    } else {
		print STDERR "Error in allele: $allele\n";
	    }
	    if (defined($organismlist{$species})) {
		$organism_id = $organismlist{$species};
	    } else {
		print STDERR "$name $species no species\n";
		next;
	    }
	    $count++;

	$start = $fmin - 63;
	$stop = $fmin + 63;
	print STDERR "$name $chrom $species\n";
	#$cmd = "blastdbcmd -db /opt/breedbase/mnt/blast_databases/triticum/durum -entry $chrom -range $start-$stop -out /home/production/tmp/fasta.txt";
	#$cmd = "blastdbcmd -db /home/production/cxgn_blast_databases/durum -entry $chrom -range $start-$stop -out /home/production/tmp/fasta.txt"; 
	 $cmd = "blastdbcmd -db /home/production/cxgn_blast_databases/barley_ibsc_v2 -entry $chrom -range $start-$stop -out /home/production/tmp/fasta.txt";
	 #print STDERR "$cmd\n";
	system($cmd);
	$in_file = "/home/production/tmp/fasta.txt";
	if(-e $in_file) {
           $seqtrim = "";
	   open (IN, "<$in_file") or die "couldn't open $in_file for reading: $!";
           while(<IN>) {
	       if ($_ =~ /^>/) {
	       } else {
	           $seqtrim .= $_;
               }
	   }
	} else {
	   print "ERROR: no $in_file\n";
	}
	$seqtrim =~ s/\s+//g;
	$flankL = substr($seqtrim, 0, 62);
	$flankR = substr($seqtrim, 63, 63);
	#for durum the SNPs where not called all we know is location
	#if (substr($seqtrim, 62) eq $a_allele) {
	    $seq = substr($seqtrim, 0, 62) . "[" . $allele . "]" . substr($seqtrim, 63, 63);;
	    #} else {
	    #    print STDERR "Error $name $allele\n$seqtrim\n$flankL\n$flankR\n";
	    #next;
	    #}
	$seqlen = length($seqtrim);
	$q = "INSERT into feature (organism_id, name, uniquename, seqlen, type_id, residues) values ($organism_id, '$name', '$name', $seqlen, $markerTypeId, '$seqtrim') returning feature_id";
	#print STDERR "$q\n";
	$sth = $dbh->prepare($q);
	$sth->execute();
	($feature_id) = $sth->fetchrow_array;

	if (defined($featurelist{$chrom})) {
            $srcfeature_id = $featurelist{$chrom};
	    $q = "INSERT into featureloc (feature_id, srcfeature_id, fmin, fmax) values ($feature_id, $srcfeature_id, $fmin, $fmax)";
	    #print STDERR "$q\n";
	    $sth = $dbh->prepare($q);
	    $sth->execute();
	} else {
	    print "Error: $name $chrom no location\n";
	}
	$q = "INSERT into featureprop (feature_id, type_id, value ) values ($feature_id, $desTypeId, '$type')";
	#print STDERR "$q\n";
	$sth = $dbh->prepare($q);
	$sth->execute();
	$q = "INSERT into featureprop (feature_id, type_id, value ) values ($feature_id, $alleleTypeId, '$allele')";
	#print STDERR "$q\n";
        $sth = $dbh->prepare($q);
	$sth->execute();
	$q = "INSERT into featureprop (feature_id, type_id, value ) values ($feature_id, $flankingTypeId, '$seq')";
	#print STDERR "$q\n";
        $sth = $dbh->prepare($q);
	$sth->execute();

	if ($count % 100) {
	    print STDERR "Done $count\n";
	    #die "Done one entry\n";
	}
    
}
print STDERR  "count duplicate $count_dup\n";



=head1 NAME
 load-marker-features.pl - load markers from csv file

=head1 SYNOPSYS

load-marker-features.pl -p [password] -H [hostname] -D [database name] file

=head1 AUTHOR

Clay Birkett <clb34@cornell.edu>

=cut

#this script load flanking sequence from a file, used to load sequence from old T3 site
#if entries already exist in db then it will be skipped
#to update entries they should be cleared with truncate table feature CASCADE
#get featureloc from genotype table
#the reference genome should be loaded before this script so that source_id can be found

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
#my $in_file = $opt_f || "/home/production/public/marker-flanking-seq.csv";
#my $in_file = $opt_f || "/home/production/public/T3oat_marker-flanking-seq.csv";
my $in_file = $opt_f || "/home/production/public/T2barley_marker-flanking-seq.csv";
my $dbuser = "postgres";

my $dbh = CXGN::DB::Connection->new( { dbhost=>$dbhost,
    dbname=>$dbname,
    dbpass=>$dbpass,
    dbuser=>$dbuser,
    dbargs=> {AutoCommit => 1,
    RaiseError => 1}
});

my @row;
my @row2;
my $sth;
my $sth2;
my $name;
my $species;
my %cvlist;
my %organismlist;
my %featurelist;
my %featureSourceList;
my %featureListGroup;

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

#adding source features, needed for Avena
#my $organism_id = 1599; # A.sativa     | Avena                  | Avena sativa
my $organism_id = 105101; # H.vulgare	| Hordeum	| Hordeum vulgare
#my $organism_id = 31675; # Hordeum
my $type_id = 66547; # chromosome
#my $assembly = 'Consensus_2018';
#my $assembly = 'PepsiCo_2019';
#my $assembly = 'PepsiCo 2019';
#my $assembly = 'IBSC';
my $assembly = 'Morex v2';
my $chrom;
my $uniquename;

$q = "SELECT feature_id, name from feature where type_id = $type_id and organism_id = $organism_id";
$sth = $dbh->prepare($q);
$sth->execute();
while (@row = $sth->fetchrow_array) {
    $featureSourceList{$row[1]} = $row[0];
    print "$row[1] = $row[0]\n";
}
   
$q = "SELECT distinct(chrom) from materialized_markerview where reference_genome_name = '$assembly'";
$sth = $dbh->prepare($q);
$sth->execute();
while (@row = $sth->fetchrow_array) {
    $chrom = $row[0];
    #    $chrom =~ s/chr//;
    if (defined($featureSourceList{$chrom})) {
	print STDERR "ignore duplicate chromosome $chrom\n";
    } else {
    $uniquename = "$chrom $assembly";
    #$q = "INSERT into feature (organism_id, name, uniquename, type_id, seqlen, residues) values ($organism_id, '$chrom', '$uniquename', $type_id, 1000000000, '$assembly') returning feature_id";
    $q = "INSERT into feature (organism_id, name, uniquename, type_id, seqlen, residues) values ($organism_id, '$chrom', '$chrom', $type_id, 1000000000, '$assembly') returning feature_id";
    print STDERR "$q\n";
    $sth2 = $dbh->prepare($q);
    $sth2->execute();
    @row2 = $sth2->fetchrow_array;
    $featureSourceList{$chrom} = $row2[0];
        print "added $chrom = $row2[0]\n";
    }
}

print STDERR "reading in genotyping results\n";
my %locChrList;
my %locPosList;
my %locRefList;
my %locSpecList;
$q = "SELECT species_name, marker_name, chrom, pos, reference_genome_name from materialized_markerview where reference_genome_name = 'RefSeq_v1'";
$q = "SELECT species_name, marker_name, chrom, pos, reference_genome_name from materialized_markerview where reference_genome_name = 'Consensus_2018'";
$q = "SELECT species_name, marker_name, chrom, pos, reference_genome_name from materialized_markerview where reference_genome_name = '$assembly'";
$sth = $dbh->prepare($q);
$sth->execute();
while (@row = $sth->fetchrow_array) {
    $name = $row[1];
    $locChrList{$name} = $row[2];
    $locPosList{$name} = $row[3];
    $locRefList{$name} = $row[4];
    $locSpecList{$name} = $row[0];
}

#if marker in more than one reference then find highest locgroup
print STDERR "reading in features\n";
$q = "SELECT feature.feature_id, name, locgroup from feature, featureloc where feature.feature_id = featureloc.feature_id order by locgroup";
$sth = $dbh->prepare($q);
$sth->execute();
while (@row = $sth->fetchrow_array) {
    $name = $row[1];
    $featurelist{$name} = $row[0];
    $featureListGroup{$name} = $row[2];
}

#my $organism_id = 38385; # T.aestivum   | Triticum               | Triticum aestivum  
#$organism_id = 1599; # A.sativa     | Avena                  | Avena sativa      
my $type;
my $seq;
my $fmin;
my $fmax;
my $allele;
my $seqtrim;
my $locgroup;
my $reference;
my $seqlen = 0;
my $count = 0;
my $count_dup = 0;
my $feature_id;
my $srcfeature_id;
my $countNoLoc = 0;

open (IN, "<$in_file") or die "couldn't open $in_file for reading: $!";
print STDERR "reading file $in_file\n";
while (<IN>) {
    my @la = split /,/;
    $name = $la[0];
    $type = $la[1];
    $seq = $la[2];
    if ($name =~ /^#/) {
    } else {
	if (defined($locChrList{$name})) {
            $chrom = $locChrList{$name};
	    $fmin = $locPosList{$name};
	    $fmax = $locPosList{$name} + 1;
	    $species = $locSpecList{$name};
	    $reference = $locRefList{$name};
	    #$chrom =~ s/chr//;
	    $chrom =~ s/UNK/Un/;
	    $chrom =~ s/UN/Un/;
	    if (defined($organismlist{$species})) {
		#$organism_id = $organismlist{$species};
		#print "$name $chrom $fmin $fmax\n";
	    } else {
		print STDERR "$name $species no species\n";
		next;
	    }
	} else {
	    #print STDERR "$name no location\n";
	    $countNoLoc++;
	    next;
	}
	$seq =~ s/\s+//g;
	$seqtrim = $seq;
	if ($seqtrim =~ /\[[A-Z\/]+\]/) {
	   $seqtrim =~ s/([A-Za-z]*)\[([A-Z]+)([A-Z\/]+)\]([A-Za-z]*)/$1$2$4/;
	   $allele = "$2$3";
	} else {
	    print STDERR "$name bad seq $seq\n";
	}
	if (defined($featurelist{$name})) {
	    $count_dup++;
	    $feature_id = $featurelist{$name};
	    $locgroup = $featureListGroup{$name} + 1;
	    #print STDERR "$name duplicate location\n";
	} else {
	    $count++;
	    $locgroup = 0;
	    $seqlen = length($seqtrim);
	    $q = "INSERT into feature (organism_id, name, uniquename, seqlen, type_id, residues) values ($organism_id, '$name', '$name', $seqlen, $markerTypeId, '$seqtrim') returning feature_id";
	    #print STDERR "$q\n";
	    $sth = $dbh->prepare($q);
	    $sth->execute();
	    @row = $sth->fetchrow_array;
	    $feature_id = $row[0];
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
        }
	if (defined($featureSourceList{$chrom})) {
            $srcfeature_id = $featureSourceList{$chrom};
	    $q = "INSERT into featureloc (feature_id, srcfeature_id, fmin, fmax, locgroup) values ($feature_id, $srcfeature_id, $fmin, $fmax, $locgroup)";
	    #$q = "INSERT into featureloc (feature_id, srcfeature_id, fmin, fmax) values ($feature_id, $srcfeature_id, $fmin, $fmax)";
	    #print STDERR "$q\n";
	    $sth = $dbh->prepare($q);
	    $sth->execute();
	} else {
	    print STDERR "$name $chrom no source feature\n";
	}

	if (($count % 1000) == 0) {
	    print STDERR "Done $count\n";
	    #die();
	}
    }
}
print STDERR  "count duplicate $count_dup\n";
print STDERR "count no location $countNoLoc\n";	


=head1 NAME
 get-links.pl - get external links to marker, accessions, traits, etc

=head1 SYNOPSYS

get-links.pl -p [password] -H [hostname] -D [database name] file

=head1 AUTHOR

Clay Birkett <clb34@cornell.edu>

=cut

# https://urgi.versailles.inra.fr/wheatis/join#tsv-tabulation-separated-values
# format is name, url, description, entryType, species, node, database
# entryType (Genetic marker, Physical marker, Marker, Germplasm, Phenotyping Study, Genotyping Experiment, Genetic map, GWAS analysis, Physical map, Study
#
# stock.type_id = cvterm.cvterm_id

use strict;
use warnings;

use Getopt::Std;
use CXGN::DB::InsertDBH;
use CXGN::Chado::Dbxref;

our ($opt_H, $opt_D, $opt_p);
getopts('p:H:D:');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dbpass = $opt_p;
my $dbuser = "postgres";

my $dbh = CXGN::DB::Connection->new( { dbhost=>$dbhost,
    dbname=>$dbname,
    dbpass=>$dbpass,
    dbuser=>$dbuser,
    dbargs=> {AutoCommit => 1,
    RaiseError => 1}
});

my @row;
my $alias = "";
my $marker_id = "";
my $q = "SELECT alias, marker_id FROM sgn.marker_alias";
my $sth = $dbh->prepare($q);
$sth->execute();
while (@row = $sth->fetchrow_array) {
    $alias = $row[0];
    $marker_id = $row[1];
    #print STDERR "$alias\n";
}

#Genotype Experiments

my $file = "experiments.tsv";
my $project_id = "";
my $desc = "";
my $name = "";
open(my $fh, ">", $file) or die("Can't open $file\n");
print STDERR "creating experiment file\n";
$q = "SELECT project.project_id, name, description from project, projectprop where project.project_id = projectprop.project_id and type_id = 76666 and rank = 0";
$sth = $dbh->prepare($q);
$sth->execute();
while(@row = $sth->fetchrow_array) {
    $project_id = $row[0];
    $name = $row[1];
    $desc = $row[2];
    $desc =~ s/\r//g;
    $desc =~ s/\n/ /g;
    print $fh "$name\tGenotyping Experiment\tT3\tThe Triticeae Toolbox\thttps://wheat.triticeaetoolbox.org/breeders/trial/$project_id\tTriticum\t$name $desc\n";
}

#Phenotype Experiments

$q = "SELECT project.project_id, name, description from project, projectprop where project.project_id = projectprop.project_id and type_id = 76475 and rank = 0";
$sth = $dbh->prepare($q);
$sth->execute();
while(@row = $sth->fetchrow_array) {
    $project_id = $row[0];
    $name = $row[1];
    $desc = $row[2];
    $desc =~ s/\r//g;
    $desc =~ s/\n/ /g;
    print $fh "$name\tPhenotyping Experiment\tT3\tThe Triticeae Toolbox\thttps://wheat.triticeaetoolbox.org/breeders/trial/$project_id\tTriticum\t$name $desc\n";
}
close($fh);

my $stock_id = "";
my $acc = "";
my $value = "";
$file = "accessions.tsv";

#type_id 76595 = institute name
#type_id 76594 = institute code
#type_id 76593 = seed source
#type_id 76588 = accession number
#type_id 76493 = organization
#type_id 76506 = stock_synonym
#type_id 76533 = is a control
#type_id 85453 = purdy pedigree
#type_id 84978 = sgn allele_id
#type_id 76658 = note
#
my @institute_code;
my @institute_name;
my @species_list;
my $allele_id;
my @allele_code;

open($fh, ">", $file) or die("Can't open $file\n");
print STDERR "creating accession file\n";
$q = "SELECT stock_id, value from stockprop where type_id = 76594 and rank = 0";
$sth = $dbh->prepare($q);
$sth->execute();
while(@row = $sth->fetchrow_array) {
   $stock_id = $row[0];
   $institute_code[$row[0]] = $row[1];
}
$q = "SELECT stock_id, value from stockprop where type_id = 84978";
$sth = $dbh->prepare($q);
$sth->execute();
while(@row = $sth->fetchrow_array) {
   $stock_id = $row[0];
   $allele_id = $row[1];
   $allele_code[$row[0]] = $row[1];
}

my $allele_symbol;
my $allele_name;
my @allele_list;
$q = "SELECT allele_id, allele_symbol, allele_name from phenome.allele";
$sth = $dbh->prepare($q);
$sth->execute();
while(@row = $sth->fetchrow_array) {
   $allele_id = $row[0];
   $allele_symbol = $row[1];
   $allele_name = $row[1];
   $allele_list[$row[0]] = "$allele_symbol $allele_name";
}

$q = "SELECT stock_id, value from stockprop where type_id = 76595";
$sth = $dbh->prepare($q);
$sth->execute();
while(@row = $sth->fetchrow_array) {
   $stock_id = $row[0];
   $institute_name[$row[0]] = $row[1];
}

$q = "SELECT organism_id, species from public.organism";
$sth = $dbh->prepare($q);
$sth->execute();
while(@row = $sth->fetchrow_array) {
   print STDERR "$row[0] $row[1]\n";
   $species_list[$row[0]] = $row[1];
}

#type_id 76393 = plot
#type_id 76427 = species
#type_id 76492 = population
#type_id 76392 = accession

my $organism_id;
my $species;
$q = "SELECT stock_id, organism_id, name from stock where type_id = 76392";
$sth = $dbh->prepare($q);
$sth->execute();
while(@row = $sth->fetchrow_array) {
    $stock_id = $row[0];
    $organism_id = $row[1];
    $acc = $row[2];
    $desc = $row[2];
    if (defined $species_list[$organism_id]) {
	    $species = $species_list[$organism_id];
    } else {
	    $species = "";
    }
    $desc =~ s/\r//g;
    $desc =~ s/\n/ /g;
    if (defined $institute_name[$stock_id]) {
	    $desc .= " $institute_name[$stock_id]";
    }
    print $fh "$acc\tGermplasm\tT3\tThe Triticeae Toolbox\thttps://wheat.triticeaetoolbox.org/stock/$stock_id/view\t$species\t$desc\n";
}

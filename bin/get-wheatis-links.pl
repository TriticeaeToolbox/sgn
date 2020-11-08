
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

#Germplasm

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
my $allele_ids_str;
my @allele_ids_list;
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
   if (defined($allele_code[$row[0]])) {
       $allele_code[$row[0]] .= ",$row[1]";
       #print STDERR "$stock_id $allele_code[$stock_id]\n";
   } else {
       $allele_code[$row[0]] = $row[1];
   }
}

my $locus_name;
my $allele_name;
my @allele_list;
$q = "SELECT allele_id, locus_id, allele_name from phenome.allele";
$q = "SELECT allele_id, locus_name, allele_name from phenome.allele, phenome.locus where phenome.allele.locus_id = phenome.locus.locus_id";
$sth = $dbh->prepare($q);
$sth->execute();
while(@row = $sth->fetchrow_array) {
   $allele_id = $row[0];
   $locus_name = $row[1];
   $allele_name = $row[2];
   $allele_list[$row[0]] = "$locus_name=$allele_name";
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
   #print STDERR "$row[0] $row[1]\n";
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
    my $gen_char = "";
    if (defined $allele_code[$stock_id]) {
        $allele_ids_str = $allele_code[$stock_id];
        @allele_ids_list = split(/,/, $allele_ids_str);
        #if (defined $allele_list[$allele_id]) {
        foreach ( @allele_ids_list ) {
            $allele_id = $_;
            if (defined($allele_list[$allele_id])) {
                if ($gen_char eq "") {
                    $gen_char = "Property $allele_list[$allele_id]";
                    $desc .= " $gen_char";
                } else {
                    $gen_char = $allele_list[$allele_id];
                    $desc .= ", $gen_char";
                }
            } else {
                #print STDERR "$allele_ids_str\n";
                #print STDERR "allele_id $allele_id not defined, stock_id = $stock_id $desc\n";
            }
        }
    }  
    if (defined $institute_name[$stock_id]) {
	    $desc .= " Institute $institute_name[$stock_id]";
    }
    print $fh "$acc\tGermplasm\tT3\tThe Triticeae Toolbox\thttps://wheat.triticeaetoolbox.org/stock/$stock_id/view\t$species\t$desc\n";
}
close($fh);

# Loci and Genes

$file = "gene.tsv";
open($fh, ">", $file) or die("Can't open $file\n");
print STDERR "creating gene file\n";

my $locus_id;
my $locus_symbol;
$q = "SELECT locus_id, locus_name, locus_symbol, description, linkage_group from phenome.locus where sp_person_id is NULL";
$sth = $dbh->prepare($q);
$sth->execute();
while(@row = $sth->fetchrow_array) {
    $locus_id = $row[0];
    $locus_name = $row[1];
    $locus_symbol = $row[2];
    if (defined $row[3]) {
        $desc = "$locus_name $locus_symbol $row[3]";
    } else {
        $desc = "$locus_name $locus_symbol";
    }
    print $fh "$locus_name\tGene\tT3\tThe Triticeae Toolbox\thttps://wheat.triticeaetoolbox.org/locus/$locus_id/view\tTriticum\t$desc\n";
}
close($fh);

# Markers
# add map and experiment in description for each marker

$file = "markers.tsv";
open($fh, ">", $file) or die("Can't open $file\n");
print STDERR "creating markers file\n";

my @map_name_list;
my $map_version_id;
$q = "SELECT map_version_id, short_name from sgn.map, sgn.map_version where sgn.map.map_id = sgn.map_version.map_id and current_version = true";
$sth = $dbh->prepare($q);
$sth->execute();
while(@row = $sth->fetchrow_array) {
    $map_version_id = $row[0];
    $map_name_list[$map_version_id] = $row[1];
}

my @lg_list;
my $lg_id;
my $lg_name;
$q = "SELECT lg_id, map_version_id, lg_name from sgn.linkage_group";
$sth = $dbh->prepare($q);
$sth->execute();
while(@row = $sth->fetchrow_array) {
    $lg_id = $row[0];
    $lg_name = $row[2];
    $lg_list[$lg_id] = $lg_name;
}

#get maps for markers
my $map_name;
my @map_list;
my $location_id;
my $position;
$q = "SELECT location_id, lg_id, map_version_id, round(position,2) from sgn.marker_location";
$sth = $dbh->prepare($q);
$sth->execute();
while(@row = $sth->fetchrow_array) {
    $location_id = $row[0];
    $lg_id = $row[1];
    $map_version_id = $row[2];
    $position = $row[3];
    $map_name = $map_name_list[$map_version_id];
    $lg_name = $lg_list[$lg_id];
    $map_list[$location_id] = "$map_name $lg_name $position";
}

#get experiments for markers
my $protocol;
my @location_list;
$q = "SELECT marker_id, location_id, protocol from sgn.marker_experiment";
$sth = $dbh->prepare($q);
$sth->execute();
while(@row = $sth->fetchrow_array) {
   $marker_id = $row[0];
   $location_id = $row[1];
   $protocol = $row[2];
   if (defined $location_list[$marker_id]) {
       $location_list[$marker_id] .= ", $map_list[$location_id]";
   } else {
       $location_list[$marker_id] = "$protocol $map_list[$location_id]";
   }
}

$q = "SELECT marker_id, alias from sgn.marker_alias";
$sth = $dbh->prepare($q);
$sth->execute();
while(@row = $sth->fetchrow_array) {
    $marker_id = $row[0];
    $alias = $row[1];
    if (defined $location_list[$marker_id]) {
      $desc = "$alias $location_list[$marker_id]"; 
      print $fh "$alias\tMarker\tT3\tThe Triticeae Toolbox\thttps://wheat.triticeaetoolbox.org/search/markers/markerinfo.pl?marker_id=$marker_id\tTriticum\t$desc\n";
    }
}



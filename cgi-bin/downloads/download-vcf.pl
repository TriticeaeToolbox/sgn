
# allows download of large VCF files
# input files should be gziped and indexed with tabix
# also requires a file with valid index values

use strict;
use warnings;

my $cgi = new CGI;

my $start = $cgi->param('start');
if (!$start) {
    $start = 0;
}
my $stop = $cgi->param('stop');
if (!$stop) {
    $stop = 0;
}
my $min = "";
my $max = "";

my $function = $cgi->param('function');
if (!$function) {
    use CXGN::Page;
    use CXGN::Page::FormattingHelpers qw/ page_title_html info_section_html /;
    my $page = CXGN::Page->new("VCF Download");
    my $title = page_title_html("VCF Download");
    $page->header("Downloads", $title);
    $page->jsan_use("download-vcf");

print "<h2>Download Genotype Data</h2>\n";
print "This tool allows you to quickly download a portion of a genotype experiment.<br>\n";
print "Select a genotype experiment, chromosome, and range.<br>\n";
print "The output format is Variant Call Format (VCF) and can be viewed in TASSEL.<br><br>\n";

my $option1 = "1kEC_genotype01222019";
my $option2 = "1kEC_genotype01222019f";
my $option3 = "all_filtered_snps_allaccessions_allploidy_snpeff";
my $option4 = "2019_hapmap";

print "<table>";
print "<tr><td>Genotype trial:<td><select id=trial onchange=\"getChromFile()\">";
print "<option value=$option1>2019_Diversity_GBS</option>\n";
print "<option value=$option2>2019_Diversity_GBS filtered</option>\n";
print "<option value=$option3>2017_WheatCAP_UCD</option>\n";
print "<option value=$option4>2019_HapMap</option>";
print "</select>\n";
print "<tr><td>Chromosome:<td><div id=\"step1\"><select id=chrom>";
print "<option>select</option>";
my $file_chr = "/home/production/genotype_files/1kEC_genotype01222019.txt";
open(IN, $file_chr);
while (<IN>) {
    chomp;
    print "<option value=$_>$_</option>\n";
}
close(IN);
print "</select></div>";
print "<tr><td>Start:<td><input type=\"text\" id=\"start\" value=\"$start\"><td>$min\n";
print "<tr><td>Stop:<td><input type=\"text\" id=\"stop\" value=\"$stop\"><td>$max\n";
print "<tr><td><input type=\"button\" value=\"Query\" onclick=\"select_chrom()\"/>";

print "</table>\n";

print "<div id=\"step2\">";

} elsif ($function eq "valid") {
    print "content-type: text/csv \n\n";
    print "Id,Trial\n";
    print "87,SeqCap_KSU_tabix\n";
    print "8123,2019_hapmap\n";
    print "8124,1kEC_genotype01222019\n";
    print "8125,2017_WheatCAP\n";
} elsif ($function eq "download") {
    my $filename = $cgi->param('filename');
    my $trial = $cgi->param('trial') . ".tsv";
    open(IN, $filename) or print STDERR "Error: $filename not found\n";;
    print "Content-type: application/vnd.ms-excel\n";
    print "Content-Disposition: attachment; filename=\"$filename\"\n";
    while (<IN>) {
	print "$_";
    }
    close(IN);
} elsif ($function eq "readChrom") {
    my $file_chr = "/home/production/genotype_files/" . $cgi->param('trial') . ".txt";
    open(IN, $file_chr) or print STDERR  "Error: $file_chr not found\n";
    print "<select id=chrom>";
    while (<IN>) {
        chomp;
        print "<option value=$_>$_</option>\n";
    }
    close(IN);
    print "</select>";
} else {
    my $trial = $cgi->param('trial'); 
    my $chrom = $cgi->param('chrom');
    my $file = "/home/production/genotype_files/" . $trial . ".vcf.gz";
    my $file_pas = "/home/production/genotype_files/" . $cgi->param('trial') . ".passport.xls";
    my $unique_str = int(rand(10000000));
    my $dir = "/export/prod/tmp/triticum-site/wheat.triticeaetoolbox.org/download_" . $unique_str;
    if ( !-d "/export/prod/tmp/triticum-site/wheat.triticeaetoolbox.org") {
	mkdir "/export/prod/tmp/triticum-site/wheat.triticeaetoolbox.org";
    }
    if ($chrom =~ /([a-z]*[A-Z0-9]+)/) {
        $chrom = $1;
    } else {
        print "Select a chromosome";
        die;
    }
    unless(mkdir $dir) {
        die "Unable to create $dir\n";
    }
    my $filename1 = $dir . "/" . $trial . ".vcf";
    my $filename2 = $dir . "/proc_error.txt";
    my $filename3 = $trial . ".vcf";

    my $cmd = "tabix -h $file $chrom:$start-$stop > $filename1 2> $filename2";
    #print "$cmd<br>\n";
    system($cmd);

    my $count = 0;
    my $errorLog = "";
    if (-e $filename2) {
        open(IN, $filename2);
        while (<IN>) {
            $errorLog .= $_;
        }
        close(IN);
    }
    if (-e $filename1) {
	open(IN, $filename1);
        while (<IN>) {
            if (!/^#/) {
                $count++;
            }
        }
        close(IN);
    }
    if (($errorLog ne "") && ($count != 0)) {
        print "Content-type: text/plain\n";
        print "Content-Disposition: attachment; filename=\"$trial\"\n";
        print "$errorLog\n";
    } elsif ($function eq "queryDownload") {
        print "Content-type: application/vnd.ms-excel\n";
        print "Content-Disposition: attachment; filename=\"$filename3\"\n";
        if (-e $filename1) {
            open(IN, $filename1);
            while (<IN>) {
              print "$_";
            }
        }
        close(IN);
    } else {
      if ($count > 0) {
          #print "<input type=\"button\" value=\"Download $count markers from $chrom:$start-$stop\" onclick=\"javascript:window.open('$filename1')\">";
          print "<br><input type=\"button\" value=\"Download $count markers from $chrom:$start-$stop\" onclick=\"javascript:output_file('$filename1','$trial')\"><br>";
      } else {
          print "<br><input type=\"button\" value=\"Error: no results from $chrom:$start-$stop\"><br>";
	  #print "$cmd\n";
      }
      if (-e $file_pas) {
        print "<br><input type=\"button\" value=\"Download Passport Data\" onclick=\"javascript:output_file('$file_pas','PassportData.xls')\">";
      }

    }
}
print "</div>";

#$page->footer();
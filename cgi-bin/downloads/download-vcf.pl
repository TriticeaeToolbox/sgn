
use strict;

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
print "The output format is Variant Call Format (VCF) and can be viewed in TASSEL.<br>\n";
print "<a href=genotyping/PassportData_160809.xlsx>Passport MetaData</a><br><br>\n";

my $option1 = "1kEC_genotype01222019";
my $option2 = "1kEC_genotype01222019f";
my $option3 = "all_filtered_snps_allaccessions_allploidy_snpeff";
my $option4 = "2019_hapmap";

print "<table>";
print "<tr><td>Genotype trial:<td><select id=trial>";
print "<option value=$option1> 2019_Diversity_GBS</option>\n";
print "<option value=$option2> 2019_Diversity_GBS filtered</option>\n";
print "<option value=$option3>2017_WheatCAP_UCD</option>\n";
print "<option value=$option4>2019_HapMap</option>";
print "</select>\n";
print "<tr><td>Chromosome:<td><select id=chrom>";
print "<option>select</option>";
my $file_chr = "1kEC_chromosomes.txt";
open(IN, $file_chr);
while (<IN>) {
    chomp;
    print "<option value=$_>$_</option>\n";
}
close(IN);
print "</select>";
print "<tr><td>Start:<td><input type=\"text\" id=\"start\" value=\"$start\"><td>$min\n";
print "<tr><td>Stop:<td><input type=\"text\" id=\"stop\" value=\"$stop\"><td>$max\n";
print "<tr><td><input type=\"button\" value=\"Query\" onclick=\"select_chrom()\"/>";

print "</table>\n";

print "<div id=\"step2\">";

} else {
    my $trial = $cgi->param('trial'); 
    my $chrom = $cgi->param('chrom');
    my $file = "/home/production/genotype_files/" . $trial . ".vcf.gz";
    my $unique_str = int(rand(10000000));
    my $dir = "/export/prod/tmp/triticum-site/wheat.triticeaetoolbox.org/download_" . $unique_str;
    if ($chrom =~ /([a-z]*[A-Z0-9]+)/) {
        $chrom = $1;
    } else {
        print "Select a chromosome";
        die;
    }
    unless(mkdir $dir) {
        die "Unable to create $dir\n";
    }
    my $filename1 = $dir . "/genotype.vcf";
    my $filename2 = $dir . "/proc_error.txt";

    my $cmd = "tabix -h $file $chrom:$start-$stop > $filename1 2> $filename2";
    #print "$cmd<br>\n";
    system($cmd);

    if (-e $filename2) {
        open(IN, $filename2);
        while (<IN>) {
            print $_;
        }
        close(IN);
    }
    my $count = 0;
    if (-e $filename1) {
        open(IN, $filename1);
        while (<IN>) {
            if (!/^#/) {
                $count++;
            }
        }
        close(IN);
    }
    if ($count > 0) {
        print "<input type=\"button\" value=\"Download $count markers from $chrom:$start-$stop\" onclick=\"javascript:window.open('$filename1')\">";
    } else {
        print "Error: no results from $chrom:$start-$stop<br>\n";
        print "$cmd\n";
    }
}

#$page->footer();

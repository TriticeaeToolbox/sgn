
use strict;
use warnings;
use CXGN::DB::Connection;

my $cgi = new CGI;

my $function = $cgi->param('function');
if (!$function) {
    use CXGN::Page;
    use CXGN::Page::FormattingHelpers qw | page_title_html columnar_table_html blue_section_html |;

    my $page = CXGN::Page->new();

    $page->header();
    $page->jsan_use("genome-gwas");

    my $page_title = page_title_html("GWAS Results");

    print <<HTML;

    $page_title
    <br/>
        This analysis can be used to identify quantitative trait locus (QTL) by displaying associations between
        markers and traits for trials within the T3 database.<br>
        <b>Analysis Methods:</b> The analysis includes genotype and phenotype trials where there were more than 50
        germplasm lines in common.<br>
        1. Trial Analysis - GWAS with no fixed effects.<br>
        2. Breeding Program Analysis - GWAS on a set of related phenotype trials
        (different location and same year or same location different year).
        Principle Components that accounted for more than 5% of the relationship matrix variance were included as fixed effects in the analysis.
        Each phenotype trial (if more than one) was included as a fixed effect.<br>
        <b>GWAS:</b> The analysis use rrBLUP GWAS package (Endleman, Jeffery, "Ridge Regression and Other Kernels for Genomic Selection with R package rrBLUP", The Plant Genome Vol 4 no. 3).
        The settings are: MAF > 0.05, P3D = TRUE (equivalent to EMMAX).
        The q-value is an estimate of significance given p-values from multiple comparisons using a false discovery rate of 0.05.<br>
        The z-value = qnorm( 1.0 - ( pvalue / 2.0 ))<br>
    <hr/>
HTML

my $start = $cgi->param('start');
my $stop = $cgi->param('stop');
my $min = "";
my $max = "";

my $id;
my $name;
my $dbh = CXGN::DB::Connection->new();

print "<table>";
print "<tr><td>Trait:<td><select id=protocol onchange=\"select_markers()\">";
my $q = "select distinct(trait), variable from genomic.gwas_report order by trait";
my $protocol_q = $dbh->prepare($q);
$protocol_q->execute();
while (my @row = $protocol_q->fetchrow_array()) {
    $name = $row[0];
    $id = $row[1];
    print "<option value=$id>$name</option>";
}
print "</select>";
print "<tr><td>Analysis Method:<td><input type=\"radio\" id=\"1\" name=\"method\" value=\"1\" onchange=\"select_markers()\" checked> trial<br>";
print "<input type=\"radio\" id=\"3\" name=\"method\" value=\"3\" onchange=\"select_markers()\"> breeding program<br>";
print "</table><br>";
print "<div id=\"step3\"></div>";

print <<HTML;
    <link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/1.10.22/css/jquery.dataTables.css">
    <script type="text/javascript">
    if ( window.addEventListener ) {
        window.addEventListener( "load", select_markers(), false );
    } else if (window.onload) {
        window.onload = select_markers();
    }
    </script>
    <script type="text/javascript" charset="utf8" src="https://cdn.datatables.net/1.10.22/js/jquery.dataTables.js"></script>
HTML

$page->footer();
} elsif ($function eq "getChrom") {
    my $dbh = CXGN::DB::Connection->new();
    my $protocol = $cgi->param('prot');
    my $q = "select distinct(s.value->>'chrom') from nd_protocolprop, jsonb_each(nd_protocolprop.value) as s where nd_protocol_id = ? and type_id = 84975 order by s.value->>'chrom'";
    my $chrom_q = $dbh->prepare($q) or die $dbh->errstr;
    $chrom_q->execute($protocol);
    print "<select id=chrom>";
    while (my ($chrom) = $chrom_q->fetchrow_array()) {
	# we only want chromosomes 1A, 1B, ... because these are the only ones that map to MNase and VEP
	if ($chrom =~ /\d[ABD]$/) {
	    print "<option value=$chrom>$chrom</option>";
	}
    }
    print "</select>\n";
} elsif ($function eq "getVEP") {
} else {
    my $dbh = CXGN::DB::Connection->new();
    my $protocol = $cgi->param('prot');
    my $method = $cgi->param('method');
    my $count = 0;
    my $value;
    my $name;
    my $type_id;
    my $pos;
    my $chrom;
    my $score;
    my $feature;
    my $feature_list;
    my $linkGene;
    my $linkJB;
    my $linkKN;
    my $linkEP;
    my @vep_list;
    my $countF;

    my $chromM = $chrom;

    my $q = "select url from public.db where name = 'KnetMiner'";
    my $sth = $dbh->prepare($q) or die $dbh->errstr;
    $sth->execute();
    my ($knet_url) = $sth->fetchrow_array();
    $q = "select url from public.db where name = 'Ensembl'";
    $sth = $dbh->prepare($q) or die $dbh->errstr;
    $sth->execute();
    my ($ensembl_url) = $sth->fetchrow_array();
    $q = "select url from public.db where name = 'JBrowse'";
    $sth = $dbh->prepare($q) or die $dbh->errstr;
    $sth->execute();
    my ($jbrowse_url) = $sth->fetchrow_array();

    $q = "select marker_name, gene, population, trait, zvalue, qvalue, pvalue, description, chromosome from gwas_report where variable = ? and method = ?";
    my $marker_q = $dbh->prepare($q) or die $dbh->errstr;

    $q = "select name from feature, featureloc where feature.feature_id = featureloc.feature_id and type_id = 75352 and (fmin <= ?) and (fmax > ?)";
    my $feature_q = $dbh->prepare($q) or die $dbh->errstr;

    $marker_q->execute($protocol, $method);
    print "<table id=\"mnase\" class=\"display\"><thead><tr><th>marker<th>chrom<th>gene<th>population<th>description<th>zvalue<th>qvalue<th>pvalue<th>Ensembl JBrowse KnetMiner\n";
    print "<tbody>";
    while (my ($marker_name, $gene, $population, $trait, $zvalue, $qvalue, $pvalue, $description, $chrom) = $marker_q->fetchrow_array()) {
        if ((defined $gene) && (defined $ensembl_url)) {
 	    $linkEP = "<a href=\"https://" . $ensembl_url . "?g=$gene\" target=\"_blank\"><img src=\"/static/img/ep.png\" style=\"width:20px;height:20px;\"></a>";
	} else {
	    $linkEP = "";
	}
	if (defined $jbrowse_url) {
            if (defined $gene) {
		$linkJB = "<a href=\"https://" . $jbrowse_url . "&loc=$gene\" target=\"_blank\"><img src=\"/static/img/GG-logo.png\" style=\"width:20px;height:20px;\"></a>";
	    } else {
	        $linkJB = "<a href=\"https://" . $jbrowse_url . "&loc=$marker_name\" target=\"_blank\"><img src=\"/static/img/GG-logo.png\" style=\"width:20px;height:20px;\"></a>";
	    }
	} else {
	    $linkJB = "";
        }
	if ((defined $gene) && (defined $knet_url)) {
	    $linkKN = "<a href=\"https://" . $knet_url . "?keyword=$trait&list=$gene\" target=\"_blank\"><img src=\"/static/img/kn.png\" style=\"width:20px;height:20px;\"></a>";
        } else {
	    $linkKN = "";
	}
	if (!defined $gene) {
	    $gene = "";
	}
	$zvalue = sprintf("%.2f", $zvalue);
	$qvalue = sprintf("%.1e", $qvalue);
	$pvalue = sprintf("%.1e", $pvalue);
	print "<tr><td>$marker_name<td>$chrom<td>$gene<td>$population<td>$description<td>$zvalue<td>$qvalue<td>$pvalue<td>$linkEP $linkJB $linkKN";
    }
    print "</tbody></table>";
    print <<HTML;
    <script type="text/javascript">
    jQuery(document).ready(function() {
        jQuery('#mnase').DataTable( {
	    "paging": false,
	    "order": [5, 'desc']
	} );
    } );
    </script>
HTML
}

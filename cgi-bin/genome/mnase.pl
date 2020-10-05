
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
    $page->jsan_use("genome-mnase");

    my $page_title = page_title_html("MNase chromatin and VEP Results");

    print <<HTML;

    $page_title
    <br/>
        This report provides the chromatin accessibility score for Chinese Spring using RefSeq v1 assembly. A higher score corresponds to more open chromatin.
	The accessibility score can be used to prioritize genomic variants and to explain phenotypes.<br>
	The MNase chromatin results are described in <a href="https://genomebiology.biomedcentral.com/track/pdf/10.1186/s13059-020-02093-1">Wheat MNase publication</a>.<br>
	The <b>accessibility score</b> is a calculation of the differential nuclease sensitivity (DNS) for 10-bp intervals across the genome.<br>
	The <b>MSF/MRF</b> is the MNase sensitive and resistant footprint. It segments the genome using the iSeg program based on regions > 1.5 Std Dev of accessibility score.<br>
        The <b>gene, consequence, and impact</b> columns lists the results of the
        <a href="http://plants.ensembl.org/info/docs/tools/vep/index.html" target="_blank"> Variant Effect Predictor</a> analysis if available, otherwise it lists the genes that are within the gene model.
    <hr/>
HTML

my $start = $cgi->param('start');
if (!$start) {
    $start = 0;
}
my $stop = $cgi->param('stop');
if (!$stop) {
    $stop = 10000000;
}
my $min = "";
my $max = "";

my $id;
my $name;
my $dbh = CXGN::DB::Connection->new();

print "<table>";
print "<tr><td>Genotype Protocol:<td><select id=protocol onchange=\"getChrom()\">";
my $q = "select nd_protocol_id, name from nd_protocol order by name";
my $protocol_q = $dbh->prepare($q);
$protocol_q->execute();
while (my @row = $protocol_q->fetchrow_array()) {
    $id = $row[0];
    $name = $row[1];
    print "<option value=$id>$name</option>";
}
print "</select><td><div id=\"step2\"></div>";
print "<tr><td>Chromosome:<td><div id=\"step1\"><select id=chrom>";
print "</select></div>";
print "<tr><td>Start:<td><input type=\"text\" id=\"start\" value=\"$start\"><td>$min\n";
print "<tr><td>Stop:<td><input type=\"text\" id=\"stop\" value=\"$stop\"><td>$max\n";
print "</table><br>";
print "<input type=\"button\" value=\"Search\" onclick=\"select_markers()\" id=\"SearchButton\"/><br><br>";
print "<div id=\"step3\"></div>";

print <<HTML;
    <link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/1.10.22/css/jquery.dataTables.css">
    <script type="text/javascript">
    if ( window.addEventListener ) {
        window.addEventListener( "load", getChrom(), false );
    } else if (window.onload) {
        window.onload = getChrom();
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
	if ($chrom =~ /\d\w$/) {
	    print "<option value=$chrom>$chrom</option>";
	}
    }
    print "</select>\n";
} elsif ($function eq "getVEP") {
    my $protocol = $cgi->param('prot');
    my $file = $protocol . ".html";
    print "<a href=\"/static_content/files/$file\" target=\"_blank\">VEP stats</a>";
} else {
    my $protocolprop_marker_hash_select = ['name', 'chrom', 'pos', 'alt', 'ref']; #THESE ARE THE KEYS IN THE MARKERS OBJECT IN THE PROTOCOLPROP OBJECT
    my $dbh = CXGN::DB::Connection->new();
    my $count = 0;
    my $value;
    my $name;
    my $type_id;
    my $chrom = $cgi->param('chrom');
    my $start = $cgi->param('start');
    my $stop = $cgi->param('stop');
    my $geneSearch = "gene:TraesCS" . $chrom;
    my $pos;
    my $score;
    my $feature;
    my $feature_list;
    my @vep_list;
    my $countF;
    my $protocol = $cgi->param('prot');

    my $chromM = $chrom;
    if ($chrom =~ /chr(\d\w)/) {
	$chromM = $1;
    }
    my @protocolprop_marker_hash_select_arr;
    foreach (@$protocolprop_marker_hash_select){
        push @protocolprop_marker_hash_select_arr, "s.value->>'$_'";
    }
    my $protocolprop_hash_select_sql = scalar(@protocolprop_marker_hash_select_arr) > 0 ? ', '.join ',', @protocolprop_marker_hash_select_arr : '';
    my $q = "select s.key $protocolprop_hash_select_sql from nd_protocolprop, jsonb_each(nd_protocolprop.value) as s";
        $q .= " where nd_protocol_id = $protocol and type_id = 84975 and (s.value->>'chrom' = ?) and (cast(s.value->>'pos' as integer) between ? and ?)";
    my $marker_q = $dbh->prepare($q) or die $dbh->errstr;

    $q = "select accessibility from genomic.mnase where chrom = ? and (start <= ?) and (stop > ?)";
    my $dns_q = $dbh->prepare($q) or die $dbh->errstr;

    $q = "select score from genomic.mnase_msf where chrom = ? and (start <= ?) and (stop > ?)";
    my $msf_q = $dbh->prepare($q) or die $dbh->errstr;

    $q = "select score from genomic.mnase_mrf where chrom = ? and (start <= ?) and (stop > ?)";
    my $mrf_q = $dbh->prepare($q) or die $dbh->errstr;

    $q = "select name from feature, featureloc where feature.feature_id = featureloc.feature_id and (? between fmin and fmax) and type_id = 75352 and name like '$geneSearch%'";
    my $feature_q = $dbh->prepare($q) or die $dbh->errstr;

    $q = "select gene, feature, consequence, impact from genomic.vep_annotations where marker_name = ?";
    my $vep_q = $dbh->prepare($q);

    $marker_q->execute($chrom, $start, $stop);
    print "<style type=\"text/css\">";
    print "td { padding: 0 35px 0 35px; }";
    print "</style>";
    print "<table id=\"mnase\" class=\"display\"><thead><tr><th>marker<th>chromosome<th>position<th>score<th>MSF/MRF<th>gene<th>consequence<th>impact\n";
    print "<tbody>";
    while (my ($marker_name, @protocolprop_info_return) = $marker_q->fetchrow_array()) {
    	$count++;
	my $feature_list = "";
	my @vep_list;
	$name = $protocolprop_info_return[0];
	$chrom = $protocolprop_info_return[1];
	$pos = $protocolprop_info_return[2];
	$dns_q->execute($chromM,$pos, $pos);
	if ($score = $dns_q->fetchrow_array()) {
	    $score = sprintf("%.2f", $score);
	    print "<tr><td>$name<td>$chrom<td>$pos<td>$score<td>";
	} else {
	    print "<tr><td>$name<td>$chrom<td>$pos<td>not found<td>";
	}
	$msf_q->execute($chromM,$pos, $pos);
	if ($score = $msf_q->fetchrow_array()) {
	    print "Sensitive";
	}
	$mrf_q->execute($chromM,$pos, $pos);
        if ($score = $mrf_q->fetchrow_array()) {
            print "Resistant";
        }

	print "<td nowrap>";
	$vep_q->execute($name);
	while (my ($gene, $feature, $consequence, $impact) = $vep_q->fetchrow_array()) {
	    $countF = @vep_list;
	    if ($countF == 0) {
		$vep_list[1] = "$feature <a href=\"https://plants.ensembl.org/Triticum_aestivum/Gene/Summary?g=$feature\" target=\"_blank\"> Ensembl</a> 
		    <a href=\"https://wheat.pw.usda.gov/jb/?data=/ggds/whe-iwgsc2018&loc=$gene\" target=\"_blank\"> JBrowse</a>";
		$vep_list[2] = "$consequence";
		$vep_list[3] = "$impact";
	    } else {
                $vep_list[1] .= "<br>$feature <a href=\"https://plants.ensembl.org/Triticum_aestivum/Gene/Summary?g=$feature\" target=\"_blank\"> Ensembl</a> 
		    <a href=\"https://wheat.pw.usda.gov/jb/?data=/ggds/whe-iwgsc2018&loc=$gene\" target=\"_blank\"> JBrowse</a>";
		$vep_list[2] .= "<br>$consequence";
		$vep_list[3] .= "<br>$impact";
	    }
        }
	$countF = @vep_list;
        if ($countF == 0) {
	    $feature_q->execute($pos);
            while ($feature = $feature_q->fetchrow_array()) {
		$countF = @vep_list;
                if ($countF == 0) {
                    $feature_list = $feature;
                } else {
                    $feature_list .= "<br>$feature";
                }
	    }
	    if ($feature_list ne "") {
	        print "$feature_list\n";
            }
        } else {
            print "$vep_list[1]<td>$vep_list[2]<td>$vep_list[3]\n";	
	}
    }
    print "</tbody></table>";
    print <<HTML;
    <script type="text/javascript">
    jQuery(document).ready(function() {
        jQuery('#mnase').DataTable( {
	    "paging": false,
	    "order": [2, 'asc']
	} );
    } );
    </script>
HTML
}

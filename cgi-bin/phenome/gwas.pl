
use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw | page_title_html blue_section_html |;

my $page = CXGN::Page->new();

$page->header();

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
Download Results in an Excel file<br>
<a href="https://wheat.triticeaetoolbox.org/static_content/files/gwas_experiment_single.xlsx">Trial Analysis</a><br>
<a href="https://wheat.triticeaetoolbox.org/static_content/files/gwas_experiment_set.xlsx">Breeding Program Analysis (set of trials)</a>

<br/><hr/>

HTML

$page->footer();


use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/ page_title_html info_section_html /;

my $page = CXGN::Page->new("SGN software downloads", "Lukas");

my $title = page_title_html("Downloads SGN software",);

$page->header("Downloads", $title);

my $contents ="";

$page->footer();

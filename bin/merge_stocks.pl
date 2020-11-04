
=head1 NAME

merge_stocks.pl - merge stocks using a file with stocks to merge

=head1 DESCRIPTION

merge_stocks.pl -H [database host] -D [database name]  [-o output log location] [-tx] mergefile.txt

Options:

 -H the database host
 -D the database name
 -o output log location
 -t flag; if present, the changes will be rolled back
 -x flag; if present, delete the empty remaining accession

mergefile.txt: A tab-separated file with two columns. Include the following header as the first line: bad name  good name

All the metadata of bad name will be transferred to good name.
If -x is used, stock with name bad name will be deleted.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;

use Getopt::Std;
use CXGN::DB::InsertDBH;
use CXGN::DB::Schemas;
use CXGN::Stock;


our($opt_H, $opt_D, $opt_o, $opt_t, $opt_x,);
getopts('H:D:o:tx');

print "Password for $opt_H / $opt_D: \n";
my $pw = (<STDIN>);
chomp($pw);

my $output_log = $opt_o;
my $delete_merged_stock = $opt_x;
my $testing = $opt_t;
my $file = shift;

if (defined($delete_merged_stock) ) {
	print STDERR "Note: -x: Deleting stocks that have been merged into other stocks.\n";
}

print STDERR "Connecting to database...\n";
my $dsn = 'dbi:Pg:database='.$opt_D.";host=".$opt_H.";port=5432";
my $dbh = DBI->connect($dsn, "postgres", $pw, { AutoCommit => 0, RaiseError=>1 });
my $s = CXGN::DB::Schemas->new({ dbh => $dbh });
my $schema = $s->bcs_schema();

if ( defined($output_log) ) {
	open(OUTPUT_LOG_FH, '>', $output_log) or die $!;
	print OUTPUT_LOG_FH "[INFO] MERGE STOCKS...\n";
	print OUTPUT_LOG_FH "[INFO] Host=$opt_H\n";
	print OUTPUT_LOG_FH "[INFO] Database=$opt_D\n";
	print OUTPUT_LOG_FH "[INFO] Delete=yes\n" if defined($delete_merged_stock);
	print OUTPUT_LOG_FH "[INFO] Delete=no\n" if !defined($delete_merged_stock);
	print OUTPUT_LOG_FH "[INFO] File=$file\n";
	close(OUTPUT_LOG_FH);
}

print STDERR "Reading merge file...\n";
open(my $F, "<", $file) || die "Can't open file $file.\n";
my $header = <$F>;
print STDERR "Skipping header line $header\n";
eval {
    while (<$F>) {
        print STDERR "Read line: $_\n";
		chomp;
		my ($merge_stock_name, $good_stock_name) = split /\t/;
		print STDERR "bad name: $merge_stock_name, good name: $good_stock_name\n";

		if ( defined($output_log) ) {
			open(OUTPUT_LOG_FH, '>>', $output_log) or die $!;
			print OUTPUT_LOG_FH "[MERGE] $good_stock_name <- $merge_stock_name\n";
		}
		
		my $stock_row = $schema->resultset("Stock::Stock")->find( { uniquename => $good_stock_name } );
		if (!$stock_row) {
			print STDERR "Stock $good_stock_name not found. Skipping...\n";
			print OUTPUT_LOG_FH "[ERROR] Stock $good_stock_name not found\n" if defined($output_log);
			next();
		}

		my $merge_row = $schema->resultset("Stock::Stock")->find( { uniquename => $merge_stock_name } );
		if (!$merge_row) {
			print STDERR "Stock $merge_stock_name not available for merging. Skipping\n";
			print OUTPUT_LOG_FH "[ERROR] Stock $merge_stock_name not found\n" if defined($output_log);
			next();
		}

		close(OUTPUT_LOG_FH) if defined($output_log);

		my $good_stock = CXGN::Stock->new( { schema => $schema, stock_id => $stock_row->stock_id });
		my $merge_stock = CXGN::Stock->new( { schema => $schema, stock_id => $merge_row->stock_id });

		print STDERR "Merging stock $merge_stock_name into $good_stock_name...\n";
		$good_stock->merge($merge_stock->stock_id(), $delete_merged_stock, $output_log);
		print STDERR "Done.\n";
    }
};

if ($@ || defined($testing)) {
	if ( $@ ) {
		print STDERR "An ERROR occurred ($@).\n";
	}
    print STDERR "Rolling back changes...\n";
    $dbh->rollback();
}
else {
    print STDERR "Script is done. Committing... ";
    $dbh->commit();
    print STDERR "Done.\n";
}
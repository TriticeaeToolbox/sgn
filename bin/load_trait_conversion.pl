#!/usr/bin/perl

=head1 NAME

load_trait_conversion.pl - loads trait conversion properties for a specific trait cvterm

=head1 DESCRIPTION

load_trait_conversion.pl -H [database host] -D [database name] -i [trait cvterm id] -n [trait name] -s [source scale] -t [target scale] -c [conversion factor]

Options:

 -H the database host
 -D the database name
 -i trait cvterm id (ex: 77328)
 -n trait name or CO identifier (ex: "Grain yield - g/m2|CO_350:0000260" or just "CO_350:0000260")
 -s source scale (ex: "g/m2")
 -t target scale (ex: "bu/ac")
 -c conversion factor, this will be multiplied with the stored value to convert from source -> target (ex: 0.2788067)

Either the cvterm id (-i) OR the trait name (-n) must be provided.  If both are given, the cvterm id will be used.

If the trait is found in the database, the conversion information will be stored as a cvtermprop in a JSON format:
{
    "source_scale": "g/m2",
    "target_scale": "bu/ac",
    "conversion": 0.2788067
}

More than one conversion can be stored for a single trait

=head1 AUTHOR

David Waring <djw64@cornell.edu>

=cut


use strict;
use warnings;
use Getopt::Std;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;
use CXGN::DB::InsertDBH;
use CXGN::Trait;
use JSON;

our ($opt_H, $opt_D, $opt_i, $opt_n, $opt_s, $opt_t, $opt_c);
getopts("H:D:i:n:s:t:c:");
my $dbhost = $opt_H;
my $dbname = $opt_D;
my $cvterm_id = $opt_i;
my $trait_name = $opt_n;
my $source_scale = $opt_s;
my $target_scale = $opt_t;
my $conversion = $opt_c;

my $dbh = CXGN::DB::InsertDBH->new({
    dbhost=>"$dbhost",
    dbname=>"$dbname",
    dbargs => { AutoCommit => 1, RaiseError => 1 }
});
my $schema= Bio::Chado::Schema->connect( sub { $dbh->get_actual_dbh() } );

# Get trait_conversion type_id
my $trait_property_cv = $schema->resultset("Cv::Cv")->find({ name => 'trait_property' });
my $trait_conversion_cvterm = $schema->resultset("Cv::Cvterm")->find({
    name  => "trait_conversion",
    cv_id => $trait_property_cv->cv_id(),
});
my $type_id = $trait_conversion_cvterm->cvterm_id();

# Get trait cvterm
my $trait_cvterm;
my $trait_cvterm_id;
if ( $opt_i ) {
    $trait_cvterm = $schema->resultset("Cv::Cvterm")->find({ cvterm_id => $opt_i });
    $trait_cvterm_id = $trait_cvterm->cvterm_id() if $trait_cvterm;
}
elsif ( $opt_n ) {
    $trait_cvterm = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $opt_n);
    $trait_cvterm_id = $trait_cvterm->cvterm_id() if $trait_cvterm;
}
die "Could not find matching trait cvterm!" if !$trait_cvterm || !$trait_cvterm_id;

# Add trait cvterm prop
die "Source scale is missing!" if !$source_scale;
die "Target scale is missing!" if !$target_scale;
die "Conversion factor is missing!" if !$conversion;
my %value = (
    source_scale => $source_scale,
    target_scale => $target_scale,
    conversion => $conversion
);
$trait_cvterm->create_cvtermprops({ 'trait_conversion' => encode_json \%value }, { cv_name => 'trait_property' });

# Get currently stored conversions
my $trait = CXGN::Trait->new({ bcs_schema => $schema, cvterm_id => $cvterm_id });
my $stored_conversions = $trait->conversions();

use Data::Dumper;
print STDERR "==> STORED TRAIT CONVERSIONS FOR " . $trait->name() . " [" . $trait->cvterm_id() . "]:\n";
print STDERR Dumper $stored_conversions;

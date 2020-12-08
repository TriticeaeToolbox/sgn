
package CXGN::List::Validate::Plugin::Accessions;

use Moose;

use Data::Dumper;
use SGN::Model::Cvterm;
use Hash::Case::Preserve;

sub name { 
    return "accessions";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    tie my(%all_names), 'Hash::Case::Preserve';
    my $synonym_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $q = "SELECT stock.uniquename, stockprop.value, stockprop.type_id FROM stock LEFT JOIN stockprop USING(stock_id) WHERE stock.type_id=$accession_type_id AND stock.is_obsolete = 'F';";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    while (my ($uniquename, $synonym, $type_id) = $h->fetchrow_array()) {
        $all_names{lc($uniquename)}++;
        if ($type_id) {
            if ($type_id == $synonym_type_id) {
                $all_names{lc($synonym)}++;
            }
        }
    }

    #print STDERR Dumper \%all_names;
    my @missing;
    foreach my $item (@$list) {
        if (!exists($all_names{lc($item)})) {
            push @missing, $item;
        }
    }

    return { missing => \@missing };
}

1;

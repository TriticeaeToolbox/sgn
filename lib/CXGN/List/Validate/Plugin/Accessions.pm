
package CXGN::List::Validate::Plugin::Accessions;

use Moose;

use Data::Dumper;
use SGN::Model::Cvterm;


sub name { 
    return "accessions";
}

sub validate { 
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my $type_id = $schema->resultset("Cv::Cvterm")->search({ name=>"accession" })->first->cvterm_id();

    my $stock_property_cv_id = $schema->resultset("Cv::Cv")->search({ name=> "stock_property" })->first()->cv_id();


    my $synonym_type_rs = $schema->resultset("Cv::Cvterm")->search({name=>"stock_synonym", cv_id=> $stock_property_cv_id });

    my $synonym_rs;
    my $synonym_type_id;
    if ($synonym_type_rs->count == 0) { 
	$synonym_rs = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property');

	$synonym_type_id = $synonym_rs->cvterm_id();
    }
    else { 
	$synonym_type_id = $synonym_type_rs->first->cvterm_id();
    }
	
    

    my %items = ();
    
    # check uniquename
    #
    foreach my $item (@$list) { 
	my $rs = $schema->resultset("Stock::Stock")->search( { uniquename => { ilike =>  $item}, is_obsolete => 'F' });
	
	if ($rs->count > 0) { $items{$item}++ }
    }
    
    foreach my $item (@$list) { 
	my $rs = $schema->resultset("Stock::Stockprop")->search( { value => { ilike =>  $item }, 'me.type_id' => $synonym_type_id })->search_related( "stock", { is_obsolete => 'F' });
	if ($rs->count > 0) { $items{$item}++ }
    }

    my @missing;

    foreach my $item (@$list) { 
	if ($items{$item} == 0) { 
	    push @missing, $item;
	}
    }

    return { missing => \@missing };
    
}

1;

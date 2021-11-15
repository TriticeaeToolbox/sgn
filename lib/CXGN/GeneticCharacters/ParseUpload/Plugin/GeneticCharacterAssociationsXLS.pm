package CXGN::GeneticCharacters::ParseUpload::Plugin::GeneticCharacterAssociationsXLS;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::GeneticCharacters;

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $overwrite_conflicting = $self->get_overwrite_conflicting();
    my $keep_conflicting = $self->get_keep_conflicting();
    my $parser = Spreadsheet::ParseExcel->new();
    my @error_messages;
    my %errors;

    #try to open the excel file and report any errors
    my $excel_obj = $parser->parse($filename);
    if (!$excel_obj) {
        push @error_messages, $parser->error();
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    if (!$worksheet) {
        push @error_messages, "Spreadsheet must be on 1st tab in Excel (.xls) file";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of data
        push @error_messages, "Spreadsheet is missing header or contains no rows";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #cannot keep and overwrite conflicting associations!
    if ($overwrite_conflicting && $keep_conflicting) {
        push @error_messages, "Cannot overwrite AND keep conflicting associations - choose one method";
    }

    #get column headers
    my $accession_head;
    my $value_head;

    if ($worksheet->get_cell(0,0)) {
        $accession_head = $worksheet->get_cell(0,0)->value();
    }
    if ($worksheet->get_cell(0,1)) {
        $value_head = $worksheet->get_cell(0,1)->value();
    }

    if (!$accession_head || $accession_head ne 'accession' ) {
        push @error_messages, "Cell A1: accession is missing from the header";
    }
    if (!$value_head || $value_head ne 'value') {
        push @error_messages, "Cell B1: value is missing from the header";
    }

    #get existing genetic character values
    my $gc_values = CXGN::GeneticCharacters->get_genetic_character_values();

    #get user values
    my %validated_data;
    my %seen_accessions;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $accession;
        my $value;

        if ($worksheet->get_cell($row,0)) {
            $accession = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $value = $worksheet->get_cell($row,1)->value();
        }

        #check for required values
        if ( !$accession || $accession eq '' ) {
            push @error_messages, "Cell A$row_name: accession missing.";
        }
        if ( !$value || $value eq '' ) {
            push @error_messages, "Cell B$row_name: value missing.";
        }

        #check for existing values
        if ( !exists($gc_values->{$value}) ) {
            push @error_messages, "Cell B$row_name: genetic character value symbol '$value' does not exist - add the genetic character value to the database first.";
        }

        #check for existing association to genetic character
        if ( !$overwrite_conflicting && !$keep_conflicting ) {
            my $existing_associations = CXGN::GeneticCharacters->get_existing_associations($accession, $value);
            if ( $existing_associations && scalar(@$existing_associations) > 0 ) {
                foreach my $ea (@$existing_associations) {
                    if ( $value ne $ea->{allele_symbol} ) {
                        push @error_messages, "Row $row_name: the provided association between the accession '$accession' and genetic character value '$value' conflicts with the existing association to the genetic character value '" . $ea->{allele_symbol} . "' - choose to either overwrite the existing association or store both."
                    }
                }
            }
        }

        #keep track of seen accessions
        $seen_accessions{$accession} = $row_name;

        #store validated data
        $validated_data{$accession.'-'.$value} = {
            accession_name => $accession,
            value_symbol => $value,
            value_id => $gc_values->{$value}->{id}
        }
    }

    #check accession names
    my @seen_accession_names = keys(%seen_accessions);
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'uniquename' => \@seen_accession_names,
        'type_id' => $accession_cvterm_id
    });
    my %found_accession_names;
    while ( my $r = $rs->next() ) {
        $found_accession_names{$r->uniquename} = $r->stock_id;
    }
    foreach (@seen_accession_names) {
        if ( !$found_accession_names{$_} ) {
            push @error_messages, "The accession name '$_' does not match an existing accession entry - make sure it exists in the database and the name is correct.";
        }
    }


    #replace accession names stock ids
    foreach my $value (keys(%validated_data)) {
        $validated_data{$value}->{accession_id} = $found_accession_names{$validated_data{$value}->{accession_name}};
    }

    #store any errors found in the parsed file to parse_errors accessor
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    $self->_set_parsed_data(\%validated_data);
    return 1; #returns true if validation is passed
}

sub _parse_with_plugin {
    my $self = shift;

    #
    # Data parsed in validator
    #

    return 1;
}

1;
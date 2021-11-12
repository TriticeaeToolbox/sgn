package CXGN::GeneticCharacters::ParseUpload::Plugin::GeneticCharacterValuesXLS;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Data::Dumper;
use CXGN::GeneticCharacters;

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
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

    #get column headers
    my $gc_head;
    my $name_head;
    my $symbol_head;
    my $phenotype_head;

    if ($worksheet->get_cell(0,0)) {
        $gc_head = $worksheet->get_cell(0,0)->value();
    }
    if ($worksheet->get_cell(0,1)) {
        $name_head = $worksheet->get_cell(0,1)->value();
    }
    if ($worksheet->get_cell(0,2)) {
        $symbol_head = $worksheet->get_cell(0,2)->value();
    }
    if ($worksheet->get_cell(0,3)) {
        $phenotype_head = $worksheet->get_cell(0,3)->value();
    }

    if (!$gc_head || $gc_head ne 'genetic_character' ) {
        push @error_messages, "Cell A1: genetic_character is missing from the header";
    }
    if (!$name_head || $name_head ne 'name') {
        push @error_messages, "Cell B1: name is missing from the header";
    }
    if (!$symbol_head || $symbol_head ne 'symbol') {
        push @error_messages, "Cell C1: symbol is missing from the header";
    }
    if (!$phenotype_head || $phenotype_head ne 'phenotype' ) {
        push @error_messages, "Cell D1: phenotype is missing from the header";
    }

    #get existing genetic characters and symbols
    my $existing_gc_map = CXGN::GeneticCharacters->get_genetic_characters();
    my $used_gc_symbols = CXGN::GeneticCharacters->get_used_genetic_character_symbols();
    my %used_gc_symbols_map = map { $_ => 1 } @$used_gc_symbols;
    my $used_gcv_symbols = CXGN::GeneticCharacters->get_used_value_symbols();
    my %used_gcv_symbols_map = map { $_ => 1 } @$used_gcv_symbols;

    #get user values
    my %validated_data;
    my %seen_gcv_symbols;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $gc;
        my $name;
        my $symbol;
        my $phenotype;

        if ($worksheet->get_cell($row,0)) {
            $gc = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $name = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $symbol = $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $phenotype = $worksheet->get_cell($row,3)->value();
        }

        #check for required values
        if ( !$gc || $gc eq '' ) {
            push @error_messages, "Cell A$row_name: genetic_character missing.";
        }
        if ( !$name || $name eq '' ) {
            push @error_messages, "Cell B$row_name: name missing.";
        }
        if ( !$symbol || $symbol eq '' ) {
            push @error_messages, "Cell C$row_name: symbol missing.";
        }

        #check for existing values
        if ( !exists($used_gc_symbols_map{$gc}) ) {
            push @error_messages, "Cell A$row_name: genetic_character symbol '$gc' does not exist - add the genetic character to the database first.";
        }
        if ( exists($used_gcv_symbols_map{$symbol}) ) {
            push @error_messages, "Cell C$row_name: symbol for genetic character value '$symbol' already exists - change it to be unique.";
        }

        #check for duplicated values
        if (exists($seen_gcv_symbols{$symbol})) {
            push @error_messages, "Cell C$row_name: symbol '$symbol' used more than once in the file.";
        }

        #keep track of seen values
        $seen_gcv_symbols{$symbol} = $row_name;

        #store validated data
        $validated_data{$symbol} = {
            genetic_character => $existing_gc_map->{$gc}->{id},
            name => $name,
            symbol => $symbol,
            phenotype => $phenotype
        }
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
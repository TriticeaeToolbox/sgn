package CXGN::GeneticCharacters::ParseUpload::Plugin::GeneticCharactersXLS;

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
    my $name_head;
    my $symbol_head;
    my $category_head;
    my $chromosome_head;
    my $arm_head;
    my $description_head;

    if ($worksheet->get_cell(0,0)) {
        $name_head = $worksheet->get_cell(0,0)->value();
    }
    if ($worksheet->get_cell(0,1)) {
        $symbol_head = $worksheet->get_cell(0,1)->value();
    }
    if ($worksheet->get_cell(0,2)) {
        $category_head = $worksheet->get_cell(0,2)->value();
    }
    if ($worksheet->get_cell(0,3)) {
        $chromosome_head = $worksheet->get_cell(0,3)->value();
    }
    if ($worksheet->get_cell(0,4)) {
        $arm_head = $worksheet->get_cell(0,4)->value();
    }
    if ($worksheet->get_cell(0,5)) {
        $description_head = $worksheet->get_cell(0,5)->value();
    }

    if (!$name_head || $name_head ne 'name' ) {
        push @error_messages, "Cell A1: name is missing from the header";
    }
    if (!$symbol_head || $symbol_head ne 'symbol') {
        push @error_messages, "Cell B1: symbol is missing from the header";
    }
    if (!$category_head || $category_head ne 'category') {
        push @error_messages, "Cell C1: category is missing from the header";
    }
    if (!$chromosome_head || $chromosome_head ne 'chromosome' ) {
        push @error_messages, "Cell D1: chromosome is missing from the header";
    }
    if (!$arm_head || $arm_head ne 'arm' ) {
        push @error_messages, "Cell E1: arm is missing from the header";
    }
    if (!$description_head || $description_head ne 'description' ) {
        push @error_messages, "Cell F1: description is missing from the header";
    }

    #get existing Genetic Characters, Symbols, and Categories
    my $used_names = CXGN::GeneticCharacters->get_used_genetic_character_names();
    my %used_names_map = map { $_ => 1 } @$used_names;
    my $used_symbols = CXGN::GeneticCharacters->get_used_genetic_character_symbols();
    my %used_symbols_map = map { $_ => 1 } @$used_symbols;
    my $categories = CXGN::GeneticCharacters->get_categories();
    my %used_categories_map;
    foreach my $category (@$categories) {
        $used_categories_map{$category->{name}} = $category;
    }

    #get user values
    my %validated_data;
    my %seen_names;
    my %seen_symbols;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $name;
        my $symbol;
        my $category;
        my $chromosome;
        my $arm;
        my $description;

        if ($worksheet->get_cell($row,0)) {
            $name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $symbol = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $category = $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $chromosome = $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $arm = $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $description = $worksheet->get_cell($row,5)->value();
        }

        #check for required values
        if ( !$name || $name eq '' ) {
            push @error_messages, "Cell A$row_name: name missing.";
        }
        if ( !$symbol || $symbol eq '' ) {
            push @error_messages, "Cell B$row_name: symbol missing.";
        }

        #check for existing values
        if ( exists($used_names_map{$name}) ) {
            push @error_messages, "Cell A$row_name: name '$name' already exists!";
        }
        if ( exists($used_symbols_map{$symbol}) ) {
            push @error_messages, "Cell B$row_name: symbol '$symbol' already exists!";
        }
        if ( $category && $category ne '' && !exists($used_categories_map{$category}) ) {
            push @error_messages, "Cell C$row_name: category '$category' does not exist!";
        }

        #check for duplicated values
        if (exists($seen_names{$name})) {
            push @error_messages, "Cell A$row_name: name '$name' used more than once in the file.";
        }
        if (exists($seen_symbols{$symbol})) {
            push @error_messages, "Cell B$row_name: symbol '$symbol' used more than once in the file.";
        }

        #keep track of seen values
        $seen_names{$name} = $row_name;
        $seen_symbols{$symbol} = $row_name;

        #store validated data
        if ( !$category || $category eq '' ) { $category = "T3 Genetic Characters"; }
        $validated_data{$symbol} = {
            name => $name,
            symbol => $symbol,
            category => $used_categories_map{$category}->{id},
            chromosome => $chromosome,
            arm => $arm,
            description => $description
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
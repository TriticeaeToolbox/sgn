package CXGN::Stock::ParseUpload::Plugin::CatalogXLS;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::People::Person;

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();

    my $dbh = $self->get_chado_schema()->storage()->dbh();

    my @error_messages;
    my %errors;

    # Match a dot, extension .xls / .xlsx
    my ($extension) = $filename =~ /(\.[^.]+)$/;
    my $parser;

    if ($extension eq '.xlsx') {
        $parser = Spreadsheet::ParseXLSX->new();
    }
    else {
        $parser = Spreadsheet::ParseExcel->new();
    }

    my $excel_obj;
    my $worksheet;
    my %supported_types;
    my %supported_categories;
    my %supported_material_sources;
    my %supported_material_types;

    $supported_types{'single item'} = 1;
    $supported_types{'set of items'} = 1;

    $supported_categories{'released variety'} = 1;
    $supported_categories{'pathogen assay'} = 1;
    $supported_categories{'control'} = 1;
    $supported_categories{'transgenic line'} = 1;

    $supported_material_types{'seed'} = 1;
    $supported_material_types{'plant'} = 1;
    $supported_material_types{'construct'} = 1;

#    $supported_material_sources{'OrderingSystemTest'} = 1;
#    $supported_material_sources{'Sendusu'} = 1;

#    $supported_availability{'in stock'} = 1;
#    $supported_availability{'out of stock'} = 1;
#    $supported_availability{'available in 3 months'} = 1;

    #try to open the excel file and report any errors
    $excel_obj = $parser->parse($filename);
    if (!$excel_obj){
        push @error_messages, $parser->error();
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    $worksheet = ($excel_obj->worksheets())[0]; #support only one worksheet
    if (!$worksheet){
        push @error_messages, "Spreadsheet must be on 1st tab in Excel (.xls) file";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my ($row_min, $row_max) = $worksheet->row_range();
    my ($col_min, $col_max) = $worksheet->col_range();
    if (($col_max - $col_min)  < 6 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of info
        push @error_messages, "Spreadsheet is missing header or no catalog info";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $item_name_header;
    my $item_type_header;
    my $material_type_header;
    my $category_header;
    my $additional_info_header;
    my $material_source_header;
    my $breeding_program_header;
#    my $availability_header;
    my $contact_person_header;

    if ($worksheet->get_cell(0,0)) {
        $item_name_header  = $worksheet->get_cell(0,0)->value();
        $item_name_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $item_type_header  = $worksheet->get_cell(0,1)->value();
        $item_type_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,2)) {
        $material_type_header  = $worksheet->get_cell(0,2)->value();
        $material_type_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,3)) {
        $category_header  = $worksheet->get_cell(0,3)->value();
        $category_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,4)) {
        $additional_info_header  = $worksheet->get_cell(0,4)->value();
        $additional_info_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,5)) {
        $material_source_header  = $worksheet->get_cell(0,5)->value();
        $material_source_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,6)) {
        $breeding_program_header  = $worksheet->get_cell(0,6)->value();
        $breeding_program_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,7)) {
        $contact_person_header  = $worksheet->get_cell(0,7)->value();
        $contact_person_header =~ s/^\s+|\s+$//g;
    }

    if (!$item_name_header || $item_name_header ne 'item_name' ) {
        push @error_messages, "Cell A1: item_name is missing from the header";
    }
    if (!$item_type_header || $item_type_header ne 'item_type') {
        push @error_messages, "Cell B1: item_type is missing from the header";
    }
    if (!$material_type_header || $material_type_header ne 'material_type') {
        push @error_messages, "Cell C1: material_type is missing from the header";
    }
    if (!$category_header || $category_header ne 'category') {
        push @error_messages, "Cell D1: category is missing from the header";
    }
    if (!$additional_info_header || $additional_info_header ne 'additional_info') {
        push @error_messages, "Cell E1: additional_info is missing from the header";
    }
    if (!$material_source_header || $material_source_header ne 'material_source') {
        push @error_messages, "Cell F1: material_source is missing from the header";
    }
    if (!$breeding_program_header || $breeding_program_header ne 'breeding_program') {
        push @error_messages, "Cell G1: breeding_program is missing from the header";
    }
#    if (!$availability_header || $availability_header ne 'availability') {
#        push @error_messages, "Cell G1: availability is missing from the header";
#    }
    if (!$contact_person_header || $contact_person_header ne 'contact_person_username') {
        push @error_messages, "Cell H1: contact_person_username is missing from the header";
    }

    my %seen_stock_names;
    my %seen_program_names;

    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $item_name;
        my $item_type;
        my $material_type;
        my $category;
        my $additional_info;
        my $material_source;
        my $breeding_program;
#        my $availability;
        my $contact_person_username;

        if ($worksheet->get_cell($row,0)) {
            $item_name = $worksheet->get_cell($row,0)->value();
            $item_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,1)) {
            $item_type =  $worksheet->get_cell($row,1)->value();
            $item_type =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,2)) {
            $material_type =  $worksheet->get_cell($row,2)->value();
            $material_type =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,3)) {
            $category = $worksheet->get_cell($row,3)->value();
            $category =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,4)) {
            $additional_info =  $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $material_source =  $worksheet->get_cell($row,5)->value();
        }
        if ($worksheet->get_cell($row,6)) {
            $breeding_program =  $worksheet->get_cell($row,6)->value();
            $breeding_program =~ s/^\s+|\s+$//g;
        }
#        if ($worksheet->get_cell($row,6)) {
#            $availability =  $worksheet->get_cell($row,6)->value();
#            $availability =~ s/^\s+|\s+$//g;
#        }
        if ($worksheet->get_cell($row,7)) {
            $contact_person_username =  $worksheet->get_cell($row,7)->value();
            $contact_person_username =~ s/^\s+|\s+$//g;
        }


        if (!$item_name || $item_name eq '') {
            push @error_messages, "Cell A$row_name: item_name missing";
        }

        if (!$item_type || $item_type eq '') {
            push @error_messages, "Cell B$row_name: item_type missing";
        } elsif (!$supported_types{$item_type}) {
            push @error_messages, "Cell B$row_name: item_type is not supported: $item_type";
        }

        if (!$material_type || $material_type eq '') {
            push @error_messages, "Cell C$row_name: material_type missing";
        } elsif (!$supported_material_types{$material_type}) {
            push @error_messages, "Cell C$row_name: material type is not supported: $material_type";
        }

        if (!$category || $category eq '') {
            push @error_messages, "Cell D$row_name: category missing";
        } elsif (!$supported_categories{$category}) {
            push @error_messages, "Cell C$row_name: category is not supported: $category";
        }

#        if (!$material_source || $material_source eq '') {
#            push @error_messages, "Cell E$row_name: material_source missing";
#        } elsif (!$supported_material_sources{$material_source}) {
#            push @error_messages, "Cell E$row_name: material source is not supported: $material_source";
#        }

        if (!$breeding_program || $breeding_program eq '') {
            push @error_messages, "Cell G$row_name: breeding_program missing";
        }

#        if (!$availability || $availability eq '') {
#            push @error_messages, "Cell G$row_name: availability missing";
#        } elsif (!$supported_availability{$availability}) {
#            push @error_messages, "Cell G$row_name: availability is not supported: $availability";
#        }

        if (!$contact_person_username || $contact_person_username eq '') {
            push @error_messages, "Cell H$row_name: contact person username missing";
        }

        my $sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $contact_person_username);
        if (!$sp_person_id) {
            push @error_messages, "Cell H$row_name: contact person username is not in database";
        }

        if ($item_name){
            $seen_stock_names{$item_name}++;
        }

        if ($breeding_program){
            $seen_program_names{$breeding_program}++;
        }

    }

#    my @stocks_missing;
    my @catalog_items = keys %seen_stock_names;
    my $catalog_item_validator = CXGN::List::Validate->new();
#    my @accessions_missing = @{$catalog_item_validator->validate($schema,'uniquenames',\@catalog_items)->{'missing'}};
#    if (scalar(@accessions_missing) > 0) {
#        @stocks_missing = @{$catalog_item_validator->validate($schema,'populations',\@accessions_missing)->{'missing'}};
#    }

    my @stocks_missing = @{$catalog_item_validator->validate($schema,'stocks',\@catalog_items)->{'missing'}};

    if (scalar(@stocks_missing) > 0){
        push @error_messages, "The following catalog items are not in the database: ".join(',',@stocks_missing);
    }

    my @breeding_programs = keys %seen_program_names;
    my $breeding_program_validator = CXGN::List::Validate->new();
    my @programs_missing = @{$breeding_program_validator->validate($schema,'breeding_programs',\@breeding_programs)->{'missing'}};

    if (scalar(@programs_missing) > 0){
        push @error_messages, "The following breeding programs are not in the database: ".join(',',@programs_missing);
    }

    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    return 1; #returns true if validation is passed

}

sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();

    my $dbh = $self->get_chado_schema()->storage()->dbh();

    # Match a dot, extension .xls / .xlsx
    my ($extension) = $filename =~ /(\.[^.]+)$/;
    my $parser;

    if ($extension eq '.xlsx') {
        $parser = Spreadsheet::ParseXLSX->new();
    }
    else {
        $parser = Spreadsheet::ParseExcel->new();
    }

    my $excel_obj;
    my $worksheet;
    my %parsed_result;

    $excel_obj = $parser->parse($filename);
    if (!$excel_obj){
        return;
    }

    $worksheet = ($excel_obj->worksheets())[0];
    my ($row_min, $row_max) = $worksheet->row_range();
    my ($col_min, $col_max) = $worksheet->col_range();

    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $item_name;
        my $item_type;
        my $material_type;
        my $category;
        my $additional_info;
        my $material_source;
        my $breeding_program;
#        my $availability;
        my $contact_person_username;

        if ($worksheet->get_cell($row,0)) {
            $item_name = $worksheet->get_cell($row,0)->value();
            $item_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,1)) {
            $item_type =  $worksheet->get_cell($row,1)->value();
            $item_type =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,2)) {
            $material_type =  $worksheet->get_cell($row,2)->value();
            $material_type =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,3)) {
            $category = $worksheet->get_cell($row,3)->value();
            $category =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,4)) {
            $additional_info =  $worksheet->get_cell($row,4)->value();
            $additional_info =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,5)) {
            $material_source =  $worksheet->get_cell($row,5)->value();
            $material_source =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,6)) {
            $breeding_program =  $worksheet->get_cell($row,6)->value();
            $breeding_program =~ s/^\s+|\s+$//g;
        }
#        if ($worksheet->get_cell($row,6)) {
#            $availability =  $worksheet->get_cell($row,6)->value();
#        }
        if ($worksheet->get_cell($row,7)) {
            $contact_person_username =  $worksheet->get_cell($row,7)->value();
            $contact_person_username =~ s/^\s+|\s+$//g;
        }

        my $contact_person_id = CXGN::People::Person->get_person_by_username($dbh, $contact_person_username);

        my $program_rs = $schema->resultset('Project::Project')->find({name => $breeding_program});
        my $breeding_program_id = $program_rs->project_id();

        $parsed_result{$item_name} = {
            'item_type' => $item_type,
            'material_type' => $material_type,
            'category' => $category,
            'additional_info' => $additional_info,
            'material_source' => $material_source,
            'breeding_program' => $breeding_program_id,
#            'availability' => $availability,
            'contact_person_id' => $contact_person_id,
        }
    }
    print STDERR "PLUGIN PARSED RESULT =".Dumper(\%parsed_result)."\n";

    $self->_set_parsed_data(\%parsed_result);

    return 1;
}

1;

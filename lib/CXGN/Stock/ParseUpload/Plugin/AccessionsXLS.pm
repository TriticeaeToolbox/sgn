package CXGN::Stock::ParseUpload::Plugin::AccessionsXLS;

use Moose::Role;
use Spreadsheet::ParseExcel;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::BreedersToolbox::StocksFuzzySearch;
use CXGN::BreedersToolbox::OrganismFuzzySearch;

sub _validate_with_plugin {
    my $self = shift;

    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $editable_stockprops = $self->get_editable_stock_props();
    my $parser = Spreadsheet::ParseExcel->new();
    my @error_messages;
    my %errors;
    my %missing_accessions;

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
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
        push @error_messages, "Spreadsheet is missing header or contains no rows";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $accession_name_head;
    my $species_name_head;

    if ($worksheet->get_cell(0,0)) {
        $accession_name_head  = $worksheet->get_cell(0,0)->value();
    }
    if ($worksheet->get_cell(0,1)) {
        $species_name_head  = $worksheet->get_cell(0,1)->value();
    }

    my @optional_columns = ('population_name', 'organization_name', 'organization_name(s)', 'synonym', 'synonym(s)');
    push @$editable_stockprops, ('location_code(s)','ploidy_level(s)','genome_structure(s)','variety(s)','donor(s)','donor_institute(s)','donor_PUI(s)','country_of_origin(s)','state(s)','institute_code(s)','institute_name(s)','biological_status_of_accession_code(s)','notes(s)','accession_number(s)','PUI(s)','seed_source(s)','type_of_germplasm_storage_code(s)','acquisition_date(s)','transgenic','introgression_parent','introgression_backcross_parent','introgression_map_version','introgression_chromosome','introgression_start_position_bp','introgression_end_position_bp');
    my @combined_columns = (@optional_columns, @$editable_stockprops);
    my %allowed_headers = map { $_ => 1 } @combined_columns;
    for my $i (2..$col_max){
        my $header;
        if ($worksheet->get_cell(0,$i)) {
            $header  = $worksheet->get_cell(0,$i)->value();
        }
        if ($header && !exists($allowed_headers{$header})){
            push @error_messages, "$header is not a valid property to have in the header! Please check the spreadsheet format help.";
        }
    }

    if (!$accession_name_head || $accession_name_head ne 'accession_name' ) {
        push @error_messages, "Cell A1: accession_name is missing from the header";
    }
    if (!$species_name_head || $species_name_head ne 'species_name') {
        push @error_messages, "Cell B1: species_name is missing from the header";
    }

    my %seen_accession_names;
    my %seen_species_names;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $accession_name;
        my $species_name;

        if ($worksheet->get_cell($row,0)) {
            $accession_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $species_name = $worksheet->get_cell($row,1)->value();
        }

        if (!$accession_name || $accession_name eq '' ) {
            push @error_messages, "Cell A$row_name: accession_name missing.";
        }
        #elsif ($accession_name =~ /\s/ || $accession_name =~ /\// || $accession_name =~ /\\/ ) {
        #    push @error_messages, "Cell A$row_name: accession_name must not contain spaces or slashes.";
        #}
        else {
            $accession_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            $seen_accession_names{$accession_name}=$row_name;
        }

        if (!$species_name || $species_name eq '' ) {
            push @error_messages, "Cell B$row_name: species_name missing.";
        }
        else {
            $species_name =~ s/^\s+|\s+$//g;
            $seen_species_names{$species_name}=$row_name;
        }
    }

    my @species = keys %seen_species_names;
    my $species_validator = CXGN::List::Validate->new();
    my @species_missing = @{$species_validator->validate($schema,'species',\@species)->{'missing'}};

    if (scalar(@species_missing) > 0) {
        push @error_messages, "The following species are not in the database as species in the organism table: ".join(',',@species_missing);
        $errors{'missing_species'} = \@species_missing;
    }

    #store any errors found in the parsed file to parse_errors accessor
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    return 1; #returns true if validation is passed
}


sub _parse_with_plugin {
    my $self = shift;
    my $editable_stockprops = $self->get_editable_stock_props();
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $do_fuzzy_search = $self->get_do_fuzzy_search();
    my $parser   = Spreadsheet::ParseExcel->new();
    my $excel_obj;
    my $worksheet;
    my %parsed_entries;

    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0];
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    my %seen_accession_names;
    my %seen_species_names;
    for my $row ( 1 .. $row_max ) {
        my $accession_name;
        my $species_name;

        if ($worksheet->get_cell($row,0)) {
            $accession_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $species_name = $worksheet->get_cell($row,1)->value();
        }
        if ($accession_name){
            $accession_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            $seen_accession_names{$accession_name}++;
        }
        if ($species_name){
            $species_name =~ s/^\s+|\s+$//g;
            $seen_species_names{$species_name}++;
        }
    }

    my @accession_list = keys %seen_accession_names;
    my @organism_list = keys %seen_species_names;
    my %accession_lookup;
    my $accessions_in_db_rs = $schema->resultset("Stock::Stock")->search({uniquename=>{-ilike=>\@accession_list}});
    while(my $r=$accessions_in_db_rs->next){
        $accession_lookup{$r->uniquename} = $r->stock_id;
    }

    # Old accession upload format had "(s)" appended to the editable_stock_props terms... this is now not the case, but should still allow for it. Now the header of the uploaded file should use the terms in the editable_stock_props configuration key directly.
    my %col_name_map = (
        'population_name' => ['population_name', 'populationName'],
        'organization_name' => ['organization_name', 'organizationName'],
        'organization_name(s)' => ['organization_name', 'organizatioName'],
        'synonym' => ['synonyms', 'synonyms'],
        'synonym(s)' => ['synonyms', 'synonyms'],
        'location_code(s)' => ['location_code', 'locationCode'],
        'location_code' => ['location_code', 'locationCode'],
        'ploidy_level(s)' => ['ploidy_level', 'ploidyLevel'],
        'ploidy_level' => ['ploidy_level', 'ploidyLevel'],
        'genome_structure(s)' => ['genome_structure', 'genomeStructure'],
        'genome_structure' => ['genome_structure', 'genomeStructure'],
        'variety(s)' => ['variety', 'variety'],
        'variety' => ['variety', 'variety'],
        'donor(s)' => ['donor', ''],
        'donor' => ['donor', ''],
        'donor_institute(s)' => ['donor institute', ''],
        'donor institute' => ['donor institute', ''],
        'donor_PUI(s)' => ['donor PUI', ''],
        'donor PUI' => ['donor PUI', ''],
        'country_of_origin(s)' => ['country of origin', 'countryOfOriginCode'],
        'country of origin' => ['country of origin', 'countryOfOriginCode'],
        'state(s)' => ['state', 'state'],
        'state' => ['state', 'state'],
        'institute_code(s)' => ['institute code', 'instituteCode'],
        'institute code' => ['institute code', 'instituteCode'],
        'institute_name(s)' => ['institute name', 'instituteName'],
        'institute name' => ['institute name', 'instituteName'],
        'biological_status_of_accession_code(s)' => ['biological status of accession code', 'biologicalStatusOfAccessionCode'],
        'biological status of accession code' => ['biological status of accession code', 'biologicalStatusOfAccessionCode'],
        'notes(s)' => ['notes', 'notes'],
        'notes' => ['notes', 'notes'],
        'accession_number(s)' => ['accession number', 'accessionNumber'],
        'accession number' => ['accession number', 'accessionNumber'],
        'PUI(s)' => ['PUI', 'germplasmPUI'],
        'PUI' => ['PUI', 'germplasmPUI'],
        'seed_source(s)' => ['seed source', 'germplasmSeedSource'],
        'seed source' => ['seed source', 'germplasmSeedSource'],
        'type_of_germplasm_storage_code(s)' => ['type of germplasm storage code', 'typeOfGermplasmStorageCode'],
        'type of germplasm storage code' => ['type of germplasm storage code', 'typeOfGermplasmStorageCode'],
        'acquisition_date(s)' => ['acquisition date', 'acquisitionDate'],
        'acquisition date' => ['acquisition date', 'acquisitionDate'],
        'transgenic(s)' => ['transgenic', 'transgenic'],
        'transgenic' => ['transgenic', 'transgenic'],
        'introgression_parent' => ['introgression_parent', 'introgression_parent'],
        'introgression_backcross_parent' => ['introgression_backcross_parent', 'introgression_backcross_parent'],
        'introgression_chromosome' => ['introgression_chromosome', 'introgression_chromosome'],
        'introgression_start_position_bp' => ['introgression_start_position_bp', 'introgression_start_position_bp'],
        'introgression_end_position_bp' => ['introgression_end_position_bp', 'introgression_end_position_bp'],
        'purdy_pedigree' => ['purdy pedigree', 'purdyPedigree'],
        'purdy pedigree' => ['purdy pedigree', 'purdyPedigree'],
        'filial_generation' => ['filial generation', 'filialGeneration'],
        'filial generation' => ['filial generation', 'filialGeneration']
    );

    my @header;
    for my $i (2..$col_max){
        my $col_head;
        if ($worksheet->get_cell(0,$i)) {
            $col_head  = $worksheet->get_cell(0,$i)->value();
        }
        push @header, $col_head;
    }

    my %seen_synonyms;
    for my $row ( 1 .. $row_max ) {
        my $accession_name;
        my $species_name;

        if ($worksheet->get_cell($row,0)) {
            $accession_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $species_name = $worksheet->get_cell($row,1)->value();
        }

        $accession_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...

        if (!$accession_name && !$species_name) {
            next;
        }

        my $stock_id;
        if(exists($accession_lookup{$accession_name})){
            $stock_id = $accession_lookup{$accession_name};
        }

        my %row_info = (
            germplasmName => $accession_name,
            defaultDisplayName => $accession_name,
            species => $species_name
        );
        #For "updating" existing accessions by adding properties.
        if ($stock_id){
            $row_info{stock_id} = $stock_id;
        }

        my $counter = 0;
        for my $i (2..$col_max){
            my $header_term = $header[$counter];
            my $stock_value;

            if ($worksheet->get_cell($row,$i)) {
                $stock_value  = $worksheet->get_cell($row,$i)->value();
            }
            if ($stock_value){
                if (exists($col_name_map{$header_term}) && ($col_name_map{$header_term}->[0] eq 'donor' || $col_name_map{$header_term}->[0] eq 'donor institute' || $col_name_map{$header_term}->[0] eq 'donor PUI') ) {
                    my %donor_key_map = ('donor'=>'donorGermplasmName', 'donor institute'=>'donorInstituteCode', 'donor PUI'=>'germplasmPUI');
                    if (exists($row_info{donors})){
                        my $donors_hash = $row_info{donors}->[0];
                        $donors_hash->{$donor_key_map{$col_name_map{$header_term}->[0]}} = $stock_value;
                        $row_info{donors} = [$donors_hash];
                    } else {
                        $row_info{donors} = [{ $donor_key_map{$col_name_map{$header_term}->[0]} => $stock_value }];
                    }
                } elsif (exists($col_name_map{$header_term})) {
                    my $key = $col_name_map{$header_term}->[1];
                    if ( $key eq 'synonyms' ) {
                        my @synonym_names = split ',', $stock_value;
                        foreach (@synonym_names) {
                            $seen_synonyms{$_} = $row;
                        }
                        $row_info{$key} = \@synonym_names;
                    }
                    else {
                        $row_info{$key} = $stock_value;
                    }
                } else {
                    $row_info{other_editable_stock_props}->{$header_term} = $stock_value;
                }
            }
            $counter++;
        }

        $parsed_entries{$row} = \%row_info;
    }

    my @synonyms_list = keys %seen_synonyms;
    my $fuzzy_accession_search = CXGN::BreedersToolbox::StocksFuzzySearch->new({schema => $schema});
    my $fuzzy_organism_search = CXGN::BreedersToolbox::OrganismFuzzySearch->new({schema => $schema});
    my $max_distance = 0.2;
    my $found_accessions = [];
    my $fuzzy_accessions = [];
    my $absent_accessions = [];
    my $found_synonyms = [];
    my $fuzzy_synonyms = [];
    my $absent_synonyms = [];
    my $found_organisms;
    my $fuzzy_organisms;
    my $absent_organisms;
    my %return_data;

    #remove all trailing and ending spaces from accessions and organisms
    s/^\s+|\s+$//g for @accession_list;
    s/^\s+|\s+$//g for @organism_list;

    if ($do_fuzzy_search) {
        my $fuzzy_search_result = $fuzzy_accession_search->get_matches(\@accession_list, $max_distance, 'accession');

        $found_accessions = $fuzzy_search_result->{'found'};
        $fuzzy_accessions = $fuzzy_search_result->{'fuzzy'};
        $absent_accessions = $fuzzy_search_result->{'absent'};

        if (scalar @synonyms_list > 0){
            my $fuzzy_synonyms_result = $fuzzy_accession_search->get_matches(\@synonyms_list, $max_distance, 'accession');
            $found_synonyms = $fuzzy_synonyms_result->{'found'};
            $fuzzy_synonyms = $fuzzy_synonyms_result->{'fuzzy'};
            $absent_synonyms = $fuzzy_synonyms_result->{'absent'};
        }

        if (scalar @organism_list > 0){
            my $fuzzy_organism_result = $fuzzy_organism_search->get_matches(\@organism_list, $max_distance);
            $found_organisms = $fuzzy_organism_result->{'found'};
            $fuzzy_organisms = $fuzzy_organism_result->{'fuzzy'};
            $absent_organisms = $fuzzy_organism_result->{'absent'};
        }

        if ($fuzzy_search_result->{'error'}){
            $return_data{error_string} = $fuzzy_search_result->{'error'};
        }
    } else {
        my $validator = CXGN::List::Validate->new();
        my $absent_accessions = $validator->validate($schema, 'accessions', \@accession_list)->{'missing'};
        my %accessions_missing_hash = map { $_ => 1 } @$absent_accessions;

        foreach (@accession_list){
            if (!exists($accessions_missing_hash{$_})){
                push @$found_accessions, { unique_name => $_,  matched_string => $_};
                push @$fuzzy_accessions, { unique_name => $_,  matched_string => $_};
            }
        }
    }

    %return_data = (
        parsed_data => \%parsed_entries,
        found_accessions => $found_accessions,
        fuzzy_accessions => $fuzzy_accessions,
        absent_accessions => $absent_accessions,
        found_synonyms => $found_synonyms,
        fuzzy_synonyms => $fuzzy_synonyms,
        absent_synonyms => $absent_synonyms,
        found_organisms => $found_organisms,
        fuzzy_organisms => $fuzzy_organisms,
        absent_organisms => $absent_organisms
    );
    print STDERR "\n\nAccessionsXLS parsed results :\n".Data::Dumper::Dumper(%return_data)."\n\n";             

    $self->_set_parsed_data(\%return_data);
    return 1;
}


1;

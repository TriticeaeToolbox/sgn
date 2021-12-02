package CXGN::GeneticCharacters;

=head1 NAME

CXGN::GeneticCharacters - used to query and manage Genetic Characters (stored as Loci), their values (stored as Alleles), 
and their associations with Accessions

=head1 USAGE

=head1 AUTHORS

David Waring <djw64@cornell.edu>

=cut

use strict;
use warnings;
use SGN::Context;

#
# Get a hash of Genetic Character info for all of the Loci tagged as Genetic Characters 
# (associated with one of the T3 Genetic Characters ontology terms)
# PARAMS:
# RETURNS:
#   a hash with the key=symbol and value=hash with the following keys:
#       - id = locus id
#       - name = locus name
#       - symbol = locus symbol
#       - chromosome = locus linkage group
#       - arm = locus linkage group arm
#       - description = locus description
#       - category:
#           - name = T3 Genetic Character ontology term cvterm name
#           - code = T3 Genetic Character ontology term accession name
#           - id = T3 Genetic Character ontology term dbxref id
#
sub get_genetic_characters {
    my $self = shift;
    my $c = SGN::Context->new;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh();

    # Get dbxref id's of genetic character categories
    my $dbxref_ids = $self->_get_category_dbxref_ids();

    # Get the genetic character info
    my $q = "SELECT locus_id AS id, locus_name AS name, locus_symbol AS symbol, linkage_group AS chromosome, lg_arm AS arm, locus.description, common_name.common_name AS organism, cvterm.name AS category_name, dbxref.accession AS category_code, dbxref.dbxref_id AS category_id
            FROM phenome.locus
            LEFT JOIN sgn.common_name USING (common_name_id)
            LEFT JOIN phenome.locus_dbxref USING (locus_id)
            LEFT JOIN public.dbxref USING (dbxref_id)
            LEFT JOIN public.cvterm USING (dbxref_id)
            WHERE locus_dbxref.dbxref_id IN (" . join(",", ("?") x @$dbxref_ids) . ")
            ORDER BY category_name, name;";
    my $sth = $dbh->prepare($q);
    $sth->execute(@$dbxref_ids);

    # Parse query into response
    my %genetic_characters;
    while ( my ($id, $name, $symbol, $chromosome, $arm, $description, $organism, $category_name, $category_code, $category_id) = $sth->fetchrow_array() ) {
        $genetic_characters{$symbol} = {
            id => $id,
            name => $name,
            symbol => $symbol,
            chromosome => $chromosome,
            arm => $arm,
            description => $description,
            organism => $organism,
            category => {
                name => $category_name,
                code => $category_code,
                id => $category_id
            }
        };
    }

    # Return genetic characters
    return \%genetic_characters;
}

#
# Get a hash of the Genetic Character Value info for all of the Alleles associated 
# with Loci that are tagged as Genetic Characters
# PARAMS
# RETURNS:
#   a hash with the key=symbol and value=hash with the following keys:
#       - genetic_character_id = locus id of genetic character
#       - id = allele id
#       - symbol = allele symbol
#       - name = allele name
#       - phenotype = allele phenotype
#
sub get_genetic_character_values {
    my $self = shift;
    my $c = SGN::Context->new;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh();

    # Get symbols of genetic character loci
    my $dbxref_ids = $self->_get_category_dbxref_ids();

    # Get the genetic character value info
    my $q = "SELECT locus_id, allele_id, allele_symbol, allele_name, allele_phenotype
            FROM phenome.allele
            LEFT JOIN phenome.locus_dbxref USING (locus_id)
            WHERE locus_dbxref.dbxref_id IN (" . join(",", ("?") x @$dbxref_ids) . ")
            ORDER BY allele_name;";
    my $sth = $dbh->prepare($q);
    $sth->execute(@$dbxref_ids);

    # Parse query into response
    my %genetic_character_values;
    while ( my ($locus_id, $id, $symbol, $name, $phenotype) = $sth->fetchrow_array() ) {
        $genetic_character_values{$symbol} = {
            genetic_character_id => $locus_id,
            id => $id,
            symbol => $symbol,
            name => $name,
            phenotype => $phenotype
        };
    }

    # Return genetic characters
    return \%genetic_character_values;
}

#
# Store the specified set of Genetic Characters in the phenome.locus table
# PARAMS:
#   - sp_person_id = id of person adding the data
#   - organism = common_name_id of common_name organism
#   - data = A hash of hashes with the genetic character info:
#       - name = locus name
#       - symbol = locus symbol
#       - chromosome = locus linkage group
#       - arm = locus linkage group arm
#       - description = locus description
#       - category = dbxref id of T3 Genetic Character ontology term
# RETURNS: an error message, if encountered
#
sub store_genetic_characters {
    my $self = shift;
    my $sp_person_id = shift;
    my $organism = shift;
    my $data = shift;
    my $c = SGN::Context->new;
    my $dbh = $c->dbc->dbh();

    eval {
        $dbh->begin_work();
        foreach my $symbol (keys %$data) {
            my $gc = $data->{$symbol};
            my $locus_name = $gc->{name};
            my $locus_symbol = $gc->{symbol};
            my $locus_description = $gc->{description};
            my $chromosome = $gc->{chromosome};
            my $arm = $gc->{arm};
            my $category_dbxref_id = $gc->{category};
            
            # Add locus
            my $q = "INSERT INTO phenome.locus (locus_name, locus_symbol, description, linkage_group, lg_arm, common_name_id) VALUES (?, ?, ?, ?, ?, ?) RETURNING locus_id;";
            my $sth = $dbh->prepare($q);
            $sth->execute($locus_name, $locus_symbol, $locus_description, $chromosome, $arm, $organism);
            my ($locus_id) = $sth->fetchrow_array();

            # Add locus alias
            $q = "INSERT INTO phenome.locus_alias (alias, locus_id) VALUES (?, ?);";
            $sth = $dbh->prepare($q);
            $sth->execute($locus_symbol, $locus_id);

            # Add locus owner
            $q = "INSERT INTO phenome.locus_owner (locus_id, sp_person_id) VALUES (?, ?);";
            $sth = $dbh->prepare($q);
            $sth->execute($locus_id, $sp_person_id);

            # Add locus dbxref reference
            $q = "INSERT INTO phenome.locus_dbxref (locus_id, dbxref_id, obsolete, sp_person_id) VALUES (?, ?, ?, ?) RETURNING locus_dbxref_id;";
            $sth = $dbh->prepare($q);
            $sth->execute($locus_id, $category_dbxref_id, 'FALSE', $sp_person_id);
            my ($locus_dbxref_id) = $sth->fetchrow_array();

            # Add locus dbxref evidence reference
            $q = "INSERT INTO phenome.locus_dbxref_evidence (locus_dbxref_id, relationship_type_id, evidence_code_id, sp_person_id, obsolete) SELECT ?, dbxref_id, ?, ?, ? FROM public.dbxref WHERE accession = 'is_a';";
            $sth = $dbh->prepare($q);
            $sth->execute($locus_dbxref_id, $category_dbxref_id, $sp_person_id, 'FALSE');
        }
    };

    if ($@) {
        $dbh->rollback();
        return $@;
    }
    else {
        $dbh->commit();
        return;
    }
}

#
# Store the specified set of Genetic Charavter Values in the phenome.allele table
# PARAMS:
#   - sp_person_id = id of person adding the data
#   - data = A hash of hashes with the genetic character value info:
#       - genetic_character = locus id of existing genetic character
#       - name = name of allele
#       - symbol = symobl of allele
#       - phenotype = phenotype of allele
#   - overwrite_conflicting = flag to overwrite conflicting associations
#   - keep_conflicting = flag to keep conflicting associations
# RETURNS: an error message, if encountered
#
sub store_genetic_character_values {
    my $self = shift;
    my $sp_person_id = shift;
    my $data = shift;
    my $c = SGN::Context->new;
    my $dbh = $c->dbc->dbh();

    eval {
        $dbh->begin_work();
        foreach my $symbol (keys %$data) {
            my $value = $data->{$symbol};
            my $locus_id = $value->{genetic_character};
            my $allele_name = $value->{name};
            my $allele_symbol = $value->{symbol};
            my $allele_phenotype = $value->{phenotype};

            # Add allele
            my $q = "INSERT INTO phenome.allele (locus_id, allele_symbol, allele_name, allele_phenotype, sp_person_id, is_default) VALUES (?, ?, ?, ?, ?, ?) RETURNING allele_id;";
            my $sth = $dbh->prepare($q);
            $sth->execute($locus_id, $allele_symbol, $allele_name, $allele_phenotype, $sp_person_id, 0);
            my ($allele_id) = $sth->fetchrow_array();
        }
    };

    if ($@) {
        $dbh->rollback();
        return $@;
    }
    else {
        $dbh->commit();
        return;
    }
}

#
# Store the associations between Accessions and Genetic Character Values in the stockprop 
# and phenome.stock_allele tables
# PARAMS:
#   - sp_person_id = id of person adding the data
#   - data = A hash of hashes with the genetic character associations:
#       - accession_name = name of accession to associate
#       - accession_id = stock id of accession to associate
#       - value_symbol = symbol of genetic character value to associate with accession
#       - value_id = allele id of genetic character value to assicate with accession
#   - overwrite_conflicting = flag to remove conflicting associations before storing a new one
# RETURNS: an error message, if encountered
#
sub store_genetic_character_associations {
    my $self = shift;
    my $sp_person_id = shift;
    my $data = shift;
    my $overwrite_conflicting = shift;
    my $c = SGN::Context->new;
    my $dbh = $c->dbc->dbh();

    eval {
        $dbh->begin_work();

        # Create a metadata entry
        my $q = "INSERT INTO metadata.md_metadata (create_person_id, modification_note) VALUES (?, ?) RETURNING metadata_id;";
        my $sth = $dbh->prepare($q);
        $sth->execute($sp_person_id, 'Bulk addition of genetic characters and associated accessions.');
        my ($metadata_id) = $sth->fetchrow_array();

        foreach my $k (keys(%$data)) {
            my $gva = $data->{$k};
            my $accession_name = $gva->{accession_name};
            my $accession_id = $gva->{accession_id};
            my $value_symbol = $gva->{value_symbol};
            my $value_id = $gva->{value_id};

            # Get existing associations
            # Remove conflicting associations, if $overwrite_conflicting is set
            my $existing = $self->get_existing_associations($accession_name, $value_symbol);
            my $skip = 0;
            if ( $existing && scalar(@$existing) > 0 ) {
                foreach my $ea (@$existing) {
                    my $ea_symbol = $ea->{allele_symbol};
                    my $ea_id = $ea->{allele_id};
                    my $ea_sp_id = $ea->{stockprop_id};
                    my $ea_stock_id = $ea->{stock_id};

                    # Skip duplicate associations
                    if ( $ea_symbol eq $value_symbol ) {
                        $skip = 1;
                    }

                    # REMOVE EXISTING ASSOCIATIONS
                    elsif ( $overwrite_conflicting ) {
                        $q = "DELETE FROM public.stockprop WHERE stockprop_id = ?;";
                        $sth = $dbh->prepare($q);
                        $sth->execute($ea_sp_id);

                        $q = "DELETE FROM phenome.stock_allele WHERE stock_id = ? AND allele_id = ?;";
                        $sth = $dbh->prepare($q);
                        $sth->execute($ea_stock_id, $ea_id);
                    }
                }
            }

            # Add new association, if it doesn't already exist
            if ( !$skip ) {
                $q = "INSERT INTO public.stockprop (stock_id, type_id, value, rank) SELECT ?, cvterm_id, ?, ? FROM public.cvterm WHERE name = 'sgn allele_id';";
                $sth = $dbh->prepare($q);
                $sth->execute($accession_id, $value_id, $value_id);

                $q = "INSERT INTO phenome.stock_allele (stock_id, allele_id, metadata_id) VALUES (?, ?, ?);";
                $sth = $dbh->prepare($q);
                $sth->execute($accession_id, $value_id, $metadata_id);
            }
        }

    };

    if ($@) {
        $dbh->rollback();
        return $@;
    }
    else {
        $dbh->commit();
        return;
    }
}

#
# Get all of the existing Locus names
# PARAMS:
# RETURNS:
#   an array of locus names
#
sub get_used_genetic_character_names {
    my $c = SGN::Context->new;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh();

    my $q = "SELECT DISTINCT(locus_name) AS name FROM phenome.locus ORDER BY name;";
    my $sth = $dbh->prepare($q);
    $sth->execute();

    my @names;
    while ( my ($name) = $sth->fetchrow_array() ) {
        push(@names, $name);
    }

    return \@names;
}

#
# Get all of the existing Locus symbols
# PARAMS:
# RETURNS:
#   an array of locus symbols
#
sub get_used_genetic_character_symbols {
    my $c = SGN::Context->new;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh();

    my $q = "SELECT DISTINCT(locus_symbol) AS symbol FROM phenome.locus ORDER BY symbol;";
    my $sth = $dbh->prepare($q);
    $sth->execute();

    my @symbols;
    while ( my ($symbol) = $sth->fetchrow_array() ) {
        push(@symbols, $symbol);
    }

    return \@symbols;
}

#
# Get all of the existing Allele symbols
# PARAMS:
# RETURNS:
#   an array of allele symbols
#
sub get_used_value_symbols {
    my $c = SGN::Context->new;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh();

    my $q = "SELECT DISTINCT(allele_symbol) FROM phenome.allele ORDER BY allele_symbol;";
    my $sth = $dbh->prepare($q);
    $sth->execute();

    my @symbols;
    while ( my ($symbol) = $sth->fetchrow_array() ) {
        push(@symbols, $symbol);
    }

    return \@symbols;
}

#
# Get existing associations between the specified Accession and a different allele 
# for the same locus as the existing allele - to warn the user that the association 
# for the accession will change to a different allele if the upload proceeds.
# PARAMS:
#   - accession_name = name of accession
#   - gcv_symbol = symbol of genetic character value to be added
# RETURNS:
#   an array of hashes with info on the existing allele association
#
sub get_existing_associations {
    my $self = shift;
    my $accession_name = shift;
    my $gcv_symbol = shift;
    my $c = SGN::Context->new;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh();

    my $q = "SELECT stockprop_id, stock_id, allele_id, locus_id, allele_symbol, allele_name
            FROM public.stockprop
            LEFT JOIN phenome.allele ON (stockprop.value::integer = allele.allele_id)
            WHERE stock_id = (SELECT stock_id FROM public.stock WHERE uniquename = ?)
            AND type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'sgn allele_id')
            AND stockprop.value IN (
                SELECT allele_id::text FROM phenome.allele WHERE locus_id IN (
                    SELECT DISTINCT(locus_id) FROM phenome.allele WHERE allele_symbol = ?
                )
            );";
    my $sth = $dbh->prepare($q);
    $sth->execute($accession_name, $gcv_symbol);

    my @existing;
    while ( my ($stockprop_id, $stock_id, $allele_id, $locus_id, $allele_symbol, $allele_name) = $sth->fetchrow_array() ) {
        push(@existing, {
            stockprop_id => $stockprop_id,
            stock_id => $stock_id,
            allele_id => $allele_id,
            locus_id => $locus_id,
            allele_symbol => $allele_symbol,
            allele_name => $allele_name
        });
    }

    return \@existing;
}

#
# Get information on all of the T3 Genetic Character Ontology terms
# PARAMS:
# RETURNS:
#   An array of hashes with the following keys:
#       - name = T3 Genetic Character ontology term cvterm name
#       - code = T3 Genetic Character ontology term accession name
#       - id = T3 Genetic Character ontology term dbxref id
#
sub get_categories() {
    my $c = SGN::Context->new;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh();
    
    my $dbxref_ids = _get_category_dbxref_ids();
    my $q = "SELECT dbxref_id AS id, accession AS code, cvterm.name AS name
            FROM public.dbxref
            LEFT JOIN public.cvterm USING (dbxref_id)
            WHERE dbxref_id IN (" . join(",", ("?") x @$dbxref_ids) . ");";
    my $sth = $dbh->prepare($q);
    $sth->execute(@$dbxref_ids);

    my @categories;
    while ( my ($id, $code, $name) = $sth->fetchrow_array() ) {
        push(@categories, {
            id => $id,
            code => $code,
            name => $name
        });
    }

    return \@categories;
}

#
# Get the organisms from the sgn.common_name table
# PARAMS:
# RETURNS:
#   An array of hashes with the following keys:
#       - id = common name id
#       - name = common name
#
sub get_organisms() {
    my $c = SGN::Context->new;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh();

    my $q = "SELECT common_name_id, common_name FROM sgn.common_name ORDER BY common_name;";
    my $sth = $dbh->prepare($q);
    $sth->execute();

    my @organisms;
    while ( my ($id, $name) = $sth->fetchrow_array() ) {
        push(@organisms, {
            id => $id,
            name => $name
        });
    }

    return \@organisms;
}

# Get the dbxref ids of the T3 Genetic Character ontology terms
sub _get_category_dbxref_ids() {
    my $c = SGN::Context->new;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my @dbxref_ids = ();
    my $ontology_term = $c->config->{loci_filter_onto_gc};
    my ($db_name, $accession) = split(':', $ontology_term);
    my $db = $schema->resultset('General::Db')->search({ name => uc($db_name) })->first();
    if ( $db ) {
        my $dbxref = $db->find_related('dbxrefs', { accession => $accession });
        if ( $dbxref ) {
            push(@dbxref_ids, $dbxref->get_column('dbxref_id'));
            my $cvterm = $dbxref->cvterm;
            my $c_rs = $cvterm->recursive_children();
            while ( my $c_row = $c_rs->next() ) {
                push @dbxref_ids, $c_row->get_column('dbxref_id');
            }
        }
    }

    return \@dbxref_ids;
}

1;
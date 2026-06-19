#!/usr/bin/env perl

=head1 NAME

AddGenotypepropIndexes.pm

=head1 SYNOPSIS

mx-run AddGenotypepropIndexes [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds indexes to the genotypeprop table to optimize genotype download queries:
- Composite index on (genotype_id, type_id) for efficient genotype lookups
- GIN index on JSONB value column for marker data queries
- GIN index with jsonb_path_ops for optimized JSONB path operations

These indexes are critical for the bulk genotype query optimization in CXGN::Genotype::Search.
Expected performance improvement: 2-5x speedup on JSONB queries, enabling bulk queries
to fetch marker data for 1000+ genotypes in a single query instead of 2000-4000 queries.

=head1 AUTHOR

David Waring

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package AddGenotypepropIndexes;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
This patch adds optimized indexes to genotypeprop table for bulk genotype queries

sub patch {
    my $self = shift;

    print STDOUT "Executing the patch:\n " . $self->name . ".\n\nDescription:\n  " . $self->description . ".\n\nExecuted by:\n " . $self->username . " .\n";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    # Add composite index on genotype_id and type_id for efficient lookups
    print STDOUT "Creating composite index on (genotype_id, type_id)...\n";
    $self->dbh->do(<<EOSQL);
CREATE INDEX IF NOT EXISTS idx_genotypeprop_genotype_type
    ON public.genotypeprop(genotype_id, type_id);
EOSQL

    # Add GIN index on JSONB value column for marker data queries
    print STDOUT "Creating GIN index on value column...\n";
    $self->dbh->do(<<EOSQL);
CREATE INDEX IF NOT EXISTS idx_genotypeprop_value_gin
    ON public.genotypeprop USING GIN (value);
EOSQL

    # Add optimized GIN index with jsonb_path_ops for JSONB path operations
    print STDOUT "Creating GIN index with jsonb_path_ops...\n";
    $self->dbh->do(<<EOSQL);
CREATE INDEX IF NOT EXISTS idx_genotypeprop_value_path_ops
    ON public.genotypeprop USING GIN (value jsonb_path_ops);
EOSQL

    print STDOUT "\nIndexes created successfully.\n";
    print STDOUT "Analyzing table to update statistics...\n";

    # Run ANALYZE to update table statistics for query planner
    $self->dbh->do(<<EOSQL);
ANALYZE public.genotypeprop;
EOSQL

    print STDOUT "Done.\n";
}

1;

#!/usr/bin/env perl


=head1 NAME

AddStockPropCvterms.pm

=head1 SYNOPSIS

mx-run AddStockPropCvterms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds the purdy pedigree and filial generation cvterms into the stock_property cv.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

David Waring <djw64@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddStockPropCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will create cvterms called purdy pedigree and filial generation in the stock_property cv

has '+prereq' => (
    default => sub {
        ['AddVectorStockType'],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $coderef = sub {

        my $purdy_pedigree_cvterm = $schema->resultset("Cv::Cvterm")->create_with({
            name => 'purdy pedigree',
            cv   => 'stock_property',
        });

        my $filial_generation_cvterm = $schema->resultset("Cv::Cvterm")->create_with({
            name => 'filial generation',
            cv   => 'stock_property',
        });

    };

    try {
        $schema->txn_do($coderef);
    
    } catch {
        die "Load failed! " . $_ .  "\n" ;
    };

    print "You're done!\n";
}


####
1; #
####
 

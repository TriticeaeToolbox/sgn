
=head1 NAME

CXGN::MixedModels - a package to run user-specified mixed models

=head1 DESCRIPTION

  my $mm = CXGN::MixedModels->new();
  my $mm->phenotype_file("t/data/phenotype_data.csv");
  my $mm->dependent_variables(qw | |);
  my $mm->fixed_factors( qw | | );
  my $mm->random_factors( qw| | );
  my $mm->traits( qw|  | );

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 METHODS

=cut

package CXGN::MixedModels;

use Moose;
use Data::Dumper;
use File::Slurp qw| slurp |;
use CXGN::Tools::Run;
use CXGN::Phenotypes::File;

=head2 dependent_variables() 

sets the dependent variables (a listref of traits)

=cut

has 'dependent_variables' => (is => 'rw', isa => 'ArrayRef[Str]|Undef');

=head2 fixed_factors()

sets the fixed factors (listref)

=cut
    
has 'fixed_factors' => (is => 'rw', isa => 'Ref', default => sub {[]});

=head2 fixed_factors_interaction()

sets the fixed factors with interaction (listref)

=cut
    
has 'fixed_factors_interaction' => (is => 'rw', isa => 'Ref', default => sub{[]});

=head2 variable_slope_factors()

=cut
    
has 'variable_slope_factors' => (is => 'rw', isa => 'Ref', default => sub{[]});

=head2 random_factors()

=cut
    
has 'random_factors' => (is => 'rw', isa => 'Ref', default => sub {[]});

=head2 variable_slop_intersects

=cut
   
has 'variable_slope_intersects' => (is => 'rw', isa => 'Ref', default => sub {[]});

=head2 traits()

sets the traits

=cut

has 'traits' => (is => 'rw', isa => 'Ref');

=head2 levels()



=cut

has 'levels' => (is => 'rw', isa => 'HashRef' );

has 'phenotype_file' => (is => 'rw', isa => 'CXGN::Phenotypes::File|Undef');

=head2 tempfile()

the tempfile that contains the phenotypic information.

=cut
    
has 'tempfile' => (is => 'rw', isa => 'Str|Undef');

sub BUILD {
    my $self = shift;

    my $phenotype_file;

    if ($self->tempfile()) {
	$phenotype_file = CXGN::Phenotypes::File->new( { file => $self->tempfile() } );
    }
    $self->phenotype_file($phenotype_file);

}

=head2 generate_models()

generates the model string, in lme4 format, from the current parameters

=cut

sub generate_model {
    my $self = shift;

    my $tempfile = $self->tempfile();
    my $dependent_variables = $self->dependent_variables();
    my $fixed_factors = $self->fixed_factors();
    my $fixed_factors_interaction = $self->fixed_factors_interaction();
    my $variable_slope_intersects = $self->variable_slope_intersects();
    my $random_factors = $self->random_factors();

    my $error;

    my @addends = ();

    print STDERR join("\n", ("DV", Dumper($dependent_variables), "FF", Dumper($fixed_factors), "RF", Dumper($random_factors), "TF", $tempfile, "FFI", Dumper($fixed_factors_interaction), "VSI: ", Dumper($variable_slope_intersects)));

    print STDERR Dumper($fixed_factors);
    my $model = "";

    if (! $dependent_variables || scalar(@$dependent_variables)==0) {
	die "Need a dependent variable(s) set in CXGN::MixedModels... Ciao!";
    }

    my $formatted_fixed_factors = "";
    if (@$fixed_factors) {
	$formatted_fixed_factors = join(" + ", @$fixed_factors);
	push @addends, $formatted_fixed_factors;
    }

    my $formatted_fixed_factors_interaction = "";
    foreach my $interaction (@$fixed_factors_interaction) {
	my $terms = "";
	if (ref($interaction)) {
	    $terms = join("*", @$interaction);
	    push @addends, $terms;
	}
	else {
	    $error = "Interaction terms are not correctly defined.";
	}
    }

    my $formatted_variable_slope_intersects = "";
    foreach my $variable_slope_groups (@$variable_slope_intersects) {
	if (exists($variable_slope_groups->[0]) && exists($variable_slope_groups->[1])) {
	    my $term = " (1+$variable_slope_groups->[0] \| $variable_slope_groups->[1]) ";
	    print STDERR "TERM: $term\n";
	    $formatted_variable_slope_intersects .= $term;
	    push @addends, $formatted_variable_slope_intersects;
	}
    }


    my $formatted_random_factors = "";
#    if ($random_factors_random_slope) {
#	$formatted_random_factors = " (1 + $random_factors->[0] | $random_factors->[1]) ";
#
#    }
 #   else {
	if (@$random_factors) {
	    $formatted_random_factors = join(" + ",  map { "(1|$_)" } @$random_factors);
	    push @addends, $formatted_random_factors;
	}

    #}
    $model .= join(" + ", @addends);

    return $model;
}

=head2 run_models()

runs the model along with the data provided in the phenotyping file

=cut

sub run_model {
    my $self = shift;

    my $tempfile = $self->tempfile();

    # generate params_file
    #
    my $param_file = $tempfile.".params";
    open(my $F, ">", $param_file) || die "Can't open $param_file for writing.";
    my $model = $self->generate_model();
    print $F $model;
    close($F);

    # run r script to create model
    #
    my $cmd = "R CMD BATCH  '--args datafile=\"".$tempfile."\" paramfile=\"".$tempfile.".params\"' R/mixed_models.R $tempfile.out";

    print STDERR Dumper($tempfile);

    print STDERR "running R command $cmd...\n";
    system($cmd);
    print STDERR "Done.\n";

    my $resultfile = $tempfile.".results";

}


1;

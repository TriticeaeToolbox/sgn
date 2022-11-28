
package SGN::Controller::Status;

use Moose;
use Data::Dumper;

BEGIN { extends "Catalyst::Controller"; }



sub status : Path('/status') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $dbh = $c->dbc->dbh();
    my $h;


    # Breeding Programs
    $h = $dbh->prepare("SELECT COUNT(breeding_program_id) AS count FROM breeding_programs WHERE breeding_program_id IS NOT NULL;");
    $h->execute();
    my ($breeding_program_count) = $h->fetchrow_array() and $h->finish();

    # Accessions
    $h = $dbh->prepare("SELECT COUNT(accession_id) AS count FROM accessions WHERE accession_id IS NOT NULL;");
    $h->execute();
    my ($accession_count) = $h->fetchrow_array() and $h->finish();

    # Accessions with Phenotype Data
    # Accessions associated with 1 or more trait
    $h = $dbh->prepare("SELECT COUNT(DISTINCT accession_id) AS count FROM accessionsxtraits WHERE trait_id IS NOT NULL AND accession_id IS NOT NULL;");
    $h->execute();
    my ($accession_count_pheno) = $h->fetchrow_array() and $h->finish();

    # Accessions with Genotype Data
    # Accessions associated with 1 or more genotyping protocol
    $h = $dbh->prepare("SELECT COUNT(DISTINCT accession_id) AS count FROM accessionsxgenotyping_protocols WHERE genotyping_protocol_id IS NOT NULL AND accession_id IS NOT NULL;");
    $h->execute();
    my ($accession_count_geno) = $h->fetchrow_array() and $h->finish();

    # Observed Traits
    # Count of traits that have observed values
    $h = $dbh->prepare("SELECT COUNT(DISTINCT observable_id) AS count FROM phenotype;");
    $h->execute();
    my ($trait_count) = $h->fetchrow_array() and $h->finish();

    # Phenotype Trials
    # Count of projects excluding all "non-trial" projects
    $h = $dbh->prepare("SELECT COUNT(DISTINCT(project_id)) AS count FROM public.project WHERE project_id NOT IN (SELECT DISTINCT(project_id) FROM public.projectprop WHERE type_id IN (SELECT cvterm_id FROM cvterm WHERE name IN ('breeding_program', 'crossing_trial', 'folder_for_trials', 'genotyping_facility', 'trial_folder')));");
    $h->execute();
    my ($pheno_trial_count) = $h->fetchrow_array() and $h->finish();

    # Get Count of Pheno Trials with Observations
    $h = $dbh->prepare("SELECT COUNT(DISTINCT(trial_id)) FROM traitsxtrials WHERE trial_id IS NOT NULL and trait_id IS NOT NULL");
    $h->execute();
    my ($pheno_trial_observation_count) = $h->fetchrow_array() and $h->finish();

    # Get Plot Count
    $h = $dbh->prepare("SELECT COUNT(DISTINCT(plot_id)) FROM plots;");
    $h->execute();
    my ($plot_count) = $h->fetchrow_array() and $h->finish();

    # Get Count of Plots with Observations
    $h = $dbh->prepare("SELECT COUNT(DISTINCT(plot_id)) FROM plotsxtraits WHERE trait_id IS NOT NULL AND plot_id IS NOT NULL;");
    $h->execute();
    my ($plot_observation_count) = $h->fetchrow_array() and $h->finish();

    # Get Count of Total Pheno Observations
    $h = $dbh->prepare("SELECT COUNT(DISTINCT phenotype_id) FROM materialized_phenoview WHERE phenotype_id IS NOT NULL AND trait_id IS NOT NULL;");
    $h->execute();
    my ($pheno_observations) = $h->fetchrow_array() and $h->finish();

    # Get last pheno addition date
    $h = $dbh->prepare("SELECT MAX(create_date) FROM phenotype;");
    $h->execute();
    my ($pheno_last_addition) = $h->fetchrow_array() and $h->finish();

    # Get gentic map count
    $h = $dbh->prepare("SELECT COUNT(map_id) FROM sgn.map;");
    $h->execute();
    my ($geno_map_count) = $h->fetchrow_array() and $h->finish();

    # Get genotype protocol count
    $h = $dbh->prepare("SELECT COUNT(genotyping_protocol_id) FROM genotyping_protocols;");
    $h->execute();
    my ($geno_protocol_count) = $h->fetchrow_array() and $h->finish();

    # Get genotype project count
    $h = $dbh->prepare("SELECT COUNT(project_id) AS count FROM project WHERE project_id IN (SELECT project_id FROM projectprop WHERE value = 'genotype_data_project' AND type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'design' AND cv_id = (SELECT cv_id FROM cv WHERE name = 'project_property')));");
    $h->execute();
    my ($geno_project_count) = $h->fetchrow_array() and $h->finish();

    # Get marker count
    $h = $dbh->prepare("SELECT COUNT(marker_id) FROM sgn.marker;");
    $h->execute();
    my ($marker_count) = $h->fetchrow_array() and $h->finish();

    # Get last geno addition date
    $h = $dbh->prepare("SELECT MAX(create_date) FROM genotype;");
    $h->execute();
    my ($geno_last_addition) = $h->fetchrow_array() and $h->finish();

    # Pass query results to template
    $c->stash->{accession_count} = $accession_count;
    $c->stash->{breeding_program_count} = $breeding_program_count;
    $c->stash->{accession_count_pheno} = $accession_count_pheno;
    $c->stash->{accession_count_geno} = $accession_count_geno;
    $c->stash->{trait_count} = $trait_count;
    $c->stash->{pheno_trial_count} = $pheno_trial_count;
    $c->stash->{pheno_trial_observation_count} = $pheno_trial_observation_count;
    $c->stash->{plot_count} = $plot_count;
    $c->stash->{plot_observation_count} = $plot_observation_count;
    $c->stash->{pheno_observations} = $pheno_observations;
    $c->stash->{pheno_last_addition} = $pheno_last_addition;
    $c->stash->{geno_map_count} = $geno_map_count;
    $c->stash->{geno_protocol_count} = $geno_protocol_count;
    $c->stash->{geno_project_count} = $geno_project_count;
    $c->stash->{marker_count} = $marker_count;
    $c->stash->{geno_last_addition} = $geno_last_addition;
    $c->stash->{template} = '/about/sgn/status.mas';
}

1;

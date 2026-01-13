package SGN::Controller::Submit;

use Moose;
use SGN::View::Stock qw/breeding_programs/;
use CXGN::Genotype::Protocol qw/list_simple/;
use URI::FromHash 'uri';

BEGIN { extends "Catalyst::Controller"; }


sub submit_geno : Path('/submit/geno') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $vcf_upload_url = $c->config->{vcf_upload_url};

    # VCF Upload URL needs to be set in the config file
    if ( !$vcf_upload_url ) {
        $c->stash->{template} = 'generic_message.mas';
        $c->stash->{message} = "<p><strong>VCF File Submissions Not Enabled</strong></p><p>This server has not been configured to accept VCF file submissions.</p>";
        return;
    }

    # Add user info, if logged in
    my $user = $c->user();
    if ( $user ) {
        $c->stash->{name} = $user->get_first_name() . " " . $user->get_last_name();
        $c->stash->{email} = $user->get_private_email();
    }
    else {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    # Get Genotyping Protocols
    my @protocols = ([0, '']);
    my $q = "SELECT genotyping_protocol_id, genotyping_protocol_name FROM public.genotyping_protocols WHERE genotyping_protocol_name IS NOT NULL GROUP BY genotyping_protocol_id, genotyping_protocol_name ORDER BY genotyping_protocol_name;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    while (my ($id, $name) = $h->fetchrow_array()) {
        push(@protocols, [$id, $name]);
    }

    # Get Reference Genomes
    my @reference_genomes = (['', '']);
    $q = "SELECT value->>'species_name' AS species, value->>'reference_genome_name' AS reference_genome
        FROM nd_protocolprop 
        WHERE type_id = (SELECT cvterm_id FROM public.cvterm WHERE name = 'vcf_map_details')
        GROUP BY species, reference_genome
        ORDER BY species, reference_genome;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    while (my ($species, $reference) = $h->fetchrow_array()) {
        push(@reference_genomes, [$species, $reference]);
    }

    # Get Gentoyping Facilities from the configuration file
    my @genotyping_facilities = split(',', $c->config->{genotyping_facilities});

    # Add data for select boxes
    $c->stash(
        breeding_programs => SGN::View::Stock::breeding_programs($schema),
        genotyping_protocols => \@protocols,
        reference_genomes => \@reference_genomes,
        genotyping_facilities => \@genotyping_facilities
    );

    $c->stash->{template} = '/submit/geno.mas';
}

sub submit_multiple_trials : Path('/submit/trials') Args(0) {
    my $self = shift;
    my $c = shift;

    my $allow_trial_submissions = $c->config->{allow_trial_submissions};
    if ( !$allow_trial_submissions ) {
        $c->stash->{template} = 'generic_message.mas';
        $c->stash->{message} = "<p><strong>Trial Submissions Not Enabled</strong></p><p>Trial submissions are not allowed on this server.</p>";
        return;
    }

    $c->stash->{template} = '/submit/trials.mas';
}


sub phenotype_upload_workflow : Path('/submit/pheno') Args(0) {
    my $self = shift;
    my $c = shift;

    my $allow_file_submissions = $c->config->{allow_file_submissions};
    if ( !$allow_file_submissions ) {
        $c->stash->{template} = 'generic_message.mas';
        $c->stash->{message} = "<p><strong>File Submissions Not Enabled</strong></p><p>File submissions are not allowed on this server.</p>";
        return;
    }

    my $user = $c->user();
    if ( $user ) {
        $c->stash->{name} = $user->get_first_name() . " " . $user->get_last_name();
        $c->stash->{email} = $user->get_private_email();
    }

    $c->stash->{template} = '/submit/pheno.mas';
}


sub view_submission_files : Path('/submit/view') Args(2) {
    my $self = shift;
    my $c = shift;
    my $user_id = shift;
    my $sub_dir = shift;

    my $submission_path = $c->config->{submission_path};

    # redirect to login page if not logged in
    if (! $c->user()) { 
        $c->res->redirect('/user/login?goto_url=' . $c->req->uri->path_query);
        return;
    }

    # Build directory path
    my $dir = $submission_path . "/" . $user_id . "/" . $sub_dir;

    # Check directory exists
    if ( !-d $dir ) {
        $c->stash->{template} = 'generic_message.mas';
        $c->stash->{message} = "<p><strong>Submission Not Found</strong></p><p>The directory <code>$dir</code> could not be found on this server.</p>";
        return;
    }

    # List files
    my @files = ();
    opendir (DIR, $dir) or die $!;
    while (my $file = readdir(DIR)) {
        push @files, $file if $file !~ /^\./;
    }
    @files = sort @files;

    $c->stash->{user_id} = $user_id;
    $c->stash->{sub_dir} = $sub_dir;
    $c->stash->{dir} = $dir;
    $c->stash->{files} = \@files;
    $c->stash->{template} = '/submit/view.mas';
}


sub view_submission_file : Path('/submit/view') Args(3) {
    my $self = shift;
    my $c = shift;
    my $user_id = shift;
    my $sub_dir = shift;
    my $file = shift;

    my $submission_path = $c->config->{submission_path};

    # redirect to login page if not logged in
    if (! $c->user()) { 
        $c->res->redirect('/user/login?goto_url=' . $c->req->uri->path_query);
        return;
    }

    # Build directory path
    my $dir = $submission_path . "/" . $user_id . "/" . $sub_dir;

    # Check directory exists
    if ( !-d $dir ) {
        $c->stash->{template} = 'generic_message.mas';
        $c->stash->{message} = "<p><strong>Submission Not Found</strong></p><p>The directory <code>$dir</code> could not be found on this server.</p>";
        return;
    }

    # Build file path
    my $file_path = $dir . "/" . $file;

    # Check file exists
    if ( !-e $file_path ) {
        $c->stash->{template} = 'generic_message.mas';
        $c->stash->{message} = "<p><strong>Submission File Not Found</strong></p><p>The file <code>$file_path</code> could not be found on this server.</p>";
        return;
    }

    # Serve the file
    open my $fh, '<', $file_path;
    $c->res->header('Content-Disposition', qq[attachment; filename="$file"]);
    $c->res->body($fh);
}

1;
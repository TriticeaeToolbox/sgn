
package SGN::Controller::AJAX::Trials;

use Moose;

use CXGN::BreedersToolbox::Projects;
use CXGN::Trial::Folder;
use Data::Dumper;
use Carp;
use File::Path qw(make_path);
use File::Spec::Functions qw / catfile catdir/;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub get_trials : Path('/ajax/breeders/get_trials') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") } );

    my $projects = $p->get_breeding_programs();

    my %data = ();
    foreach my $project (@$projects) { 
        my $trials = $p->get_trials_by_breeding_program($project->[0]);
        $data{$project->[1]} = $trials;

    }

    $c->stash->{rest} = \%data;
}

sub get_trials_with_folders : Path('/ajax/breeders/get_trials_with_folders') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $schema  } );

    my $projects = $p->get_breeding_programs();

    my $html = "";
    foreach my $project (@$projects) { 
	   my $folder = CXGN::Trial::Folder->new( { bcs_schema => $schema, folder_id => $project->[0] });
	   $html .= $folder->get_jstree_html('breeding_program');
    }
    
    my $dir = catdir($c->site_cluster_shared_dir, "folder");
    eval { make_path($dir) };
    if ($@) {
        print "Couldn't create $dir: $@";
    }
    my $filename = $dir."/entire_jstree_html.txt";

    my $OUTFILE;
    open $OUTFILE, '>', $filename or die "Error opening $filename: $!";
    print { $OUTFILE } $html or croak "Cannot write to $filename: $!";
    close $OUTFILE or croak "Cannot close $filename: $!";

    $c->stash->{rest} = { status => 1 };
}

sub get_trials_with_folders_cached : Path('/ajax/breeders/get_trials_with_folders_cached') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $dir = catdir($c->site_cluster_shared_dir, "folder");
    my $filename = $dir."/entire_jstree_html.txt";
    my $html = '';
    open(my $fh, '<', $filename) or die "cannot open file $filename";
    {
        local $/;
        $html = <$fh>;
    }
    close($fh);

    #print STDERR $html;
    $c->stash->{rest} = { html => $html };
}

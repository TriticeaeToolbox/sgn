
=head1 NAME

SGN::Controller::AJAX::Search::GenotypingDataProject - a REST controller class to provide genotyping data project

=head1 DESCRIPTION


=head1 AUTHOR

=cut

package SGN::Controller::AJAX::Search::GenotypingDataProject;

use Moose;
use Data::Dumper;
use JSON;
use CXGN::People::Login;
use CXGN::Trial::Search;
use CXGN::Genotype::GenotypingProject;
use CXGN::Genotype::Protocol;
use CXGN::Trial;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );

sub genotyping_data_project_search : Path('/ajax/genotyping_data_project/search') : ActionClass('REST') { }

sub genotyping_data_project_search_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema=>$bcs_schema,
        trial_design_list=>['genotype_data_project', 'pcr_genotype_data_project']
    });
    my ($data, $total_count) = $trial_search->search();
    my @result;
    foreach (@$data){
        my $genotyping_project_id = $_->{trial_id};

        my $plate_info = CXGN::Genotype::GenotypingProject->new({
            bcs_schema => $bcs_schema,
            project_id => $genotyping_project_id
        });
        my ($plate_data, $number_of_plates) = $plate_info->get_plate_info();
        my $total_accession_count = 0;
        if ($plate_data) {
            foreach (@$plate_data) {
                my $trial_id = $_->{trial_id};
                my $trial = CXGN::Trial->new( { bcs_schema => $bcs_schema, trial_id => $trial_id });
                my $accession_count = $trial->get_trial_stock_count();
                $total_accession_count += $accession_count;
            }
        }

        my $folder_string = '';
        if ($_->{folder_name}){
            $folder_string = "<a href=\"/folder/$_->{folder_id}\">$_->{folder_name}</a>";
        }
        my $design = $_->{design};
        my $data_type;
        if ($design eq 'pcr_genotype_data_project') {
            $data_type = 'SSR';
        } else {
            $data_type = 'SNP';
        }
        print STDERR "DESIGN =".Dumper($design)."\n";
        push @result,
          [
            "<a href=\"/breeders_toolbox/trial/$_->{trial_id}\">$_->{trial_name}</a>",
            $data_type,
            $_->{description},
            "<a href=\"/breeders/program/$_->{breeding_program_id}\">$_->{breeding_program_name}</a>",
            $folder_string,
            $_->{year},
            $_->{location_name},
            $_->{genotyping_facility},
            $number_of_plates,
            $total_accession_count
          ];
    }
    #print STDERR Dumper \@result;

    $c->stash->{rest} = { data => \@result };
}

sub genotyping_data_public_search : Path('/ajax/genotyping_data_public/search') : ActionClass('REST') { }

sub genotyping_data_public_search_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $public_date;
    my $create_date;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema=>$bcs_schema,
        trial_design_list=>['genotype_data_project', 'pcr_genotype_data_project']
    });
    my ($data, $total_count) = $trial_search->search();
    my $copied_to_t3_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'copied_to_t3', 'project_property')->cvterm_id();
    my $transferred = "";
    my @result;
    foreach (@$data){
        my $folder_string = '';

	my $q = "select create_date from project where project_id = ?";
	my $h = $bcs_schema->storage->dbh()->prepare($q);
	$h->execute($_->{trial_id});
	my @info = $h->fetchrow_array();
        $create_date = $info[0];
	my $dt1 = DateTime->now;
        my $dt2 = $dt1 - DateTime::Duration->new( years => 2 );
	if ($create_date =~ /(\d+)-(\d+)-(\d+)/) {
            my $dt3 = DateTime->new(
                year => $1,
                month => $2,
                day => $3
            );
            $create_date = $1 . "-" . $2 . "-" . $3;
            my $cmp = DateTime->compare( $dt2, $dt3 );
	    if ($cmp < 0) {
                $public_date = int($1) + 2 . "-" . $2 . "-" . $3;
            } else {
                $public_date = "now";
            }
	}

	$q = "SELECT projectprop.value FROM projectprop WHERE projectprop.type_id = ? AND projectprop.project_id = ?";
	$h = $bcs_schema->storage->dbh()->prepare($q);
        $h->execute($copied_to_t3_cvterm_id, $_->{trial_id});
        my @info = $h->fetchrow_array();
        $transferred = $info[0];

        if ($_->{folder_name}){
            $folder_string = "<a href=\"/folder/$_->{folder_id}\">$_->{folder_name}</a>";
        }
        push @result,
          [
            "<a href=\"/breeders_toolbox/trial/$_->{trial_id}\">$_->{trial_name}</a>",
            $_->{description},
            "<a href=\"/breeders/program/$_->{breeding_program_id}\">$_->{breeding_program_name}</a>",
            $_->{year},
	    $create_date,
            $public_date,
            $transferred
          ];
	  #print STDERR Dumper $_;
    }
    #print STDERR Dumper \@result;

    $c->stash->{rest} = { data => \@result };
}

sub genotyping_project_plates : Path('/ajax/genotyping_project/genotyping_plates') : ActionClass('REST') { }

sub genotyping_project_plates_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $genotyping_project_id = $c->req->param('genotyping_project_id');

    my $plate_info = CXGN::Genotype::GenotypingProject->new({
        bcs_schema => $bcs_schema,
        project_id => $genotyping_project_id
    });
    my ($data, $total_count) = $plate_info->get_plate_info();
    my @result;
    foreach (@$data){
        my $folder_string = '';
        if ($_->{folder_name}){
            $folder_string = "<a href=\"/folder/$_->{folder_id}\">$_->{folder_name}</a>";
        }
        push @result,
        [
            "<a href=\"/breeders_toolbox/trial/$_->{trial_id}\">$_->{trial_name}</a>",
            $_->{description},
            $folder_string,
            $_->{genotyping_plate_format},
            $_->{genotyping_plate_sample_type},
            "<a class='btn btn-sm btn-default' href='/breeders/trial/$_->{trial_id}/download/layout?format=csv&dataLevel=plate'>Download Layout</a>"
        ];
    }

    $c->stash->{rest} = { data => \@result };

}


sub genotyping_project_plate_names : Path('/ajax/genotyping_project/plate_names') : ActionClass('REST') { }

sub genotyping_project_plate_names_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $genotyping_project_id = $c->req->param('genotyping_project_id');

    my $plate_info = CXGN::Genotype::GenotypingProject->new({
        bcs_schema => $bcs_schema,
        project_id => $genotyping_project_id
    });
    my ($data, $total_count) = $plate_info->get_plate_info();
    my @plates;
    foreach  my $plate(@$data){
        my $plate_id = $plate->{trial_id};
        my $plate_name = $plate->{trial_name};
        push @plates, {plate_name => $plate_name, plate_id => $plate_id};
    }

    $c->stash->{rest} = { data => \@plates };

}


sub genotyping_project_protocols : Path('/ajax/genotyping_project/protocols') : ActionClass('REST') { }

sub genotyping_project_protocols_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $genotyping_project_id = $c->req->param('genotyping_project_id');
    my @project_list = ($genotyping_project_id);
    my $protocol_search_result = CXGN::Genotype::Protocol::list($bcs_schema, undef, undef, undef, undef, undef ,\@project_list);
#    print STDERR "PROTOCOL SEARCH RESULT =".Dumper($protocol_search_result)."\n";
    my @protocol_info;
    foreach my $protocol (@$protocol_search_result){
        my $protocol_id = $protocol->{protocol_id};
        my $protocol_name = $protocol->{protocol_name};
        push @protocol_info, {
            protocol_id => $protocol_id,
            protocol_name => $protocol_name
        }

    }


    $c->stash->{rest} = { data => \@protocol_info };

}



1;


package SGN::Controller::AJAX::Search::Trial;

use Moose;
use Data::Dumper;
use CXGN::Trial;
use CXGN::Trial::Search;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

sub search : Path('/ajax/search/trials') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my @location_ids;
    my $location_id = $c->req->param('location_id');
    if ($location_id && $location_id ne 'not_provided'){
        #print STDERR "location id: " . $location_id . "\n";
        push @location_ids, $location_id;
    }

    my $checkbox_select_name = $c->req->param('select_checkbox_name');
    my $field_trials_only = $c->req->param('field_trials_only') || 1;
    my $trial_design_list = $c->req->param('trial_design') ? [$c->req->param('trial_design')] : [];

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema=>$schema,
        location_id_list=>\@location_ids,
        field_trials_only=>$field_trials_only,
        trial_design_list=>$trial_design_list
    });
    my ($data, $total_count) = $trial_search->search();
    my @result;
    my %selected_columns = ('plot_name'=>1, 'plot_id'=>1, 'block_number'=>1, 'plot_number'=>1, 'rep_number'=>1, 'row_number'=>1, 'col_number'=>1, 'accession_name'=>1, 'is_a_control'=>1);
    my $selected_columns_json = encode_json \%selected_columns;
    foreach (@$data){
        my $folder_string = '';
        if ($_->{folder_name}){
            $folder_string = "<a href=\"/folder/$_->{folder_id}\">$_->{folder_name}</a>";
        }
        my @res;
        if ($checkbox_select_name){
            push @res, "<input type='checkbox' name='$checkbox_select_name' value='$_->{trial_id}'>";
        }
        push @res, (
            "<a href=\"/breeders_toolbox/trial/$_->{trial_id}\">$_->{trial_name}</a>",
            $_->{description},
            "<a href=\"/breeders/program/$_->{breeding_program_id}\">$_->{breeding_program_name}</a>",
            $folder_string,
            $_->{year},
            $_->{location_name},
            $_->{trial_type},
            $_->{design},
            $_->{project_planting_date},
            $_->{project_harvest_date},
            "<a class='btn btn-sm btn-default' href='/breeders/trial/$_->{trial_id}/download/layout?format=csv&dataLevel=plots&selected_columns=$selected_columns_json'>Download Plot Layout</a>"
        );
        push @result, \@res;
    }
    #print STDERR Dumper \@result;

    $c->stash->{rest} = { data => \@result };
}

sub search_public : Path('/ajax/search/trials_public') : Args(0) {
    my $self = shift;
    my $c    = shift;
    my $public_date;
    my $create_date;

    my @location_ids;
    my $location_id = $c->req->param('location_id');
    if ($location_id && $location_id ne 'not_provided'){
        #print STDERR "location id: " . $location_id . "\n";
        push @location_ids, $location_id;
    }

    my $checkbox_select_name = $c->req->param('select_checkbox_name');
    my $field_trials_only = $c->req->param('field_trials_only') || 1;
    my $trial_design_list = $c->req->param('trial_design') ? [$c->req->param('trial_design')] : [];

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema=>$schema,
        location_id_list=>\@location_ids,
        field_trials_only=>$field_trials_only,
        trial_design_list=>$trial_design_list
    });
    my ($data, $total_count) = $trial_search->search();
    my $copied_to_t3_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'copied_to_t3', 'project_property')->cvterm_id();
    my $transferred = "";
    my @result;
    my %selected_columns = ('plot_name'=>1, 'plot_id'=>1, 'block_number'=>1, 'plot_number'=>1, 'rep_number'=>1, 'row_number'=>1, 'col_number'=>1, 'accession_name'=>1, 'is_a_control'=>1);
    my $selected_columns_json = encode_json \%selected_columns;
    foreach (@$data){
        my @res;
        if ($checkbox_select_name){
            push @res, "<input type='checkbox' name='$checkbox_select_name' value='$_->{trial_id}'>";
        }
        my $q = "select create_date from project where project_id = ?";
        my $h = $schema->storage->dbh()->prepare($q);
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
        $h = $schema->storage->dbh()->prepare($q);
        $h->execute($copied_to_t3_cvterm_id, $_->{trial_id});
        @info = $h->fetchrow_array();
        $transferred = $info[0];

        # Query to get the count of defined row and col numbers in the trial layout
        # The layout is defined if the number of row and col numbers are not 0
        # (See the CXGN::Project->has_col_and_row_numbers() function)
        $q = "SELECT 
                SUM(CASE WHEN sub.row_number IS NULL THEN 0 ELSE 1 END) AS row_count, 
                SUM(CASE WHEN sub.col_number IS NULL THEN 0 ELSE 1 END) AS col_count
                FROM (
                    SELECT sub.key AS plot, sub.value->'row_number' AS row_number, sub.value->'col_number' AS col_number
                    FROM public.projectprop
                    CROSS JOIN LATERAL json_each(value::json) sub
                    WHERE project_id = ?
                    AND type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'trial_layout_json')
                ) AS sub;";
        $h = $schema->storage->dbh()->prepare($q);
        $h->execute($_->{trial_id});
        my @row_col_counts = $h->fetchrow_array();
        my $has_trial_layout = $row_col_counts[0] && $row_col_counts[1] && $row_col_counts[0] != 0 && $row_col_counts[1] != 0;

        push @res, (
            "<a href=\"/breeders_toolbox/trial/$_->{trial_id}\">$_->{trial_name}</a>",
            $_->{description},
            "<a href=\"/breeders/program/$_->{breeding_program_id}\">$_->{breeding_program_name}</a>",
            $_->{year},
            $_->{project_planting_date},
            $_->{project_harvest_date},
            $has_trial_layout ? '<span class="glyphicon glyphicon-ok-sign" style="color: #3c7d3d; font-size: 150%"></span>' : '',
            $create_date,
            $public_date,
            $transferred
        );
        push @result, \@res;
    }
    #print STDERR Dumper \@result;

    $c->stash->{rest} = { data => \@result };
}


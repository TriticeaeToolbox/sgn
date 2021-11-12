use strict;

package SGN::Controller::AJAX::GeneticCharacters;

use Moose;
use JSON;
use File::Basename;

use CXGN::UploadFile;
use CXGN::GeneticCharacters;
use CXGN::GeneticCharacters::ParseUpload;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);

sub genetic_character_organisms : Path('/ajax/genetic_characters/organisms') : ActionClass('REST') {
    my $self = shift;
    my $c = shift;

    my $organisms = CXGN::GeneticCharacters->get_organisms();

    $c->stash->{rest} = { organisms => $organisms };
    $c->detach();
}

sub genetic_characters_upload : Path('/ajax/genetic_characters/file_upload') : ActionClass('REST') { }
sub genetic_characters_upload_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $upload_file = $c->req->upload('file');
    my $upload_type = $c->req->param('type');
    my $organism = $c->req->param('organism');
    my $overwrite_conflicting = $c->req->param('overwrite_conflicting');
    my $keep_conflicting = $c->req->param('keep_conflicting');
    $overwrite_conflicting = $overwrite_conflicting && $overwrite_conflicting eq 'true' ? 1 : 0;
    $keep_conflicting = $keep_conflicting && $keep_conflicting eq 'true' ? 1 : 0;

    # Check Logged In Status
    if (!$c->user){
        $c->stash->{rest} = {error => 'You must be logged in to do this!'};
        $c->detach();
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_role = $c->user->get_object->get_user_type();
    if ( $user_role ne 'submitter' && $user_role ne 'curator' ) {
        $c->stash->{rest} = {error => 'You must have either submitter or curator privileges to add genetic characters.'};
        $c->detach();
    }

    # Check for required params
    if ( !defined $upload_file || $upload_file eq '' ) {
        $c->stash->{rest} = {error => 'You must provide the upload file!'};
        $c->detach();
    }
    if ( !defined $upload_type || $upload_type eq '' ) {
        $c->stash->{rest} = {error => 'You must provide the file type!'};
        $c->detach();
    }
    if ( $upload_type eq 'genetic_characters' && (!defined $organism || $organism eq '') ) {
        $c->stash->{rest} = {error => 'You must provide the organism id!'};
        $c->detach();
    }

    # Set file paths
    my $upload_original_name = $upload_file->filename();
    my $upload_tempfile = $upload_file->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $subdirectory = "genetic_characters_upload";

    # Upload and Archive file
    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filepath = $uploader->archive();
    if (!$archived_filepath) {
        $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive"};
        $c->detach();
    }

    # Parse Upload
    my $parser = CXGN::GeneticCharacters::ParseUpload->new(
        chado_schema => $schema, 
        filename => $archived_filepath,
        overwrite_conflicting => $overwrite_conflicting,
        keep_conflicting => $keep_conflicting
    );
    my $plugin = undef;
    if ( $upload_type eq 'genetic_characters' ) { $plugin = "GeneticCharactersXLS"; }
    elsif ( $upload_type eq 'genetic_character_values' ) { $plugin = "GeneticCharacterValuesXLS"; }
    elsif ( $upload_type eq 'genetic_character_associations' ) { $plugin = "GeneticCharacterAssociationsXLS"; }
    if ( !$plugin ) {
        $c->stash->{rest} = {error => "No upload plugin found for upload type $upload_type"};
        $c->detach();
    }
    $parser->load_plugin($plugin);
    my $parsed_data = $parser->parse();

    # No Parsed Data returned...
    if (!$parsed_data) {
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors()) {
            $c->stash->{rest} = {error => "Upload failed: could not get parsing errors"};
            $c->detach();
        } 
        else {
            $parse_errors = $parser->get_parse_errors();
            $c->stash->{rest} = {
                error => "Upload failed",
                messages => $parse_errors->{error_messages}
            };
            $c->detach();
        }
    }

    # Store Parsed Data
    my $error;
    if ( $upload_type eq 'genetic_characters' ) {
        $error = CXGN::GeneticCharacters->store_genetic_characters($user_id, $organism, $parsed_data);
    }
    elsif ( $upload_type eq 'genetic_character_values' ) {
        $error = CXGN::GeneticCharacters->store_genetic_character_values($user_id, $parsed_data);
    }
    elsif ( $upload_type eq 'genetic_character_associations' ) {
        $error = CXGN::GeneticCharacters->store_genetic_character_associations($user_id, $parsed_data, $overwrite_conflicting);
    }
    else {
        $error = "No store function defined!";
    }

    # Return error
    if ( $error ) {
        $c->stash->{rest} = {
            error => "Upload failed: Could not store data in database",
            messages => [$error]
        };
        $c->detach();
    }

    # Return success
    $c->stash->{rest} = {success => 1};
    $c->detach();
}

=head1 NAME

SGN::Controller::AJAX::PhenotypesUpload - a REST controller class to provide the
backend for uploading phenotype spreadsheets

=head1 DESCRIPTION

Uploading Phenotype Spreadsheets

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>
Naama Menda <nm249@cornell.edu>
Alex Ogbonna <aco46@cornell.edu>
Nicolas Morales <nm529@cornell.edu>

=cut

package SGN::Controller::AJAX::PhenotypesUpload;

use Moose;
use Try::Tiny;
use DateTime;
use File::Slurp;
use File::Spec::Functions;
use File::Copy;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub upload_phenotype_verify :  Path('/ajax/phenotype/upload_verify') : ActionClass('REST') { }
sub upload_phenotype_verify_POST : Args(1) {
    my ($self, $c, $file_type) = @_;
    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new();
    my $warning_status;

    my ($success_status, $error_status, $parsed_data, $plots, $traits, $phenotype_metadata, $timestamp_included, $data_level) = _prep_upload($c, $file_type);
    if (scalar(@$error_status)>0) {
        $c->stash->{rest} = {success => $success_status, error => $error_status };
        return;
    }

    my ($verified_warning, $verified_error) = $store_phenotypes->verify($c, $plots, $traits, $parsed_data, $phenotype_metadata, $timestamp_included);
    if ($verified_error) {
        push @$error_status, $verified_error;
        $c->stash->{rest} = {success => $success_status, error => $error_status };
        return;
    }
    if ($verified_warning) {
        push @$warning_status, $verified_warning;
    }
    push @$success_status, "File data verified. Plot names and trait names are valid.";

    $c->stash->{rest} = {success => $success_status, warning => $warning_status, error => $error_status};
}

sub upload_phenotype_store :  Path('/ajax/phenotype/upload_store') : ActionClass('REST') { }
sub upload_phenotype_store_POST : Args(1) {
    my ($self, $c, $file_type) = @_;
    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new();

    my ($success_status, $error_status, $parsed_data, $plots, $traits, $phenotype_metadata, $timestamp_included, $data_level) = _prep_upload($c, $file_type);
    if (scalar(@$error_status)>0) {
        $c->stash->{rest} = {success => $success_status, error => $error_status };
        return;
    }

    #upload_phenotype_store function redoes the same verification that upload_phenotype_verify does before actually uploading. maybe this should be commented out.
    #my ($verified_warning, $verified_error) = $store_phenotypes->verify($c,$plots,$traits, $parsed_data, $phenotype_metadata);
    #if ($verified_error) {
	#push @$error_status, $verified_error;
	#$c->stash->{rest} = {success => $success_status, error => $error_status };
	#return;
    #}
    #push @$success_status, "File data verified. Plot names and trait names are valid.";


    my $size = scalar(@$plots) * scalar(@$traits);
    my $stored_phenotype_error = $store_phenotypes->store($c, $size, $plots, $traits, $parsed_data, $phenotype_metadata, $data_level);

    if ($stored_phenotype_error) {
        push @$error_status, $stored_phenotype_error;
        $c->stash->{rest} = {success => $success_status, error => $error_status};
        return;
    }
    push @$success_status, "Metadata saved for archived file.";
    push @$success_status, "File data successfully stored.";

    $c->stash->{rest} = {success => $success_status, error => $error_status};
}

sub _prep_upload {
    my ($c, $file_type) = @_;
    my $uploader = CXGN::UploadFile->new();
    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $timestamp_included;
    my $upload;
    my $subdirectory;
    my $validate_type;
    my $metadata_file_type;
    my $data_level;
    if ($file_type eq "spreadsheet") {
        print STDERR "Spreadsheet \n";
        $subdirectory = "spreadsheet_phenotype_upload";
        $validate_type = "phenotype spreadsheet";
        $metadata_file_type = "spreadsheet phenotype file";
        $timestamp_included = $c->req->param('upload_spreadsheet_phenotype_timestamp_checkbox');
        $data_level = $c->req->param('upload_spreadsheet_phenotype_data_level') || 'plots';
        $upload = $c->req->upload('upload_spreadsheet_phenotype_file_input');
    } 
    elsif ($file_type eq "fieldbook") {
        print STDERR "Fieldbook \n";
        $subdirectory = "tablet_phenotype_upload";
        $validate_type = "field book";
        $metadata_file_type = "tablet phenotype file";
        $timestamp_included = 1;
        $upload = $c->req->upload('upload_fieldbook_phenotype_file_input');
        $data_level = $c->req->param('upload_fieldbook_phenotype_data_level') || 'plots';
    }
    elsif ($file_type eq "datacollector") {
        print STDERR "Datacollector \n";
        $subdirectory = "data_collector_phenotype_upload";
        $validate_type = "datacollector spreadsheet";
        $metadata_file_type = "data collector phenotype file";
        $timestamp_included = $c->req->param('upload_datacollector_phenotype_timestamp_checkbox');
        $upload = $c->req->upload('upload_datacollector_phenotype_file_input');
    }

    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my %phenotype_metadata;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my @success_status;
    my @error_status;

    my $archived_filename_with_path = $uploader->archive($c, $subdirectory, $upload_tempfile, $upload_original_name, $timestamp);
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        push @error_status, "Could not save file $upload_original_name in archive.";
    } else {
        push @success_status, "File $upload_original_name saved in archive.";
    }
    unlink $upload_tempfile;

    ## Validate and parse uploaded file
    my $validate_file = $parser->validate($validate_type, $archived_filename_with_path, $timestamp_included, $data_level);
    if (!$validate_file) {
        push @error_status, "Archived file not valid: $upload_original_name.";
    }
    if ($validate_file == 1){
        push @success_status, "File valid: $upload_original_name.";
    } else { 
        if ($validate_file->{'error'}) {
            push @error_status, $validate_file->{'error'};
        }
    }

    ## Set metadata
    $phenotype_metadata{'archived_file'} = $archived_filename_with_path;
    $phenotype_metadata{'archived_file_type'} = $metadata_file_type;
    my $operator = $c->user()->get_object()->get_username();
    $phenotype_metadata{'operator'} = $operator; 
    $phenotype_metadata{'date'} = $timestamp;

    my $parsed_file = $parser->parse($validate_type, $archived_filename_with_path, $timestamp_included);
    if (!$parsed_file) {
        push @error_status, "Error parsing file $upload_original_name.";
    }
    if ($parsed_file->{'error'}) {
        push @error_status, $parsed_file->{'error'};
    }
    my %parsed_data;
    my @plots;
    my @traits;
    if (scalar(@error_status) == 0) {
        if ($parsed_file && !$parsed_file->{'error'}) {
            %parsed_data = %{$parsed_file->{'data'}};
            @plots = @{$parsed_file->{'plots'}};
            @traits = @{$parsed_file->{'traits'}};
            push @success_status, "File data successfully parsed.";
        }
    }

    return (\@success_status, \@error_status, \%parsed_data, \@plots, \@traits, \%phenotype_metadata, $timestamp_included, $data_level);
}

#########
1;
#########

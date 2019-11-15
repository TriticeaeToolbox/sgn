=head1 NAME

t3-create-trials.pl - script to load trials

=head1 DESCRIPTION

perl t3-create-trials.pl -H host -D dbname -p password -N trail_name -U user_name -i infile

Adds a phenotype trial using xls format. This script can be automated by calling it for all files in directory

expects files [trial_name].xls and [trial_name].meta

=head1 AUTHOR

Clay Birkett <clb343@cornell.edu>

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
  -H host name (required) e.g. "localhost"
  -D database name (required) e.g. "cxgn_triticum"
  -p database password
  -N trial name (required)
  -U database username (required)
  -i path to infile (required)

=cut

use strict;
use warnings;
use Try::Tiny;
use Getopt::Std;
use Bio::Chado::Schema;
use CXGN::Metadata::Schema;
use CXGN::Phenome::Schema;
use CXGN::DB::InsertDBH;
use CXGN::Trial;
use CXGN::Trial::TrialCreate;
use CXGN::UploadFile;
use CXGN::Trial::ParseUpload;
use File::Basename;
use DateTime;
use CXGN::BreederSearch;

our ($opt_H, $opt_D, $opt_p, $opt_N, $opt_U, $opt_i);

getopts('H:D:p:N:U:i:');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dbpass = $opt_p;
my $trial_name = $opt_N;
my $user_name = $opt_U;
my $upload = $opt_i;
my $dbuser = "postgres";

my $dbh = CXGN::DB::Connection->new( { dbhost=>$dbhost,
    dbname=>$dbname,
    dbpass=>$dbpass,
    dbuser=>$dbuser,
    dbargs => {AutoCommit => 1,
    RaiseError => 1}
    }
);

# from sgn_local.conf
my $archive_path = '/home/production/archive/';
my $localtime = "";

print STDERR "Connecting to database...\n";
my $chado_schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
my $metadata_schema = CXGN::Metadata::Schema->connect( sub { $dbh->get_actual_dbh() });
my $phenome_schema = CXGN::Phenome::Schema->connect( sub { $dbh->get_actual_dbh() });

chomp $user_name;
my $q = "SELECT sp_person_id from sgn_people.sp_person where username = '$user_name'";
my $h = $dbh->prepare($q);
$h->execute();
my ($user_id) = $h->fetchrow_array();
if (!$user_id){
    die "User name $user_name Not a valid\n";
}

$localtime = localtime(); 
print STDERR "Check 1: $localtime\n";

my $trial = $chado_schema->resultset("Project::Project")->find( { name => $trial_name });
if ($trial) {
    die "Trial $trial_name already loaded, please delete\n";
}

# the following is taken from /home/production/cxgn/sgn/lib/SGN/Controller/AJAX/Trial.pm

my $filename_meta = $trial_name . ".meta";
my $filename_layout = $upload . $trial_name . ".xls";
my $tmp = $upload . $filename_meta;
open(my $fh, $tmp)
  or die "Couuld not open file $tmp $!";
$trial_name = <$fh>;
chomp $trial_name;
$q = "SELECT project_id from project where name = '$trial_name'";
$h = $dbh->prepare($q);
$h->execute();
if (my @row = $h->fetchrow_array) {
    print STDERR "$trial_name exist, please delete\n";
}

    my $program_name = <$fh>;
    chomp $program_name;
    my $program_id = "";
    $q = "SELECT project_id from project where name = '$program_name'";
    print STDERR "$q\n";
    $h = $dbh->prepare($q);
    $h->execute();
    if (my @row = $h->fetchrow_array) {
        $program_id = $row[0];
    } else {
        die "$program_name does not exist, please create\n";
    }
   
    my $trial_location = <$fh>;
    chomp $trial_location;
    my $location_id = "";
    $q = "SELECT location_id from locations where location_name = '$trial_location'";
    $q = "SELECT nd_geolocation_id from nd_geolocation where description = '$trial_location'";
    $h = $dbh->prepare($q);
    $h->execute();
    if (my @row = $h->fetchrow_array) {
        $location_id = $row[0];
    } else {
        die "trial location $trial_location not found\n";
    }

    my $trial_type = <$fh>; 
    chomp $trial_type;
    my $trial_type_id = "";
    $q = "SELECT cvterm_id from cvterm where name = '$trial_type'";
    $h = $dbh->prepare($q);
    $h->execute();
    if (my @row = $h->fetchrow_array) {
        $trial_type_id = $row[0];
    } else {
        die "trial type $trial_type not found\n";
    }
    $h->finish;
    
    my $trial_year = <$fh>;
    chomp $trial_year;
 
    my $trial_description = <$fh>;
    chomp $trial_description;

    my $trial_design_method = <$fh>;
    chomp $trial_design_method;

    my $field_size = "";
    my $plot_width = "";
    my $plot_length = "";
    my $field_trial_is_planned_to_be_genotyped = "no";
    my $field_trial_is_planned_to_cross = "no";
    my @add_project_trial_source = ();
    my $add_project_trial_genotype_trial;
    my $add_project_trial_crossing_trial;
    my $add_project_trial_genotype_trial_select = [$add_project_trial_genotype_trial];
    my $add_project_trial_crossing_trial_select = [$add_project_trial_crossing_trial];
    close($fh); 

    #my $upload = $filename_layout;
    my $parser;
    my $parsed_data;
    my $upload_original_name = $filename_layout;
    my $upload_tempfile = $filename_layout;
    my $subdirectory = "trial_upload";
    my $archived_filename_with_path;
    my $md5;
    my $validate_file;
    my $parsed_file;
    my $parse_errors;
    my %parsed_data;
    my %upload_metadata;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $error;

    $localtime = localtime();
    print STDERR "Check 2: $localtime\n";

    ## Store uploaded temporary file in archive
    my $uploader = CXGN::UploadFile->new({
        tempfile => $filename_layout,
        subdirectory => $subdirectory,
        archive_path => $archive_path,
        archive_filename => basename($filename_layout),
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => 'curator'
    });
    $archived_filename_with_path = $uploader->archive();
    if (!$archived_filename_with_path) {
        print STDERR "Could not save file $upload_original_name in archive\n";
        return;
    }
    $md5 = $uploader->get_md5($archived_filename_with_path);
    #unlink $upload_tempfile;

    $localtime = localtime();
    print STDERR "Check 3: $localtime\n";

    $upload_metadata{'archived_file'} = $archived_filename_with_path;
    $upload_metadata{'archived_file_type'}="trial upload file";
    $upload_metadata{'user_id'}=$user_id;
    $upload_metadata{'date'}="$timestamp";

    #parse uploaded file with appropriate plugin
    $parser = CXGN::Trial::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path);
    $parser->load_plugin('TrialExcelFormat');
    $parsed_data = $parser->parse();

    if ($parsed_data) {
        print STDERR "\n";
    } else {
        my $return_error = '';

        if (! $parser->has_parse_errors() ){
            print STDERR "Could not get parsing errors\n";
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;

            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error=$return_error.$error_string."\n";
            }
        }

        print STDERR "$return_error, missing_accessions => $parse_errors->{'missing_accessions'}\n";
    }

    $localtime = localtime();
    print STDERR "Check 4: $localtime\n";

    my $save;
    my $transaction_error;
    my $coderef = sub {

        my %trial_info_hash = (
            chado_schema => $chado_schema,
            dbh => $dbh,
            trial_year => $trial_year,
            trial_description => $trial_description,
            trial_location => $trial_location,
            trial_type => $trial_type_id,
            trial_name => $trial_name,
            user_name => $user_name, #not implemented
            design_type => $trial_design_method,
            design => $parsed_data,
            program => $program_name,
            upload_trial_file => $upload,
            operator => $user_name,
            field_trial_is_planned_to_cross => $field_trial_is_planned_to_cross,
            field_trial_is_planned_to_be_genotyped => $field_trial_is_planned_to_be_genotyped,
            field_trial_from_field_trial => \@add_project_trial_source,
            genotyping_trial_from_field_trial => $add_project_trial_genotype_trial_select,
            crossing_trial_from_field_trial => $add_project_trial_crossing_trial_select,
        );

        my $trial_create = CXGN::Trial::TrialCreate->new(\%trial_info_hash);

        if ($trial_create->trial_name_already_exists()) {
            die "Trial name \"".$trial_create->get_trial_name()."\" already exists\n";
        } else {
            print STDERR "Trial name good\n";
        }
        $save = $trial_create->save_trial();
            
        if ($save->{error}){
            $chado_schema->txn_rollback();
            print STDERR "save error\n";
        }   

    };
    try {
        $chado_schema->txn_do($coderef);
        print STDERR "Successfully saved\n";
    } catch {
        print STDERR "Transaction Error: $_\n";
        $save->{'error'} = $_;
    };
    if ($save->{'error'}) {
        die "Error saving trial: ".$save->{'error'};
    } elsif ($save->{'trial_id'}) {
        #my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, $dbname, } );
        print STDERR "Transaction successful\n";
    }
    $dbh->disconnect;


  
#} else {
#    print STDERR "Not found $trial_name\n";
#}


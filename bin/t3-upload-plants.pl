=head1 NAME

t3-upload-plants.pl - script to load plants 

=head1 DESCRIPTION

perl t3-create-trials.pl -H host -D dbname -p password -N trail_name -U user_name -i infile

Adds plants using xls format. This script can be automated by calling it for all files in directory

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

$q = "SELECT project_id from project where name = '$trial_name'";
$h = $dbh->prepare($q);
$h->execute();
my ($trial_id) = $h->fetchrow_array();
if (!$trial_id) {
    die "Trial name $trial_name Not valid\n";
}

$localtime = localtime(); 
print STDERR "Check 1: $localtime\n";

my $trial = $chado_schema->resultset("Project::Project")->find( { name => $trial_name });
if (!$trial) {
    die "Trial $trial_name is missing, please load\n";
}

# the following is taken from /home/production/cxgn/sgn/lib/SGN/Controller/AJAX/TrialMetadata.pm
# sub trial_upload_plants

my $filename_layout = $upload . $trial_name . "_plant.xls";

$q = "SELECT project_id from project where name = '$trial_name'";
$h = $dbh->prepare($q);
$h->execute();
if (my @row = $h->fetchrow_array) {
    print STDERR "$trial_name found\n";
} else {
    print STDERR "$trial_name exist, please delete\n";
}

    my @add_project_trial_source = ();
    my $add_project_trial_genotype_trial;
    my $add_project_trial_crossing_trial;
    my $add_project_trial_genotype_trial_select = [$add_project_trial_genotype_trial];
    my $add_project_trial_crossing_trial_select = [$add_project_trial_crossing_trial];

    my $parser;
    my $parsed_data;
    my $upload_original_name = $filename_layout;
    my $upload_tempfile = $filename_layout;

    my $plants_per_plot = 10;
    my $inherits_plot_treatments = 'true';

    my $subdirectory = "trial_plants_upload";
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
    print STDERR "Using $filename_layout in $subdirectory\n";
    $archived_filename_with_path = $uploader->archive();
    if (!$archived_filename_with_path) {
        print STDERR "Could not save file $upload_original_name in archive\n";
        return;
    }
    $md5 = $uploader->get_md5($archived_filename_with_path);
    # unlink $upload_tempfile;

    $localtime = localtime();
    print STDERR "Check 3: $localtime\n";

    #parse uploaded file with appropriate plugin
    $parser = CXGN::Trial::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path);
    $parser->load_plugin('TrialPlantsXLS');
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
    my $trial_layout;
    try {
	my %param = ( schema => $chado_schema, trial_id => $trial_id );
	$param{experiment_type} = 'field_layout';
	$trial_layout = CXGN::Trial::TrialLayout->new(\%param);
	print STDERR "Found trial_layout\n";
    } catch {
	print STDERR "Trial Layout for does not exist.\n";
    };

    $localtime = localtime();
    print STDERR "Check 4: $localtime\n";

    my $upload_plants_txn = sub {
        my %plot_plant_hash;
	my $parsed_entries = $parsed_data->{data};
	foreach (@$parsed_entries){
	    $plot_plant_hash{$_->{plot_stock_id}}->{plot_name} = $_->{plot_name};
	    push @{$plot_plant_hash{$_->{plot_stock_id}}->{plant_names}}, $_->{plant_name};
	}
	my $t = CXGN::Trial->new( {
            bcs_schema => $chado_schema,
	    metadata_schema => $metadata_schema, 
	    phenome_schema => $phenome_schema,
	    trial_id => $trial_id
        });
	$t->save_plant_entries(\%plot_plant_hash, $plants_per_plot, $inherits_plot_treatments);
	$trial_layout->generate_and_cache_layout();
    };
    eval {
        $chado_schema->txn_do($upload_plants_txn);
    };
    if ($@) {
        print STDERR "An error ($@).\n";
    }

    $h->finish;
    $dbh->disconnect;


  
#} else {
#    print STDERR "Not found $trial_name\n";
#}


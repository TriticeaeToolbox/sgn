package solGS::asyncJob;


use Moose;
use namespace::autoclean;

use CXGN::Tools::Run;
use File::Slurp qw /write_file read_file/;
use File::Spec::Functions qw / catfile catdir/;
use File::Temp qw / tempfile tempdir /;
use Try::Tiny;
use Scalar::Util qw /weaken reftype/;
use Storable qw/ nstore retrieve /;

use Carp qw/ carp confess croak /;

with 'MooseX::Getopt';
with 'MooseX::Runnable';


has "prerequisite_jobs" => (
    is       => 'ro',
    isa      =>  'Str',
    default  => 0,
    );

has "prerequisite_type" => (
    is       => 'ro',
    isa      =>  'Str',
    default  => 0,
    );

has "dependent_jobs" => (
    is       => 'ro',
    isa      =>  'Str',
    required  => 1,
    );

has "analysis_report_job" => (
    is       => 'ro',
    isa      => 'Str',
    required => 1, 
    );

has "temp_dir" => (
    is       => 'ro',
    isa      => 'Str',
    required => 1, 
    );



sub run {
    my $self = shift;
   
    my $jobs = $self->run_job();
    $self->send_analysis_report($jobs);
          
}


sub run_job {
    my $self = shift;

    my $jobs = [];
    
    eval
    {
	my $job;
	my $prerequisite_type = $self->prerequisite_type;
     
	if ($prerequisite_type =~ /combine_populations/)
	{
	    $job = $self->run_combine_populations();

	    foreach my $job (@$job)
	    {
		while (1) 
		{	 
		    last if !$job->alive();
		    sleep 30 if $job->alive();
		}
	    }

	    $jobs = $self->run_model();
     	  
	}
	elsif ($prerequisite_type =~ /selection_pop_download_data/) 
	{      
	    $job =  $self->query_genotype_data();
	    
	    if ($job)
	    {	  
		while (1)
		{
		    last if !$job->alive();
		    sleep 30 if $job->alive();
		}	             		
	    }

	    $jobs = $self->run_model();
	} else {
	    $self->run_any_job();
	}
              	
    };

    return $jobs;
    
}


sub run_any_job {
    my $self = shift;

    my $args_file = $self->dependent_jobs;
    my $any_jobs = retrieve($args_file);
     
    if (reftype $any_jobs ne 'ARRAY') 
    {
	$any_jobs = [$any_jobs];
    }
   
    my @jobs;
    foreach my $any_job (@$any_jobs) 
    {	
	my $job = $self->submit_job($any_job);
	push @jobs, $job;
    }
    
    return \@jobs;
        
}


sub run_combine_populations {
    my $self = shift;

    my $args_file = $self->prerequisite_jobs;
    my $combine_jobs = retrieve($args_file);
     
    if (reftype $combine_jobs ne 'ARRAY') 
    {
	$combine_jobs = [$combine_jobs];
    }
   
    my @jobs;
    foreach my $combine_job (@$combine_jobs) 
    {	
	my $job = $self->submit_job($combine_job);
	push @jobs, $job;
    }
    
    return \@jobs;
   
}


sub query_genotype_data {
    my $self = shift;

    my $query_job_file = $self->prerequisite_jobs;
    my $query_job = retrieve($query_job_file);
   
    my $genotype_file = $query_job->{genotype_file};
    
    my $job;
   
    if (!-s $genotype_file)
    {
	$job = $self->submit_job($query_job);
    }
    
    return $job;    
}


sub run_model {
    my $self = shift;
    
    my $model_job_file = $self->dependent_jobs;
    my $model_jobs = retrieve($model_job_file);

    if (reftype $model_jobs ne 'ARRAY') 
    {
	$model_jobs = [$model_jobs];
    }

    my @jobs;
    foreach my $model_job (@$model_jobs) 
    {	
	my $job = $self->submit_job($model_job);
	push @jobs, $job;
    }
    
    return \@jobs;

}



sub send_analysis_report {
    my $self = shift;
    my $jobs = shift;
    
    if (reftype $jobs ne 'ARRAY') 
    {
	$jobs = [$jobs];
    }
    
    foreach my $job (@$jobs) 
    {
	while (1)
	{
	    last if !$job->alive();
	    sleep 30 if $job->alive();
	}
    }
     
    my $report_file    = $self->analysis_report_job;
    my $report_job = retrieve($report_file);  

    my $job = $self->submit_job($report_job);

    return $job;

}


sub submit_job {
    my ($self, $args) = @_;

    my $job;
    
    eval 
    {
    	$job = CXGN::Tools::Run->new($args->{config});
    	$job->do_not_cleanup(1);
	 
    	$job->is_async(1);
	$job->run_cluster($args->{cmd});

	print STDERR "Submitted job... $args->{cmd}\n";	   
    };

    if ($@) 
    {
    	print STDERR "An error occurred submitting job $args->{cmd} \n$@\n";
    }

    return $job;
    
}



__PACKAGE__->meta->make_immutable;




####
1; #
####

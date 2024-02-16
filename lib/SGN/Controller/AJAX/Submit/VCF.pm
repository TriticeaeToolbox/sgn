package SGN::Controller::AJAX::Submit::VCF;

use Moose;
use CXGN::Contact;

use JSON;
use CXGN::Contact;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);


sub submit_vcf : Path('/ajax/submit/vcf') : ActionClass('REST') { }

sub submit_vcf_POST : Args(0) {
    my ($self, $c) = @_;
    my $params = $c->req->body_data();

    # Build Email Body
    my $body = "==== Submitter ====\n";
    $body .= "  - Database: " . $params->{database} . "\n";
    $body .= "  - Name: " . $params->{name} . "\n";
    $body .= "  - Email: " . $params->{email} . "\n";
    $body .= "  - Breeding Program: " . ($params->{breeding_program} ne 'other' ? $params->{breeding_program} : $params->{breeding_program_other}) . "\n";
    $body .= "\n";
    $body .= "==== PROTOCOL ====\n";
    if ( $params->{genotyping_protocol} ne 'new' ) {
      $body .= "  - Existing Genotyping Protocol: " . $params->{genotyping_protocol} . "\n";
    }
    else {
      $body .= "  - New Protocol Name: " . $params->{genotyping_protocol_name} . "\n";
      if ( $params->{genotyping_protocol_reference} ne 'other' ) {
        $body .= "  - Reference Genome: " . $params->{genotyping_protocol_reference} . "\n";
      }
      else {
        $body .= "  - Reference Genome: " . $params->{genotyping_protocol_reference_new_name} . " (" . $params->{genotyping_protocol_reference_new_species} . ")\n";
      }
      $body .= "  - Protocol Description: " . $params->{genotyping_protocol_description} . "\n";
    }
    $body .= "\n";
    $body .= "==== PROJECT ====\n";
    $body .= "  - Project Name: " . $params->{genotyping_project_name} . "\n";
    $body .= "  - Project Year: " . $params->{genotyping_project_year} . "\n";
    $body .= "  - Genotyping Facility: " . ($params->{genotyping_facility} ne 'other' ? $params->{genotyping_facility} : $params->{genotyping_facility_other}) . "\n";
    $body .= "  - Sample Population: " . $params->{sample_population} . "\n";
    $body .= "  - Project Description: " . $params->{genotyping_project_description} . "\n";
    $body .= "\n";
    $body .= "==== VCF FILE ====\n";
    $body .= "  - File Name: " . $params->{file_name} . "\n";
    $body .= "  - Additional Comments: " . $params->{additional_comments} . "\n";

    # Send the email
    my $subject = "[VCF Submission] " . ($params->{breeding_program} ne 'other' ? $params->{breeding_program} : $params->{breeding_program_other});
    CXGN::Contact::send_email($subject, $body, "dwaring87\@gmail.com");

    
    $c->stash->{rest} = { success => 1 };
}

1;
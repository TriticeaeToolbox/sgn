use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $d = SGN::Test::WWW::WebDriver->new();
#my $f = SGN::Test::Fixture->new();
`rm -r /tmp/localhost/`;

sleep(5);
$d->while_logged_in_as("submitter", sub {
    sleep(2);
    $d->get('/solgs', 'solgs home page');

    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese');
    sleep(5); 
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(5);     
    $d->find_element_ok('Kasese', 'partial_link_text', 'create training pop')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'submit job tr pop')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test Kasese Tr pop');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(80);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);
    $d->find_element_ok('population_search_entry', 'id', 'population search form')->send_keys('Kasese');
    sleep(5);
    $d->find_element_ok('search_training_pop', 'id', 'search for training pop')->click();
    sleep(5);  
    $d->find_element_ok('Kasese', 'partial_link_text', 'create training pop')->click();
    sleep(15);

    my $corr = $d->find_element('Phenotypic correlation', 'partial_link_text', 'scroll to correlation');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $corr);
    sleep(2);
    $d->find_element_ok('run_pheno_correlation', 'id', 'run correlation')->click();
    sleep(60);
    $d->find_element_ok('//div[@id="correlation_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot')->click();
    sleep(5);
    $d->find_element_ok('Download correlation', 'partial_link_text',  'download  corr coefs')->click();
    sleep(3);
    $d->find_element_ok('//*[contains(text(), "DMCP")]', 'xpath', 'check corr download')->click();
    sleep(5);
    $d->driver->go_back();
    sleep(5);

    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    sleep(2);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    sleep(2);
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(3);
    $d->find_element_ok('queue_job', 'id', 'no job queueing')->click();
    sleep(2);
    $d->find_element_ok('analysis_name', 'id', 'no job queueing')->send_keys('Test DMCP-FRW modeling  Kasese');
    sleep(2);
    $d->find_element_ok('submit_job', 'id', 'submit')->click();
    sleep(150);
    $d->find_element_ok('Go back', 'partial_link_text', 'go back')->click();
    sleep(3);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[1]/td/input', 'xpath', 'select 1st trait')->click();
    sleep(3);
    $d->find_element_ok('//table[@id="population_traits_list"]/tbody/tr[2]/td/input', 'xpath', 'select 2nd trait')->click();
    sleep(3);
    $d->find_element_ok('runGS', 'id',  'build multi models')->click();
    sleep(10);

    my $cor = $d->find_element('Genetic correlation', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-200);", $cor);
    sleep(5); 
    $d->find_element_ok('corre_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);  
    $d->find_element_ok('//dl[@class="corre_dropdown"]/dd/ul/li/a[text()="Kasese solgs trial"]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('run_genetic_correlation', 'id',  'calc gen corr')->click();
    sleep(50);
    $d->find_element_ok('//div[@id="correlation_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot')->click();
    sleep(5);
    
   
    my $si = $d->find_element('Calculate selection', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $si);
    sleep(5); 
    $d->find_element_ok('si_dropdown', 'class', 'select list sl pop')->click();
    sleep(3);  
    $d->find_element_ok('//dl[@class="si_dropdown"]/dd/ul/li/a[text()="Kasese solgs trial"]', 'xpath', 'select trial type tr pop')->click();
    sleep(3);
    $d->find_element_ok('DMCP', 'id', 'rel wt 1st')->send_keys(3);
    sleep(5);
    $d->find_element_ok('FRW', 'id', 'rel wt 2st')->send_keys(5);
    sleep(5);
    $d->find_element_ok('calculate_si', 'id',  'calc selection index')->click();
    sleep(60);
    my $si = $d->find_element('Correlation between', 'partial_link_text', 'scroll up');
    $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-100);", $si);
    sleep(5); 
    $d->find_element_ok('//div[@id="si_correlation_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot')->click();
    sleep(5);
    
    `rm -r /tmp/localhost/`;
    $d->get_ok('/breeders/trial/139', 'trial detail home page');     
    sleep(5);
    my $analysis_tools = $d->find_element('Analysis Tools', 'partial_link_text', 'toogle analysis tools');
    my $elem = $d->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-50);", $analysis_tools);
    sleep(5);    
    $d->find_element_ok('Analysis Tools', 'partial_link_text', 'toogle analysis tools')->click();
    sleep(5);
    $d->find_element_ok('run_pheno_correlation', 'id', 'run correlation')->click();
    sleep(60);
    $d->find_element_ok('//div[@id="correlation_canvas"]//*[contains(text(), "DMCP")]', 'xpath', 'check corr plot')->click();
    sleep(5);
    $d->find_element_ok('Download correlation', 'partial_link_text',  'download  corr coefs')->click();
    sleep(3);
    $d->find_element_ok('//*[contains(text(), "DMCP")]', 'xpath', 'check corr download')->click();
    sleep(5);
    
});


done_testing();
		       

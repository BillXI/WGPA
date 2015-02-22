package DCGenes;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
	my $app = shift;

	$ENV{MOJO_REVERSE_PROXY} = 1;

	$app->config(hypnotoad => {listen => ['http://*:2080']});
	
	# Router
	my $r = $app->routes;

	$r->get('/')->to('home#index');
	$r->get('/contact')->to('home#contact', tab => 'contact');

	$r->get('/evotol/ontologies')->to(controller => 'api', action => 'evotol_ontologies');

	my $enrichment = $r->route('/enrichment')->to(controller => 'enrichment', tab => 'enrichment');
	$enrichment->get('/')->to(action =>'index');
	$enrichment->post('/')->to(action =>'queue');
	$enrichment->post('/:id/network')->to(action =>'network'); 
	$enrichment->get('/:id/*fileName')->to(action =>'result', fileName => 'index.html');

	my $substitutions = $r->route('/substitutions')->to(controller => 'substitutions', tab => 'substitutions');
	$substitutions->get('/')->to(action =>'index');
	$substitutions->post('/')->to(action =>'submit');
	$substitutions->post('/network')->to(action =>'network'); 

	my $networks = $r->route('/networks')->to(controller => 'networks', tab => 'networks');
	$networks->get('/')->to(action => 'index');
	$networks->post('/')->to(action => 'submit');

	# Defaults
	$app->defaults(layout => 'default');
	$app->defaults(tab => 'none');

	$app->start;
}

1;

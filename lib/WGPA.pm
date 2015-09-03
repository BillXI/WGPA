package WGPA;
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

	my $networks = $r->route('/basic')->to(controller => 'basic', tab => 'basic');
	$networks->get('/')->to(action => 'index');
	$networks->post('/')->to(action => 'submit');

	my $gsea = $r->route('/gsea')->to(controller => 'gsea', tab => 'gsea');
	$gsea->get('/')->to(action =>'index');
	$gsea->post('/')->to(action =>'submit');
	$gsea->get('/:id/*fileName')->to(action =>'results', fileName => 'index.html');
	$gsea->post('/:id/network')->to(action =>'network');

	my $fathmm = $r->route('/fathmm')->to(controller => 'fathmm', tab => 'fathmm');
	$fathmm->get('/')->to(action =>'index');
	$fathmm->post('/')->to(action =>'submit');

	my $polyphen = $r->route('/polyphen')->to(controller => 'polyphen', tab => 'polyphen');
	$polyphen->get('/')->to(action => 'index');
	$polyphen->post('/')->to(action => 'submit');
	$polyphen->get('/:id')->to(action =>'results');

	# Defaults
	$app->defaults(layout => 'default');
	$app->defaults(tab => 'none');

	$app->start;
}

1;

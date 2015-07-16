package WGPA::Home;
use Mojo::Base 'Mojolicious::Controller';

sub index {
	my $c = shift;
	return $c->render();
}

sub contact {
	my $c = shift;
	return $c->render();
}

1;
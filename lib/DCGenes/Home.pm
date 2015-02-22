package DCGenes::Home;
use DCGenes::Utils;
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
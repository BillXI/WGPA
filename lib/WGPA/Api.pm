package WGPA::Api;
use WGPA::Utils::DB;
use Mojo::Base 'Mojolicious::Controller';

sub evotol_ontologies {
	my $c = shift;
    my $dbh = WGPA::Utils::DB::ConnectTo('WGPA');
    my $sth = $dbh->prepare( "SELECT DISTINCT(Ontology) FROM EvoTol WHERE Ontology <> 'all';"); 
    $sth->execute();
    my @ontologies;
    push(@ontologies, 'all');
    while (my @temp = $sth->fetchrow_array ) {
        push(@ontologies, $temp[0]);      
    }
    $sth->finish();
    WGPA::Utils::DB::Disconnect($dbh);
	return $c->render(json => \@ontologies)
}

1;
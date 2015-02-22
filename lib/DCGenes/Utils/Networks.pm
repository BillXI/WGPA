package DCGenes::Utils::Networks;
use DCGenes::Utils;
use DCGenes::Utils::DB;

sub GetFromGeneList {
	my $genes = shift;
	my @genes = @{$genes};
	my $score = shift;
	my $ontology = shift;
	my $threshold = shift;
	my $rankingFile = shift;
	my $dbh = shift;

	my (%ranking, $error) = DCGenes::Utils::getGenePercentiles($score, $ontology, $threshold, $rankingFile, $dbh);
	return (undef, $error) if defined $error;

	my @nodes;
	my @edges;
	my %nodeDegree = ();
	my %nodeIntolerance = ();

	my $geneList = '';
	foreach my $gene (@genes) {
		if (my $perc = $ranking{$gene}) {
			my $color = $perc * 0.85 + 5;
			push(@nodes, { data => { id => $gene, name => $gene, backgroundColor => "hsl(204, 100%, $color%)" } });
			$nodeIntolerance{$gene} = $perc; 
		} else {
			push(@nodes, { data => { id => $gene, name => $gene, backgroundColor => 'red' } });
		}
		$geneList .= "'$gene',";
	}

	chop $geneList;

	my $mydbh = $dbh ? $dbh : DCGenes::Utils::DB::ConnectTo('DCGenes');
	my $sql = "SELECT protein_s, protein_l FROM PPI WHERE combined_score > 700 AND protein_s IN ($geneList) AND protein_l IN ($geneList);";
	my $sth = $mydbh->prepare($sql);
	$sth->execute();

	while (my @edge = $sth->fetchrow_array) {
		push(@edges, {data => {source => $edge[0], target => $edge[1]}});
		foreach my $gene (@edge) {
			if (exists $nodeDegree{$gene}) {
				$nodeDegree{$gene} = $nodeDegree{$gene} + 1;
			} else {
				$nodeDegree{$gene} = 1;
			}
		}
	}

	$sth->finish();	
	DCGenes::Utils::DB::Disconnect($mydbh) unless $dbh;

	my @serie;
	while ( my ($key, $value) = each %nodeDegree ) {
		push(@serie, {name => $key, data => [[0 + $nodeIntolerance{$key}, $value]]});
	}
	
	return (
		Network => { Nodes => \@nodes, Edges => \@edges },
		DegreePlot => { Score => $score, Series => \@serie }
	);
}

sub GetFromNetwork {
	my $edges = shift;
	my @inputEdges = @{$edges};
	my $score = shift;
	my $ontology = shift;
	my $threshold = shift;
	my $rankingFile = shift;
	my $dbh = shift;

	my (%ranking, $error) = DCGenes::Utils::getGenePercentiles($score, $ontology, $threshold, $rankingFile, $dbh);
	return (undef, $error) if defined $error;

	my @nodes;
	my @edges;
	my %nodeDegree = ();
	my %nodeIntolerance = ();

	foreach my $genes (@inputEdges){
		my @genes = @{$genes};
		foreach my $gene (@genes) {
			if (my $perc = $ranking{$gene}) {
				my $color = $perc * 0.85 + 5;
				push(@nodes, { data => { id => $gene, name => $gene, backgroundColor => "hsl(204, 100%, $color%)" } });
				if (exists $nodeDegree{$gene}) {
					$nodeDegree{$gene} = $nodeDegree{$gene} + 1;
				} else {
					$nodeDegree{$gene} = 1;
					$nodeIntolerance{$gene} = $perc; 
				}
			} else {
				push(@nodes, { data => { id => $gene, name => $gene, backgroundColor => 'red' } });
			}
		}
		push(@edges, { data => { source => $genes[0], target => $genes[1] } });
	}

	my @serie;
	while ( my ($key, $value) = each %nodeDegree ) {
		push(@serie, {name => $key, data => [[0 + $nodeIntolerance{$key}, $value]]});
	}

	return (
		Network => { Nodes => \@nodes, Edges => \@edges },
		DegreePlot => { Score => $score, Series => \@serie }
	);
}

1;
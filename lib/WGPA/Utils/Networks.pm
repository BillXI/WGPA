package WGPA::Utils::Networks;
use WGPA::Utils;
use WGPA::Utils::DB;

sub GetFromGeneList {
	my $genesRef = shift;
	my @genes;
	my %scores;
	if (ref($genesRef) eq 'ARRAY') {
		@genes = @{$genesRef};
	} elsif (ref($genesRef) eq 'HASH') {
		%scores = %{$genesRef};
		@genes = keys %scores;
	} else {
		return (undef, 'Invalid gene list.');
	}
	my $score = shift;
	my $ontology = shift;
	my $threshold = shift;
	my $rankingFile = shift;
	my $inputMapRef = shift;
	my %inputMap = %{$inputMapRef};
	my $dbh = shift;

	my %ranking;
	my $error;
	if (ref($rankingFile) eq 'HASH') {
		%ranking = %{$rankingFile};
	} else {
		(%ranking, $error) = WGPA::Utils::getGenePercentiles($score, $ontology, $threshold, $rankingFile, $dbh);
		return (undef, $error) if defined $error;
	}

	my @nodes;
	my @edges;
	my %nodeDegree = ();

	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');

	my $geneList = '';

	foreach my $gene (@genes) {
		next if exists $nodeDegree{$gene};
		my %node = %{{ id => $gene, input => $inputMap{$gene}, name => $gene }};
		if (my $perc = $ranking{$gene}) {
			my $color = $perc * 0.85 + 5;
			$node{percentile} = $perc;
			$node{backgroundColor} = "hsl(204, 100%, $color%)";
		} else {
			$node{percentile} = 'Unknown';
			$node{backgroundColor} = 'red';
		}

		if (%scores) {
			if (my $perc = $scores{$gene}) {
				my $color = $perc * 0.85 + 5;
				$node{borderColor} = "hsl(204, 100%, $color%)";
			} else {
				$node{borderColor} = 'red';
			}
		}
		push(@nodes, { data => \%node });
		$nodeDegree{$gene} = 0;
		$geneList .= $mydbh->quote_identifier($gene).',';
	}

	$geneList =~ s/`/'/g;
	chop $geneList;

	my $sth = $mydbh->prepare("SELECT protein_s, protein_l FROM PPI WHERE combined_score > 700 AND protein_s IN ($geneList) AND protein_l IN ($geneList);");
	$sth->execute();

	while (my @edge = $sth->fetchrow_array) {
		push(@edges, {data => {source => $edge[0], target => $edge[1]}});
		foreach my $gene (@edge) {
			$nodeDegree{$gene} = $nodeDegree{$gene} + 1;
		}
	}

	$sth->finish();	
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;

	my @serie;
	while ( my ($key, $value) = each %nodeDegree ) {
		push(@serie, {name => $key, data => [[0 + $ranking{$key}, $value]]});
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
	my $inputMapRef = shift;
	my %inputMap = %{$inputMapRef};
	my $dbh = shift;

	my (%ranking, $error) = WGPA::Utils::getGenePercentiles($score, $ontology, $threshold, $rankingFile, $dbh);
	return (undef, $error) if defined $error;

	my @nodes;
	my @edges;
	my %nodeDegree = ();

	foreach my $genes (@inputEdges){
		my @genes = @{$genes};
		foreach my $gene (@genes) {
			if (exists $nodeDegree{$gene}) {
				$nodeDegree{$gene} = $nodeDegree{$gene} + 1;
				next;
			}
			$nodeDegree{$gene} = 1;
			my %node = %{{ id => $gene, input => $inputMap{$gene}, name => $gene }};
			if (my $perc = $ranking{$gene}) {
				my $color = $perc * 0.85 + 5;
				$node{percentile} = $perc;
				$node{backgroundColor} = "hsl(204, 100%, $color%)";
			} else {
				$node{percentile} = 'Unknown';
				$node{backgroundColor} = 'red';
			}

			if (%scores) {
				if (my $perc = $scores{$gene}) {
					my $color = $perc * 0.85 + 5;
					$node{borderColor} = "hsl(204, 100%, $color%)";
				} else {
					$node{borderColor} = 'red';
				}
			}

			push(@nodes, { data => \%node });
		}
		push(@edges, { data => { source => $genes[0], target => $genes[1] } });
	}

	my @serie;
	while ( my ($key, $value) = each %nodeDegree ) {
		push(@serie, {name => $key, data => [[0 + $ranking{$key}, $value]]});
	}

	return (
		Network => { Nodes => \@nodes, Edges => \@edges },
		DegreePlot => { Score => $score, Series => \@serie }
	);
}

1;

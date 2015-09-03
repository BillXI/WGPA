package WGPA::Basic;
use WGPA::Utils::DB;
use WGPA::Utils::NameConversion;
use WGPA::Utils::Networks;
use WGPA::Utils::Paths;
use Mojo::Base 'Mojolicious::Controller';

my $tmpFolder = $WGPA::Utils::Paths::fathmmFolder;

sub index {
	my $c = shift;
	return $c->render();
}

sub submit {
	my $c = shift;

	return $c->render(status => 400, json => { message => 'File is too big.' })
		if $c->req->is_limit_exceeded;

	my $networkFile = $c->req->upload('File');
	my $network = $c->param('Network');
	
	my $all = $c->param('All');
	my $score = $c->param('Score');
	my $ontology = $c->param('Ontology');
	my $threshold = $c->param('Threshold');
	my $rankingFile = $c->req->upload('RankingFile');
	if (defined $rankingFile and not $rankingFile->asset->is_file ) {
		my $file = Mojo::Asset::File->new(path => $tmpFolder.int(rand(10000000000)).'.txt');
		$file->add_chunk( $rankingFile->slurp );
		$rankingFile->asset($file);
	}

	if (defined($networkFile)) {
		return $c->render(status => 400, json => { message => 'The network file uploaded can\'t be empty' })
			unless $networkFile->size;
		$network = $networkFile->slurp;
	} elsif (!defined($network)) {
		return $c->render(status => 400, json => { message => 'No file was selected and no genes provided' });
	}

	return getAllData($c, $network) if $all eq 'true';

	my @lines = split(/\r\n|\n/, $network);
	my %inputMap;
	my %inputMapReverse;
	my %networkData;
	my $error;
	my $dbh = WGPA::Utils::DB::Connect('WGPA');
	if (0+split(/\s+/, $lines[0]) == 1){
		# List of genes
		my @genes;
		foreach my $line (@lines) {
			next if($line=~/^\s*$/);
			my $gene;
			if (exists $inputMapReverse{$line}) {
				$gene = $inputMapReverse{$line};
			} else {
				$gene = WGPA::Utils::NameConversion::Any2Symbol($line, $dbh);
				$inputMapReverse{$line} = $gene;
				$inputMap{$gene} = $line;
				push @genes, $gene;
			}
		}
		(%networkData, $error) = WGPA::Utils::Networks::GetFromGeneList(
			\@genes,
			$score,
			$ontology,
			$threshold,
			defined $rankingFile ? $rankingFile->asset->path : undef,
			\%inputMap,
			$dbh
		);
	}else {
		# List of pairs of genes
		my @edges;
		foreach my $line (@lines) {
			next if($line=~/^\s*$/);
			my @edgeNodes = split(/\s/, $line);
			my @edgeNodesSymbols= ();

			if (0 + @edgeNodes != 2) {
				WGPA::Utils::DB::Disconnect($dbh);
				return $c->render(status => 400, json => { message => 'Invalid input format.' });
			}

			foreach my $node (@edgeNodes) {
				my $gene;
				if (exists $inputMapReverse{$node}) {
					$gene = $inputMapReverse{$node};
				} else {
					$gene = WGPA::Utils::NameConversion::Any2Symbol($node, $dbh);
					$inputMapReverse{$node} = $gene;
					$inputMap{$gene} = $node;
				}
				push @edgeNodesSymbols, $gene;
			}

			push @edges, [@edgeNodesSymbols];
		}
		(%networkData, $error) = WGPA::Utils::Networks::GetFromNetwork(
			\@edges,
			$score,
			$ontology,
			$threshold,
			defined $rankingFile ? $rankingFile->asset->path : undef,
			\%inputMap,
			$dbh
		);
	}

	WGPA::Utils::DB::Disconnect($dbh);

	return $c->render(status => 400, json => { message => $error})
		if defined $error;


	my @nodes = @{$networkData{Network}{Nodes}};
	my @labels;
	my @vals;

	foreach my $node (sort { $a->{data}->{percentile} <=> $b->{data}->{percentile} }  @nodes) {
		if ($node->{data}->{percentile} ne 'Unknown') {
			push(@labels, $node->{data}->{name});
			push(@vals, 0 + $node->{data}->{percentile});
		}
	}

	return $c->render(json => { 
		Score => $score,
		Network => \%networkData,
		bar => {
			labels => \@labels,
			vals => \@vals
		}
	});
}

sub getAllData {
	my $c = shift;
	my $network = shift;
	my $networkFile = shift;

	my @lines = split(/\r\n|\n/, $network);
	my @genes;

	my %evotol;
	my %rvis;
	my %constraint;
	my $error;
	my %inputMap;
	my %inputMapReverse;

	my $dbh = WGPA::Utils::DB::Connect('WGPA');

	foreach my $line (@lines) {
		next if($line=~/^\s*$/);
		my @edgeNodes = split(/\s/, $line);

		if (0 + @edgeNodes > 2) {
			return $c->render(status => 400, json => { message => 'Invalid input format.' });
		}

		foreach my $node (@edgeNodes) {
			my $gene;
			if (exists $inputMapReverse{$node}) {
				$gene = $inputMapReverse{$node};
			} else {
				$gene = WGPA::Utils::NameConversion::Any2Symbol($node, $dbh);
				$inputMapReverse{$node} = $gene;
				$inputMap{$gene} = $node;
				push @genes, $gene;
			}
		}
	}

	(%evotol, $error) = WGPA::Utils::getGenePercentiles('EvoTol', 'all', '1', undef, $dbh);
	return (undef, $error) if defined $error;

	(%rvis, $error) = WGPA::Utils::getGenePercentiles('RVIS', undef, '001', undef, $dbh);
	return (undef, $error) if defined $error;

	(%constraint, $error) = WGPA::Utils::getGenePercentiles('Constraint', undef, '1', undef, $dbh);
	return (undef, $error) if defined $error;

	WGPA::Utils::DB::Disconnect($dbh);

	my @result;
	foreach my $gene (@genes) {
		push @result, {
			input => $inputMap{$gene},
			name => $gene,
			EvoTol => $evotol{$gene} || 'Unknown',
			RVIS => $rvis{$gene} || 'Unknown',
			Constraint => $constraint{$gene} || 'Unknown'
		};
	}

	return $c->render(json => { 
		Score => 'All',
		Percentiles => \@result
	});
}

1;

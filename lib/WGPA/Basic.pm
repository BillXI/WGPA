package WGPA::Basic;
use WGPA::Utils::Networks;
use Mojo::Base 'Mojolicious::Controller';

sub index {
	my $c = shift;
	return $c->render();
}

sub submit {
	my $c = shift;

	return $c->render(status => 400, json => { message => 'File is too big.' })
		if $c->req->is_limit_exceeded;

	my $netwokFile = $c->req->upload('File');
	my $network = $c->param('Network');
	
	my $all = $c->param('All');
	my $score = $c->param('Score');
	my $ontology = $c->param('Ontology');
	my $threshold = $c->param('Threshold');
	my $rankingFile = $c->req->upload('RankingFile');

	if (defined($netwokFile)) {
		return $c->render(status => 400, json => { message => 'The network file uploaded can\'t be empty' })
			unless $netwokFile->size;
		$network = $netwokFile->slurp;
	} elsif (!defined($network)) {
		return $c->render(status => 400, json => { message => 'No file was selected and no genes provided' });
	}

	return getAllData($c, $network) if $all eq 'true';

	my @lines = split(/\n/, $network);
	my %networkData;
	my $error;
	if (0+split(/\s+/, $lines[0]) == 1){
		# List of genes
		my @genes;
		foreach my $line (@lines) {
			# Retarded loop necessary for the ranking hash to work
			push @genes, split(/\s/, $line);
		}
		(%networkData, $error) = WGPA::Utils::Networks::GetFromGeneList(
			\@genes,
			$score,
			$ontology,
			$threshold,
			defined $rankingFile ? $rankingFile->asset->path : undef
		);
	}else {
		# List of pairs of genes
		my @edges;
		foreach my $line (@lines) {
			push @edges, [split(/\s/, $line)];
		}
		(%networkData, $error) = WGPA::Utils::Networks::GetFromNetwork(
			\@edges,
			$score,
			$ontology,
			$threshold,
			defined $rankingFile ? $rankingFile->asset->path : undef
		);
	}

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
	my $netwokFile = shift;

	my @lines = split(/\n/, $network);
	my @genes;

	my %evotol;
	my %rvis;
	my %constraint;
	my $error;

	foreach my $line (@lines) {
		# Retarded loop necessary for the ranking hash to work
		push @genes, split(/\s/, $line);
	}

	my $dbh = WGPA::Utils::DB::ConnectTo('WGPA');

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
			name => $gene,
			EvoTol => $evotol{$gene} || 'Unkown',
			RVIS => $rvis{$gene} || 'Unkown',
			Constraint => $constraint{$gene} || 'Unkown'
		};
	}

	return $c->render(json => { 
		Score => 'All',
		Percentiles => \@result
	});
}

1;

package DCGenes::Utils;
use DCGenes::Utils::DB;
use Mojo::DOM;
use POSIX qw(ceil);

sub readFile {
	my $filePath = shift || return '';
	open my $file, '<', $filePath || return '';
	local $/ = undef;
	my $content = <$file>;
	close $file;
	return $content
}

sub readToDOM {
	my $path = shift;
	my $content = readFile($path) || return '';
	return Mojo::DOM->new($content);
}

sub saveWGCNAFile {
	my $wgcnaFile = shift;
	my $outputFile = shift;
	my %gmxContent = ();

	return (undef, 'No custom score ranking was provided.')
		unless defined $wgcnaFile;

	open my $wgcnaFileHandler, $wgcnaFile or return (undef, 'File doesn\'t exist.');
	while (my $line = <$wgcnaFileHandler>) {
		chomp($line);
		my @row = split(/\t/, $line);
		if (0+@row < 2) {
			@row = split(/ +/, $line);
		}
		return (undef, 'Custom score ranking file provided is in an invalid format.')
			unless 0+@row == 2;
		push(@{$gmxContent{$row[0]}}, $row[1]);
	}
	close $wgcnaFileHandler;

	open my $outputFileHandler, '>'.$outputFile or return (undef, 'File doesn\'t exist.');
	foreach my $setId (keys %gmxContent) {
		my $line = $setId."\tna\t".join("\t", @{$gmxContent{$setId}})."\n";
		print $outputFileHandler $line;
	}
	close $outputFileHandler;

	return %ranking;
}

sub getGenePercentiles {
	my $score = shift;
	my $ontology = shift;
	my $threshold = shift;
	my $rankingFile = shift;
	my $dbh = shift || 0;
	my %ranking;

	if ($score eq 'Custom') {
		return (undef, 'No custom score ranking was provided.')
			unless defined $rankingFile;

		open my $rankingFileHandler, $rankingFile or return (undef, 'File doesn\'t exist.');
		while (my $line = <$rankingFileHandler>) {
			my @row = split(/\t/, $line);
			return (undef, 'Custom score ranking file provided is in an invalid format.')
				unless 0+@row == 2;
			$ranking{$row[0]} = $row[1];
		}
		close $rankingFileHandler;
		my @genes = sort { $ranking{$a} <=> $ranking{$b} } keys(%ranking);
		my $genesSize = 0 + @genes;
		my $cont = 0;

		foreach my $gene (@genes) {
			my $geneDetails = ($ranking{$gene}, ($cont/$genesSize) * 100);
			$ranking{$gene} = $geneDetails;
			$cont++;
		}
	} else {
		my $sql;

		if ($score eq 'EvoTol') {
			$sql = "SELECT Gene, Percentile FROM EvoTol WHERE Ontology = '$ontology' AND Threshold = $threshold ORDER BY Percentile;";
		} elsif ($score eq 'RVIS'){
			$sql = "SELECT Gene_Name, ALL_".$threshold."_perc FROM RVIS ORDER BY ALL_".$threshold."_perc;"; 
		} elsif ($score eq 'Constraint') {
			$sql = "SELECT Gene, Percentile FROM GeneConstraint ORDER BY Percentile;";
		}

		my $mydbh = $dbh ? $dbh : DCGenes::Utils::DB::ConnectTo('DCGenes');
		$sth = $mydbh->prepare($sql);
		$sth->execute();

		while (my @row = $sth->fetchrow_array) {
			$ranking{$row[0]} = $row[1];
		}

		DCGenes::Utils::DB::Disconnect($mydbh) unless $dbh;
	}
	return %ranking;
}

1;
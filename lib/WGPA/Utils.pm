package WGPA::Utils;
use WGPA::Utils::DB;
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
			return (undef, 'Invalid custom score ranking format.')
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
		my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');
		my $sth;

		if ($score eq 'EvoTol') {
			$sth = $mydbh->prepare('SELECT Gene, FORMAT(Percentile,2) FROM EvoTol WHERE Ontology = ? AND Threshold = ? ORDER BY Percentile;');
			$sth->execute($ontology, $threshold);
		} elsif ($score eq 'RVIS'){
			$sth = $mydbh->prepare('SELECT Gene_Name, '.$mydbh->quote_identifier('ALL_'.$threshold.'_perc').' FROM RVIS ORDER BY '.$mydbh->quote_identifier('ALL_'.$threshold.'_perc').';');
			$sth->execute();
		} elsif ($score eq 'Constraint') {
			$sth = $mydbh->prepare('SELECT Gene, FORMAT(Percentile,2) FROM GeneConstraint ORDER BY Percentile;');
			$sth->execute();
		}

		while (my @row = $sth->fetchrow_array) {
			$ranking{$row[0]} = $row[1];
		}

		$sth->finish();
		WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	}
	return (%ranking, undef);
}

1;

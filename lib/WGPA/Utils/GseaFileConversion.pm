package WGPA::Utils::GseaFileConversion;
use WGPA::Utils::NameConversion;

sub saveGRPFileFromInput {
	my $input = shift or return 'No input file was provided.';
	my $outputFile = shift;
	my $dbh = shift or 0;

	my @lines = split(/\r\n|\n/, $input);

	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');
	open my $outputFileHandler, '>'.$outputFile or return 'File doesn\'t exist.';
	foreach my $line (@lines) {
		my $gene = WGPA::Utils::NameConversion::Any2Symbol($line, $mydbh);
		print $outputFileHandler "$gene\n";
	}
	close $outputFileHandler;
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return;
}

sub saveGRPFile {
	my $grpFile = shift or return 'No input file was provided.';
	my $outputFile = shift;
	my $dbh = shift or 0;

	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');
	open my $grpFileHandler, $grpFile or return 'File doesn\'t exist.';
	open my $outputFileHandler, '>'.$outputFile or return 'File doesn\'t exist.';
	while (my $line = <$grpFileHandler>) {
		chomp($line);

		my $gene = WGPA::Utils::NameConversion::Any2Symbol($line, $mydbh);
		print $outputFileHandler "$gene\n";
	}
	close $grpFileHandler;
	close $outputFileHandler;
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return;
}

sub saveGMTFile {
	my $gmtFile = shift or return 'No input file was provided.';
	my $outputFile = shift;
	my $dbh = shift or 0;

	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');
	open my $gmtFileHandler, $gmtFile or return 'File doesn\'t exist.';
	open my $outputFileHandler, '>'.$outputFile or return 'File doesn\'t exist.';
	while (my $line = <$gmtFileHandler>) {
		chomp($line);
		my @row = split(/\s+|\t+/, $line);
		my $i = 0;
		foreach my $column (@row) {
			if ($i < 2) {
				print $outputFileHandler $column."\t";
				$i++;
			}
			my $gene = WGPA::Utils::NameConversion::Any2Symbol($column, $mydbh);
			print $outputFileHandler $gene."\t";
		}
		print $outputFileHandler "\n";
	}
	close $gmtFileHandler;
	close $outputFileHandler;
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return;
}

sub saveGMXFile {
	my $gmxFile = shift or return 'No input file was provided.';
	my $outputFile = shift;
	my $dbh = shift or 0;

	my $i = 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');
	open my $gmxFileHandler, $gmxFile or return 'File doesn\'t exist.';
	open my $outputFileHandler, '>'.$outputFile or return 'File doesn\'t exist.';
	while (my $line = <$gmxFileHandler>) {
		chomp($line);
		if ($i < 2) {
			print $outputFileHandler $line."\n";
			$i++;
		}
		my @row = split(/\s+|\t+/, $line);

		foreach my $column (@row) {
			my $gene = WGPA::Utils::NameConversion::Any2Symbol($column, $mydbh);
			print $outputFileHandler $gene."\t";
		}
		print $outputFileHandler "\n";
	}
	close $gmxFileHandler;
	close $outputFileHandler;
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return;
}

sub saveWGCNAFile {
	my $wgcnaFile = shift;
	my $outputFile = shift;
	my $dbh = shift or 0;
	my %gmxContent = ();

	return (undef, 'No input file was provided.')
		unless defined $wgcnaFile;

	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');
	open my $wgcnaFileHandler, $wgcnaFile or return 'File doesn\'t exist.';
	while (my $line = <$wgcnaFileHandler>) {
		chomp($line);
		my @row = split(/\s+|\t+/, $line);
		return (undef, 'Invalid input format.')
			unless 0+@row == 2;

		my $gene = WGPA::Utils::NameConversion::Any2Symbol($row[1], $mydbh);
		push(@{$gmxContent{$row[0]}}, $gene);
	}
	close $wgcnaFileHandler;
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;

	open my $outputFileHandler, '>'.$outputFile or return 'File doesn\'t exist.';
	foreach my $setId (keys %gmxContent) {
		my $line = $setId."\tna\t".join("\t", @{$gmxContent{$setId}})."\n";
		print $outputFileHandler $line;
	}
	close $outputFileHandler;
	return;
}

1;
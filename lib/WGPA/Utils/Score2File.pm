package WGPA::Utils::Score2File;
use WGPA::Utils::Paths;

my $dataFolder = $WGPA::Utils::Paths::GSEA{RANKINGS_FOLDER};

sub EvoTol {
	my $ontology = shift;
	my $threshold = shift;
	my $dbh = shift;
	my $rnk_path = $dataFolder;

	my $escapedOntology = $ontology;
	$escapedOntology =~ s/ /_/g;
	$escapedOntology =~ s/\//*/g;
	mkdir $rnk_path unless -e $rnk_path;
	$rnk_path .= "/EvoTol";
	mkdir $rnk_path unless -e $rnk_path;
	$rnk_path .= "/$threshold";
	mkdir $rnk_path unless -e $rnk_path;
	$rnk_path .= "/$escapedOntology.rnk";
	unless (-e $rnk_path) {
		my $sth = $dbh->prepare("SELECT Gene, 100-Percentile FROM EvoTol WHERE Ontology = ? AND Threshold = ?;");
		$sth->execute($ontology, $threshold);
		if ($sth->rows > 0) {
			open my $FILE, '>'.$rnk_path;
			while (my @temp = $sth->fetchrow_array ) {
				print $FILE $temp[0]."\t".$temp[1]."\n";
			}
			close $FILE;
		}
	}

	return $rnk_path;
}

sub RVIS {
	my $threshold = shift;
	my $dbh = shift;
	my $rnk_path = $dataFolder;

	mkdir $rnk_path unless -e $rnk_path;
	$rnk_path .= '/RVIS';
	mkdir $rnk_path unless -e $rvisFolder;
	$rnk_path .= '/'.$threshold.'.rnk';

	unless (-e $rnk_path) {
		$sth = $dbh->prepare('SELECT Gene_Name, 100-'.$dbh->quote_identifier('ALL_'.$threshold.'_perc').' FROM RVIS;');
		$sth->execute();
		open my $FILE, '>'.$rnk_path;
		while (my @temp = $sth->fetchrow_array) {
			print $FILE $temp[0]."\t".$temp[1]."\n";
		}
		close $FILE;
	}
	return $rnk_path;
}

sub GeneConstraint {
	my $dbh = shift;	
	my $rnk_path = $dataFolder;

	mkdir $rnk_path unless -e $rnk_path;
	$rnk_path .= '/GeneConstraint.rnk';

	unless (-e $rnk_path) {
		$sth = $dbh->prepare('SELECT Gene, 100-Percentile FROM GeneConstraint;');
		$sth->execute();
		open my $FILE, '>'.$rnk_path;
		while (my @temp = $sth->fetchrow_array) {
			print $FILE $temp[0]."\t".$temp[1]."\n";
		}
		close $FILE;
	}
	return $rnk_path;
}

1;

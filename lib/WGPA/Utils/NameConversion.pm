package WGPA::Utils::NameConversion;
use WGPA::Utils::DB;

sub LU_ensp {
	my $refseq_mrna = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::ConnectTo('WGPA');
	my $sth = $mydbh->prepare( "SELECT Distinct(Ensembl_P_ID) FROM accession2ensembl WHERE Ensembl_P_ID = ?"); 
	$sth->execute($refseq_mrna);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return @table;
}

sub LU_ensg {
	my $refseq_mrna = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::ConnectTo('WGPA');
	my $sth = $mydbh->prepare( "SELECT Distinct(Ensembl_P_ID) FROM accession2ensembl WHERE Ensembl_G_ID = ?"); 
	$sth->execute($refseq_mrna);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return @table;
}

sub LU_enst {
	my $refseq_mrna = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::ConnectTo('WGPA');
	my $sth = $mydbh->prepare( "SELECT Distinct(Ensembl_P_ID) FROM accession2ensembl WHERE Ensembl_T_ID = ?"); 
	$sth->execute($refseq_mrna);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return @table;
}

sub LU_refseq_mrna {
	my $refseq_mrna = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::ConnectTo('WGPA');
	my $sth = $mydbh->prepare( "SELECT Distinct(Ensembl_P_ID) FROM accession2ensembl WHERE RefSeq_M_ID = ?"); 
	$sth->execute($refseq_mrna);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return @table;
}

sub LU_uniprot {
	my $uniprot = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::ConnectTo('WGPA');
	my $sth = $mydbh->prepare( "SELECT Distinct(Ensemble_P_ID) FROM uniprot2ensembl WHERE UniProt_acc = ?"); 
	$sth->execute($uniprot);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return @table;
}

sub LU_refseq_p {
	my $refseq_p = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::ConnectTo('WGPA');
	my $sth = $mydbh->prepare( "SELECT Distinct(Ensembl_P_ID) FROM accession2ensembl WHERE RefSeq_P_ID = ?"); 
	$sth->execute($refseq_p);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return @table;
}

sub ensp2Symbol {
	my $ensp = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::ConnectTo('WGPA');

	my $sth = $mydbh->prepare("SELECT Symbol FROM accession2ensembl WHERE Ensembl_P_ID = ? LIMIT 1;"); 
	$sth->execute($ensp);
	my $symbol;	
	if (my @temp = $sth->fetchrow_array ) {
		$symbol = $temp[0];	
	}
	$sth->finish();
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return $symbol;
}

1;
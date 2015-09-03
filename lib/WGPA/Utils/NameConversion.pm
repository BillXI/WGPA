package WGPA::Utils::NameConversion;
use WGPA::Utils::DB;

sub Any2Ensp {
	my $ID = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');

	if($ID =~ /ENSP/) {
		return ($ID);
	} elsif($ID =~ /ENSG/) {
		return Ensg2Ensp($ID, $dbh);
	} elsif($ID =~ /ENST/) {
		return Enst2Ensp($ID, $dbh);
	} elsif($ID =~ /NP_/) {
		return Refseqp2Ensp($ID, $dbh);
	} elsif($ID =~ /NM_/) {
		return Refseqm2Ensp($ID, $dbh);
	} else {
		return Uniprot2Ensp($ID, $dbh) || Symbol2Ensp($ID, $dbh);	
	}

	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
}

sub Ensg2Ensp {
	my $ensg = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');
	my $sth = $mydbh->prepare( "SELECT Distinct(Ensembl_P_ID) FROM accession2ensembl WHERE Ensembl_G_ID = ?;"); 
	$sth->execute($ensg);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return @table;
}

sub Enst2Ensp {
	my $enst = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');
	my $sth = $mydbh->prepare( "SELECT Distinct(Ensembl_P_ID) FROM accession2ensembl WHERE Ensembl_T_ID = ?;"); 
	$sth->execute($enst);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return @table;
}

sub Refseqp2Ensp {
	my $refseq_p = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');
	my $sth = $mydbh->prepare( "SELECT Distinct(Ensembl_P_ID) FROM accession2ensembl WHERE RefSeq_P_ID = ?;"); 
	$sth->execute($refseq_p);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return @table;
}

sub Refseqm2Ensp {
	my $refseq_mrna = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');
	my $sth = $mydbh->prepare( "SELECT Distinct(Ensembl_P_ID) FROM accession2ensembl WHERE RefSeq_M_ID = ?;"); 
	$sth->execute($refseq_mrna);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return @table;
}

sub Uniprot2Ensp {
	my $uniprot = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');
	my $sth = $mydbh->prepare( "SELECT Distinct(Ensemble_P_ID) FROM uniprot2ensembl WHERE UniProt_acc = ?;"); 
	$sth->execute($uniprot);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return @table;
}

sub Symbol2Ensp {
	my $refseq_mrna = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');
	my $sth = $mydbh->prepare( "SELECT Distinct(Ensembl_P_ID) FROM accession2ensembl WHERE Symbol = ?;"); 
	$sth->execute($refseq_mrna);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return @table;
}


sub Any2Symbol {
	my $ID = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');

	if($ID =~ /ENSP/) {
		return Ensp2Symbol($ID, $dbh);
	} elsif($ID =~ /ENSG/) {
		return Ensg2Symbol($ID, $dbh);
	} elsif($ID =~ /ENST/) {
		return Enst2Symbol($ID, $dbh);
	} elsif($ID =~ /NP_/) {
		return Refseqp2Symbol($ID, $dbh);
	} elsif($ID =~ /NM_/) {
		return Refseqm2Symbol($ID, $dbh);
	} else {
		return $ID;	
	}

	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
}

sub Ensp2Symbol {
	my $ensp = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');
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

sub Ensg2Symbol {
	my $ensg = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');
	my $sth = $mydbh->prepare( "SELECT Symbol FROM accession2ensembl WHERE Ensembl_G_ID = ? LIMIT 1;"); 
	$sth->execute($ensg);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return @table;
}

sub Enst2Symbol {
	my $enst = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');
	my $sth = $mydbh->prepare( "SELECT Symbol FROM accession2ensembl WHERE Ensembl_T_ID = ? LIMIT 1;"); 
	$sth->execute($enst);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return @table;
}

sub Refseqp2Symbol {
	my $refseq_p = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');
	my $sth = $mydbh->prepare( "SELECT Symbol FROM accession2ensembl WHERE RefSeq_P_ID = ? LIMIT 1;"); 
	$sth->execute($refseq_p);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return @table;
}

sub Refseqm2Symbol {
	my $refseq_mrna = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : WGPA::Utils::DB::Connect('WGPA');
	my $sth = $mydbh->prepare( "SELECT Symbol FROM accession2ensembl WHERE RefSeq_M_ID = ? LIMIT 1;"); 
	$sth->execute($refseq_mrna);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	WGPA::Utils::DB::Disconnect($mydbh) unless $dbh;
	return @table;
}

1;
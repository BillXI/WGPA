package DCGenes::Substitutions;
use DCGenes::Utils;
use DCGenes::Utils::DB;
use DCGenes::Utils::Networks;
use DCGenes::Utils::Paths;
use Mojo::Base 'Mojolicious::Controller';

sub index {
	my $c = shift;
	return $c->render();
}

sub submit {
	my $c = shift;

	return $c->render(status => 400, json => { message => 'File is too big.' })
		if $c->req->is_limit_exceeded;

	my $genesFile = $c->req->upload('GenesFile');
	my $genes = $c->req->param('Genes');

	my $weighted = $c->param('Weighted');
	my $phenotype = $c->param('Phenotype');
	my $predThreshold = $c->param('PredThreshold');

	my $score = $c->param('Score');
	my $ontology = $c->param('Ontology');
	my $threshold = $c->param('Threshold');	
	my $rankingFile = $c->req->upload('RankingFile');
	
	if (defined($genesFile)) {
		# Extension
		my $ext = ($genesFile->filename =~ m/([^.]+)$/)[0];
		my %valid_ext = map {$_ => 1} qw(txt);
		my $error;
		$error = 'The substitutions file uploaded can\'t be empty' unless $genesFile->size;
		$error = 'Only txt files are valid to submit substitutions.' unless $valid_ext{$ext};
		return $c->render(status => 400, json => { message => $error})
			unless defined $error;
		# Read the file content
		$genes = $genesFile->slurp;
	} elsif (! defined $genes) {
		return $c->render(status => 400, json => { message => 'No file was selected and no substitutions provided.'});
	}

	my $dbh = DCGenes::Utils::DB::ConnectTo('DCGenes');

	my (%ranking, $error) = DCGenes::Utils::getGenePercentiles(
		$score,
		$ontology,
		$threshold,
		defined $rankingFile ? $rankingFile->asset->path : undef
	);
	return $c->render(status => 400, json => { message => $error})
		if defined $error;

	my ($output, %map_input) = createInputs($c, $genes, $weighted , $phenotype, $predThreshold, $dbh);

	result($c, $output, \%map_input, $predThreshold, $score, $ontology, $threshold, \%ranking, $dbh)
		if defined $output;

	DCGenes::Utils::DB::Disconnect($dbh);
}

sub createInputs {
	my $c = shift;

	my $genes = shift;

	my $weighted = shift;
	my $phenotype = shift;
	my $predThreshold = shift;

	my $dbh = shift;

	my %map_input;
	my @row = split(/\n/, $genes);
	my $details;

	my $id = int(rand(10000000000));
	my $folder = $DCGenes::Utils::Paths::Substitutions;
	my $input = "$folder/$id.in";
	my $histogram = "$folder/$id.hist";
	my $output = "$folder/$id.out";

	mkdir $folder unless -e $folder;

	open INPUT, ">$input";
	open HIST, ">$histogram";

	foreach my $row (@row){
		my @element = split(/ +/,$row);
		unless (0 + @element == 2) {
			$c->render(status => 400, json => { message => 'The substitutions provided are in an invalid format.' });
			return;
		}

		my $ID = $element[0];
		my $locations = $element[1];
		my $posextract = $locations;
		$posextract =~ s/^.//;
		$posextract =~ s/.$//;
		if($ID =~ /ENSP/){
			$details =  LU_ensp($ID, $dbh);
			foreach my $t (@{$details}){
				$map_input{$t} = $ID;
				print HIST "$t\t$posextract\n";
			}
		}elsif($ID =~ /NM_/){
			$details =  LU_refseq_mrna($ID, $dbh);
			foreach my $t (@{$details}){
				$map_input{$t} = $ID;
				print HIST "$t\t$posextract\n";
			}
		}elsif($ID =~ /NP_/){
			$details =  LU_refseq_p($ID, $dbh);
			foreach my $t (@{$details}){
				$map_input{$t} = $ID;
				print HIST "$t\t$posextract\n";
			}
		}elsif($ID =~ /ENSG/){
			$details =  LU_ensg($ID, $dbh);
			foreach my $t (@{$details}){
				$map_input{$t} = $ID;
				print HIST "$t\t$posextract\n";
			}
		}elsif($ID =~ /ENST/){
			$details =  LU_enst($ID, $dbh);
			foreach my $t (@{$details}){
				$map_input{$t} = $ID;
				print HIST "$t\t$posextract\n";
			}
		}else{
			$details =  LU_uniprot($ID, $dbh);
			foreach my $t (@{$details}){
				$map_input{$t} = $ID;
				print HIST "$t\t$posextract\n";
			}		
		}
		foreach my $prot (@{$details}){
			print INPUT "$prot $locations\n";
		}
	}

	close INPUT;
	close HIST;

	my $cmd = "python $DCGenes::Utils::Paths::RootFolder/lib/fathmm/fathmm.py $input $output ";
	$cmd .= "-w $weighted " unless ! defined $weighted;
	$cmd .= "-p $phenotype " unless ! defined $phenotype;
	$cmd .= "-t $predThreshold " unless ! defined $predThreshold;

	if (system $cmd) {
		$c->render_exception('There was an error executing fathmm.');
		return;
	}
	return ($output, %map_input);
}

sub result {
	my $c = shift;
	
	my $output = shift;
	my $map_input = shift;
	my %map_input = %{$map_input};

	my $predThreshold = shift;

	my $score = shift;
	my $ontology = shift;
	my $threshold = shift;
	my $rankingRef = shift;
	my %ranking = %{$rankingRef};

	my $dbh = shift;

	my $hot_count = 0;
	my $all_count = 0;
	my %intolerance;
	my @table;
	my %domains;
	my %scatter = (
		hot => undef,
		cold => undef
	);
	my @genes;



	open OUTPUT, $output;
	while(<OUTPUT>){
		chomp;
		unless($. == 1){
			my @line = split("\t",$_);
			my $pred = $line[4];
			unless($line[4] eq ""){
				my $enspId = $line[2];
				my $geneSymbol = ensp2Symbol($enspId, $dbh);
				push(@genes, $geneSymbol);
				my $intPerc = $ranking{$geneSymbol};
				unless (! defined $geneSymbol || ! defined $intPerc) {
					my $mutation =$line[3];
					my $fathmmScore = $line[5];
					my $domain = $line[9];
					if($domain eq ''){
						$domain = $line[8];
					}
					if($domain eq ''){
						$domain = "No details";
					}
					$all_count++;
					if($pred eq 'DAMAGING'){	
						if(exists($domains{$domain})){
							$domains{$domain} = $domains{$domain} + 1;
						}else{
							$domains{$domain} = 1;
						}
					}
			
					$intolerance{$geneSymbol} = 0 + $intPerc;
					if($intPerc < 25 && $fathmmScore < $predThreshold){
						$hot_count++;
						push(@table,[$map_input{$enspId},$enspId,$mutation,$pred,$fathmmScore,$geneSymbol,$intPerc,'hot']);
						push(@{$scatter{hot}}, {
							info => $enspId.'_'.$mutation.'_'.$geneSymbol,
							x => 0 + $fathmmScore,
							y => 0 + $intPerc
						});
					} else {
						push(@table,[$map_input{$enspId},$enspId,$mutation,$pred,$fathmmScore,$geneSymbol,$intPerc,'cold']);
						push(@{$scatter{cold}}, {
							info => $enspId.'_'.$mutation.'_'.$geneSymbol,
							x => 0 + $fathmmScore,
							y => 0 + $intPerc
						});
					}
				}
			}
		}
	}

	my @dom_table;
	foreach my $dom (sort { $domains{$b} <=> $domains{$a} } keys %domains){
		push(@dom_table,[$dom,$domains{$dom}]);
	}

	@table = sort {$a->[4] <=> $b->[4]} @table;

	my @labels;
	my @vals;
	foreach my $label (sort { $intolerance{$a} <=> $intolerance{$b} } keys %intolerance){
		push(@labels, $label);
		push(@vals, $intolerance{$label});
	}
	
	return $c->render(json => {
		metadata => {
			hot_count => $hot_count,
			all_count => $all_count,
			score => $score,
		},
		intolerance => {
			labels => \@labels,
			vals => \@vals
		},
		table => \@table, 
		domains => \@dom_table,
		scatter => [
			{
				name => 'hot',
				color => 'rgba(223, 83, 83, 0.5)',
				data => $scatter{hot}
			},
			{
				name => 'cold',
				color => 'rgba(119, 152, 191, 0.5)',
				data => $scatter{cold}
			},
		],
		genes => \@genes
	});
}


sub  network {
	my $c = shift;

	my $genesList = $c->param('Genes');
	my @genes = split(',', $genesList);

	my $score = $c->param('Score');
	my $ontology = $c->param('Ontology');
	my $threshold = $c->param('Threshold');	
	my $rankingFile = $c->req->upload('RankingFile');

	my (%networkData, $error) = DCGenes::Utils::Networks::GetFromGeneList(
			\@genes,
			$score,
			$ontology,
			$threshold,
			defined $rankingFile ? $rankingFile->asset->path : undef
		);

	return $c->render(status => 400, json => { message => $error})
		if defined $error;
	
	return $c->render(json => \%networkData);
}

# Gene/Protein identifier conversion methods
#####################################

sub LU_ensp {
	my $refseq_mrna = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : DCGenes::Utils::DB::ConnectTo('DCGenes');
	my $sth = $mydbh->prepare( "SELECT Distinct(Ensembl_P_ID) FROM accession2ensembl WHERE Ensembl_P_ID = ?"); 
	$sth->execute($refseq_mrna);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	DCGenes::Utils::DB::Disconnect($mydbh) unless $dbh;
	return \@table;
}

sub LU_ensg {
	my $refseq_mrna = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : DCGenes::Utils::DB::ConnectTo('DCGenes');
	my $sth = $mydbh->prepare( "SELECT Distinct(Ensembl_P_ID) FROM accession2ensembl WHERE Ensembl_G_ID = ?"); 
	$sth->execute($refseq_mrna);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	DCGenes::Utils::DB::Disconnect($mydbh) unless $dbh;
	return \@table;
}

sub LU_enst {
	my $refseq_mrna = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : DCGenes::Utils::DB::ConnectTo('DCGenes');
	my $sth = $mydbh->prepare( "SELECT Distinct(Ensembl_P_ID) FROM accession2ensembl WHERE Ensembl_T_ID = ?"); 
	$sth->execute($refseq_mrna);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	DCGenes::Utils::DB::Disconnect($mydbh) unless $dbh;
	return \@table;
}

sub LU_refseq_mrna {
	my $refseq_mrna = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : DCGenes::Utils::DB::ConnectTo('DCGenes');
	my $sth = $mydbh->prepare( "SELECT Distinct(Ensembl_P_ID) FROM accession2ensembl WHERE RefSeq_M_ID = ?"); 
	$sth->execute($refseq_mrna);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	DCGenes::Utils::DB::Disconnect($mydbh) unless $dbh;
	return \@table;
}

sub LU_uniprot {
	my $uniprot = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : DCGenes::Utils::DB::ConnectTo('DCGenes');
	my $sth = $mydbh->prepare( "SELECT Distinct(Ensemble_P_ID) FROM uniprot2ensembl WHERE UniProt_acc = ?"); 
	$sth->execute($uniprot);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	DCGenes::Utils::DB::Disconnect($mydbh) unless $dbh;
	return \@table;
}

sub LU_refseq_p {
	my $refseq_p = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : DCGenes::Utils::DB::ConnectTo('DCGenes');
	my $sth = $mydbh->prepare( "SELECT Distinct(Ensembl_P_ID) FROM accession2ensembl WHERE RefSeq_P_ID = ?"); 
	$sth->execute($refseq_p);
	my @table;
	while (my @temp = $sth->fetchrow_array ) {
		push(@table,$temp[0]);
	}
	$sth->finish();
	DCGenes::Utils::DB::Disconnect($mydbh) unless $dbh;
	return \@table;
}

sub ensp2Symbol {
	my $ensp = shift;
	my $dbh = shift || 0;
	my $mydbh = $dbh ? $dbh : DCGenes::Utils::DB::ConnectTo('DCGenes');

	my $sth = $mydbh->prepare("SELECT Symbol FROM accession2ensembl WHERE Ensembl_P_ID = ? LIMIT 1;"); 
	$sth->execute($ensp);
	my $symbol;	
	if (my @temp = $sth->fetchrow_array ) {
		$symbol = $temp[0];	
	}
	$sth->finish();
	DCGenes::Utils::DB::Disconnect($mydbh) unless $dbh;
	return $symbol;
}
#####################################

1;
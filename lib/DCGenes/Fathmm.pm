package DCGenes::Fathmm;
use DCGenes::Utils;
use DCGenes::Utils::DB;
use DCGenes::Utils::NameConversion;
use DCGenes::Utils::Networks;
use DCGenes::Utils::Paths;
use Mojo::Base 'Mojolicious::Controller';
use Scalar::Util qw(looks_like_number);

my $rootFolder = $DCGenes::Utils::Paths::rootFolder;
my $fathmmFolder = $DCGenes::Utils::Paths::fathmmFolder;

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
	return $c->render(status => 400, json => { message => 'The prediction cutoff needs to be a number.' })
		unless looks_like_number($predThreshold);

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
	my @details;

	my $id = int(rand(10000000000));
	my $input = "$fathmmFolder/$id.in";
	my $histogram = "$fathmmFolder/$id.hist";
	my $output = "$fathmmFolder/$id.out";

	open INPUT, ">$input";
	open HIST, ">$histogram";

	foreach my $row (@row){
		my @element = split(/ +/,$row);

		return $c->render(status => 400, json => { message => 'The substitutions provided are in an invalid format.' })
			unless (0 + @element == 2);

		my $ID = $element[0];
		my $locations = $element[1];
		my $posextract = $locations;
		$posextract =~ s/^.//;
		$posextract =~ s/.$//;
		if($ID =~ /ENSP/){
			@details = DCGenes::Utils::NameConversion::LU_ensp($ID, $dbh);
			foreach my $t (@details){
				$map_input{$t} = $ID;
				print HIST "$t\t$posextract\n";
			}
		}elsif($ID =~ /NM_/){
			@details = DCGenes::Utils::NameConversion::LU_refseq_mrna($ID, $dbh);
			foreach my $t (@details){
				$map_input{$t} = $ID;
				print HIST "$t\t$posextract\n";
			}
		}elsif($ID =~ /NP_/){
			@details = DCGenes::Utils::NameConversion::LU_refseq_p($ID, $dbh);
			foreach my $t (@details){
				$map_input{$t} = $ID;
				print HIST "$t\t$posextract\n";
			}
		}elsif($ID =~ /ENSG/){
			@details = DCGenes::Utils::NameConversion::LU_ensg($ID, $dbh);
			foreach my $t (@details){
				$map_input{$t} = $ID;
				print HIST "$t\t$posextract\n";
			}
		}elsif($ID =~ /ENST/){
			@details = DCGenes::Utils::NameConversion::LU_enst($ID, $dbh);
			foreach my $t (@details){
				$map_input{$t} = $ID;
				print HIST "$t\t$posextract\n";
			}
		}else{
			@details = DCGenes::Utils::NameConversion::LU_uniprot($ID, $dbh);
			foreach my $t (@details){
				$map_input{$t} = $ID;
				print HIST "$t\t$posextract\n";
			}		
		}
		foreach my $prot (@details){
			print INPUT "$prot $locations\n";
		}
	}

	close INPUT;
	close HIST;

	my $cmd = "python $rootFolder/lib/fathmm/fathmm.py $input $output ";
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

	my %intolerances;
	my @table;
	my %domains;
	my %scatter = (
		hot => undef,
		cold => undef
	);

	open OUTPUT, $output;
	while(<OUTPUT>){
		chomp;
		unless($. == 1){
			my @line = split("\t",$_);
			my $ensemblPID = $line[2];
			my $input = $map_input{$ensemblPID};
			my $geneSymbol = DCGenes::Utils::NameConversion::ensp2Symbol($ensemblPID, $dbh) or 'Unkown';
			my $mutation =$line[3];
			my $prediction = $line[4] or 'Unkown';
			my $score = $line[5];
			my $intolerance = $ranking{$geneSymbol};
			my $domain = $line[9];

			if($domain eq ''){
				$domain = $line[8];
			}
			if($domain eq ''){
				$domain = "No details";
			}

			if($prediction eq 'DAMAGING'){
				if(exists($domains{$domain})){
					$domains{$domain} = $domains{$domain} + 1;
				}else{
					$domains{$domain} = 1;
				}
			}

			if (defined $intolerance) {
				$intolerances{$geneSymbol} = 0 + $intolerance;
				if($intolerance < 25 and $score < $predThreshold){
					push(@table,[$input, $ensemblPID, $geneSymbol, $mutation, $prediction, $score, $intolerance, 'hot']);
					push(@{$scatter{hot}}, {
						info => "$ensemblPID($geneSymbol)_$mutation",
						x => 0 + $score,
						y => 0 + $intolerance
					});
				} else {
					push(@table,[$input, $ensemblPID, $geneSymbol, $mutation, $prediction,$ score, $intolerance,'cold']);
					push(@{$scatter{cold}}, {
						info => "$ensemblPID($geneSymbol)_$mutation",
						x => 0 + $score,
						y => 0 + $intolerance
					});
				}
			} else {
				push @table, [$input, $ensemblPID, $geneSymbol, $mutation, $prediction, $score, 'Unkown', ''];
			}
		}
	}

	shift @table;

	my @dom_table;
	foreach my $dom (sort { $domains{$b} <=> $domains{$a} } keys %domains){
		push(@dom_table,[$dom,$domains{$dom}]);
	}

	my @labels;
	my @vals;
	foreach my $label (sort { $intolerances{$a} <=> $intolerances{$b} } keys %intolerances){
		push(@labels, $label);
		push(@vals, $intolerances{$label});
	}
	
	return $c->render(json => {
		score => $score,
		bar => {
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
			}
		]
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

1;
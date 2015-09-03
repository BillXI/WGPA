package WGPA::Fathmm;
use WGPA::Utils;
use WGPA::Utils::DB;
use WGPA::Utils::NameConversion;
use WGPA::Utils::Networks;
use WGPA::Utils::Paths;
use Mojo::Base 'Mojolicious::Controller';
use Scalar::Util qw(looks_like_number);

my $rootFolder = $WGPA::Utils::Paths::rootFolder;
my $fathmmFolder = $WGPA::Utils::Paths::fathmmFolder;
my $tmpFolder = $WGPA::Utils::Paths::fathmmFolder;

sub index {
	my $c = shift;
	return $c->render();
}

sub submit {
	my $c = shift;

	return $c->render(status => 400, json => { message => 'File is too big.' })
		if $c->req->is_limit_exceeded;

	my $genesFile = $c->req->upload('File');
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
	if (defined $rankingFile and not $rankingFile->asset->is_file ) {
		my $file = Mojo::Asset::File->new(path => $tmpFolder.int(rand(10000000000)).'.txt');
		$file->add_chunk( $rankingFile->slurp );
		$rankingFile->asset($file);
	}
	
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

	my $dbh = WGPA::Utils::DB::Connect('WGPA');

	my (%ranking, $error) = WGPA::Utils::getGenePercentiles(
		$score,
		$ontology,
		$threshold,
		defined $rankingFile ? $rankingFile->asset->path : undef
	);
	return $c->render(status => 400, json => { message => $error})
		if defined $error;

	my ($output, %inputMap) = createInputs($c, $genes, $weighted , $phenotype, $predThreshold, $dbh);

	result($c, $output, \%inputMap, $predThreshold, $score, $ontology, $threshold, \%ranking, $dbh)
		if defined $output;

	WGPA::Utils::DB::Disconnect($dbh);
}

sub createInputs {
	my $c = shift;

	my $genes = shift;

	my $weighted = shift;
	my $phenotype = shift;
	my $predThreshold = shift;

	my $dbh = shift;

	my %inputMap;
	my %inputMapReverse;
	my @row = split(/\r\n|\n/, $genes);

	my $id = int(rand(10000000000));
	my $input = "$fathmmFolder/$id.in";
	my $output = "$fathmmFolder/$id.out";

	open INPUT, ">$input";

	foreach my $row (@row){
		my @element = split(/ +/,$row);
		my $elementCount = 0 + @element;

		if ($elementCount == 1) {
			print INPUT $element[0];
		} elsif ($elementCount == 2) {
			my $input = $element[0];
			my $locations = $element[1];
			my @proteins;

			if (exists $inputMapReverse{$input}) {
				@proteins = @{$inputMapReverse{$input}};
			} else {
				@proteins = WGPA::Utils::NameConversion::Any2Ensp($input, $dbh);
				$inputMapReverse{$input} = \@proteins;
			}

			foreach my $prot (@proteins){
				$inputMap{$prot} = $input;
				print INPUT "$prot $locations\n";
			}
		} elsif ($elementCount == 4) {
			my $input = $element[0];
			my $position = $element[1];
			my $wt = $element[2];
			my $mutant = $element[3];

			my @proteins;

			if (exists $inputMapReverse{$input}) {
				@proteins = $inputMapReverse{$input};
			} else {
				@proteins = WGPA::Utils::NameConversion::Any2Ensp($input, $dbh);
				$inputMapReverse{$input} = @proteins;
			}

			foreach my $prot (@proteins){
				$inputMap{$prot} = $input;
				print INPUT "$prot $wt$position$mutant\n";
			}
		} else {
			WGPA::Utils::DB::Disconnect($dbh);
			return $c->render(status => 400, json => { message => 'Invalid input format.' });
		}
	}

	close INPUT;

	my $cmd = "python $rootFolder/lib/fathmm/fathmm.py $input $output ";
	$cmd .= "-w $weighted " unless ! defined $weighted;
	$cmd .= "-p $phenotype " unless ! defined $phenotype;
	$cmd .= "-t $predThreshold " unless ! defined $predThreshold;

	if (system $cmd) {
		$c->render_exception('There was an error executing fathmm.');
		return;
	}
	return ($output, %inputMap);
}

sub result {
	my $c = shift;
	
	my $output = shift;
	my $inputMap = shift;
	my %inputMap = %{$inputMap};

	my $predThreshold = shift;

	my $score = shift;
	my $ontology = shift;
	my $threshold = shift;
	my $rankingRef = shift;
	my %ranking = %{$rankingRef};

	my $dbh = shift;

	my %scores;
	my @table;
	my %domains;
	my %scatter = (
		hot =>  [],
		cold =>  []
	);

	open OUTPUT, $output;
	while(<OUTPUT>){
		chomp;
		unless($. == 1){
			my @line = split("\t",$_);
			my $ensemblPID = $line[2];
			my $input = $inputMap{$ensemblPID};
			my $geneSymbol = WGPA::Utils::NameConversion::Ensp2Symbol($ensemblPID, $dbh) || 'Unknown';
			my $mutation =$line[3];
			my $prediction = $line[4] || 'Unknown';
			my $score = $line[5];
			unless (defined $score and $score ne ''){
				$score = 'Unknown';			
			}
			my $intolerance = $ranking{$geneSymbol} || 'Unknown';
			my $domain = $line[9] || 'Unknown';

			if($prediction eq 'DAMAGING'){
				if(exists($domains{$domain})){
					$domains{$domain} = $domains{$domain} + 1;
				}else{
					$domains{$domain} = 1;
				}
			}

			if ($score eq 'Unknown' or $intolerance eq 'Unknown') {
				push @table, [$input, $ensemblPID, $geneSymbol, $mutation, $prediction, $score, $intolerance, ''];
			} else {
				$intolerance = 0 + $intolerance;
				my $zone = 'cold';
				if($intolerance < 25 and $score < $predThreshold){
					$zone =  'hot';
				}
				push(@table,[$input, $ensemblPID, $geneSymbol, $mutation, $prediction, $score, $intolerance, $zone]);
				push(@{$scatter{$zone}}, {
					info => "$ensemblPID($geneSymbol)_$mutation",
					x => 0 + $score,
					y => 0 + $intolerance
				});
				$score = (10 + $score) * 100 / 20;
				if ($score < 0) {
					$score = 0;
				} elsif ($score > 100) {
					$score = 100;
				}
				$scores{$geneSymbol} = $score;
			}
		}
	}

	my (%networkData, $error) = WGPA::Utils::Networks::GetFromGeneList(
		\%scores,
		$score,
		$ontology,
		$threshold,
		\%ranking,
		undef,
		$dbh
	);

	if (defined $error) {
		WGPA::Utils::DB::Disconnect($dbh);
		return $c->render(status => 400, json => { message => $error});
	}

	shift @table;

	my @dom_table;
	foreach my $dom (sort { $domains{$b} <=> $domains{$a} } keys %domains){
		push(@dom_table,[$dom,$domains{$dom}]);
	}
	
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
		],
		networkData => \%networkData
	});
}

1;

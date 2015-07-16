package WGPA::Polyphen;
use WGPA::Utils;
use WGPA::Utils::DB;
use WGPA::Utils::NameConversion;
use WGPA::Utils::Networks;
use WGPA::Utils::Paths;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw(decode_json encode_json);
use Scalar::Util qw(looks_like_number);

my $polyphenFolder = $WGPA::Utils::Paths::polyphenFolder;
my $polyphenSubmissionUrl = 'http://genetics.bwh.harvard.edu/cgi-bin/ggi/ggi2.cgi';
my $polyphenResultsUrl = 'http://genetics.bwh.harvard.edu/ggi/pph2';

sub index {
	my $c = shift;
	return $c->render();
}

sub submit {
	my $c = shift;

	return $c->render(status => 400, json => { message => 'File is too big.' })
		if $c->req->is_limit_exceeded;

	my $fileInput = $c->req->upload('FileInput');
	my $manualInput = $c->req->param('ManualInput');

	my $fastaFile = $c->req->upload('FastaFile');
	my $classifierModel = $c->param('ClassifierModel');
	my $genomeAssembly = $c->param('GenomeAssembly');
	my $transcripts = $c->param('Transcripts');
	my $annotations = $c->param('Annotations');

	my $predThreshold = $c->param('PredThreshold');
	return $c->render(status => 400, json => { message => 'The prediction cutoff needs to be a number.' })
		unless looks_like_number($predThreshold);

	my $score = $c->param('Score');
	my $ontology = $c->param('Ontology');
	my $threshold = $c->param('Threshold');	
	my $rankingFile = $c->req->upload('RankingFile');

	my $title = $c->param('Tittle');

	$c->ua->post($polyphenSubmissionUrl => form => {
		_ggi_project => 'PPHWeb2',
		_ggi_origin => 'query',
		_ggi_target_pipeline => 1,
		_ggi_batch => $manualInput,
		_ggi_batch_file => $fileInput,
		_uploaded_sequences_1 => $fastaFile,
		MODELNAME => $classifierModel,
		UCSCDB => $genomeAssembly,
		SNPFILTER => $transcripts,
		SNPFUNC => $annotations
	} => sub {
		my ($ua, $tx) = @_;
		if (my $res = $tx->success) {
			my $polyphenId;
			for my $cookie (@{$res->cookies}) {
				if ($cookie->name eq 'polyphenweb2') {
					$polyphenId = $cookie->value;
					last;
				}
			}
			return $c->render_exception unless defined $polyphenId;

			my $dbh = WGPA::Utils::DB::ConnectTo('WGPA');
			$dbh->do('INSERT INTO PolyPhen (PolyphenId, Title, LastPoll, PredThreshold, Score, Ontology, Threshold) VALUES (?, ?, ?, ?, ?, ?, ?);', undef, $polyphenId, $title, ''.time, $predThreshold, $score, $ontology, $threshold);#TODO
			my $id = $dbh->{mysql_insertid};

			if ($score eq 'Custom') {
				my $error = 'The gene sets file uploaded can\'t be empty' unless $rankingFile->size;
				unless (defined $error) {
					$dbh->do('DELETE FROM PolyPhen WHERE Id = ?;', undef, $id);
					WGPA::Utils::DB::Disconnect($dbh);
					return $c->render(status => 400, json => { message => $error});
				}
				$rankingFile->move_to("$polyphenFolder/$id.txt");
			}
			
			WGPA::Utils::DB::Disconnect($dbh);

			return $c->render(json => { message => $id });
		}
		return $c->render(status => 502, json => { message => "Something went wrong contacting the PolyPhen server.\nTry again later." });
	});
}

sub results {
	my $c = shift;
	$c->render_later;
	my $id = $c->param('id');

	return $c->redirect_to("$id/") if (not $c->req->url->path->trailing_slash);

	my $dbh = WGPA::Utils::DB::ConnectTo('WGPA');
	my $sth = $dbh->prepare("SELECT PolyphenId, Title, Status, LastPoll, PredThreshold, Score, Ontology, Threshold FROM PolyPhen WHERE Id = ?;");
	$sth->execute($id);
	my @row = $sth->fetchrow_array();
	unless (@row) {
		WGPA::Utils::DB::Disconnect($dbh);
		return $c->render_not_found; 
	}
	my $polyphenId = $row[0];
	my $title = $row[1];
	my $status = $row[2];
	my $lastPoll = $row[3];
	my $predThreshold = $row[4];
	my $score = $row[5];
	my $ontology = $row[6];
	my $threshold = $row[7];

	$sth->finish();

	if ($status eq 'Queued') {
		checkIfRunning($c, $id, $polyphenId, $title, $predThreshold, $score, $ontology, $threshold, $dbh);
	} elsif ($status eq 'Running') {
		checkIfCompleted($c, $id, $polyphenId, $title, $predThreshold, $score, $ontology, $threshold, $dbh);
	} else {
		renderResults($c, $id, $polyphenId, $title, $predThreshold, $score, $ontology, $threshold, $dbh);
	}
}

sub checkIfRunning {
	my $c = shift;
	my $id = shift;
	my $polyphenId = shift;
	my $title =  shift;
	my $predThreshold = shift;
	my $score = shift;
	my $ontology = shift;
	my $threshold = shift;
	my $dbh = shift;

	$c->ua->get($polyphenResultsUrl.'/'.$polyphenId.'/1/started.txt' => sub {
		my ($ua, $tx) = @_;
		if (my $res = $tx->success) {
			checkIfCompleted($c, $id, $polyphenId, $title, $predThreshold, $score, $ontology, $threshold, $dbh);
		} else {
			WGPA::Utils::DB::Disconnect($dbh);
			my $header = 'Your analysis has been queued and will be run as soon as possible';
			my $message = 'This page will be automatically refreshed when the analysis is ready or you can save the link and come back at any time.';

			$c->respond_to(
				json => {json => {status => 'Queued', header => $header, message => $message}},
				any => sub {
					$c->render(template => 'shared/wait',
						url => 'polyphen',
						id => $id, 
						header => $header,
						message => $message,
						customTitle => 'PolyPhen-2 Analysis Not Ready',
						polling => 70
					);
				}
			);
		}
	});
}

sub checkIfCompleted {
	my $c = shift;
	my $id = shift;
	my $polyphenId = shift;
	my $title =  shift;
	my $predThreshold = shift;
	my $score = shift;
	my $ontology = shift;
	my $threshold = shift;
	my $dbh = shift;

	$c->ua->get($polyphenResultsUrl.'/'.$polyphenId.'/1/completed.txt' => sub {
		my ($ua, $tx) = @_;
		if (my $res = $tx->success) {
			$dbh->do('UPDATE PolyPhen SET Status = ?, LastPoll = ? WHERE Id = ?;', undef, 'Completed', ''.time,  $id); #TODO
			renderResults($c, $id, $polyphenId, $title, $predThreshold, $score, $ontology, $threshold, $dbh);
		} else {
			$dbh->do('UPDATE PolyPhen SET Status = ?, LastPoll = ? WHERE Id = ?;', undef, 'Running', ''.time, $id);
			WGPA::Utils::DB::Disconnect($dbh);

			my $header = 'Your analysis is running and will be done in few minutes';
			my $message = 'This page will be automatically refreshed when the analysis is ready or you can save the link and come back at any time.';
			$c->respond_to(
				json => {json => {status => 'Running', header => $header, message => $message}},
				any => sub {
					$c->render(template => 'shared/wait',
						url => 'polyphen',
						id => $id, 
						header => $header,
						message => $message,
						customTitle => 'PolyPhen-2 Analysis Not Ready',
						polling => 70
					);
				}
			);
		}
	});
}

sub renderResults {
	my $c = shift;
	my $id = shift;
	my $polyphenId = shift;
	my $title = shift;
	my $predThreshold = shift;
	my $score = shift;
	my $ontology = shift;
	my $threshold = shift;
	my $dbh = shift;

	return $c->respond_to(
		json => { json => {status => 'Completed' } },
		any => sub {
			$c->delay(
				sub {
					my $delay = shift;

					$c->ua->get($polyphenResultsUrl.'/'.$polyphenId.'/1/pph2-short.txt' => $delay->begin);
					$c->ua->get($polyphenResultsUrl.'/'.$polyphenId.'/1/pph2-snps.txt' => $delay->begin);
					$c->ua->get($polyphenResultsUrl.'/'.$polyphenId.'/1/pph2-log.txt' => $delay->begin);
				},
				sub {
					my ($delay, $shortTx, $snpsTx, $logTx) = @_;

					return $c->render(status => 502, json => { message => "Something went wrong contacting the PolyPhen server.\nTry again later." })
						unless (my $shortRes = $shortTx->success);

					my (%ranking, $error) = WGPA::Utils::getGenePercentiles(
						$score,
						$ontology,
						$threshold,
						"$polyphenFolder/$id.txt",
						$dbh
					);

					return $c->render(status => 400, json => { message => $error})
						if defined $error;

					return $c->render(template => 'polyphen/results',
						customTitle => $title,
						score => $score,
						url => $polyphenResultsUrl.'/'.$polyphenId.'/1/',
						hasSNPs => (my $snpsRes = $snpsTx->success),
						hasErrors => ($logTx->success->body =~ /'No errors'/g) != 7,
						pphResults => encode_json(processPPHResults(
							$shortRes->body,
							$id,
							$predThreshold,
							\%ranking,
							$dbh
						))
					);
				}
			);
		}
	);
}

sub processPPHResults {
	my $pph2PlainText = shift;
	my $id = shift;
	my $predThreshold = shift;
	my $rankingRef = shift;
	my %ranking = %{$rankingRef};
	my $dbh = shift;

	my %intolerances;
	my @table;
	my %domains;
	my %scatter = (
		hot => [],
		cold => []
	);

	my @lines = split(/\n/, $pph2PlainText);
	foreach my $line (@lines) {
		my @columns = split(/\s*\t\s*/, $line);
		my $input = $columns[0];
		if ($input !~ /^#/) {
			my @ensemblPIDs = WGPA::Utils::NameConversion::LU_uniprot($columns[5], $dbh);
			my $mutation = $columns[7].'-'.$columns[8].' ('.$columns[6].')';
			my $prediction = $columns[9];
			my $score = (1 - $columns[10]) * 100;

			foreach my $ensemblPID (@ensemblPIDs) {
				my $geneSymbol = WGPA::Utils::NameConversion::ensp2Symbol($ensemblPID);
				my $intolerance = $ranking{$geneSymbol};

				if (defined $intolerance) {
					$intolerance = 0 + $intolerance;
					$intolerances{$geneSymbol} = $intolerance;
					if($intolerance < 25 and $score < $predThreshold){
						push @table, [$input, $ensemblPID, $geneSymbol, $mutation, $prediction, $score, $intolerance, 'hot'];
						push(@{$scatter{hot}}, {
							info => "$ensemblPID($geneSymbol)_$mutation",
							x => 0 + $score,
							y => 0 + $intolerance
						});
					} else {
						push @table, [$input, $ensemblPID, $geneSymbol, $mutation, $prediction, $score, $intolerance, 'cold'];
						push(@{$scatter{cold}}, {
							info => "$ensemblPID($geneSymbol)_$mutation",
							x => 0 + $score,
							y => 0 + $intolerance
						});
					}
				} else {
					push @table, [$input, $ensemblPID, $geneSymbol, $mutation, $prediction, $score, 'No Score Reported', ''];
				}
			}
		}
	}

	WGPA::Utils::DB::Disconnect($dbh);

	# TODO @table = sort {$a->[4] <=> $b->[4]} @table;

	my @labels;
	my @vals;
	foreach my $label (sort { $intolerances{$a} <=> $intolerances{$b} } keys %intolerances){
		push(@labels, $label);
		push(@vals, $intolerances{$label});
	}

	return {
		bar => {
			labels => \@labels,
			vals => \@vals
		},
		table => \@table, 
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
	};
}

sub  network {
	my $c = shift;
	
	my $id = $c->param('id');

	my @genes = @{$c->req->json->{genes}};

	my $dbh = WGPA::Utils::DB::ConnectTo('WGPA');
	my $sth;
	my $sql;

	$sth = $dbh->prepare("SELECT Score, Ontology, Threshold FROM PolyPhen WHERE id = ?;");
	$sth->execute($id);

	return $c->render_exception unless (my @temp = $sth->fetchrow_array);

	my $score = $temp[0];
	my $ontology = $temp[1];
	my $threshold = $temp[2];

	$sth->finish();

	my (%networkData, $error) = WGPA::Utils::Networks::GetFromGeneList(
		\@genes,
		$score,
		$ontology,
		$threshold,
		$polyphenFolder."$id.rnk", 
		$dbh
	);

	return $c->render(status => 400, json => { message => $error})
		if defined $error;

	WGPA::Utils::DB::Disconnect($dbh);
	
	return $c->render(json => \%networkData);
}

1;

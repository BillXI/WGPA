package DCGenes::Gsea;
use DCGenes::Utils;
use DCGenes::Utils::DB;
use DCGenes::Utils::Paths;
use DCGenes::Utils::Networks;
use DCGenes::Utils::Score2File;
use Mojo::Base 'Mojolicious::Controller';
use File::Spec;

my %GSEA =  %DCGenes::Utils::Paths::GSEA;

sub index {
	my $c = shift;
	return $c->render();
}

sub submit {
	my $c = shift;

	# Check file size
	return $c->render(status => 400, json => { message => 'File is too big.' })
		if $c->req->is_limit_exceeded;

	my $genesFile = $c->req->upload('GenesFile');
	my $genes = $c->req->param('Genes');

	my $title = $c->param('Title');

	my $score = $c->param('Score');
	my $ontology = $c->param('Ontology');
	my $threshold = $c->param('Threshold');
	my $rankingFile = $c->req->upload('RankingFile');

	my $dbh = DCGenes::Utils::DB::ConnectTo('DCGenes');
	
	my $rnk_path;
	if ($score eq 'EvoTol') {
		$rnk_path = DCGenes::Utils::Score2File::EvoTol($ontology, $threshold, $dbh);
	} elsif ($score eq 'RVIS') { 
		$rnk_path = DCGenes::Utils::Score2File::RVIS($threshold, $dbh);
	} elsif ($score eq 'Constraint') {
		$rnk_path = DCGenes::Utils::Score2File::GeneConstraint($dbh);
	} else {
		return $c->render(status => 400, json => { message => "Invalid score selected." });
	}

	return $c->render(status => 400, json => { message => "Invalid ontology or threshold selected." })
		unless defined $rnk_path;

	$dbh->do("INSERT INTO GSEAAnalysis (Title, Score, Ontology, Threshold) VALUES ('$title', '$score', '$ontology', '$threshold');");
	my $id = $dbh->{mysql_insertid};

	return $c->render_exception unless $id;

	my $ext = 'grp';
	if (defined $genesFile) {
		# Extension
		$ext = ($genesFile->filename =~ m/([^.]+)$/)[0];
		my %valid_ext = map {$_ => 1} qw(gmt gmx grp wgcna);
		my $error;
		$error = 'The gene sets file uploaded can\'t be empty' unless $genesFile->size;
		$error = 'Only gmt, gmx, grp and wgcna files are valid to submit gene sets.' unless $valid_ext{$ext};
		unless (defined $error) {
			$dbh->do("DELETE FROM GSEAAnalysis WHERE Id=$id;");
			DCGenes::Utils::DB::Disconnect($dbh);
			return $c->render(status => 400, json => { message => $error});
		}
		# Save to folder
		my $gmt_path .= $GSEA{INPUT_FOLDER}."/$id.$ext";
		if ($ext eq 'wgcna') {
			DCGenes::Utils::saveWGCNAFile($genesFile->asset->path, $gmt_path);
		} else {
			$genesFile->move_to($gmt_path);
		}
	} elsif (defined $genes) {
		# Create file
		my $gmt_path = $GSEA{INPUT_FOLDER}."/$id.grp";
		my $file;
		unless (open $file, '>'.$gmt_path) {
			$dbh->do("DELETE FROM GSEAAnalysis WHERE Id=$id;");
			DCGenes::Utils::DB::Disconnect($dbh);
			return $c->render_exception;
		}
		print $file $genes;
		close $file;
	} else {
		$dbh->do("DELETE FROM GSEAAnalysis WHERE Id=$id;");
		DCGenes::Utils::DB::Disconnect($dbh);
		return $c->render(status => 400, json => { message => 'No file was selected and no genes provided.'});
	}

	if ($score eq 'Custom') {
		if (defined $rankingFile) {
			# Extension
			my $rankingExt = ($rankingFile->filename =~ m/([^.]+)$/)[0];
			my $error;
			$error = 'The gene sets file uploaded can\'t be empty' unless $rankingFile->size;
			$error = 'Only rnk files are valid to submit gene rankings.' unless $rankingExt eq 'rnk';
			unless (defined $error) {
				$dbh->do("DELETE FROM GSEAAnalysis WHERE Id=$id;");
				DCGenes::Utils::DB::Disconnect($dbh);
				return $c->render(status => 400, json => { message => $error});
			}
			# Save to folder
			my $custRnk_path .= $GSEA{INPUT_FOLDER}."/$id.rnk";
			$rankingFile->move_to($custRnk_path);
		} else {
			$dbh->do("DELETE FROM GSEAAnalysis WHERE Id=$id;");
			DCGenes::Utils::DB::Disconnect($dbh);
			return $c->render(status => 400, json => { message => 'No custom score ranking was provided.'});
		}
	}

	$dbh->do("UPDATE GSEAAnalysis SET Input = \"$ext\" WHERE Id = $id;");
	DCGenes::Utils::DB::Disconnect($dbh);

	return $c->render(json => { message => $id });
}

sub results {
	my $c = shift;
	my $id = $c->param('id');

	my $dbh = DCGenes::Utils::DB::ConnectTo('DCGenes');
	my $sth = $dbh->prepare('SELECT Title, Status, Error FROM GSEAAnalysis WHERE Id = ?;');
	$sth->execute($id);
	my @row = $sth->fetchrow_array();
	unless (@row) {
		DCGenes::Utils::DB::Disconnect($dbh);
		return $c->render_not_found; 
	}
	my $title = $row[0];
	my $status = $row[1];
	my $message = $row[2];

	$sth->finish();
	DCGenes::Utils::DB::Disconnect($dbh);

	my $header;
	if ($status eq 'Queued') {
		$header = 'Your analysis has been queued and will be run as soon as possible';
		$message = 'This page will be automatically refreshed when the analysis is ready or you can save the link and come back at any time.';
	} elsif ($status eq 'Running') {
		$header = 'Your analysis is running and will be done in few minutes';
		$message = 'This page will be automatically refreshed when the analysis is ready or you can save the link and come back at any time.';
	} elsif ($status eq 'Error') {
		$header = 'Your analysis failed';
	}

	$c->respond_to(
		json => {json => {status => $status, header => $header, message => $message}},
		any => sub {
			if ($status eq 'Completed') {
				my $result_dir = $GSEA{RESULTS_FOLDER}.'/'.$id;
				my $path = $c->param('fileName');

				if ($path eq 'index.html') { # Main summary
					return $c->redirect_to("$id/") if (not $c->req->url->path->trailing_slash);

					## Render results view
					my ($setsSubmitted, $setsAnalyzed, $setDiscarted, $posTableFile, $negTableFile)
						= getAnalysisMetadata("$result_dir/index.html");

					# If only 1 set. Redirect to its result
					if ($setsAnalyzed == 1) {
						my $setName = getFirstSet("$result_dir/".($posTableFile || $negTableFile));
						return $c->redirect_to("$setName");
					}

					my ($posTable, $posSnapshot, $negTable, $negSnapshot);

					if ($posTableFile) {
						$posTable = processTable("$result_dir/$posTableFile");
						$posSnapshot = processSnapshot("$result_dir/pos_snapshot.html");
						$posTableFile =~ s/.html$/.xls/;
					}

					if ($negTableFile) {
						$negTable = processTable("$result_dir/$negTableFile");
						$negSnapshot = processSnapshot("$result_dir/neg_snapshot.html");
						$negTableFile =~ s/.html$/.xls/;
					}

					return $c->render(template => 'gsea/summary',
						title => $title,
						setsSubmitted => $setsSubmitted,
						setsAnalyzed => $setsAnalyzed,
						setDiscarted => $setDiscarted,
						posEnrichedXls => $posTableFile,
						posTable => $posTable,
						posSnapshot => $posSnapshot,
						negEnrichedXls => $negTableFile,
						negTable => $negTable,
						negSnapshot => $negSnapshot
					);
				} elsif ($path =~ /.html$/) { # Gene Set Summary
					# This checks avoid trying to parse files that exists but shouldn't be shown
					# beause they are part of the summary
					my ($setsSubmitted, $setsAnalyzed, $setDiscarted, $posTableFile, $negTableFile) 
						= getAnalysisMetadata("$result_dir/index.html");

					return $c->render_not_found
						if ($path eq $posTableFile || $path eq $negTableFile 
							||  $path eq 'post_snapshot.html' ||  $path eq 'neg_snapshot.html');

					# Parse and render the set summary
					my ($summaryTable, $enrichmentPlot, $esDistribution, $genesTable)
						= processSet("$result_dir/$path", isNegEnriched("$result_dir/neg_snapshot.html", $path));
					
					return $c->render_not_found
						unless ($summaryTable);

					$path =~  s/.html$/ /;
					return $c->render(template => 'gsea/set',
						title => $title,
						isOnlySet => $setsAnalyzed == 1,
						setName => $path,
						summaryTable => $summaryTable,
						enrichmentPlot => $enrichmentPlot,
						esDistribution => $esDistribution,
						genesTable => $genesTable
					);
				} else { # Static files (images, CSVs, etc.)
					my $staticPath = File::Spec->abs2rel("$result_dir/$path", $DCGenes::Utils::Paths::rootFolder.'/public');
					return $c->reply->static($staticPath);
				}
			} elsif ($status eq 'Error') {
				return $c->render(template => 'shared/error', 
					id => $id, header => $header, message => $message);
			} else {
				return $c->render(template => 'shared/wait',
					url => 'gsea', 
					id => $id, 
					header => $header,
					message => $message,
					customTitle => 'GSEA Analysis Not Ready',
					polling => 30
				);
			}
		}
	);
}

sub  network {
	my $c = shift;
	
	my $id = $c->param('id');

	my @genes = @{$c->req->json->{genes}};

	my $dbh = DCGenes::Utils::DB::ConnectTo('DCGenes');
	my $sth;
	my $sql;

	$sth = $dbh->prepare("SELECT Score, Ontology, Threshold FROM GSEAAnalysis WHERE Id = ?;");
	$sth->execute($id);

	return $c->render_exception unless (my @temp = $sth->fetchrow_array);

	my $score = $temp[0];
	my $ontology = $temp[1];
	my $threshold = $temp[2];

	$sth->finish();

	my (%networkData, $error) = DCGenes::Utils::Networks::GetFromGeneList(
		\@genes,
		$score,
		$ontology,
		$threshold,
		$GSEA{INPUT_FOLDER}."$id.rnk", 
		$dbh
	);

	return $c->render(status => 400, json => { message => $error})
		if defined $error;

	DCGenes::Utils::DB::Disconnect($dbh);
	
	return $c->render(json => \%networkData);
}

# GSEA Analysis parser methods
#####################################

sub getAnalysisMetadata {
	my $path = shift  || return '';
	my $dom = DCGenes::Utils::readToDOM($path);
	my $setsDetailsString =$dom->at('div:nth-child(5) li:first-child')->content;
	# Use REGEXPs to get values from the HTML
	my ($setDiscarted, $setsSubmitted) = $setsDetailsString =~ /(\d+) \/ (\d+)/;
	my $setsAnalyzed = $setsSubmitted - $setDiscarted;

	my $posTableFile = $dom->at('div:nth-child(2) li:nth-child(6) a');
	my $negTableFile = $dom->at('div:nth-child(3) li:nth-child(6) a');
	$posTableFile = defined $posTableFile ? $posTableFile->attr('href') : 0;
	$negTableFile = defined $negTableFile ? $negTableFile->attr('href') : 0;
	return ($setsSubmitted, $setsAnalyzed, $setDiscarted, $posTableFile, $negTableFile);
}

sub getFirstSet {
	my $path = shift  || return '';
	my $dom = DCGenes::Utils::readToDOM($path) || return '';
	return $dom->at('table tr td:nth-child(3) a')->attr('href');
}

sub processTable {
	my $path = shift  || return '';
	my $dom = DCGenes::Utils::readToDOM($path) || return '';
	my $table;
	my $anchor;
	for my $row ($dom->at('table')->find('tr')->each) {
		$row->at('td:nth-child(1)')->remove;
		$anchor = $row->at('td:nth-child(2)')->at('a');
		if (length($anchor)) {
			$row->at('td:nth-child(1)')->at('a')->attr(href => $anchor->attr('href'));
		}
		$row->at('td:nth-child(2)')->remove;

		$table .= $row->to_string;
	}
	return $table;
}

sub processSnapshot {
	my $path = shift || return '';
	my $dom = DCGenes::Utils::readToDOM($path) || return '';
	my $snapshot;
	for my $a ($dom->find('a')->each) {
		$snapshot .= $a->to_string;
	}
	return $snapshot;
}

sub processSet {
	my $path = shift || return '';
	my $negEnrichment = shift || 0;
	my $dom = DCGenes::Utils::readToDOM($path) || return '';
	my $tableDOM = $dom->at('.keyValTable')->at('table');
	$tableDOM->at('tr')->remove;
	$tableDOM->at('tr')->remove;
	$tableDOM->at('tr')->remove;
	my $summaryTable;
	for my $tr ($tableDOM->find('tr')->each) {
		$summaryTable .= $tr->to_string;
	}
	my $enrichmentPlot = $dom->find('.image')->[0]->at('img')->attr('src');
	my $esDistribution = $dom->find('.image')->[1]->at('img')->attr('src');

	$tableDOM = $dom->at('.richTable')->at('table');
	$tableDOM->at('tr')->remove;
	my $genesTable;
	my $genesTableRows = $tableDOM->find('tr');
	if ($negEnrichment){
		$genesTableRows = $genesTableRows->reverse;
	}
	for my $tr ($genesTableRows->each) {
		$tr->find('td')->[0]->remove;
		$tr->find('td')->[1]->remove;
		$tr->find('td')->[1]->remove;
		my $geneLink = $tr->find('td')->[0]->at('a');
		my $geneName = $geneLink->text;
		$geneLink->attr(href => "http://www.genecards.org/cgi-bin/carddisp.pl?gene=$geneName");
		$geneLink->attr(target => "_blank");
		$genesTable .= $tr->to_string;
	}
	return ($summaryTable, $enrichmentPlot, $esDistribution, $genesTable);
}

sub isNegEnriched {
	my $negSnapshotPath = shift || return 0;
	my $setPath = shift || return 0;
	my $dom = DCGenes::Utils::readToDOM($negSnapshotPath) || return '';
	return CORE::index($dom->to_string, $setPath) != -1;
}

#####################################

1;
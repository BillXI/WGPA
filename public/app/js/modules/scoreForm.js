var ScoreForm = (function (window, document) {

	var evotol = function (ontologies) {
		var evoTol ='<div class="form-group">' +
			'<label class="control-label col-sm-5" for="ontology">Cell specificty:</label>' +
			'<div class="col-sm-7">' +
				'<select name="ontology" id="Ontology" class="form-control" data-select2-placeholder="Select a cell type" data-select2-width="resolve">';
				var ontology,
					ontologyLength = ontologies.length;
				for (var i = 0; i < ontologyLength; i++) {
					ontology = ontologies[i];
					evoTol = evoTol + '<option value="' + ontology + '">' + ontology + '</option>';
				};
				evotol = evoTol + '</select>' +
			'</div>' +
		'</div>' +

		'<div class="form-group">' +
			'<label class="control-label col-sm-5" for="threshold">Intolerance expression cutoff:</label>' +
			'<div class="col-sm-7">' +
				'<select name="threshold" id="Threshold" class="form-control">' +
					'<option value="1">1</option>' +
					'<option value="10">10</option>' +
					'<option value="100">100</option>' +
				'</select>' +
			'</div>' +
		'</div>'
		return evotol;
	};

	var rvis = 
		'<div class="form-group">' +
			'<label class="control-label col-sm-5" for="threshold">Population Cutoff:</label>' +
			'<div class="col-sm-7">' +
				'<select name="threshold" id="Threshold" class="form-control">' +
					'<option value="001">001</option>' +
					'<option value="01">01</option>' +
					'<option value="1">1</option>' +
				'</select>' +
			'</div>' +
		'</div>';

	var constraint = ''

	var custom =
		'<div class="form-group">' +
			'<label class="control-label col-sm-5" for="threshold">Ranking:</label>' +
			'<div class="col-sm-7">' +
				'<input type="file" id="RankingFile" name="ranking-file" class="form-control">' +
				'<p class="help-block">file containing the whole genome ranked</p>' +
			'</div>' +
		'</div>'
	;

	var scoreDDL = document.getElementById('Score'),
		scoreHelpBlock = scoreDDL.parentNode.getElementsByClassName('help-block'),
		optionsContainer = document.getElementById("score-options");
	$(scoreDDL).on('change', renderScoreOptions);
	renderScoreOptions();

	function renderScoreOptions() {
		// TODO update help
		switch(scoreDDL.value) {
			case 'EvoTol':
				if (typeof evotol === 'function') {
					var getOntologiesRquest = new XMLHttpRequest();
					getOntologiesRquest.open('get', '/evotol/ontologies');
					getOntologiesRquest.onreadystatechange = function () {
						if(this.readyState === 4) {
							if (this.status === 500) {
								Alert({text: 'There was an unexpected error. Please contact the web admin.', type: 'danger', layout: 'top-center'});
							} else {
								var data = JSON.parse(this.responseText);
								if(this.status === 200) {
									evotol = evotol(data);
									optionsContainer.innerHTML = evotol;
									initializeSelect2();
								} else {
									Alert({text: data.message, type: 'danger', layout: 'top-center'});
								}
							}
						}
					};
					getOntologiesRquest.send();
				} else {
					optionsContainer.innerHTML = evotol;
				}
				break;
			case 'RVIS':
				optionsContainer.innerHTML = rvis;
				break;
			case 'Constraint':
				optionsContainer.innerHTML = constraint;
				break;
			case 'Custom':
				optionsContainer.innerHTML = custom;
				break;
			default:
				throw 'Invalid score selected.'
		}
		initializeSelect2();
	}

	function getFormData() {
		var ontology = document.getElementById('Ontology'),
			threshold = document.getElementById('Threshold'),
			rankingFile = document.getElementById('RankingFile');

		var formData = new FormData();
		formData.append('Score', scoreDDL.value);
		ontology && formData.append('Ontology', ontology.value);
		threshold && formData.append('Threshold', threshold.value);
		rankingFile && formData.append('RankingFile', rankingFile.files[0]);

		return formData;
	}

	function enable(enable) {
		var ontology = document.getElementById('Ontology'),
			threshold = document.getElementById('Threshold'),
			rankingFile = document.getElementById('RankingFile');

		if (enable) {
			scoreDDL.removeAttribute('disabled');
			ontology && ontology.removeAttribute('disabled');
			threshold && threshold.removeAttribute('disabled');
			rankingFile && rankingFile.removeAttribute('disabled');
		} else {
			scoreDDL.setAttribute('disabled', '');
			ontology && ontology.setAttribute('disabled', '');
			threshold && threshold.setAttribute('disabled', '');
			rankingFile && rankingFile.setAttribute('disabled', '');
		}
	}

	return {
		GetFormData: getFormData,
		Enable:enable
	}

})(window, document);

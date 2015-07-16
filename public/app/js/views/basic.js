var Basic = (function (window, document) {
	var epi4kGenes = 'KCNB1\nKMT2B\nGRIN1\nNCOR2\nSCN8A\nRANGAP1\nGABRA1\nSCN2A\nCDC25B\nTRRAP\nNFASC\n' +
		'SMURF1\nFLNC\nATP2B4\nPRKX\nGNAO1\nPLA1A\nAKAP6\nTAF1\nCDKL5\nETS1\nTTN\nSTXBP1\nCAMK4\nGABRB3\n' +
		'PLXNA1\nKCNQ2\nMAST1\nCSNK1E\nITGAM\nXPO1\nDIA\nTHOC2\nNEDD4L\nMAPK8IP1\nSMG9\nDNM1\nNR1H2\n' +
		'DDX58\nC18orf25\nSCN1A\nRUVBL2\nITGB4\nCACNA1A\nCUX2\nYWHAG\nHCK\nRIOK3\nMTOR\nFASN\nHIST2H2BE\n' +
		'LUC7L3\nKCNQ3\nTRIO\nGRIN2B\nANK3\nHIPK3\nCHD4\nMEOX2\nFLNA\nMLL\nCTTNBP2NL\nSLC1A2\nPTEN\nRRP1B\nGABRB1';

	var cardiacMuscleContractionNetwork = 'ACTC1 MYH6\nACTC1 MYH6\nACTC1 MYH7\nACTC1 MYH7\n' +
		'ACTC1 MYL2\nACTC1 MYL2\nACTC1 MYL3\nACTC1 MYL3\nACTC1 MYL4\nACTC1 MYL4\nTNNC1 TNNI3\n' +
		'TNNC1 TNNT2\nTNNI3 ACTC1\nTNNI3 ACTC1\nTNNI3 TNNT2\nTNNT2 TNNC1\nTNNT2 TPM1\nTNNT2 TPM2\n' +
		'TNNT2 TPM3\nTNNT2 TPM4\nTPM1 ACTC1\nTPM2 ACTC1\nTPM3 ACTC1\nTPM4 ACTC1';

	var allCheckbox,
		submitButton,
		formContainer,
		resultsContainer;

	function init(){
		allCheckbox = document.getElementById('all');
		submitButton = document.getElementById('submit-button');
		formContainer  = $('#form-container');
		resultsContainer = $('#results-container');

		allCheckbox.addEventListener('click', enable);
		submitButton.addEventListener('click', submit);

		document.getElementById('epi4k').addEventListener('click', populateEpi4kGenes);
		document.getElementById('populatebox').addEventListener('click', populateBox);
	}

	function populateEpi4kGenes() {
		$(this).closest('div').find('textarea').html(epi4kGenes);
	}

	function populateBox() {
		$(this).closest('div').find('textarea').html(cardiacMuscleContractionNetwork);
	}

	function enable(e) {
		ScoreForm.Enable(!this.checked);
	}

	function submit(e) {
		e.preventDefault();
		submitButton.setAttribute('disabled', '');

		var formData = ScoreForm.GetFormData(),
			file = document.getElementById('network-file').files[0],
			textBox = document.getElementById('network-box').value;

		if (file) {
			formData.append('File', file);
		} else if (textBox) {
			formData.append('Network', textBox);
		} else {
			Alert({text: 'No file was selected and no network provided', type: 'danger', layout: 'top-center'});
			submitButton.removeAttribute('disabled');
			return;
		}
		formData.append('All', allCheckbox.checked);

		var xhr = new XMLHttpRequest();
		xhr.open('post', '/basic');
		xhr.onreadystatechange = callback;
		xhr.send(formData);
	}

	function callback() {
		if(this.readyState === 4) {
			if (this.status === 500) {
				Alert({text: 'There was an unexpected error. Please contact the web admin.', type: 'danger', layout: 'top-center'});
			} else {
				var data = JSON.parse(this.responseText);
				if(this.status === 200) {
					if (data) {
						initResults(data);
						formContainer.collapse('hide');
						resultsContainer.collapse('show');
					}
				} else {
					Alert({text: data.message, type: 'danger', layout: 'top-center'});
				}
			}
			submitButton.removeAttribute('disabled');
		}
	}

	var showNetwokButton,
		networkContainer,
		network,
		networkModel;

	function initResults(data) {
		if (data.Score !== 'All')  {
			showNetwokButton = document.getElementById('show-network');
			networkContainer = document.getElementById('cy-container');
			document.getElementById('all-results-table').style.display = 'none';

			showNetwokButton.addEventListener('click', showNetwork);

			networkModel = data.Network;

			new BarChart('bars-chart', {
				score: data.Score,
				data: data.bar
			}).render();
		
			renderRanking(data.Score, data.Network.Network.Nodes);
		} else {
			document.getElementById('results-table').style.display = 'none';
			document.getElementById('show-network').style.display = 'none';
			renderAllRanking(data.Percentiles);
		}
	}

	function renderRanking(score, genes) {
		document.getElementById('score-header').innerHTML = score;

		var gene,
			tbdy=document.createElement('tbody'),
			tr,
			td;
		
		for(var i = 0; i < genes.length; i++) {
			gene = genes[i].data;
			
			tr = document.createElement('tr');

			td = document.createElement('td');
			td.appendChild(document.createTextNode(gene.name));
			tr.appendChild(td);

			td = document.createElement('td');
			td.appendChild(document.createTextNode(gene.percentile));
			tr.appendChild(td);

			tbdy.appendChild(tr);
		}

		var tbl = document.getElementById('results-table');
		tbl.removeChild(tbl.getElementsByTagName('tbody')[0]);
		tbl.appendChild(tbdy);

		tsorter.create('results-table');
	}

	function renderAllRanking(genes) {
		var gene,
			tbdy=document.createElement('tbody'),
			tr,
			td;
		
		for(var i = 0; i < genes.length; i++) {
			gene = genes[i];
			
			tr = document.createElement('tr');

			td = document.createElement('td');
			td.appendChild(document.createTextNode(gene.name));
			tr.appendChild(td);

			td = document.createElement('td');
			td.appendChild(document.createTextNode(gene.EvoTol));
			tr.appendChild(td);

			td = document.createElement('td');
			td.appendChild(document.createTextNode(gene.RVIS));
			tr.appendChild(td);

			td = document.createElement('td');
			td.appendChild(document.createTextNode(gene.Constraint));
			tr.appendChild(td);

			tbdy.appendChild(tr);
		}

		var tbl = document.getElementById('all-results-table');
		tbl.removeChild(tbl.getElementsByTagName('tbody')[0]);
		tbl.appendChild(tbdy);

		tsorter.create('all-results-table');
	}

	function showNetwork() {
		if (networkContainer.style.display === 'block') {
			hideNetwork();
		} else {
			if (!network) {
				network = new Network('#cy-container', networkModel);
				network.render();
			}
			networkContainer.style.display = 'block';
			showNetwokButton.innerText = 'Hide interaction network';
		}
	}

	function hideNetwork (){
		networkContainer.style.display = 'none';
		showNetwokButton.innerText = 'Show interaction network';
	}

	return {
		Init: init
	};

})(window, document);

Basic.Init();
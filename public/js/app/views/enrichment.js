var Enrichment = (function (window, document) {
	var epi4kGenes = 'KCNB1\nKMT2B\nGRIN1\nNCOR2\nSCN8A\nRANGAP1\nGABRA1\nSCN2A\nCDC25B\nTRRAP\nNFASC\n' +
		'SMURF1\nFLNC\nATP2B4\nPRKX\nGNAO1\nPLA1A\nAKAP6\nTAF1\nCDKL5\nETS1\nTTN\nSTXBP1\nCAMK4\nGABRB3\n' +
		'PLXNA1\nKCNQ2\nMAST1\nCSNK1E\nITGAM\nXPO1\nDIA\nTHOC2\nNEDD4L\nMAPK8IP1\nSMG9\nDNM1\nNR1H2\n' +
		'DDX58\nC18orf25\nSCN1A\nRUVBL2\nITGB4\nCACNA1A\nCUX2\nYWHAG\nHCK\nRIOK3\nMTOR\nFASN\nHIST2H2BE\n' +
		'LUC7L3\nKCNQ3\nTRIO\nGRIN2B\nANK3\nHIPK3\nCHD4\nMEOX2\nFLNA\nMLL\nCTTNBP2NL\nSLC1A2\nPTEN\nRRP1B\nGABRB1';

	var runGSEAButton;

	function init() {
		runGSEAButton = document.getElementById('runGSEA');		
		runGSEAButton.addEventListener('click', runGSEA);

		document.getElementById('epi4k').addEventListener('click', populateEpi4kGenes);
	}

	function populateEpi4kGenes() {
		$(this).closest('div').find('textarea').html(epi4kGenes);
	}

	function runGSEA(e) {
		e.preventDefault();
		runGSEAButton.setAttribute('disabled', '');
		var formData = ScoreForm.GetFormData(),
			file = document.getElementById('GenesFile').files[0],
			genes = document.getElementById('Genes').value,
			title = document.getElementById('Title').value;

		formData.append('Title', title);

		if (file) {
			formData.append('GenesFile', file);
		} else if (genes) {
			formData.append('Genes', genes);
		} else {
			Alert({text: 'No file was selected and no genes provided', type: 'danger', layout: 'top-center'});
			runGSEAButton.removeAttribute('disabled');
			return;
		}

		var runGSEAClient = new XMLHttpRequest();
		runGSEAClient.open('post', '/enrichment');
		runGSEAClient.onreadystatechange = callback;
		runGSEAClient.send(formData);
	}

	function callback() {
		if(this.readyState === 4) {
			if (this.status === 500) {
				Alert({text: 'There was an unexpected error. Please contact the web admin.', type: 'danger', layout: 'top-center'});
			} else {
				var data = JSON.parse(this.responseText);
				if(this.status === 200) {
					window.location.href = '/enrichment/' + data.message + '/';
				} else {
					Alert({text: data.message, type: 'danger', layout: 'top-center'});
				}
			}
			runGSEAButton.removeAttribute('disabled');
		}
	}

	return {
		Init: init
	};
})(window, document);

Enrichment.Init();
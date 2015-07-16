var Polyphen = (function (window, document) {
	var sampleBatch = 'Q92889 706 I T\n' +
		'Q92889 875 E G\n' +
		'NP_005792 59 L P\n' +
		'rs1799931\n' +
		'chr1:1267483 G/A\n' +
		'chr1:1158631 A/C,G,T\n';

	var runPolyphenButton;

	function init() {
		runPolyphenButton = document.getElementById('runPolyPhen');		
		runPolyphenButton.addEventListener('click', runPolyphen);

		document.getElementById('sample-batch').addEventListener('click', populateSampleBatch);
	}

	function populateSampleBatch() {
		$(this).closest('div').find('textarea').html(sampleBatch);
	}

	function runPolyphen(e) {
		e.preventDefault();
		runPolyphenButton.setAttribute('disabled', '');
		var formData = ScoreForm.GetFormData(),
			fileInput = document.getElementById('file-input').files[0],
			manualInput = document.getElementById('manual-input').value,
			fastaFile = document.getElementById('fasta-file').files[0];

		if (fileInput) {
			formData.append('FileInput', inputFile);
		} else if (manualInput) {
			formData.append('ManualInput', manualInput);
		} else {
			Alert({text: 'No file was selected and no substitutions provided', type: 'danger', layout: 'top-center'});
			runPolyphenButton.removeAttribute('disabled');
			return;
		}

		if (fastaFile) {
			formData.append('FastaFile', fastaFile.files[0]);
		}
		formData.append('ClassifierModel', document.getElementById('classifier-model').value);
		formData.append('GenomeAssembly', document.getElementById('genome-assembly').value);
		formData.append('Transcripts', document.getElementById('transcripts').value);
		formData.append('Annotations', document.getElementById('annotations').value);
		formData.append('Title', document.getElementById('title').value);
		formData.append('PredThreshold', document.getElementById('pred-threshold').value);

		var runPolyphenClient = new XMLHttpRequest();
		runPolyphenClient.open('post', '/polyphen');
		runPolyphenClient.onreadystatechange = callback;
		runPolyphenClient.send(formData);
	}

	function callback() {
		if(this.readyState === 4) {
			if (this.status === 500) {
				Alert({text: 'There was an unexpected error. Please contact the web admin.', type: 'danger', layout: 'top-center'});
			} else {
				var data = JSON.parse(this.responseText);
				if(this.status === 200) {
					window.location.href = '/polyphen/' + data.message + '/';
				} else {
					Alert({text: data.message, type: 'danger', layout: 'top-center'});
				}
			}
			runPolyphenButton.removeAttribute('disabled');
		}
	}

	return {
		Init: init
	};
})(window, document);

Polyphen.Init();

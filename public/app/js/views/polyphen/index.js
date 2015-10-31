var Polyphen = (function (window, document) {
	var sampleBatch = 'Q92889 706 I T\n' +
		'Q92889 875 E G\n' +
		'NP_005792 59 L P\n' +
		'rs1799931\n' +
		'chr1:1267483 G/A\n' +
		'chr1:1158631 A/C,G,T\n';
	
	var epi4kSubstitutions ='ENSP00000283256 1422 K E\nENSP00000352035 581 R G\nENSP00000360608 668 Y S\n' +
				'ENSP00000307288 363 D H\nENSP00000362014 359 G A\nENSP00000346534 214 G D\nENSP00000414232 292 T I\n' +
				'ENSP00000283256 853 R Q\nENSP00000347733 3728 R Q\nENSP00000354621 115 R H\nENSP00000340930 1054 L P\n'+
				'ENSP00000262493 275 F S\nENSP00000362396 544 G D\nENSP00000369325 213 G E\nENSP00000362396 335 P L\n' +
				'ENSP00000308725 110 N D\nENSP00000352035 144 R Q\nENSP00000441691 246 R G\nENSP00000362396 406 R H\n' +
				'ENSP00000245838 517 Y C\nENSP00000270066 18 R Q\nENSP00000362014 206 K N\nENSP00000253727 318 R C\n' +
				'ENSP00000386312 931 C Y\nENSP00000346534 875 L Q\nENSP00000307900 163 C R\nENSP00000353362 712 A T\n' +
				'ENSP00000261726 590 E K\nENSP00000303540 1741 C S\nENSP00000378323 92 H R\nENSP00000304592 154 S N\n' +
				'ENSP00000369325 127 H Y\nENSP00000339299 2945 T M\nENSP00000279593 461 C F\nENSP00000425236 199 K R\n'+
				'ENSP00000362396 190 R W\nENSP00000304226 206 G D\nENSP00000383049 109 E G\nENSP00000386312 393 R C\n' +
				'ENSP00000308725 120 D N\nENSP00000283256 853 R Q\nENSP00000362014 177 A P\nENSP00000374157 1154 R W\n'+
				'ENSP00000303540 1510 A E\nENSP00000278379 82 G R\nENSP00000262493 270 N H\nENSP00000362014 237 R W\n' +
				'ENSP00000229854 304 A V\nENSP00000362014 65 T N';


	var runPolyphenButton;

	function init() {
		runPolyphenButton = document.getElementById('runPolyPhen');		
		runPolyphenButton.addEventListener('click', runPolyphen);

		document.getElementById('sample-batch').addEventListener('click', populateSampleBatch);
		document.getElementById('epi4k-subs').addEventListener('click', populateEpi4kSubstitutions);	
	}

	function populateSampleBatch() {
		$(this).closest('div').find('textarea').html(sampleBatch);
	}

	function populateEpi4kSubstitutions() {
		$(this).closest('div').find('textarea').html(epi4kSubstitutions);
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

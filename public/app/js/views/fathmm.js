var Fathmm = (function (window, document) { 
	var epi4kSubstitutions ='ENSP00000283256 K1422E\nENSP00000352035 R581G\nENSP00000360608 Y668S\n' +
		'ENSP00000307288 D363H\nENSP00000362014 G359A\nENSP00000346534 G214D\nENSP00000414232 T292I\n' +
		'ENSP00000283256 R853Q\nENSP00000347733 R3728Q\nENSP00000354621 R115H\nENSP00000340930 L1054P\n' +
		'ENSP00000262493 F275S\nENSP00000362396 G544D\nENSP00000369325 G213E\nENSP00000362396 P335L\n' +
		'ENSP00000308725 N110D\nENSP00000352035 R144Q\nENSP00000441691 R246G\nENSP00000362396 R406H\n' +
		'ENSP00000245838 Y517C\nENSP00000270066 R18Q\nENSP00000362014 K206N\nENSP00000253727 R318C\n' +
		'ENSP00000386312 C931Y\nENSP00000346534 L875Q\nENSP00000307900 C163R\nENSP00000353362 A712T\n' +
		'ENSP00000261726 E590K\nENSP00000303540 C1741S\nENSP00000378323 H92R\nENSP00000304592 S154N\n' +
		'ENSP00000369325 H127Y\nENSP00000339299 T2945M\nENSP00000279593 C461F\nENSP00000425236 K199R\n' +
		'ENSP00000362396 R190W\nENSP00000304226 G206D\nENSP00000383049 E109G\nENSP00000386312 R393C\n' +
		'ENSP00000308725 D120N\nENSP00000283256 R853Q\nENSP00000362014 A177P\nENSP00000374157 R1154W\n' +
		'ENSP00000303540 A1510E\nENSP00000278379 G82R\nENSP00000262493 N270H\nENSP00000362014 R237W\n' +
		'ENSP00000229854 A304V\nENSP00000362014 T65N';

	var submitButton,
		formContainer,
		waitContainer,
		resultsContainer,
		algorithmSelector,
		inheritedOptions,
		predThreshold,
		networkData;

	function init(){
		submitButton = document.getElementById('submit-button');
		formContainer = $('#form-container');
		waitContainer = $('#wait-container');
		resultsContainer = $('#results-container');
		algorithmSelector = document.getElementById('algorithm');
		inheritedOptions = $('#InheritedOptions');
		predThreshold = document.getElementById('pred-threshold');

		submitButton.addEventListener('click', submit);

		document.getElementById('epi4k-subs').addEventListener('click', populateEpi4kSubstitutions);
		$(algorithm).on('change', updateForm).trigger('change');
	}

	function populateEpi4kSubstitutions() {
		$(this).closest('div').find('textarea').html(epi4kSubstitutions);
	}

	function updateForm() {
		switch(this.value) {
			case 'INHERITED':
				inheritedOptions.show();
				predThreshold.value = '-3.00';
				break;
			case 'UNWEIGHTED':
				predThreshold.value = '-1.50';
				break;	
			case 'CANCER':
				inheritedOptions.hide();
				predThreshold.value = '-0.75';
				break;
		}
	}

	function submit(e){
		e.preventDefault();
		submitButton.setAttribute('disabled', '');
		var formData = ScoreForm.GetFormData(),
			file = document.getElementById('file').files[0],
			textBox = document.getElementById('text-box').value;

		if (file) {
			formData.append('File', file);
		} else if (textBox) {
			formData.append('Genes', textBox);
		} else {
			Alert({text: 'No file was selected and no network provided', type: 'danger', layout: 'top-center'});
			submitButton.removeAttribute('disabled');
			return;
		}

		formData.append('Weighted', algorithm.value);
		formData.append('PredThreshold', predThreshold.value);
		if (algorithm.value !== 'Cancer') {
			formData.append('Phenotype', document.getElementById('Phenotype').value);
		}

		formContainer.collapse('hide');
		waitContainer.collapse('show');

		var xhr = new XMLHttpRequest();
		xhr.open('post', '/fathmm');
		xhr.onreadystatechange = callback;
		xhr.send(formData);
	}

	function callback(data) {
		if(this.readyState === 4) {
			if (this.status === 500) {
				waitContainer.collapse('hide');
				formContainer.collapse('show');
				Alert({text: 'There was an unexpected error. Please contact the web admin.', type: 'danger', layout: 'top-center'});
			} else {
				var data = JSON.parse(this.responseText);
				if(this.status === 200){
					initResults(data);
					waitContainer.collapse('hide');
					resultsContainer.collapse('show');
				} else {
					setTimeout(function(){
						waitContainer.collapse('hide');
						formContainer.collapse('show');
						Alert({text: data.message, type: 'danger', layout: 'top-center'});
					}, 300);
				}
			}
			submitButton.removeAttribute('disabled');
		}
	}

	var showNetwokButton,
		networkContainer,
		spinner,
		network,
		genes;

	function initResults(data) {
		showNetwokButton = document.getElementById('show-network');
		networkContainer = document.getElementById('cy-container');
		spinner = document.getElementsByClassName('spinnerContainer')[0];

		showNetwokButton.addEventListener('click', toggleNetwork);

		genes = data.bar.labels;

		var scatter,
			hotCount = 0,
			totalCount = 0;
		for (var i = data.scatter.length - 1; i >= 0; i--) {
			var scatter = data.scatter[i];
			if (scatter.name === 'hot') {
				hotCount = hotCount + scatter.data.length;
			}
			totalCount = totalCount + scatter.data.length;
		};
		var src = document.getElementById('summary');
		src.innerHTML = '<h3>In your set of mutations there were ' + hotCount 
			+ ' out of ' + totalCount + ' in the <i>hot zone</i></h3>';

		new BarChart('bars-chart', {
			score: data.score,
			data: data.bar
		}).render();

		renderSubsTable(data.score, data.table);

		new ScatterChart(
			'hotzone-scatter', 
			{
				score: data.score,
				data: data.scatter,
			},
			{
				xAxis: {
					title: 'FATHMM Z-Score',
					min: -10,
					max: 10
				}
			}
		).render();

		renderDomTable(data.domains);

		networkData = data.networkData;
	}

	function renderSubsTable(score, data){		
		document.getElementById('score-header').innerHTML = score;

		var tbdy=document.createElement('tbody'),
			tr,
			td;
		
		for(var i = 0; i < data.length; i++) {
			var mutation = data[i][3];
			var address = 'http://supfam3.cs.bris.ac.uk/oates/cgi-bin/archpic.cgi?genome=hs&amp;seqids='
				+ data[i][1]
				+ '&amp;mark_ruler='
				+ mutation.substring(1, mutation.length-1)
				+ '~'
				+ mutation
				+ '&external';
			
			tr = document.createElement('tr');
			for(var j = 0; j < data[i].length; j++) {
				td = document.createElement('td');
				td.appendChild(document.createTextNode(data[i][j]));
				if (j === 4) {
					var prediction = data[i][j];
					if (prediction === 'DAMAGING') {
						td.style.color = 'red';
					} else if (prediction === 'TOLERATED') {
						td.style.color = 'green';
					}
				}
				tr.appendChild(td);
			}

			var link = document.createElement('a');
			link.setAttribute('target', '_blank');
			link.setAttribute('href', address);
			link.setAttribute('name', 'show details');
			link.innerHTML = "details";
			
			td = document.createElement('td');
			td.appendChild(link);
			tr.appendChild(td);
			tbdy.appendChild(tr);	
		}

		var tbl = document.getElementById('results-table');
		tbl.removeChild(tbl.getElementsByTagName('tbody')[0]);
		tbl.appendChild(tbdy);

		tsorter.create('results-table');
	}

	function renderDomTable(table_data) {
		var tbdy=document.createElement('tbody'),
			tr,
			td;
		
		for(var i = 0; i < table_data.length; i++){
			tr = document.createElement('tr');
			for(var j = 0; j < table_data[i].length; j++){
				td = document.createElement('td');
				td.appendChild(document.createTextNode(table_data[i][j]));
				tr.appendChild(td);
			}			
			tbdy.appendChild(tr);			
		}

		var tbl  = document.getElementById('dom-table');
		tbl.removeChild(tbl.getElementsByTagName('tbody')[0]);
		tbl.appendChild(tbdy);

		tsorter.create('dom-table');
	}

	function toggleNetwork() {
		if (networkContainer.style.display === 'none') {
			if (!network) {
				network = new Network('#cy-container', networkData);
				network.render();
			}
			networkContainer.style.display = 'block';
			showNetwokButton.innerText = 'Hide interaction network';
		} else {
			networkContainer.style.display = 'none';
			showNetwokButton.innerText = 'Show interaction network';
		}
	}

	return {
		Init: init
	};
})(window, document);

Fathmm.Init();
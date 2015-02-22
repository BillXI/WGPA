(function (document) { 
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

	var formContainer = $('#form'),
		resultsContainer = $('#results'),
		submitButton = document.getElementById('submit_subs'),
		algorithm = document.getElementById('Algorithm'),
		inheritedOptions = $('#InheritedOptions'),
		predThreshold = document.getElementById('PredThreshold');

	submitButton.addEventListener('click', submit);

	document.getElementById('epi4k-subs').addEventListener('click', populateEpi4kSubstitutions);
	$(algorithm).on('change', updateForm).trigger('change');

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
		resultsContainer.collapse('show');

		var xhr = new XMLHttpRequest();
		xhr.open('post', '/substitutions');
		xhr.onreadystatechange = callback;
		xhr.send(formData);
	}

	function callback(data) {
		if(this.readyState === 4) {
			if (this.status === 500) {
				formContainer.collapse('show');
				resultsContainer.collapse('hide');
				Alert({text: 'There was an unexpected error. Please contact the web admin.', type: 'danger', layout: 'top-center'});
			} else {
				var data = JSON.parse(this.responseText);
				if(this.status === 200){
					genes = data.genes;
					renderResults(data);
					$('#wait-container').collapse('hide');
					$('#results-container').collapse('show');
				} else {
					formContainer.collapse('show');
					resultsContainer.collapse('hide');
					Alert({text: data.message, type: 'danger', layout: 'top-center'});
				}
			}
			submitButton.removeAttribute('disabled');
		}
	}

	function renderResults(data) {
		var src = document.getElementById("genes_box_results");
		src.innerHTML = '<h3>In your set of mutations there were '
			+ data.metadata.hot_count 
			+ ' out of ' 
			+ data.metadata.all_count 
			+ ' in the <i>hot zone</i></h3>';

		renderIntolerance(data.metadata.score, data.intolerance);
		renderSubsTable(data.metadata.score, data.table);
		renderScatter(data.metadata.score, data.scatter);
		renderDomTable(data);
	}

	function renderIntolerance(score, data) {
		new Highcharts.Chart({
			chart: {
				type: 'column',
				renderTo: 'IntoleranceChart'
			},
	        title: {
	            text: score + ' intolerance'
	        },
	        subtitle: {
	            text: 'Percentile'
	        },
	        xAxis: {
	            categories: data.labels
	        },
	        yAxis: {
	            min: 0,
	            max: 100,
	            tickInterval: 10,
	            title: {
	                text: 'Percentile'
	            }
	        },
	        plotOptions: {
	            column: {
	                pointPadding: 00,
	                borderWidth: 0
	            }
	        },
	        series: [{
	        	name: 'Genes',
	            data: data.vals
	        }]
	    });
	    // Horrible hack necessary to display the chart properly
		setTimeout(function () {
			$(window).trigger('resize');
		}, 0);
	}

	function renderSubsTable(score, data){		
		document.getElementById('ScoreHeader').innerHTML = score + 'Percentile';

		var tbdy=document.createElement('tbody'),
			tr,
			td;
		
		for(var i = 0; i < data.length; i++) {
			var mutation = data[i][2];
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

		var tbl = document.getElementById('subs_table_out');
		tbl.removeChild(tbl.lastChild);
		tbl.appendChild(tbdy);

		var tableSorter1 = new TSorter;
		tableSorter1.init('subs_table_out');
	}

	function renderDomTable(table_data){
		var tbdy=document.createElement('tbody'),
			tr,
			td;
		
		for(var i = 0; i < table_data.domains.length; i++){
			tr = document.createElement('tr');
			for(var j = 0; j < table_data.domains[i].length; j++){
				td = document.createElement('td');
				td.appendChild(document.createTextNode(table_data.domains[i][j]));
				tr.appendChild(td);
			}			
			tbdy.appendChild(tr);			
		}

		var tbl  = document.getElementById('dom_table_out');
		tbl.removeChild(tbl.lastChild);
		tbl.appendChild(tbdy);

		var tableSorter1 = new TSorter;
		tableSorter1.init('dom_table_out');
	}

	function renderScatter(score, data) {
		new Highcharts.Chart({
			chart: {
				type: 'scatter',
				zoomType: 'xy',
				renderTo: 'hotzone'
			},
			colors: [
				'#2f7ed8', 
				'#0d233a', 
				'#8bbc21', 
				'#910000', 
				'#1aadce', 
				'#492970',
				'#f28f43', 
				'#77a1e5', 
				'#c42525', 
				'#a6c96a'
			],
			title: {
				text: 'Are the mutatations in the hotzone?'
			},
			xAxis: {
				title: {
					enabled: true,
					text: 'FATHMM Z-Score' 
				},
				startOnTick: true,
				endOnTick: true,
				showLastLabel: true,
				min: -10, 
				max: 10
			},
			yAxis: {
				min: 0, 
				max: 100,
				title: {
					text: score + ' Percentile'
				}
			},
			legend: {
				layout: 'vertical',
				align: 'left',
				verticalAlign: 'bottom',
				floating: true,
				backgroundColor: '#FFFFFF',
				borderWidth: 1
			},
			plotOptions: {
				scatter: {
					marker: {
						radius: 3,
						states: {
							hover: {
								enabled: true,
								lineColor: 'rgb(100,100,100)'
							}
						}
					},
					states: {
						hover: {
							marker: {
								enabled: false
							}
						}
					},
					tooltip: {
						headerFormat: '<b>{series.name}</b><br>',
						pointFormat: '{point.x} cm, {point.y} kg'
					}
				}
			},
			tooltip:{
				formatter:function(){
					return this.point.info;
				}
			},
			credits: {
				enabled: false
			},
			series: data
		});
		// Horrible hack necessary to display the chart properly
		setTimeout(function () {
			$(window).trigger('resize');
		}, 0);
	}

	var showNetwokButton = document.getElementById('show-network'),
		networkContainer = document.getElementById('cy-container'),
		spinner = document.getElementsByClassName('spinnerContainer')[0],
		genes,
		network;
	showNetwokButton.addEventListener('click', submitNetwork);

	function submitNetwork() {
		if (networkContainer.style.display === 'block') {
			hideNetwork();
		} else {
			if (network) {
				showNetwork();
			}  else {
				showNetwokButton.setAttribute('disabled', '');
				spinner.style.display = 'block';
				var networkRequest = new XMLHttpRequest();
				var url = window.location.href,
					lastIndex = url.length - 1;
				if (url.substring(lastIndex) === '/') {
					url = url.substring(0, lastIndex);
				}

				var formData = ScoreForm.GetFormData();
				formData.append('Genes', genes); 

				networkRequest.open('post', url + '/network', true);
				networkRequest.onreadystatechange = function () {
					if(this.readyState === 4) {
						if (this.status === 500) {
							Alert({text: 'There was an unexpected error. Please contact the web admin.', type: 'danger', layout: 'top-center'});
						} else {
							var data = JSON.parse(this.responseText);
							if(this.status === 200) {
								spinner.style.display = 'none';
								network = new Network('#cy-container', data);
								network.render();
								showNetwork();
							} else {
								Alert({text: data.message, type: 'danger', layout: 'top-center'});
							}
						}
						showNetwokButton.removeAttribute('disabled');
					}
				};
				networkRequest.send(formData);
			}
		}
	}

	function showNetwork () {
		networkContainer.style.display = 'block';
		showNetwokButton.innerText = 'Hide interaction network';
	}

	function hideNetwork (){
		networkContainer.style.display = 'none';
		showNetwokButton.innerText = 'Show interaction network';
	}
})(document);
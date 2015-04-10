var PolyphenResults = (function (document) { 
	var genes,
		network;

	function init(score, data) {
		data.score = score;
		genes = data.bar.labels;
		renderResults(data);
	}

	function renderResults(data) {
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
		src.innerHTML = 'In your set of mutations there were ' + hotCount 
			+ ' out of ' + totalCount + ' in the <i>hot zone</i>';

		new BarChart('IntoleranceChart', {
			score: data.score,
			data: data.bar
		}).render();

		renderSubsTable(data.score, data.table);
		
		new ScatterChart(
			'hotzone-scatter', 
			{
				score: data.score,
				data: data.scatter
			},
			{
				xAxis: {
					title: 'Polyphen-2 Percentile',
					min: 0,
					max: 100
				}
			}
		).render();
	}

	function renderSubsTable(score, data){
		document.getElementById('ScoreHeader').innerHTML = score;

		var tbdy=document.createElement('tbody'),
			tr,
			td;

		if (!data.length) {
			tr = document.createElement('tr');
			td = document.createElement('td');
			td.colSpan = 7;
			td.appendChild(document.createTextNode('No results to show.'));
			tbdy.appendChild(tr);
		}
		
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
				var cell = data[i][j];
				td.appendChild(document.createTextNode(cell));
				if (j === 4) {
					if (cell == 'probably damaging') {
						td.style.color = 'red';
					} else if (cell == 'possibly damaging') {
						td.style.color = 'orange';
					} else {
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
				networkRequest.send(JSON.stringify({ genes: genes }));
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

	return {
		Init: init
	}
})(document);
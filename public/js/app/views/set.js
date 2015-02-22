var Set = (function (document) {
	var showNetwokButton = document.getElementById('show-network'),
		networkContainer = document.getElementById('cy-container'),
		spinner = document.getElementsByClassName('spinnerContainer')[0],
		network;
	showNetwokButton.addEventListener('click', onClick);

	function onClick() {
		if (networkContainer.style.display === 'block') {
			hideNetwork();
		} else {
			if (network) {
				showNetwork();
			}  else {
				showNetwokButton.setAttribute('disabled', '');
				spinner.style.display = 'block';
				var table = document.getElementsByTagName('table')[1].querySelectorAll('td:first-child');
				var genes = [];
				for (var i = table.length - 1; i >= 0; i--) {
					genes.push(table[i].innerText);
				}
				var networkRequest = new XMLHttpRequest();
				networkRequest.open('post', 'network', true);
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
				networkRequest.send(JSON.stringify({genes: genes}));
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
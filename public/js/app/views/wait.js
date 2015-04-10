Wait = (function (window, document) {
	var analysisURL,
		analysisId,
		pollingTime,
		header,
		message,
		bookMarkButton,
		xhr;

	function init(url, id, polling) {
		analysisURL = url;
		analysisId = id;
		pollingTime = 1000 * (polling || 30);
		header = document.getElementById('Header');
		message = document.getElementById('Message');
		bookMarkButton = document.getElementById('AddBookMark');
		bookMarkButton.addEventListener('click', addBookMark);

		checkStatus();
	}

	function checkStatus () {	
		xhr = new XMLHttpRequest();
		xhr.open('get', '/' + analysisURL + '/' + analysisId, true);
		xhr.setRequestHeader('Accept', 'application/json');
		xhr.onreadystatechange = updateUI;
		xhr.send();
	}

	function updateUI (){
		if(this.readyState === 4) {
			if(this.status === 200) {
				if (this.status === 500) {
					Alert({text: 'There was an unexpected error. Please contact the web admin.', type: 'danger', layout: 'top-center'});
				} else {
					var data = JSON.parse(this.responseText);
					switch (data.status) {
						case 'Completed':
						case 'Error':
							window.location.reload();
							break;
						default:
							header.innerHTML = data.header;
							message.innerHTML = data.message;
							window.setTimeout(checkStatus, pollingTime);
							break;
					}
				}
			}
		}
	}

	return {
		Init: init
	}
})(window, document);
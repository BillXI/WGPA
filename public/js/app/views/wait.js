Wait = (function (window, document) {
	var analysisId,
		header,
		message,
		bookMarkButtons,
		xhr;

	function init(id) {
		analysisId = +id;
		header = document.getElementById('Header');
		message = document.getElementById('Message');
		bookMarkButtons = document.getElementById('AddBookMark');
		bookMarkButtons.addEventListener('click', addBookMark);

		checkStatus();
	}

	function checkStatus () {	
		xhr = new XMLHttpRequest();
		xhr.open('get', '/enrichment/' + analysisId, true);
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
							window.setTimeout(checkStatus, 30000);
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
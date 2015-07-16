(function () {
	function alert(options) {
		var html = '<div class="alert alert-' + options.type + ' alert-' +   options.layout;

		// if (options.dismissible) {
		// 	html += ' alert-dismissible';
		// }
		html += '" role="alert">';
		// if (options.dismissible) {
		// 	html += '<button type="button" class="close" data-dismiss="alert"><span aria-hidden="true">&times;</span><span class="sr-only">Close</span></button>';
		// }

		html += options.text + '</div>';

		var alert = $('#alert-container').append(html).children().last();


		alert.on('click', function () {
			dismiss(alert);
		});

		if (!options.dismissible && options.timeout ===  undefined) {
			options.timeout =  1500;
		}

		if(options.timeout) {
			setTimeout(function () {
				dismiss(alert);
			}, options.timeout);
		}
	}

	function dismiss(alert) {
		alert.slideUp(500, function () {
			alert.remove();
		})
	}

	window.Alert = alert;
})();
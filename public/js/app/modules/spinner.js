var Spinner = (function () {

	var spinnerContent = 	
		'<div class="spinner1"></div>' +
		'<div class="spinner2"></div>' +
		'<div class="spinner3"></div>' +
		'<div class="spinner4"></div>' +
		'<div class="spinner5"></div>' +
		'<div class="spinner6"></div>' +
		'<div class="spinner7"></div>' +
		'<div class="spinner8"></div>';

	function init () {
		$('div.spinner').html(spinnerContent);
	}
	
	return {
		Init: init
	};
})();

Spinner.Init();
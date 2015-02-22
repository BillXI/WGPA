function addBookMark() {
	if (window.sidebar && window.sidebar.addPanel) { // Mozilla Firefox Bookmark
		window.sidebar.addPanel(document.title,window.location.href,'');
	} else if(window.external && ('AddFavorite' in window.external)) { // IE Favorite
		window.external.AddFavorite(location.href,document.title); 
	} else if(window.opera && window.print) { // Opera Hotlist
		this.title=document.title;
			return true;
	} else { // webkit - safari/chrome
		noty({text: 'Press ' + (navigator.userAgent.toLowerCase().indexOf('mac') != - 1 ? 'Command/Cmd' : 'CTRL') + ' + D to bookmark this page.'});
	}
}

function initializeSelect2 () {
	var selects = $('select'),
		select;

	for (var i = selects.length - 1; i >= 0; i--) {
		select = selects.eq(i);
		select.select2({
			placeholder: select.data('select2-placeholder'),
			dropdownCssClass : select.data('select2-dropdowncssclass'),
			width: select.data('select2-width'),
			minimumResultsForSearch: 10
		});
	};
}
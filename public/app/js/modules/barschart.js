(function() {
	function barChart (element, model) {
		this.element = element;
		this.model = model;
	}

	barChart.prototype.render = function() {
		if (!this.model.data.vals.length) {
			return;
		}
		new Highcharts.Chart({
			chart: {
				type: 'column',
				renderTo: this.element
			},
	        title: {
	            text: this.model.score + ' intolerance'
	        },
	        subtitle: {
	            text: 'Percentile'
	        },
	        xAxis: {
	            categories: this.model.data.labels
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
	            data: this.model.data.vals
	        }],
			credits: {
				enabled: false
			}
	    });
	    // Horrible hack necessary to display the chart properly
		setTimeout(function () {
			$(window).trigger('resize');
		}, 0);
	}

	window.BarChart = barChart;
})();
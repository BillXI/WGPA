(function() {
	function scatterChart (element, model, options) {
		this.element = element;
		this.model = model;
		this.options = options || {};
	}

	scatterChart.prototype.render = function() {
		new Highcharts.Chart({
			chart: {
				type: 'scatter',
				zoomType: 'xy',
				renderTo: this.element
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
				text: 'Hot-zone analysis of mutations'
			},
			xAxis: {
				title: {
					enabled: true,
					text: this.options.xAxis.title
				},
				startOnTick: true,
				endOnTick: true,
				showLastLabel: true,
				min: this.options.xAxis.min, 
				max: this.options.xAxis.max
			},
			yAxis: {
				min: 0, 
				max: 100,
				title: {
					text: this.model.score + ' Percentile'
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
			series: this.model.data
		});
		// Horrible hack necessary to display the chart properly
		setTimeout(function () {
			$(window).trigger('resize');
		}, 0);
	}

	window.ScatterChart = scatterChart;
})();

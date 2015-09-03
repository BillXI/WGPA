(function () { 
	function network (element, model) {
		this.element = element;
		this.$element = $(element);
		this.model = model;
	}

	network.prototype.render = function () {
		if (this.model.Network) {
			this.$element.append(
				'<div class="col-lg-12 vmargin25">' +
					'<p><span class="pull-left">Intolerant</span><span class="pull-right">Tolerant</span></p>' +
					'<div id="cy-colors"></div>' +
					'<p class="text-center">Tap a node to highlight its neighbourhood</p>' +
					((this.model.Network.Nodes[0] || [{}]).data.borderColor 
						? '<p class="text-center">The inner color represents the intolerance and the border color the score given by the anlysis.</p>' 
						: '' ) +
					(!window.chrome 
						? '<p class="text-center" style="color: red;">There are issues displaying the network with several browsers. If you\'re having trouble try downloading the latest version of <a href="http://www.google.com/chrome/" target="_blank">chrome</a></p>'
						: '') +
				'</div>' +
				'<div class="col-lg-12">' +
					'<div id="cy"></div></div>' +
				'</div>'
			);
			showNetwork(this.$element.find('#cy'), this.model.Network);
		}

		if (this.model.DegreePlot) {
			this.$element.append(
				'<div class="col-lg-12">' +
					'<div id="degree-plot"></div>' +
				'</div>'
			);
			showDegreePlot(this.$element.find('#degree-plot'), this.model.DegreePlot);
		}
	}

	network.prototype.destroy = function () {
		this.element.innerHTML = '';
	}

	network.prototype.setElement = function (element) {
		this.element.innerHTML = '';
		this.element = element;
	}

	network.prototype.setModel = function (model) {
		this.element.innerHTML = '';
		this.model = model;
	}

	function showNetwork(container, model) {
		container.cytoscape({
			style: cytoscape.stylesheet()
				.selector('node')
					.css({
						'content': 'data(name)',
						'text-valign': 'center',
						'color': 'white',
						'background-color': 'data(backgroundColor)',
						'text-outline-width': 2,
						'text-outline-color': '#888'
					})
				.selector('node[borderColor]')
					.css({
						'border-width': '5px',
						'border-color': 'data(borderColor)'
					})
				.selector('edge')
					.css({
						'target-arrow-shape': 'triangle'
					})
				.selector(':selected')
					.css({
						'background-color': 'black',
						'line-color': 'black',
						'target-arrow-color': 'black',
						'source-arrow-color': 'black'
					})
				.selector('.faded')
					.css({
						'opacity': 0.25,
						'text-opacity': 0
					}),
			
			elements: {
				nodes: model.Nodes,
				edges: model.Edges
			},
			
			layout: {
				name: model.Edges.length < 20 ? 'springy' : 'circle',
			},
			
			ready: function () {
				var that = this;

				container.cytoscapePanzoom();
				container.cytoscapeNavigator();
				
				// giddy up...
				
				this.elements().unselectify();
				
				this.on('tap', 'node', function(e){
					var node = e.cyTarget; 
					var neighborhood = node.neighborhood().add(node);
					
					that.elements().addClass('faded');
					neighborhood.removeClass('faded');
				});
				
				this.on('tap', function(e){
					if( e.cyTarget === that ){
						that.elements().removeClass('faded');
					}
				});

				window.onrezise = function () {
					that.layout();
				};
			}
		});
	}

	function showDegreePlot(container, model) {
		if (!model.Series.length) {
			// TODO Remove gap under network
			return;
		}
		container.highcharts({
			chart: {
				type: 'scatter',
				zoomType: 'xy'
			},
			title: {
				text: 'Node degree in the network vs ' + model.Score + ' intolerance'
			},
			subtitle: {
				text: ''
			},
			xAxis: {
				title: {
					text: model.Score + ' (Percentile) <br> Most intolerant genes are closer to 0 and most tolerant to 100. You can zoom in by clicking and dragging over a specific area.'
				},
				startOnTick: true,
				endOnTick: true,
				showLastLabel: true,
				min: 0, 
				max: 100
			},
			yAxis: {
				title: {
					text: 'Node degree'
				},
				min: 0
			},
			legend: {
				enabled: true
			},
			plotOptions: {
				scatter: {
					marker: {
						symbol: 'circle',
						radius: 5,
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
						pointFormat: model.Score + ': {point.x} <br> Degree: {point.y}'
					}
				}
			},
			credits: {
				enabled: false
			},
			series: model.Series
		});
		// Horrible hack necessary to display the chart properly
		setTimeout(function () {
			$(window).trigger('resize');
		}, 0);
	}

	window.Network =  network;
})();

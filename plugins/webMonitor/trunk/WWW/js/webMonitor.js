(function($) {
	$(function() {
		$('abbr, [rel=tooltip]').tooltip()
		
		var socket;
		if (WebSocket && CONFIG.socketPort) {
			socket = new WebSocket('ws://' + CONFIG.socketHost + ':' + CONFIG.socketPort + '/');

			socket.onclose = function() {
				console.log('Socket closed.');
			}

			socket.onerror = function() {
				// TODO meaningful error message
			}

			socket.onmessage = function(event) {
				message = JSON.parse(event.data);

				switch (message.type) {
					case 'values':
						$.each(message.data, function(key, value) {
							var percent = (value * 100 / $('.value_' + key + '_max').first().text()).toFixed(2) + '%';
							$('.value_' + key).text(value);
							$('.progress_' + key).attr({'data-original-title': percent});
							$('.progress_' + key + ' .bar').css({width: percent});

							switch (key) {
								case 'field_image':
									$('#mapa').css({'background-image': 'url("' + value + '")'});
								break;
							}
						});
					break;
					default:
						//console.log('Unknown message', message);
				}
			}
		}
	});
})(jQuery);

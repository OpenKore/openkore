(function($) {
	$(function() {
		var messageHTML = function(html, domain) {
			$('.log').each(function() {
				var domains = $(this).data('domains')
				if (domains && $.inArray(domain, domains.split(' ')) == -1) return;

				$(this).stop()
				// autoscroll only if already are at bottom
				var scrolled = $(this).scrollTop() > $(this).prop('scrollHeight') - $(this).prop('offsetHeight') * 1.5

				$(this).append(html)

				if (scrolled) {
					$(this).animate({scrollTop: $(this).prop('scrollHeight')}, 'fast')
				}
			})
		}

		var message = function(text, domain, cssClass) {
			var line = $('<span/>')
			line.addClass(cssClass)
			line.text(text)
			messageHTML(line, domain)
		}

		// initial log scrolling
		$('.log').each(function() {
			$(this).scrollTop($(this).prop('scrollHeight'))
		})

		$('abbr, [rel=tooltip]').tooltip()

		$('.map').each(function() {
			var c = $(this)[0].getContext('2d')
			c.fillStyle = '#ff0000'
			c.fillRect(150, 150, 5, 3)
		})

		var socketAddr, socket;
		if (typeof WebSocket !== 'undefined' && CONFIG.socketPort) {
			socketAddr = CONFIG.socketHost + ':' + CONFIG.socketPort
			message("Connecting (" + socketAddr + ")... ", 'web', 'msg_web')

			socket = new WebSocket('ws://' + socketAddr + '/');

			socket.onopen = function() {
				console.log('Socket opened.');
				message("connected\n", 'web', 'msg_web')
				
				$("#button_send").removeAttr("disabled");
			}

			socket.onclose = function() {
				console.log('Socket closed.');
				message("Disconnecting (" + socketAddr + ")... disconnected\n", 'web', 'msg_web')
				message("Reload to get new messages.\n", 'web', 'msg_web')
				
				$("#button_send").attr("disabled", "disabled");
			}

			socket.onerror = function(e) {
				console.log('Socket error.', e);
				messageHTML('<br/>', 'web');
			}

			socket.onmessage = function(event) {
				packet = JSON.parse(event.data);

				switch (packet.type) {
					case 'console':
						message(packet.data.message, packet.data.domain, packet.data.class)
					break;
					case 'values':
						$.each(packet.data, function(key, value) {
							$('.value_' + key).text(value);
							var $progress = $('.progress_' + key);
							if ($progress.length) {
								var percent = (value * 100 / $('.value_' + key + '_max').first().text()).toFixed(2) + '%';
								$progress.attr({'data-original-title': percent});
								$progress.find('.bar').css({width: percent});
							}

							switch (key) {
								case 'field_image':
									$('#map').css({'background-image': 'url("' + value + '")'});
								break;
							}
						});
					break;
					default:
						//console.log('Unknown message', message);
				}
			}
		} else {
			message("Reload to get new messages.\n", 'web', 'msg_web')
		}
	});
})(jQuery);

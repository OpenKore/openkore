#########################################################################
#  OpenKore - Ragnarok Online Assistent
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################
##
# MODULE DESCRIPTION: Object for obtaining web server request info and sending response messages
#
# This is the object you use for obtaining information about a request, and to reply to a request.
# It has a PHP-like interface.
#
# You should also read <a href="http://www.w3.org/Protocols/rfc2616/rfc2616.html">the HTTP specification</a>.
package Base::WebServer::Process;

use strict;
use IO::Socket::INET;
use Encode;
use Utils qw(urldecode);

# Internal function; do not use directly!
sub new {
	my ($class, $socket, $query, $headers) = @_;
	my $self = {
		socket => $socket,
		query => $query,
		headers => $headers || {},
		buffer => '',
		outHeaders => {},
		outHeadersLC => {}
	};
	bless $self, $class;

	$self->{file} = $query;
	$self->{file} =~ s/\?.*//;

	my $vars = $query;
	my %GET;
	$vars =~ s/.*?\?//;
	foreach my $entry (split /&/, $vars) {
		my ($key, $value) = split /=/, $entry, 2;
		$key = urldecode($key);
		$GET{$key} = urldecode($value);
	}
	$self->{GET} = \%GET;

	$self->status(200, "OK");
	$self->header("Content-Type", "text/html; charset=utf-8");
	$self->header("Date", Base::WebServer::_dateString(time()));
	$self->header("Server", "OpenKore Web Server");
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	$self->_sendHeaders;

	if ($self->{socket} && $self->{socket}->connected) {
		if ($self->{chunkedEncoding}) {
			# Finish sending chunked encoded data.
			eval {
				$self->{socket}->send("0\x0D\x0A\x0D\x0A", 0);
				$self->{socket}->flush;
			};
			undef $@;
		}

		my $key = $self->{outHeadersLC}{connection};
		if ($key && $self->{outHeaders}{$key} eq 'close') {
			$self->{socket}->close;
		}
	}
}

##
# void $BaseWebServerProcess->shortResponse(String content)
# content: the data to send to the web browser.
# Requires: defined($content)
#
# Send data (usually HTML) to the web server. This function also automatically sets the HTTP Content-Length
# header for you, allowing the browser to keep the HTTP connection persistent, and to display download
# progress information.
#
# <b>Warning:</b> after calling this function, you shouldn't call any of the other functions in this class
# which send data to the web server. It is undefined what will happen if you do so.
#
# This function should only be used for small amount of data, because the entire content has to be in memory.
# For larger amounts of data, you should send small chunks of data incrementally using $BaseWebServerProcess->print().
#
# The default status message is "200 OK". The default Content-Type is "text/html; charset=utf-8".
sub shortResponse {
	my ($self, $content) = @_;
	$self->header("Content-Length", length($content));
	$self->print($content);
}

##
# void $BaseWebServerProcess->status(int statusCode, String statusMsg)
# statusCode: a HTTP status code.
# statusMsg: the associated HTTP status message.
# Requires:
#    defined($statusMsg)  <br>
#    $BaseWebServerProcess->print() or $BaseWebServerProcess->shortResponse() must not have been called before.
#
# Schedule a HTTP response status message for sending. See <a href="http://www.w3.org/Protocols/rfc2616/rfc2616.html">the
# HTTP specification</a> (section 10) for a list of codes. This status code will be sent when the connection to
# the web browser is closed, or when you first call $BaseWebServerProcess->print() or $BaseWebServerProcess->shortResponse().
# If you have sent a HTTP status before, the previous status is overwritten by this one.
#
# See also: $BaseWebServerProcess->header()
#
# Example:
# $BaseWebServerProcess->status(404, "File Not Found");
sub status {
	my ($self, $statusCode, $statusMsg) = @_;

	if ($self->{sentHeaders}) {
		warn "Cannot send HTTP response status - content already sent";
	} else {
		$self->{outStatus} = "HTTP/1.1 $statusCode $statusMsg";
	}
}

##
# void $BaseWebServerProcess->header(String name, String value)
# name: the name of the header.
# value: the value of the header.
# Requires:
#    defined(name)      <br>
#    defined(value)     <br>
#    $BaseWebServerProcess->print() or $BaseWebServerProcess->shortResponse() must not have been called before.
#
# Schedule a HTTP header for sending. This header will be sent when the connection to the web browser is closed,
# or when you first call $BaseWebServerProcess->print() or $BaseWebServerProcess->shortResponse(). If you have sent a header with
# the same name before, the previous header is overwritten by this one.
#
# For sending HTTP status messages, you should use $BaseWebServerProcess->status() instead.
#
# Example:
# $BaseWebServerProcess->header("WWW-Authenticate", "Negotiate");
# $BaseWebServerProcess->header("WWW-Authenticate", "NTLM");
sub header {
	my ($self, $name, $value) = @_;

	if ($self->{sentHeaders}) {
		warn "Cannot send HTTP header - content already sent";

	} else {
		# outHeadersLC maps lowercase key names to actual key names.
		# This prevents us from sending duplicate header keys.
		my $actualKey = $self->{outHeadersLC}{lc($name)} || $name;
		$self->{outHeaders}{$actualKey} = $value;
		$self->{outHeadersLC}{lc($actualKey)} = $actualKey;
	}
}

##
# void $BaseWebServerProcess->print(String content)
# content: the content to print.
# Requires: defined($content)
#
# Output a string to the web browser. Any scheduled headers and status message will be sent first.
# So after calling this function, you cannot send headers or a status message anymore.
#
# The default status message is "200 OK". The default Content-Type is "text/html; charset=utf-8".
#
# Should should send the Content-Length header (see HTTP specification) before calling this function,
# if possible. That header allows the web browser to keep persistent connections to the server,
# and to display download progress.
sub print {
	my $self = shift;

	if (!$self->{sentHeaders}) {
		# This is the first time print is called, and we haven't sent
		# headers yet, so do so.

		# The client specifically requested that it doesn't
		# want a persistent connection.
		if ($self->{headers}{connection} eq 'close') {
			$self->header("Connection", "close");
		}

		# We don't know the content length, so send in chuncked
		# encoding.
		if (!$self->{outHeadersLC}{'content-length'}) {
			$self->{chunkedEncoding} = 1;
			$self->header("Transfer-Encoding", "chunked");
		}

		$self->_sendHeaders;
	}

	my $data = $_[0];
	if (Encode::is_utf8($data)) {
		Encode::_utf8_off($data);
	}

	eval {
		if ($self->{chunkedEncoding}) {
			$self->{socket}->send(_encodeChunk($data));
		} else {
			$self->{socket}->send($data);
		}
		$self->{socket}->flush;
	};
	undef $@;
}

##
# String $BaseWebServerProcess->file()
# Ensures: defined(result)
#
# Returns the name of the file that the web browser requested.
# The return value does not include the host name and does not include everythign after '?', so it will be something like "/foo/bar.html".
sub file {
	my ($self) = @_;
	return $self->{file};
}

##
# Hash<Bytes>* $BaseWebServerProcess->GET()
# Returns: a reference to a hash.
#
# Returns a reference to a hash, which contains variables provided via
# the URL query string.
sub GET {
	return $_[0]->{GET};
}

##
# String $BaseWebServerProcess->clientHeader(String name)
# name: the name of the header you want to lookup.
# Returns: the value of the header, or undef if the browser didn't send that header.
#
# Lookup the value of a header the browser sent you.
sub clientHeader {
	my ($self, $name) = @_;
	return $self->{headers}{lc($name)};
}

# Send a HTTP error and disconnect the client.
sub _killClient {
	my ($self, $errorID, $errorMsg) = @_;
	if (!$self->{sentHeaders}) {
		$self->status($errorID, $errorMsg);
		$self->print("<h1>HTTP $errorID - $errorMsg</h1>\n");
		$self->{socket}->close if ($self->{socket} && $self->{socket}->connected);
	}
}

sub _sendHeaders {
	my ($self) = @_;
	return if ($self->{sentHeaders});

	my $text = "$self->{outStatus}\r\n";
	foreach my $key (keys %{$self->{outHeaders}}) {
		$text .= "$key: $self->{outHeaders}{$key}\r\n";
	}
	$text .= "\r\n";

	#print "Response:\n$text";

	eval {
		$self->{socket}->send($text);
		$self->{socket}->flush;
	};
	undef $@;
	$self->{sentHeaders} = 1;
}

# Encode a string using HTTP chunked encoding.
sub _encodeChunk {
	return sprintf("%X", length($_[0])) . "\x0D\x0A$_[0]\x0D\x0A";
}

1;

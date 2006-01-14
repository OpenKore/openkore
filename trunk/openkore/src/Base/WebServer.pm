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
# MODULE DESCRIPTION: Basic implementation of a HTTP 1.1 server
#
# <b>Derived from Base::Server.pm</b>
#
# This class implements a basic HTTP 1.1 server. It is probably not entirely
# RFC 2616-compliant, but it works well, especially with modern browsers.
# This implementation can be easily integrated into Perl applications.
# Persistent connections and pipelining are supported. HTTP 1.0 and 0.9 are
# <i>not</i> supported.
#
# You are supposed to create a child class of this class, and override the
# request() function. That is the function in which you handle all HTTP requests.
# See $webserver->request().
#
# <h3>Example</h3>
# First, create a child class derived from Base::WebServer (MyWebServer.pm):
# <pre class="example">
# package MyWebServer;
#
# use strict;
# use Base::WebServer;
# use base qw(Base::WebServer);
#
# sub request {
#     my ($self, $process) = @_;
#
#     if ($process->file eq '/') {
#         $process->shortResponse("<b>Hello browser.</b> You requested the toplevel file.");
#
#     } elsif ($process->file eq '/random.txt') {
#         $process->header("Content-Type", "text/plain");
#         for (my $i = 0; $i < 100; $i++) {
#             $process->print(rand() . "\n");
#         }
#
#     } else {
#         $process->status(404, "File Not Found");
#         $process->shortResponse("<h1>File " . $process->file . " not found.</h1>");
#     }
# }
#
# 1;
# </pre>
#
# In the main script, you write:
# <pre class="example">
# use strict;
# use MyWebServer;
# use Time::HiRes qw(sleep);
#
# my $webserver = new MyWebServer(1025);
# while (1) {
#     $webserver->iterate;
#     sleep 0.01;
# }
# </pre>
# You can test the web server by going to http://localhost:1025/
package Base::WebServer;

use strict;
use Time::HiRes qw(time);
use Base::Server;
use base qw(Base::Server);
use Base::WebServer::Process;

# Maximum size of a HTTP request header.
use constant MAX_REQUEST_LEN  => 1024 * 32;


##
# Base::WebServer Base::WebServer->new([int port, String bind])
# port: the port to bind the server socket to. If unspecified, the first available port (as returned by the operating system) will be used.
# bind: the IP address to bind the server socket to. If unspecified, the socket will be bound to "localhost". Specify "0.0.0.0" to not bind to any address.
#
# Create a new Base::WebServer object at the specified port and IP address.


# struct HTTPState {
#     Bytes requestData;
#     Bytes request;
#     int time;
# }

sub onClientData {
	my ($self, $client, $data, $index) = @_;
	my $state; # Type: HTTPState

	# Retrieve client's state information
	if (!$client->{http}) {
		# This is the first time the client connected.
		$client->{http} = $state = {};
		$state->{requestData} = '';
		$state->{request} = '';
	} else {
		$state = $client->{http};
	}

	$state->{time} = time;

	# Buffer data until at least one entire HTTP request header has been received.
	$state->{requestData} .= $data;
	# If the request is unusually long, disconnect the client.
	if (length($state->{requestData} > MAX_REQUEST_LEN)) {
		$self->rejectClient($client, 413, "Request Entity Too Large");
		return;
	}

	# Extract the first request from the data and process it.
	# We do this because clients may pipeline requests.
	while (($state->{request} = _getFirstRequest($state)) ne '') {
		$self->_processRequest($client);
	}
}

##
# abstract void $BaseWebServer->request(Base::WebServer::Process process)
# process: the process object associated with this request. This object contains information about the current request (like the file the client requested, or the HTTP headers sent byt he client), and allows you to send responses to the client (with a PHP-like API).
# Requires: defined($process)
#
# This virtual method will be called every time a web browser requests
# a page from this web server. You should override this function in a
# child class. This is where you respond to requests.
#
# See also: @MODULE(Base::WebServer::Process)
sub request {
	my ($self, $process) = @_;
	my $content = "<title>Hello World</title>\n" .
	    "<h1>Hello World</h1>\n" .
	    "This is a default implementation for the " .
	    "<code>Base::WebServer::request()</code> method. " .
	    "You should override this method.";
	$process->header("Content-Length", length($content));
	$process->print($content);
}


####### Private methods #######


# Process a complete HTTP request.
sub _processRequest {
	my ($self, $client) = @_;
	my $state = $client->{http}; # Type: HTTPState
	my ($httpVersion, $file);

	# HTTP/1.1 spec says we should ignore leading newlines.
	$state->{request} =~ s/^(\x0D\x0A)*//s;

	#print "Request:\n$state->{request}\n\n";

	# Process request line
	my @lines = split /\x0D\x0A/, $state->{request};
	if ($lines[0] !~ /^GET (.*) HTTP\/(.*)$/) {
		$self->_rejectClient($client, 405, "Method Not Allowed");
		return;
	}
	$file = $1;
	$httpVersion = $2;

	if ($httpVersion ne '1.1') {
		$self->_rejectClient($client, 505, "HTTP Version Not Supported");
		return;
	}

	# Split the headers into key-value pairs.
	my %headers;
	shift @lines;
	foreach my $line (@lines) {
		my ($key, $value) = split /: */, $line, 2;
		if ($key eq '' || $value eq '') {
			$self->_rejectClient($client, 400, "Bad Request");
			return;
		}
		$headers{lc($key)} = $value;
	}

	my $process = new Base::WebServer::Process($client->getSocket(),
						   $file, \%headers);
	$self->request($process);
}

# Reject a client by sending it a HTTP error message, then closing the connection.
sub _rejectClient {
	my ($self, $client, $errorID, $errorMsg) = @_;
	my $process = new Base::WebServer::Process($client->{sock});
	$process->_killClient($errorID, $errorMsg);
}


####### Utility functions #######


# Return the first HTTP request and remove it from $state->{requestData}.
sub _getFirstRequest {
	my ($state) = @_;

	$state->{requestData} =~ /^(.*?)\x0D\x0A\x0D\x0A(.*)$/s;
	if (defined $1) {
		$state->{requestData} = $2;
		return $1;
	} else {
		return undef;
	}
}

# Convert a unix timestamp into a date in RFC 1123 format.
sub _dateString {
	my ($time) = @_;
	my @items = gmtime($time);
	my @weekdays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	my ($weekday, $date, $time);

	$weekday = $weekdays[$items[6]];
	$date = sprintf("%02d %s %d", $items[3], $months[$items[4]], $items[5] + 1900);
	$time = sprintf("%02d:%02d:%02d", $items[2], $items[1], $items[0]);
	return "$weekday, $date $time GMT"
}


1;

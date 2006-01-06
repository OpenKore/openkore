package webMonitorServer;

# webMonitor - an HTTP interface to monitor bots
# Copyright (C) 2006 kaliwanagan
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

use strict;
use Base::WebServer;
use base qw(Base::WebServer);
use Globals;
use Log qw(message debug);
use Utils;
use Log;

###
# cHook
#
# This sub hooks into the Log module of OpenKore in order to store console
# messages into a FIFO array @messages. Many thanks to PlayingSafe, from whom
# most of the code was derived from.
my @messages;
my $cHook = Log::addHook(\&cHook, "Console Log");
sub cHook {
	my $type = shift;
	my $domain = shift;
	my $level = shift;
	my $currentVerbosity = shift;
	my $messages = shift;
	my $user_data = shift;
	my $logfile = shift;
	my $deathmsg = shift;

	if ($level <= $currentVerbosity) {
		# Prepend the time to the message
		my (undef, $microseconds) = Time::HiRes::gettimeofday;
		$microseconds = substr($microseconds, 0, 2);
		my $message = "[".getFormattedDate(int(time)).".$microseconds] ".$messages;	
	
		push(@messages, $messages);

		# Make sure we don't let @messages grow too large
		# TODO: make the message size configurable
		if (@messages > 20) {
			shift(@messages);
		}
	}
}

###
# $webMonitorServer->request
#
# This virtual method will be called every time a web browser requests a page
# from this web server. We override this method so we can respond to requests.
sub request {
	my ($self, $process) = @_;
	my $content = '';
	
	# We inspect the headers sent by the browser.
	# In order to comply with HTTP 1.1 specs, we need to require the Host header
	# from the client's request. This really isn't a problem, as most modern
	# browsers will send the host header by default; also we don't really have
	# much use for this information either.
	if (!$process->clientHeader('Host')) {
		$process->status(400, "Bad Request");
		$content .= '<html><body>\n';
		$content .= '<h2>No Host: header received</h2>\n';
		$content .= 'HTTP 1.1 requests must include the Host: header.\n';
		$content .= '</body></html>';
		$process->shortResponse($content);
		return;
	}
	
	# We then inspect the headers the client sent us to see if there are any
	# resources that was sent
	my %resources;
	if ($process->clientHeader('GET')) {
		# The get method simply tacks the resource at the end of the resource
		# request. We manipulate the header to extract the resource sent.
		my $resource = $process->clientHeader('GET');
		# Remove the filename from the header, as well as the ?
		$resource =~ s/$process->file//;
		$resource =~ s/\?//;
		my @resources = split '&', $resource;
		foreach my $item (@resources) {
			$item =~ s/\+//;
			my ($key, $value) = split '=', $item;
			$resources{$key} = $value;
		}

	} elsif ($process->clientHeader('POST')) {
		# Looks like the Base::Server::Webserver doesn't support the POST
		# method, however we still include this portion just in case support
		# for POST gets written :)
		my $resourceLength = $process->clientHeader('Content-Length');
		# FIXME: how read the resource?
	}

	# Keywords are specific fields in the template that will eventually get
	# replaced by dynamic content.
	my %keywords =	(
		'characterName' => $char->name(),
		'characterJob' => $jobs_lut{$char->{jobID}},
		'characterSex' => $sex_lut{$char->{sex}},
		'characterLevel' => $char->{lv},
		'characterJobLevel' => $char->{lv_job},
		'characterID' => unpack("V", $char->{ID}),
		'characterZeny' => $char->{zenny},
		'characterStr' => $char->{str},
		'characterAgi' => $char->{agi},
		'characterVit' => $char->{vit},
		'characterInt' => $char->{int},
		'characterDex' => $char->{dex},
		'characterLuk' => $char->{luk},
		'characterBaseExp' => $char->{exp},
		'characterBaseMax' => $char->{exp_max},
		'characterBasePercent' => $char->{exp_max} ?
			sprintf("%.2f", $char->{exp} / $char->{exp_max} * 100) :
			0,
		'characterJobExp' => $char->{exp_job},
		'characterJobMax' => $char->{exp_job_max},
		'characterJobPercent' => $char->{exp_job_max} ?
			sprintf("%.2f", $char->{'exp_job'} / $char->{'exp_job_max'} * 100) :
			0,
		'characterHP' => $char->{hp},
		'characterHPMax' => $char->{hp_max},
		'characterHPPercent' => sprintf("%.2f", $char->hp_percent()),
		'characterSP' => $char->{sp},
		'characterSPMax' => $char->{sp_max},
		'characterSPPercent' => sprintf("%.2f", $char->sp_percent()),
		'characterWeightPercent' => sprintf("%.0f", $char->weight_percent()),
		'characterLocationX' => $char->position()->{x},
		'characterLocationY' => $char->position()->{y},
		'characterLocationMap' => $field{name},
		'lastConsoleMessage' => $messages[-1],
	);
	
	# Marks signal the parser that the word encountered is a keyword. Since we
	# are going to be using regexp, make sure to escape any non-alphanumeric
	# characters in the marker string.
	my $markF = '\$';	# marker front
	my $markB = '\$';	# marker back

	if ($process->file eq '/') {
		# Initialize some variables and the templates
		my @index;
		my $indexTemplate = "plugins/webMonitor/index.template";
		if (open (TEMPLATE, "<$indexTemplate")) {
			@index = <TEMPLATE>;
			close (TEMPLATE);
		} else {
			die "Unable to find $indexTemplate";
		}

		# We are going to be using chunk encoding, so make sure the proper
		# headers are sent
		$process->header("Transfer-Encoding", "chunked");
		foreach my $line (@index) {
			# TODO: find a more optimized way of reading and replacing template
			# variables
			while ((my $key, my $value) = each %keywords) {
				# Here we inspect each line of the template, and replace the
				# keywords with their proper content.
				# TODO: find a way to iterate through marked keywords and replace
				# an array variable with multiple instances of itself.
				$line =~ s/$markF$key$markB/$value/;
			}
			# Then we chunk send the line to the browser
			chunkSend($process, $line);
		}
		
	} elsif ($process->file eq '/variables') {
		# Reload the page every 5 seconds
		$content .= '<head><meta http-equiv="refresh" content="5"></head>';
		
		# Display internal variables in alphabetical order (useful for debugging)
		$content .= '<hr><h1>%keywords</h1><hr>';
		foreach my $key (sort keys %keywords) {
			$content .= "$key => " . $keywords{$key} . '<br>';
		}
		$content .= '<hr>';

		$content .= '<hr><h1>$char</h1><hr>';
		foreach my $key (sort keys %{$char}) {
			$content .= "$key => " . ${%{$char}}{$key} . '<br>';
		}
		$content .= '<hr>';
		$process->shortResponse($content);

	} elsif ($process->file eq '/console') {
		# Reload the page every 5 seconds
		$content .= '<head><meta http-equiv="refresh" content="5"></head>' . "\n";
		$content .= '<pre>' . "\n";

		# Concatenate the message buffer
		foreach my $message (@messages) {
			$content .= $message;
		}
		
		$content .= '</pre>';
		$process->shortResponse($content);

	} else {
		# See first if the file being requested exists in the file system.
		# This is useful for static stuff like style sheets and graphics.
		if (open (FILE, "<" . "plugins/webMonitor/" . $process->file)) {
			# Figure out the content-type of the file and send a header to the
			# client containing that information. Well-behaved clients should
			# respect this header.
			$process->header("Content-Type", contentType($process->file));
			# TODO: enable the file to be templated if a corresponding
			# template is found as well
			while (read FILE, my $buffer, 1024) {
				$content .= $buffer;
			}
			close FILE;
			# TODO: chunk encode this also
			$process->print($content);
			
		} else {
			# our custom 404 message
			$process->status(404, "File Not Found");
			$content .= "<h1>File " . $process->file . " not found.</h1>";
			$process->shortResponse($content);
		}
	}
}

###
# chunkSend (process, data, [parameters])
# process: a process object from Base::Server::Webserver
# data: data to be chunk encoded
# parameters: optional parameters
#
# If the server wants to start sending a response before knowing its total
# length, the data can be chunk-encoded. Make sure the header "Transfer-Enconding:
# chunked" is scheduled before calling this function. That is:
#
# $process->header("Transfer-Encoding", "chunked");
#
# must have been called before any calls to this funuction.
#
# Example:
# $process->header("Transfer-Encoding", "chunked");
# my $data = "abcdefghijklmnopqrstuvwxyz"
# chunkSend($process, $data, "part one of two");
# ... (do some other stuff here that adds to $data) ...
# chunkSend($process, $data, "part two of two");
sub chunkSend {
	my $process = shift;
	my $data = shift;
	my $parameters = shift;

	# The specs for chunk encoding call for sending the size of the chunk data
	# in hexadecimal, followed by a semicolon, followed by parameters (which is
	# usually ignored but included here for completion), followed by CRLF
	my $dataHex = uc(sprintf "%lx", length $data);
	$process->print($dataHex . ";$parameters\x0D\x0A");

	# The data itself is then sent, followed by CRLF
	$process->print($data . "\x0D\x0A");
}	

sub contentType {
	my $filename = shift;
	
	my @parts = split /\./, $filename;
	my $extension = $parts[-1];
	if (lc($extension) eq "asf") {
		return "video/x-ms-asf";
	} elsif (lc($extension) eq "avi") {
		return "video/avi";
	} elsif (lc($extension) eq "doc") {
		return "application/msword";
	} elsif (lc($extension) eq "zip") {
		return "application/zip";
	} elsif (lc($extension) eq "xls") {
		return "application/vnd.ms-excel";
	} elsif (lc($extension) eq "gif") {
		return "image/gif";
	} elsif (lc($extension) eq "png") {
		return "image/png";
	} elsif (lc($extension) eq "jpg" || lc($extension) eq "jpeg") {
		return "image/jpeg";
	} elsif (lc($extension) eq "wav") {
		return "audio/wav";
	} elsif (lc($extension) eq "mp3") {
		return "audio/mpeg3";
	} elsif (lc($extension) eq "mpg"|| lc($extension) eq "mpeg") {
		return "video/mpeg";
	} elsif (lc($extension) eq "rtf") {
		return "application/rtf";
	} elsif (lc($extension) eq "htm"|| lc($extension) eq "html") {
		return "text/html";
	} elsif (lc($extension) eq "txt") {
		return "text/plain";
	} elsif (lc($extension) eq "css") {
		return "text/css";
	} elsif (lc($extension) eq "pdf") {
		return "application/pdf";
	} else {
		return "application/x-unknown";
	}
}

1;

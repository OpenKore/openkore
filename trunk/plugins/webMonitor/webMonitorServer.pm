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
use Commands;

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
	
		push(@messages, $message);

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
	my %resources = %{$process->{GET}};
	
	# TODO: sanitize $filename for possible exploits (like ../../config.txt)
	my $filename = $process->file;
	$filename .= 'index.html' if ($filename =~ /\/$/);

	# Keywords are specific fields in the template that will eventually get
	# replaced by dynamic content.
	my %keywords =	(
		'version' => $Settings::NAME . ' ' . $Settings::VERSION . ' ' . $Settings::CVS,
		'characterName' => $char->name(),
		'characterJob' => $jobs_lut{$char->{jobID}},
		'characterSex' => $sex_lut{$char->{sex}},
		'characterLevel' => $char->{lv},
		'characterJobLevel' => $char->{lv_job},
		'characterID' => unpack("V", $char->{ID}),
		'characterZeny' => $char->{zenny},
		'characterStr' => $char->{str},
		'characterStrBonus' => $char->{str_bonus},
		'characterStrPoints' => $char->{points_str},
		'characterAgi' => $char->{agi},
		'characterAgiBonus' => $char->{agi_bonus},
		'characterAgiPoints' => $char->{points_agi},
		'characterVit' => $char->{vit},
		'characterVitBonus' => $char->{vit_bonus},
		'characterVitPoints' => $char->{points_vit},
		'characterInt' => $char->{int},
		'characterIntBonus' => $char->{int_bonus},
		'characterIntPoints' => $char->{points_int},
		'characterDex' => $char->{dex},
		'characterDexBonus' => $char->{dex_bonus},
		'characterDexPoints' => $char->{points_dex},
		'characterLuk' => $char->{luk},
		'characterLukBonus' => $char->{luk_bonus},
		'characterLukPoints' => $char->{points_luk},
		'characterFreePoints' => $char->{points_free},
		'characterAttack' => $char->{attack},
		'characterAttackBonus' => $char->{attack_bonus},
		'characterAttackMagicMax' => $char->{attack_magic_max},
		'characterAttackMagicMin' => $char->{attack_magic_min},
		'characterAttackRange' => $char->{attack_range},
		'characterAttackSpeed' => $char->{attack_speed},
		'characterHit' => $char->{hit},
		'characterCritical' => $char->{critical},
		'characterDef' => $char->{def},
		'characterDefBonus' => $char->{def_bonus},
		'characterDefMagic' => $char->{def_magic},
		'characterDefMagicBonus' => $char->{def_magic_bonus},
		'characterFlee' => $char->{flee},
		'characterFleeBonus' => $char->{flee_bonus},
		'characterSpirits' => $char->{spirits},
		
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
		'characterWeight' => $char->{weight},
		'characterWeightMax' => $char->{weight_max},
		'characterWeightPercent' => sprintf("%.0f", $char->weight_percent()),
		'characterWalkSpeed' => $char->{walk_speed},
		'characterLocationX' => $char->position()->{x},
		'characterLocationY' => $char->position()->{y},
		'characterLocationMap' => $field{name},
		'lastConsoleMessage' => $messages[-1],
		'skin' => 'bibian', # TODO: replace with config.txt entry for the skin
	);
	
	# Markers signal the parser that the word encountered is a keyword. Since we
	# are going to be using regexp, make sure to escape any non-alphanumeric
	# characters in the marker string.
	my $keywordF = '\$';	# keyword front
	my $keywordB = '\$';	# keyword back
	my $arrayF = '\@';		# array front
	my $arrayB = '\@';		# array back

	if ($filename eq '/handler') {
		$filename = handle(\%resources) || '/';
		$process->print('<HTML>');
		$process->print('<HEAD>');
		$process->print('<META HTTP-EQUIV="refresh" content="0;URL='.$filename.'">');
		$process->print('<TITLE>Redirecting</TITLE>');
		$process->print('</HEAD>');
		$process->print('<BODY>');
		$process->print('Request received for processing. Redirecting you to: '.$filename);
		$process->print('</BODY>');
		$process->print('</HTML>');
		return;
	}
	# TODO: will be removed later
	if ($filename eq '/variables') {
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
			$content .= "$key => " . $char->{$key} . '<br>';
		}
		$content .= '<hr>';
		$process->shortResponse($content);

	# TODO: will be removed later
	} elsif ($filename eq '/console') {
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
		# Figure out the content-type of the file and send a header to the
		# client containing that information. Well-behaved clients should
		# respect this header.
		$process->header("Content-Type", contentType($filename));

		# The file requested has an associated template. Do a replacement.
		if (open (TEMPLATE, "<" . "plugins/webMonitor/WWW/" . $filename . '.template')) {
			my @template = <TEMPLATE>;
			close (TEMPLATE);

			# Here we inspect each line of the template, and replace the
			# keywords with their proper content. Then we chunk send the line to
			# the browser
			foreach my $line (@{replaceArray(\@template, \%keywords, $keywordF, $keywordB)}) {
				$process->print($line);
			}

		# See if the file being requested exists in the file system. This is
		# useful for static stuff like style sheets and graphics.
		} elsif (open (FILE, "<" . "plugins/webMonitor/WWW/" . $filename)) {
			while (read FILE, my $buffer, 1024) {
				$process->print($buffer);
			}
			close FILE;
			
		} else {
			# our custom 404 message
			$process->status(404, "File Not Found");
			$content .= "<h1>File " . $filename . " not found.</h1>";
			$process->shortResponse($content);
		}
	}
}

###
# replace (source, keywords, markF, markB)
# source: the string to do replacements on
# keywords: a hash containing the keyword and the replacement string
# markF: front delimiter to identify a keyword
# markB: back delimiter to identify a keyword
sub replaceLine {
	my $source = shift;
	my $keywords = shift;
	my $markF = shift;
	my $markB = shift;

	# TODO: find a more optimized way of reading and replacing template
	# variables
	while ((my $key, my $value) = each %{$keywords}) {
		# TODO: find a way to iterate through marked keywords and replace
		# an array variable with multiple instances of itself.
		$source =~ s/$markF$key$markB/$value/sg;
	}
	return $source;
}

sub replaceArray {
	my $source = shift;
	my $keywords = shift;
	my $markF = shift;
	my $markB = shift;

	foreach my $line (@{$source}) {
		$line = replaceLine($line, $keywords, $markF, $markB);
	}
	return $source;
}

sub handle {
	my $resources = shift;
	my $content;

	foreach my $key (sort keys %{$resources}) {
		if ($key eq 'command') {
			Commands::run($resources->{command});
		}
	}
	return $resources->{page};
}

sub contentType {
	# TODO: make it so we don't depend on the filename extension for the content
	# type. Instead, look in the file to determine the content-type.
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
		return "text/html";
	}
}

1;

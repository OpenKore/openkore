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
use template;

# Keywords are specific fields in the template that will eventually get
# replaced by dynamic content.
my %keywords;

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
	
		# TODO: make this configurable (doesn't prepend the time for now)
		my @lines = split "\n", $messages;
		if (@lines > 1) {
			foreach my $line (@lines) {
				$line .= "\n";
				push @messages, $line;
			}
		} else {
			push(@messages, $messages);
		}

		# Make sure we don't let @messages grow too large
		# TODO: make the message size configurable
		while (@messages > 20) {
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

	# We then inspect the headers the client sent us to see if there are any
	# resources that was sent
	my %resources = %{$process->{GET}};
	
	# TODO: sanitize $filename for possible exploits (like ../../config.txt)
	my $filename = $process->file;

	# map / to /index.html
	$filename .= 'index.html' if ($filename =~ /\/$/);
	# alias the newbie maps to new_zone01
	$filename =~ s/new_.../new_zone01/;

	my (@unusable, @usable, @equipment, @uequipment);
	my (@unusableAmount, @usableAmount);
	for (my $i; $i < @{$char->inventory->getItems()}; $i++) {
		my $item = $char->inventory->getItems()->[$i];
		next unless $item && %{$item};
		if (($item->{type} == 3 || $item->{type} == 6 ||
			$item->{type} == 10) && !$item->{equipped})
		{
			push @unusable, $item->{name};
			push @unusableAmount, $item->{amount};
		} elsif ($item->{type} <= 2) {
			push @usable, $item->{name};
			push @usableAmount, $item->{amount};
		} else {
			if ($item->{equipped}) {
				push @equipment, $item->{name};
			} else {
				push @uequipment, $item->{name};
			}
		}
	}
	my @statuses = (keys %{$char->{statuses}});
	my (@npcName, @npcLocX, @npcLocY);
	foreach my $npcsID (@npcsID) {
		push @npcName, $npcs{$npcsID}{name};
		push @npcLocX, $npcs{$npcsID}{pos}{x};
		push @npcLocY, $npcs{$npcsID}{pos}{y};
	}	

	%keywords =	(
		'npcName' => \@npcName,
		'npcLocationX' => \@npcLocX,
		'npcLocationY' => \@npcLocY,
		'inventoryEquipped' => \@equipment,
		'inventoryUnequipped' => \@uequipment,
		'inventoryUsable' => \@usable,
		'inventoryUsableAmount' => \@usableAmount,
		'inventoryUnusableAmount' => \@unusableAmount,
		'inventoryUnusable' => \@unusable,
		'consoleMessages' => \@messages,
		'characterStatuses' => \@statuses,
		'characterName' => $char->name(),
		'characterJob' => $jobs_lut{$char->{jobID}},
		'characterSex' => $sex_lut{$char->{sex}},
		'characterLevel' => $char->{lv},
		'characterJobLevel' => $char->{lv_job},
		'characterID' => unpack("V", $char->{ID}),
		'characterHairColor'=> $haircolors{$char->{hair_color}},
		'characterGuildName' => $char->{guild}{name},
		'characterLeftHand' => $char->{equipment}{leftHand}{name} || 'none',
		'characterRightHand' => $char->{equipment}{rightHand}{name} || 'none',
		'characterTopHead' => $char->{equipment}{topHead}{name} || 'none',
		'characterMidHead' => $char->{equipment}{midHead}{name} || 'none',
		'characterLowHead' => $char->{equipment}{lowHead}{name} || 'none',
		'characterRobe' => $char->{equipment}{robe}{name} || 'none',
		'characterArmor' => $char->{equipment}{armor}{name} || 'none',
		'characterShoes' => $char->{equipment}{shoes}{name} || 'none',
		'characterLeftAccessory' => $char->{equipment}{leftAccessory}{name} || 'none',
		'characterRightAccessory' => $char->{equipment}{rightAccessory}{name} || 'none',
		'characterArrow' => $char->{equipment}{arrow}{name} || 'none',
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
		'characterSpirits' => $char->{spirits} || 'none',
	
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
		'skin' => 'default', # TODO: replace with config.txt entry for the skin
		'version' => $Settings::NAME . ' ' . $Settings::VERSION . ' ' . $Settings::CVS,
	);
	
	if ($filename eq '/handler') {
		handle(\%resources, $process);
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

		my $file = new template("plugins/webMonitor/WWW/" . $filename . '.template');

		# The file requested has an associated template. Do a replacement.
		if ($file->{template}) {
			$content = $file->replace(\%keywords, '{', '}');
			$process->print($content);

		# See if the file being requested exists in the file system. This is
		# useful for static stuff like style sheets and graphics.
		} elsif (open (FILE, "<" . "plugins/webMonitor/WWW/" . $filename)) {
			binmode FILE;
			while (read FILE, my $buffer, 1024) {
				$process->print($buffer);
			}
			close FILE;
			
		} else {
			# our custom 404 message
			$process->header("Content-Type", 'text/html');
			$process->status(404, "File Not Found");
			$content .= "<h1>File " . $filename . " not found.</h1>";
			$process->shortResponse($content);
		}
	}
}

sub handle {
	my $resources = shift;
	my $process = shift;
	my $retval;

	if ($resources->{command}) {
		Commands::run($resources->{command});
	}
	
	if ($resources->{requestVar}) {
		$process->print($keywords{$resources->{requestVar}});
	}

	# make sure this is the last resource to be checked
	if ($resources->{page}) {
		my $filename = $resources->{page};
		$filename .= 'index.html' if ($filename =~ /\/$/);

		# hooray for standards-compliance
 		$process->header('Location', $filename);
		$process->status(303, "See Other");
		$process->print("\n");
	}
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
		return "application/x-unknown";
	}
}

1;

	# the webserver shouldn't differentiate between actual characters and url
	# encoded characters. see http://www.blooberry.com/indexdot/html/topics/urlencoding.htm
#	$filename =~ s/\%24/\$/sg;
#	$filename =~ s/\%26/\&/sg;
#	$filename =~ s/\%2B/\+/sg;
#	$filename =~ s/\%2C/\,/sg;
#	$filename =~ s/\%2F/\//sg;
#	$filename =~ s/\%3A/\:/sg;
#	$filename =~ s/\%3B/\:/sg;
#	$filename =~ s/\%3D/\=/sg;
#	$filename =~ s/\%3F/\?/sg;
#	$filename =~ s/\%40/\@/sg;
#	$filename =~ s/\%20/\+/sg;
#	$filename =~ s/\%22/\"/sg;
#	$filename =~ s/\%3C/\</sg;
#	$filename =~ s/\%3E/\>/sg;
#	$filename =~ s/\%23/\#/sg;
#	$filename =~ s/\%25/\%/sg;
#	$filename =~ s/\%7B/\{/sg;
#	$filename =~ s/\%7D/\}/sg;
#	$filename =~ s/\%7C/\|/sg;
#	$filename =~ s/\%5C/\\/sg;
#	$filename =~ s/\%5E/\^/sg;
#	$filename =~ s/\%7E/\~/sg;
#	$filename =~ s/\%5B/\[/sg;
#	$filename =~ s/\%5D/\]/sg;
#	$filename =~ s/\%60/\`/sg;

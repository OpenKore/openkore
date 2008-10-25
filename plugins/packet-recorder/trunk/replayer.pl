##############################################################################
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
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
##############################################################################

# Configuration options: 
# replayPacket (FILENAME)
#    Packets from FILENAME will be replayed.
#
# replayPacket_realtime (flag)
#    If enabled, packets will be replayed in the same speed as they were
#    originally received. If disabled, all packets will be replayed as quickly
#    as your hardware allows.
#
# replayPacket_clockInterval (number)
#    Every (number) seconds, this plugin will display the time of when the
#    current packet was received. If not set, (number) will be assumed to be 1.


package ReplayerPlugin;

use strict;
use Time::HiRes qw(time);
use Plugins;
use Globals;
use Settings;
use Log qw(message);
use Utils;


Plugins::register("replayer", "Packet Replayer", \&on_unload);
my $hooks = Plugins::addHooks(
	['start3', \&on_start3],
	['mainLoop_pre', \&on_main]
);
my ($reader, $replayBegin, $recordBegin, $recordEnd, $nextTime,
    %nextPacket, $timeDisplay);


sub on_unload {
	Plugins::delHooks($hooks);
}

sub on_start3 {
	if ($config{replayPacket}) {
		my $field;

		$Settings::no_connect = 1;
		$config{char} = 0;
		$chars[0] = {};
		$char = $chars[0];
		$conState = 5;
		$config{sleepTime} = 0;

		$reader = new Replayer::Reader($config{replayPacket});
		$reader->header(\$recordBegin, \$accountID, \$charID, \$field, \$char->{name});
		message "Packet recording was started at : " . localtime($recordBegin) . "\n", "info";
		my %packet;
		while ($reader->next(\%packet)) {
			# Do nothing
		}
		$recordEnd = $packet{time};
		message "Packet recording was finished at: " . localtime($recordEnd) . "\n", "info";
		message "Total time recorded: " . timeConvert($recordEnd - $recordBegin) . " (" . int($recordEnd - $recordBegin) . " seconds)\n", "info";

		message "You can flash forward to a given time, or start replaying from the beginning.\n";
		message "Enter the number of seconds you want to skip, or press ENTER if you want to\n";
		message "replay from the beginning: \n";
		my $input = $interface->getInput(-1);
		if ($input eq "") {
			message "Replaying from the beginning.\n", "info";
			$reader->reset();
			$reader->next(\%nextPacket);
			$replayBegin = time;

		} else {
			while (!$quit) {
				if ($input !~ /^\d+$/) {
					message "Enter number: ";
					$input = $interface->getInput(-1);
					next;
				}

				my $time = $recordBegin + $input;
				if ($time > $recordEnd) {
					message "The number is too high, retry: ";
					$input = $interface->getInput(-1);
					next;
				}

				do {
					message "Start replaying at " . localtime($time) . "? (y/n) ";
					$input = $interface->getInput(-1);
				} while (!$quit && $input !~ /^[yn]$/);
				return if ($quit);

				if ($input eq "n") {
					message "Enter number: ";
					$input = $interface->getInput(-1);
					next;
				}

				$reader->reset();
				while ($reader->next(\%nextPacket)) {
					last if ($nextPacket{time} > $time);
				}
				$replayBegin = time - ($nextPacket{time} - $recordBegin);
				last;
			}
			return if ($quit);
		}

		$nextTime = $replayBegin + $nextPacket{time} - $recordBegin;
		main::getField($field, \%field);
	}
}

sub on_main {
	return unless ($reader && time >= $nextTime);

	# Play packet
	if (timeOut($timeDisplay, $config{replayPacket_clockInterval} || 1)) {
		my $time = localtime($nextPacket{time});
		my $sec = int($nextPacket{time} - $recordBegin);
		message "This packet was received at: $time ($sec secs since begin)\n", "system";
		$timeDisplay = time;
	}
	main::parseMsg($nextPacket{data});

	# Get next packet and calculate next waiting time
	if (!$reader->next(\%nextPacket)) {
		undef $reader;
		message "Done replaying $config{replayPacket}\n", "system";
	}
 
	if ($config{replayPacket_realtime}) {
		$nextTime = $replayBegin + $nextPacket{time} - $recordBegin;
	}
}


package Replayer::Reader;

sub new {
	my ($class, $file) = @_;
	my %self;

	$self{file} = $file;
	open($self{handle}, "< $file");
	binmode $self{handle};

	bless \%self, $class;
	return \%self;
}

sub DESTROY {
	my ($self) = @_;
	close $self->{handle};
}

sub header {
	my ($self, $beginTime, $accountID, $charID, $field, $charName) = @_;
	my ($data, $magic, $version);

	seek $self->{handle}, 0, 0;
	read $self->{handle}, $data, 1024;

	($magic, $version, $$beginTime, $$accountID, $$charID, $$field, $$charName)
	    = unpack("C4 S F C4 C4 a20 a25", $data);
	# TODO: check whether $magic is "PKT\0" and whether $version is 0

	$$field =~ s/\0//g;
	$$charName =~ s/\0//g;
}

sub next {
	my ($self, $item) = @_;
	my ($time, $len, $data);

	if (eof $self->{handle}) {
		return 0;
	} elsif (tell($self->{handle}) < 1024) {
		seek $self->{handle}, 1024, 0;
	}

	read $self->{handle}, $time, 8;
	$time = unpack("F", $time);
	read $self->{handle}, $len, 2;
	$len = unpack("S", $len);
	read $self->{handle}, $data, $len;

	$item->{time} = $time;
	$item->{data} = $data;
	return 1;
}

sub reset {
	my ($self) = @_;
	seek $self->{handle}, 1024, 0;
}


1;

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

# This plugin records packets into a file. You can replay them with the
# packet replayer plugin. This is useful for debugging purposes.
#
# Limitations:
# The packet recorder can only record the packets you received on one map.
# If you change map, the packet record file is reset.
#
# Configuration options:
# recordPacket (FILENAME)
#    Packets will be recorded to FILENAME.

package PacketRecorderPlugin;

use strict;
use Plugins;
use Globals;
use Log qw(message error);


Plugins::register("Packet Recorder", "Packet Recorder", \&on_unload);
my $hooks = Plugins::addHooks(
	['parseMsg/pre', \&on_parseMsg],
	['start3', \&on_start3]
);
my $writer;
my $oldConState;


sub on_unload {
	Plugins::delHooks($hooks);
	undef $writer;
}

sub on_start3 {
	if ($config{recordPacket}) {
		if ($config{replayPacket}) {
			error "Don't enable the packet replayer and recorder at the same time!\n";
			$config{recordPacket} = 0;
			return;
		}
		message "Packet recorder enabled: packets will be recorded to $config{recordPacket}\n", "system";
		$writer = new PacketRecorder::Writer($config{recordPacket});
	}
}

sub on_parseMsg {
	my (undef, $args) = @_;

	return unless ($writer);

	if ($oldConState != $conState) {
		# $conState changed
		$oldConState = $conState;
		if ($conState == 5) {
			# We just changed map or logged in.
			$writer->reset();
			$writer->writeHeader($accountID, $charID, $field{name},
			    $char->{name});
		}
	}

	return unless ($conState == 5);
	$writer->add(substr($args->{msg}, 0, $args->{msg_size}));
}


package PacketRecorder::Writer;

use Time::HiRes qw(time);

sub new {
	my ($class, $file) = @_;
	my $self = {};

	$self->{file} = $file;
	bless $self, $class;
	$self->reset();
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	close $self->{handle};
}

sub reset {
	my ($self) = @_;

	close $self->{handle} if ($self->{handle});
	open($self->{handle}, "> $self->{file}");
	binmode $self->{handle};
	syswrite $self->{handle}, chr(0) x 1024;
}

sub writeHeader {
	my ($self, $accountID, $charID, $field, $charName) = @_;
	my $data = "PKT" . chr(0) . pack("S", 0);
	$data .= pack("F C4 C4 a20", time, $accountID, $charID, $field);
	$data .= pack("a25", $charName);

	seek $self->{handle}, 0, 0;
	syswrite $self->{handle}, pack("a1024", $data);
}

sub add {
	my ($self, $data) = @_;

	seek $self->{handle}, 0, 2;
	syswrite $self->{handle}, pack("FS", time, length($data)) . $data;
}

1;

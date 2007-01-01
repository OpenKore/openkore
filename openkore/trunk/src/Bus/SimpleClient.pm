#########################################################################
#  OpenKore - Bus system
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
# MODULE DESCRIPTION: Low-level bus client implementation.
#
# This module is a bare-bones implementation of a bus client. It can
# only parse messages, but knows nothing about the actual protocol.

package Bus::SimpleClient;

use strict;
use warnings;
no warnings 'redefine';
use IO::Socket::INET;

use Modules 'register';
use Bus::Messages qw(serialize);
use Bus::MessageParser;
use Utils qw(dataWaiting);
use Utils::Exceptions;


##
# Bus::Client->new(String host, int port)
# host: host address of the IPC manager.
# port: port number of the IPC manager.
#
# Create a new Bus::Client object.
#
# Throws a SocketException if unable to connect.
sub new {
	my ($class, $host, $port) = @_;
	my %self;

	$self{sock} = new IO::Socket::INET(
			PeerHost => $host,
			PeerPort => $port,
			Proto => 'tcp',
			Timeout => 4
		);
	if (!$self{sock}) {
		SocketException->throw("$!");
	}

	$self{sock}->autoflush(0);
	$self{parser} = new Bus::MessageParser();

	return bless \%self, $class;
}

sub DESTROY {
	my ($self) = @_;
	$self->{sock}->close if ($self->{sock});
}

##
# void $Bus_Client->send(String messageID, args)
#
# Send a message through the bus. Throws IOException if it fails.
sub send {
	my ($self, $MID, $args) = @_;
	eval {
		$self->{sock}->send(serialize($MID, $args), 0);
		$self->{sock}->flush();
	};
	if ($@) {
		IOException->throw($@);
	}
}

##
# Scalar* $Bus_Client->readNext(String* messageID)
# messageID: If a message has been read, then the message ID will be stored here.
# Returns: Either a reference to a hash or a reference to an array, as the message arguments.
#          Or returns undef if there is no complete message on the socket yet.
#
# Read the next message from the bus, if any. This method returns undef immediately
# when there are no messages.
#
# Throws IOException if reading from the socket fails.
sub readNext {
	my ($self, $ID) = @_;
	return if (!dataWaiting($self->{sock}));

	my $data;
	eval {
		$self->{sock}->recv($data, 1024 * 32, 0);
	};
	if ($@) {
		IOException->throw($@);
	} elsif (!defined $data || length($data) == 0) {
		IOException->throw("Bus server closed connection.");
	}

	$self->{parser}->add($data);
	return $self->{parser}->readNext($ID);
}

1;

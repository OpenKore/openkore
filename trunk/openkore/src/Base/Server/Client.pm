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
# MODULE DESCRIPTION: A client within a Base::Server
#
# The three abstract functions in @MODULE(Base::Server) all have
# an $client object as parameter, which is of this type.
# This class represents a client which the server handles.

package Base::Server::Client;

use strict;
use IO::Socket::INET;

sub new {
	my ($class, $socket, $host, $fd, $index) = @_;
	my %self = (
		sock => $socket,
		host => $host,
		fd => $fd,
		index => $index
	);
	bless \%self, $class;
	return \%self;
}

sub DESTROY {
	$_[0]->{sock}->close;
}

##
# IO::Socket::INET $BaseServerClient->getSocket()
# Ensure: defined(result)
#
# Return the client's socket.
sub getSocket {
	return $_[0]->{sock};
}

##
# String $BaseServerClient->getIP()
# Ensure: result ne ''
#
# Returns the client's IP address in text form.
sub getIP {
	return $_[0]->{host};
}

##
# String $BaseServerClient->getFD()
# Ensure: defined(result)
#
# Returns the client's file descriptor.
sub getFD {
	return $_[0]->{fd};
}

##
# String $BaseServerClient->getIndex()
# Ensure: defined(result)
#
# Returns the index of this object in the @MODULE(Base::Server) object's internal list.
sub getIndex {
	return $_[0]->{index};
}

##
# String $BaseServerClient->send(String data)
# data: The data to send.
# Requires: defined($data)
# Returns: 1 on success, 0 on failure.
#
# Send data to the client.
sub send {
	my ($self) = @_;

	undef $@;
	eval {
		$self->{sock}->send($_[1], 0);
		$self->{sock}->flush;
	};
	if ($@) {
		# Client disconnected
		$self->{sock}->close;
		return 0;
	}
	return 1;
}

##
# void $BaseServerClient->close()
#
# Disconnect this client. In the next main loop iteration, this Base::Server::Client
# object will be removed from the @MODULE(Base::Server) object's internal list.
#
# You must not call $client->send() anymore after having called this function.
sub close {
	$_[0]->{sock}->close;
}

1;

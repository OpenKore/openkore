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
	my ($class, $socket, $host, $fd) = @_;
	my %self = (
		BSC_sock  => $socket,
		BSC_host  => $host,
		BSC_fd    => $fd
	);
	return bless \%self, $class;
}

sub DESTROY {
	$_[0]->{BSC_sock}->close if ($_[0]->{BSC_sock}->connected);
}

##
# IO::Socket::INET $BaseServerClient->getSocket()
# Ensures: defined(result)
#
# Return the client's socket.
sub getSocket {
	return $_[0]->{BSC_sock};
}

##
# String $BaseServerClient->getIP()
# Ensures: result ne ''
#
# Returns the client's IP address in text form.
sub getIP {
	return $_[0]->{BSC_host};
}

##
# int $BaseServerClient->getFD()
# Ensures: defined(result)
#
# Returns the client's file descriptor.
sub getFD {
	return $_[0]->{BSC_fd};
}

##
# int $BaseServerClient->getIndex()
# Ensures: defined(result)
#
# Returns the index of this object in the @MODULE(Base::Server) object's internal list.
sub getIndex {
	return $_[0]->{BSC_index};
}

sub setIndex {
	my ($self, $index) = @_;
	$self->{BSC_index} = $index;
}

##
# boolean $BaseServerClient->send(Bytes data)
# data: The data to send.
# Requires: defined($data)
# Returns: 1 on success, 0 on failure.
#
# Send data to the client.
sub send {
	my ($self) = @_;

	eval {
		$self->{BSC_sock}->send($_[1], 0);
		$self->{BSC_sock}->flush;
	};
	if ($@) {
		# Client disconnected
		$self->{BSC_sock}->close;
		return 0;
	}
	return 1;
}

##
# void $BaseServerClient->close()
#
# Disconnect this client. In the next $BaseServer->iterate() call, this Base::Server::Client
# object will be removed from the @MODULE(Base::Server) object's internal list.
#
# You must not call $BaseServerClient->send() anymore after having called this function.
sub close {
	$_[0]->{BSC_sock}->close;
}

1;

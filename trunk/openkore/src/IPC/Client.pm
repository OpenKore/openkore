#########################################################################
#  OpenKore - Inter-Process Communication system
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
# MODULE DESCRIPTION: Low-level IPC client implementation
#
# This module is a bare-bones implementation of an IPC client.
# It's used by IPC.pm and should not be used directly.

package IPC::Client;

use strict;
use warnings;
no warnings 'redefine';
use Exporter;
use base qw(Exporter);
use IO::Socket::INET;

use IPC::Protocol;
use Utils qw(dataWaiting);


##
# IPC::Client->new(host, port)
# host: host address of the IPC manager.
# port: port number of the IPC manager.
#
# Create a new IPC::Client object.
sub new {
	my ($class, $host, $port) = @_;
	my %client;

	$client{sock} = new IO::Socket::INET(
			PeerHost => $host,
			PeerPort => $port,
			Proto => 'tcp',
			Timeout => 4
		);
	return undef if (!$client{sock});
	$client{sock}->autoflush(0);

	$client{buffer} = '';
	bless \%client, $class;
	return \%client;
}

sub DESTROY {
	my $self = shift;
	$self->{sock}->close if ($self->{sock});
}

##
# $ipc_client->send(ID, hash | key => value)
#
# Send a message to the IPC manager.
sub send {
	my $self = shift;
	my $ID = shift;

	my $r_hash;
	if (ref($_[0]) && ref($_[0]) eq "HASH") {
		$r_hash = shift;
	} else {
		my %hash = @_;
		$r_hash = \%hash;
	}

	my $msg = IPC::Protocol::encode($ID, $r_hash);
	undef $@;
	eval {
		$self->{sock}->send($msg, 0);
		$self->{sock}->flush;
	};
	return (defined $@) ? 0 : 1;
}

##
# $ipc_client->recv(r_msgs)
# r_msgs: reference to an array, in which the messages are stored.
# Returns: the number of messages received (0 if there are none), or -1 if the connection has closed.
#
# Receive messages from the server. This function returns immediately
# if there are no messages.
#
# The returned array contains hashes. Each hash has an "ID" and "args" key.
# "ID" is the ID of the message, and "args" is a hash containing the message's arguments.
sub recv {
	my ($client, $r_msgs) = @_;
	my $msg;

	return 0 if (!dataWaiting($client->{sock}));

	undef $@;
	eval {
		$client->{sock}->recv($msg, 1024 * 32, 0);
	};
	if ($@ || !defined $msg || length($msg) == 0) {
		return -1;
	}

	$client->{buffer} .= $msg;

	my (@messages, $ID, %hash);
	while (($ID = IPC::Protocol::decode($client->{buffer}, \%hash, \$client->{buffer}))) {
		my %copy = %hash;
		push @messages, {ID => $ID, args => \%copy};
		undef %hash;
	}
	@{$r_msgs} = @messages;
	return scalar(@messages);
}

return 1;

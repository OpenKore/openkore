#########################################################################
#  OpenKore - Message sending
#  This module contains functions for sending messages to the RO server.
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
# MODULE DESCRIPTION: Sending messages to RO server
#
# This class contains convenience methods for sending messages to the RO
# server.
#
# Please also read <a href="http://www.openkore.com/wiki/index.php/Network_subsystem">the
# network subsystem overview.</a>
package Network::Send;

use strict;
use encoding 'utf8';

use Exception::Class (
	'Network::Send::ServerTypeNotSupported',
	'Network::Send::CreationException'
);

use Globals qw(%config $encryptVal $bytesSent $conState %packetDescriptions);
use I18N qw(stringToBytes);

sub import {
	# This code is for backward compatibility reasons, so that you can still
	# write:
	#  sendFoo(\$remote_socket, args);

	my ($package) = caller;
	# This is necessary for some weird reason.
	return if ($package =~ /^Network::Send/);

	package Network::Send::Compatibility;
	require Exporter;
	our @ISA = qw(Exporter);
	require Network::Send::ServerType0;
	no strict 'refs';

	our @EXPORT_OK;
	@EXPORT_OK = ();

	my $class = shift;
	if (@_) {
		@EXPORT_OK = @_;
	} else {
		@EXPORT_OK = grep {/^send/} keys(%{Network::Send::ServerType0::});
	}

	foreach my $symbol (@EXPORT_OK) {
		*{$symbol} = sub {
			my $remote_socket = shift;
			my $func = $Globals::messageSender->can($symbol);
			return $func->($Globals::messageSender, @_);
		};
	}
	Network::Send::Compatibility->export_to_level(1, undef, @EXPORT_OK);
}

# Not not call this method directly, use create() instead.
sub new {
	my ($class) = @_;
	return bless {}, $class;
}

##
# int $NetworkSend->{serverType}
#
# The server type for this message sender object, as passed to the
# create() method.

##
# Network::Send->create(net, int serverType)
# net: An object compatible with the '@MODULE(Network)' class.
# serverType: A server type.
#
# Create a new message sender object for the specified server type.
#
# Throws Network::Send::ServerTypeNotSupported if the specified server type
# is not supported.
# Throws Network::Send::CreationException if the server type is supported, but the
# message sender object cannot be created.
sub create {
	my (undef, $net, $serverType) = @_;

	my $class = "Network::Send::ServerType" . int($serverType);
	eval("use $class;");
	if ($@ =~ /Can\'t locate/) {
		Network::Send::ServerTypeNotSupported->throw(error => "Server type '$serverType' not supported.");
	} elsif ($@) {
		die $@;
	}

	my $instance = eval("new $class;");
	if (!$instance) {
		Network::Send::CreationException->throw(
			error => "Cannot create message sender object for server type '$serverType'.");
	}

	$instance->{net} = $net;
	$instance->{serverType} = $serverType;
	Modules::register($class);

	return $instance;
}

# This is an old method used back in the iRO beta 2 days when iRO had encrypted packets.
# At the moment (December 20 2006) there are no servers that still use encrypted packets.
sub encrypt {
	use bytes;
	my $r_msg = shift;
	my $themsg = shift;
	my @mask;
	my $newmsg;
	my ($in, $out);
	my $temp;
	my $i;

	if ($config{encrypt} == 1 && $conState >= 5) {
		$out = 0;
		for ($i = 0; $i < 13;$i++) {
			$mask[$i] = 0;
		}
		{
			use integer;
			$temp = ($encryptVal * $encryptVal * 1391);
		}
		$temp = ~(~($temp));
		$temp = $temp % 13;
		$mask[$temp] = 1;
		{
			use integer;
			$temp = $encryptVal * 1397;
		}
		$temp = ~(~($temp));
		$temp = $temp % 13;
		$mask[$temp] = 1;
		for($in = 0; $in < length($themsg); $in++) {
			if ($mask[$out % 13]) {
				$newmsg .= pack("C1", int(rand() * 255) & 0xFF);
				$out++;
			}
			$newmsg .= substr($themsg, $in, 1);
			$out++;
		}
		$out += 4;
		$newmsg = pack("v2", $out, $encryptVal) . $newmsg;
		while ((length($newmsg) - 4) % 8 != 0) {
			$newmsg .= pack("C1", (rand() * 255) & 0xFF);
		}
	} elsif ($config{encrypt} >= 2 && $conState >= 5) {
		$out = 0;
		for ($i = 0; $i < 17;$i++) {
			$mask[$i] = 0;
		}
		{
			use integer;
			$temp = ($encryptVal * $encryptVal * 34953);
		}
		$temp = ~(~($temp));
		$temp = $temp % 17;
		$mask[$temp] = 1;
		{
			use integer;
			$temp = $encryptVal * 2341;
		}
		$temp = ~(~($temp));
		$temp = $temp % 17;
		$mask[$temp] = 1;
		for($in = 0; $in < length($themsg); $in++) {
			if ($mask[$out % 17]) {
				$newmsg .= pack("C1", int(rand() * 255) & 0xFF);
				$out++;
			}
			$newmsg .= substr($themsg, $in, 1);
			$out++;
		}
		$out += 4;
		$newmsg = pack("v2", $out, $encryptVal) . $newmsg;
		while ((length($newmsg) - 4) % 8 != 0) {
			$newmsg .= pack("C1", (rand() * 255) & 0xFF);
		}
	} else {
		$newmsg = $themsg;
	}

	$$r_msg = $newmsg;
}

sub injectMessage {
	my ($self, $message) = @_;
	my $name = stringToBytes("|");
	my $msg .= $name . stringToBytes(" : $message") . chr(0);
	encrypt(\$msg, $msg);
	$msg = pack("C*",0x09, 0x01) . pack("v*", length($name) + length($message) + 12) . pack("C*",0,0,0,0) . $msg;
	encrypt(\$msg, $msg);
	$self->{net}->clientSend($msg);
}

sub injectAdminMessage {
	my ($self, $message) = @_;
	$message = stringToBytes($message);
	$message = pack("C*",0x9A, 0x00) . pack("v*", length($message)+5) . $message .chr(0);
	encrypt(\$message, $message);
	$self->{net}->clientSend($message);
}

sub sendToServer {
	my ($self, $msg) = @_;
	my $net = $self->{net};

	# Old plugins still send a non-existant $remote_socket. Unless we fix
	# this, it'll cause unblessed reference errors and halt openkore.
	#$r_net = $net if (!defined($r_net) || ref($r_net) eq ""
	#		  || ref($r_net) eq 'SCALAR');

	return unless ($net->serverAlive);
	if ($self->{serverType} != 2) {
		encrypt(\$msg, $msg);
	}

	my $messageID = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));

	my $hookname = "packet_send/$messageID";
	# FIXME: this is ugly and may not even always work.
	my $hook = $Plugins::hooks{$hookname}->[0];
	if ($hook && $hook->{r_func} &&
	    $hook->{r_func}($hookname, {switch => $messageID, data => $msg}, $hook->{user_data})) {
		return;
	}

	$net->serverSend($msg);
	$bytesSent += length($msg);

	if ($config{debugPacket_sent} && !existsInList($config{debugPacket_exclude}, $messageID)) {
		my $label = $packetDescriptions{Send}{$messageID} ?
			" - $packetDescriptions{Send}{$messageID}" : '';
		if ($config{debugPacket_sent} == 1) {
			debug("Packet Switch SENT: $messageID$label\n", "sendPacket", 0);
		} else {
			Misc::visualDump($msg, $messageID.$label);
		}
	}
}

1;

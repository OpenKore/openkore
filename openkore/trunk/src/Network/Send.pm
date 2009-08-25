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
use Carp::Assert;

use Exception::Class ('Network::Send::ServerTypeNotSupported', 'Network::Send::CreationException');

use Globals qw(%config $encryptVal $bytesSent $conState %packetDescriptions $enc_val1 $enc_val2);
use I18N qw(stringToBytes);
use Utils qw(existsInList);
use Misc;
use Log qw(debug);

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
			if (!$func) {
				die "No such function: $symbol";
			} else {
				return $func->($Globals::messageSender, @_);
			}
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
	my (undef, $net, $type) = @_;

	my $mode = 0; # Mode is Old by Default
	my $class = "Network::Send::ServerType0";
	my $param;

	# Remove Blanks
	$type =~ s/^\s//;
	$type =~ s/\s$//;

	$type = 0 if $type eq '';

	# Type checking
	if ($type =~ /^([0-9_]+)/) {
		# Old ServerType
		($type) = $type =~ /([0-9_]+)/;
		$type = 0 if $type eq '';
		$class = "Network::Send::ServerType" . $type;
	} else {
		# New ServerType based on Server name
		my ($real_type) = $type =~ /^([a-zA-Z0-9]+)_/;
		$class = "Network::Send::" . $real_type;
		my ($real_version) = $type =~ /_([a-zA-Z0-9_]+)/;
		#debug "$real_type <-> $real_version\n";
		$type = $real_type;
		$param = $real_version;
		$param = undef if ($real_version eq '');
		$mode = 1;
	}

	eval("use $class;");
	if ($@ =~ /Can\'t locate/) {
		Network::Send::ServerTypeNotSupported->throw(error => "Server type '$type' not supported.");
	} elsif ($@) {
		die $@;
	}

	my $instance;
	if ($mode == 1) {
		$instance = $class->create($param);
	} else {
		$instance = $class->new();
	}
	if (!$instance) {
		Network::Send::CreationException->throw(
			error => "Cannot create message sender object for server type '$type'.");
	}

	$instance->{net} = $net;
	$instance->{serverType} = $type;
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

sub encryptMessageID {
	use bytes;
	my ($self, $r_message) = @_;

	if ($self->{net}->getState() != Network::IN_GAME) {
		$enc_val1 = 0;
		$enc_val2 = 0;
		return;
	}

	my $messageID = unpack("v", $$r_message);
	if ($enc_val1 != 0 && $enc_val2 != 0) {
		# Prepare encryption
		$enc_val1 = (0x000343FD * $enc_val1) + $enc_val2;
		$enc_val1 = $enc_val1 % 2 ** 32;
		debug (sprintf("enc_val1 = %x", $enc_val1) . "\n", "sendPacket", 2);
		# Encrypt message ID
		$messageID = $messageID ^ (($enc_val1 >> 16) & 0x7FFF);
		$messageID &= 0xFFFF;
		$$r_message = pack("v", $messageID) . substr($$r_message, 2);
	}
}

sub injectMessage {
	my ($self, $message) = @_;
	my $name = stringToBytes("|");
	my $msg .= $name . stringToBytes(" : $message") . chr(0);
	# encrypt(\$msg, $msg);

	# Packet Prefix Encryption Support
	#$self->encryptMessageID(\$msg);

	$msg = pack("C*", 0x09, 0x01) . pack("v*", length($name) + length($message) + 12) . pack("C*",0,0,0,0) . $msg;
	## encrypt(\$msg, $msg);
	$self->{net}->clientSend($msg);
}

sub injectAdminMessage {
	my ($self, $message) = @_;
	$message = stringToBytes($message);
	$message = pack("C*",0x9A, 0x00) . pack("v*", length($message)+5) . $message .chr(0);
	# encrypt(\$message, $message);

	# Packet Prefix Encryption Support
	#$self->encryptMessageID(\$message);
	$self->{net}->clientSend($message);
}

sub sendToServer {
	my ($self, $msg) = @_;
	my $net = $self->{net};

	shouldnt(length($msg), 0);
	return unless ($net->serverAlive);

	my $messageID = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));

	my $hookName = "packet_send/$messageID";
	if (Plugins::hasHook($hookName)) {
		my %args = (
			switch => $messageID,
			data => $msg
		);
		Plugins::callHook($hookName, \%args);
		return if ($args{return});
	}

	# encrypt(\$msg, $msg);

	# Packet Prefix Encryption Support
	$self->encryptMessageID(\$msg);

	$net->serverSend($msg);
	$bytesSent += length($msg);

	if ($config{debugPacket_sent} && !existsInList($config{debugPacket_exclude}, $messageID)) {
		my $label = $packetDescriptions{Send}{$messageID} ?
			"[$packetDescriptions{Send}{$messageID}]" : '';
		if ($config{debugPacket_sent} == 1) {
			debug(sprintf("Sent packet    : %-4s    [%2d bytes]  %s\n", $messageID, length($msg), $label), "sendPacket", 0);
		} else {
			Misc::visualDump($msg, ">> Sent packet: $messageID  $label");
		}
	}
}

1;

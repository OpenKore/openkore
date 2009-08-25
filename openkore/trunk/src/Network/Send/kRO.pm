#########################################################################
#  OpenKore - Packet sending
#  This module contains functions for sending packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 6687 $
#  $Id: kRO.pm 6687 2009-04-19 19:04:25Z technologyguild $
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO
package Network::Send::kRO;

use strict;
use encoding 'utf8';
use Carp::Assert;

use Network::Send ();
use base qw(Network::Send);

use Exception::Class ('Network::Send::kRO::ServerTypeNotSupported', 'Network::Send::kRO::CreationException');

use Misc;
use Log qw(debug);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

##
# Network::Send->create(net, serverType)
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
	my (undef, $serverType) = @_;

	my $class = "Network::Send::kRO::" . $serverType;

	eval("use $class;");
	if ($@ =~ /Can\'t locate/) {
		Network::Send::kRO::ServerTypeNotSupported->throw(error => "Server type '$serverType' not supported.");
	} elsif ($@) {
		die $@;
	}

	my $instance = eval("new $class;");
	if (!$instance) {
		Network::Send::kRO::CreationException->throw(
			error => "Cannot create message sender object for server type '$serverType'.");
	}

	# $instance->{net} = $net;
	# $instance->{serverType} = $serverType;
	# Modules::register($class);

	return $instance;
}

# SEEMS LIKE LOGIN PACKETS ARE MISSING!! SO I HAVE PUT THEM HERE
use Globals qw($masterServer);
# missing packets
sub sendMasterLogin {
	my ($self, $username, $password, $master_version, $version) = @_;
	my $msg = pack("v1 V", hex($masterServer->{masterLogin_packet}) || 0x64, $version) .
			pack("a24", $username) .
			pack("a24", $password) .
			pack("C*", $master_version);
	$self->sendToServer($msg);
}

sub sendGameLogin {
	my ($self, $accountID, $sessionID, $sessionID2, $sex) = @_;
	my $msg = pack("v1", hex($masterServer->{gameLogin_packet}) || 0x65) . $accountID . $sessionID . $sessionID2 . pack("C*", 0, 0, $sex);
	if (hex($masterServer->{gameLogin_packet}) == 0x0273 || hex($masterServer->{gameLogin_packet}) == 0x0275) {
		my ($serv) = $masterServer->{ip} =~ /\d+\.\d+\.\d+\.(\d+)/;
		$msg .= pack("x16 C1 x3", $serv);
	}
	$self->sendToServer($msg);
	debug "Sent sendGameLogin\n", "sendPacket", 2;
}

sub sendCharLogin {
	my ($self, $char) = @_;
	my $msg = pack("C*", 0x66,0) . pack("C*",$char);
	$self->sendToServer($msg);
}

1;
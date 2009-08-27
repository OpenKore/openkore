#########################################################################
#  OpenKore - Server message parsing
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Server message parsing
#
# This class is responsible for parsing messages that are sent by the RO
# server to Kore. Information in the messages are stored in global variables
# (in the module Globals).
#
# Please also read <a href="http://www.openkore.com/wiki/index.php/Network_subsystem">the
# network subsystem overview.</a>
package Network::Receive;

use strict;
use encoding 'utf8';
use Carp::Assert;
use Scalar::Util;

use Exception::Class ('Network::Receive::InvalidServerType', 'Network::Receive::CreationError');

use Globals;
#use Settings;
use Log qw(message warning error debug);
#use FileParsers;
use Interface;
use Network;
use Network::MessageTokenizer;
use Misc;
use Plugins;
use Utils;
use Utils::Exceptions;
use Utils::Crypton;
use Translation;

######################################
### Public methods
######################################

# Do not call this directly. Use create() instead.
sub new {
	my ($class) = @_;
	my $self;

	# If you are wondering about those funny strings like 'x2 v1' read http://perldoc.perl.org/functions/pack.html
	# and http://perldoc.perl.org/perlpacktut.html

	# Defines a list of Packet Handlers and decoding information
	# 'packetSwitch' => ['handler function','unpack string',[qw(argument names)]]

	$self->{packet_list} = {};

	return bless $self, $class;
}

##
# Network::Receive->create(String serverType)
#
# Create a new server message parsing object for the specified server type.
#
# Throws Network::Receive::InvalidServerType if the specified server type does
# not exist.
# Throws Network::Receive::CreationError if some other error occured.
sub create {
	my ($self, $type) = @_;
	
	my $mode = 0; # Mode is Old by Default
	my $class = "Network::Receive::ServerType0";
	my $param;

	# Remove Blanks
	$type =~ s/^\s//;
	$type =~ s/\s$//;

	$type = 0 if $type eq '';

	# Type checking
	if ($type =~ /^([0-9_]+)/) {
		# Old ServerType
		($type) = $type =~ /^([0-9_]+)/;
		$class = "Network::Receive::ServerType" . $type;
	} else {
		# New ServerType based on Server name
		my ($real_type) = $type =~ /^([a-zA-Z0-9]+)_/;
		$class = "Network::Receive::" . $real_type;
		my ($real_version) = $type =~ /_([a-zA-Z0-9_]+)/;
		#debug "$real_type <-> $real_version\n";
		$type = $real_type;
		$param = $real_version;
		$param = undef if ($real_version eq '');
		$mode = 1;
	}
	
	undef $@;
	eval("use $class;");
	if ($@ =~ /^Can't locate /s) {
		Network::Receive::InvalidServerType->throw(
			TF("Cannot load server message parser for server type '%s'.", $type)
		);
	} elsif ($@) {
		Network::Receive::CreationError->throw(
			TF("An error occured while loading the server message parser for server type '%s':\n%s",
				$type, $@)
		);
	} else {
		if ($mode == 1) {
			# New ServerType
			return $class->create($param);
		} else {
			# Old ServerType
			return $class->new();
		}
	}
}

# $packetParser->reconstruct($args)
#
# Reconstructs a raw packet from $args using $self->{packet_list}.
sub reconstruct {
	my ($self, $args) = @_;

	my $switch = $args->{switch};
	my $packet = $self->{packet_list}{$switch};
	my ($name, $packString, $varNames) = @{$packet};

	my @vars = ();
	for my $varName (@{$varNames}) {
		push(@vars, $args->{$varName});
	}
	my $packet = pack("H2 H2 $packString", substr($switch, 2, 2), substr($switch, 0, 2), @vars);
	return $packet;
}

sub parse {
	my ($self, $msg) = @_;

	$bytesReceived += length($msg);
	my $switch = Network::MessageTokenizer::getMessageID($msg);
	my $handler = $self->{packet_list}{$switch};

	return undef unless $handler;

	debug "Received packet: $switch Handler: $handler->[0]\n", "packetParser", 2;

	# RAW_MSG is the entire message, including packet switch
	my %args = (
		switch => $switch,
		RAW_MSG => $msg,
		RAW_MSG_SIZE => length($msg)
	);
	if ($handler->[1]) {
		my @unpacked_data = unpack("x2 $handler->[1]", $msg);
		my $keys = $handler->[2];
		foreach my $key (@{$keys}) {
			$args{$key} = shift @unpacked_data;
		}
	}

	my $callback = $self->can($handler->[0]);
	if ($callback) {
		Plugins::callHook("packet_pre/$handler->[0]", \%args);
		Misc::checkValidity("Packet: " . $handler->[0] . " (pre)");
		$self->$callback(\%args);
		Misc::checkValidity("Packet: " . $handler->[0]);
	} else {
		warning "Packet Parser: Unhandled Packet: $switch Handler: $handler->[0]\n";
	}

	Plugins::callHook("packet/$handler->[0]", \%args);
	return \%args;
}

##
# boolean $packetParser->willMangle(Bytes messageID)
# messageID: a message ID, such as "008A".
#
# Check whether the message with the specified message ID will be mangled.
# If the bot is running in X-Kore mode, then messages that will be mangled will not
# be sent to the RO client.
#
# By default, a message will never be mangled. Plugins can register mangling procedures
# though. This is done by using the following hooks:
# `l
# - "Network::Receive/willMangle" - This hook has arguments 'messageID' (Bytes) and 'name' (String).
#          'name' is a human-readable description of the message, and may be undef. Plugins
#          should set the 'return' argument to 1 if they want willMangle() to return 1.
# - "Network::Receive/mangle" - This hook has arguments 'messageArgs' and 'messageName' (the latter may be undef).
# `l`
# The following example demonstrates how this is done:
# <pre class="example">
# Plugins::addHook("Network::Receive/willMangle", \&willMangle);
# Plugins::addHook("Network::Receive/mangle", \&mangle);
#
# sub willMangle {
#     my (undef, $args) = @_;
#     if ($args->{messageID} eq '008A') {
#         $args->{willMangle} = 1;
#     }
# }
#
# sub mangle {
#     my (undef, $args) = @_;
#     my $message_args = $args->{messageArgs};
#     if ($message_args->{switch} eq '008A') {
#         ...Modify $message_args as necessary....
#     }
# }
# </pre>
sub willMangle {
	if (Plugins::hasHook("Network::Receive/willMangle")) {
		my ($self, $messageID) = @_;
		my $packet = $self->{packet_list}{$messageID};
		my $name;
		$name = $packet->[0] if ($packet);

		my %args = (
			messageID => $messageID,
			name => $name
		);
		Plugins::callHook("Network::Receive/willMangle", \%args);
		return $args{return};
	} else {
		return undef;
	}
}

# boolean $packetParser->mangle(Array* args)
#
# Calls the appropriate plugin function to mangle the packet, which
# destructively modifies $args.
# Returns false if the packet should be suppressed.
sub mangle {
	my ($self, $args) = @_;

	my %hook_args = (messageArgs => $args);
	my $entry = $self->{packet_list}{$args->{switch}};
	if ($entry) {
		$hook_args{messageName} = $entry->[0];
	}

	Plugins::callHook("Network::Receive/mangle", \%hook_args);
	return $hook_args{return};
}

##
# Network::Receive->decrypt(r_msg, themsg)
# r_msg: a reference to a scalar.
# themsg: the message to decrypt.
#
# Decrypts the packets in $themsg and put the result in the scalar
# referenced by $r_msg.
#
# This is an old method used back in the iRO beta 2 days when iRO had encrypted packets.
# At the moment (December 20 2006) there are no servers that still use encrypted packets.
#
# Example:
# } elsif ($switch eq "ABCD") {
# 	my $level;
# 	Network::Receive->decrypt(\$level, substr($msg, 0, 2));
sub decrypt {
	use bytes;
	my ($self, $r_msg, $themsg) = @_;
	my @mask;
	my $i;
	my ($temp, $msg_temp, $len_add, $len_total, $loopin, $len, $val);
	if ($config{encrypt} == 1) {
		undef $$r_msg;
		undef $len_add;
		undef $msg_temp;
		for ($i = 0; $i < 13;$i++) {
			$mask[$i] = 0;
		}
		$len = unpack("v1",substr($themsg,0,2));
		$val = unpack("v1",substr($themsg,2,2));
		{
			use integer;
			$temp = ($val * $val * 1391);
		}
		$temp = ~(~($temp));
		$temp = $temp % 13;
		$mask[$temp] = 1;
		{
			use integer;
			$temp = $val * 1397;
		}
		$temp = ~(~($temp));
		$temp = $temp % 13;
		$mask[$temp] = 1;
		for($loopin = 0; ($loopin + 4) < $len; $loopin++) {
 			if (!($mask[$loopin % 13])) {
  				$msg_temp .= substr($themsg,$loopin + 4,1);
			}
		}
		if (($len - 4) % 8 != 0) {
			$len_add = 8 - (($len - 4) % 8);
		}
		$len_total = $len + $len_add;
		$$r_msg = $msg_temp.substr($themsg, $len_total, length($themsg) - $len_total);
	} elsif ($config{encrypt} >= 2) {
		undef $$r_msg;
		undef $len_add;
		undef $msg_temp;
		for ($i = 0; $i < 17;$i++) {
			$mask[$i] = 0;
		}
		$len = unpack("v1",substr($themsg,0,2));
		$val = unpack("v1",substr($themsg,2,2));
		{
			use integer;
			$temp = ($val * $val * 34953);
		}
		$temp = ~(~($temp));
		$temp = $temp % 17;
		$mask[$temp] = 1;
		{
			use integer;
			$temp = $val * 2341;
		}
		$temp = ~(~($temp));
		$temp = $temp % 17;
		$mask[$temp] = 1;
		for($loopin = 0; ($loopin + 4) < $len; $loopin++) {
 			if (!($mask[$loopin % 17])) {
  				$msg_temp .= substr($themsg,$loopin + 4,1);
			}
		}
		if (($len - 4) % 8 != 0) {
			$len_add = 8 - (($len - 4) % 8);
		}
		$len_total = $len + $len_add;
		$$r_msg = $msg_temp.substr($themsg, $len_total, length($themsg) - $len_total);
	} else {
		$$r_msg = $themsg;
	}
}


#######################################
###### Private methods
#######################################

sub queryLoginPinCode {
	my $message = $_[0] || T("You've never set a login PIN code before.\nPlease enter a new login PIN code:");
	do {
		my $input = $interface->query($message, isPassword => 1,);
		if (!defined($input)) {
			quit();
			return;
		} else {
			if ($input !~ /^\d+$/) {
				$interface->errorDialog(T("The PIN code may only contain digits."));
			} elsif ((length($input) <= 3) || (length($input) >= 9)) {
				$interface->errorDialog(T("The PIN code must be between 4 and 9 characters."));
			} else {
				return $input;
			}
		}
	} while (1);
}

sub queryAndSaveLoginPinCode {
	my ($message) = @_;
	my $pin = queryLoginPinCode($message);
	if (defined $pin) {
		configModify('loginPinCode', $pin, silent => 1);
		return 1;
	} else {
		return 0;
	}
}

1;
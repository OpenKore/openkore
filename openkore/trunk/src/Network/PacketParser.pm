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
package Network::PacketParser;

use strict;
use encoding 'utf8';
use Carp::Assert;
use Scalar::Util;

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

### CATEGORY: Hash members

##
# Hash* {packet_list}
#
# A list of packet handlers and decoding information.
#
# 'packet switch' => ['handler function', 'unpack string', [qw(argument names)]]

##
# Hash* {packet_lut}
#
# Lookup table for currently used packet switches.
# Used for constructing packets by handler name.
#
# 'handler function' => 'packet switch'

######################################
### CATEGORY: Class methods
######################################

# Do not call this directly. Use create() instead.
sub new {
	my ($class) = @_;
	my $self;

	# If you are wondering about those funny strings like 'x2 v1' read http://perldoc.perl.org/functions/pack.html
	# and http://perldoc.perl.org/perlpacktut.html

	$self->{packet_list} = {};
	$self->{packet_lut} = {};

	return bless $self, $class;
}

##
# Network::PacketParser->create(Network net, String serverType)
# net: An object compatible with the '@MODULE(Network)' class.
# serverType: A server type.
#
# Create a new server message parsing object for the specified server type.
#
# Throws FileNotFoundException, ModuleLoadException.
sub create {
	my ($base, $net, $serverType) = @_;
	
	my ($mode, $type, $param) = Settings::parseServerType ($serverType);
	my $class = join '::', $base, $type, (($param) || ()); #param like Thor in bRO_Thor
	
	debug "[$base] $class ". " (mode: " . ($mode ? "new" : "old") .")\n";

	undef $@;
	eval("use $class;");
	if ($@ =~ /^Can't locate /s) {
		FileNotFoundException->throw(
			TF("Cannot load server message parser for server type '%s'.", $type)
		);
	} elsif ($@) {
		ModuleLoadException->throw(
			TF("An error occured while loading the server message parser for server type '%s':\n%s",
				$type, $@)
		);
	}
	
	my $self = $class->new;
	
	$self->{hook_prefix} = $base;
	$self->{net} = $net;
	$self->{serverType} = $type; # TODO: eliminate {serverType} from there
	Modules::register($class);
	
	return $self;
}

### CATEGORY: Methods

##
# Bytes $packetParser->reconstruct(Hash* args)
#
# Reconstructs a raw packet from $args using {packet_list} and {packet_lut}.
#
# $args->{switch} may contain a packet switch or a handler name.
sub reconstruct {
	my ($self, $args) = @_;

	my $switch = $args->{switch};
	unless ($switch =~ /^[0-9A-F]{4}$/) {
		# lookup by handler name
		unless (exists $self->{packet_lut}{$switch}) {
			# alternative (if any) isn't set yet, pick the first available
			for (sort {$a cmp $b} keys %{$self->{packet_list}}) {
				if ($self->{packet_list}{$_}[0] eq $switch) {
					$self->{packet_lut}{$switch} = $_;
					last;
				}
			}
		}
		
		$switch = $self->{packet_lut}{$switch} || $switch;
	}

	unless (exists $self->{packet_list}{$switch}) {
		die "Can't reconstruct unknown packet: $switch";
	}

	my $packet = $self->{packet_list}{$switch};
	my ($name, $packString, $varNames) = @{$packet};

	if (my $custom_reconstruct = $self->can('reconstruct_'.$name)) {
		$self->$custom_reconstruct($args);
	}
	my @vars = ();
	for my $varName (@{$varNames}) {
		push(@vars, $args->{$varName});
	}
	my $packet = pack("H2 H2 $packString", substr($switch, 2, 2), substr($switch, 0, 2), @vars);
	
	if (exists $rpackets{$switch}) {
		if ($rpackets{$switch} > 0) {
			# fixed length packet, pad/truncate to the correct length
			# TODO: preprocess %rpackets so it doesn't contain garbage like whitespace
			my $length = $rpackets{$switch};
			$length =~ s/\s//g;
			$packet = pack('a'.$length, $packet);
		} else {
			# variable length packet, store its length in the packet
			substr($packet, 2, 2) = pack('v', length $packet);
		}
	}
	
	return $packet;
}

##
# Hash* $packetParser->parse(Bytes msg)
#
# Parses a raw packet using {packet_list}.
#
# Result hashref would contain parsed arguments and the following information:
# `l
# - switch: packet switch
# - RAW_MSG: original message passed
# - RAW_MSG_SIZE: length of original message passed
# - KEYS: list of argument names from {packet_list}
# `l`
sub parse {
	my ($self, $msg) = @_;

	$bytesReceived += length($msg);
	my $switch = Network::MessageTokenizer::getMessageID($msg);
	my $handler = $self->{packet_list}{$switch};

	unless ($handler) {
		warning "Packet Parser: Unknown switch: $switch\n";
		return undef;
	}

	# set this alternative (if any) as the one in use with that server
	# TODO: permanent storage (with saving)?
	$self->{packet_lut}{$handler->[0]} = $switch;

	debug "Received packet: $switch Handler: $handler->[0]\n", "packetParser", 2;

	# RAW_MSG is the entire message, including packet switch
	my %args = (
		switch => $switch,
		RAW_MSG => $msg,
		RAW_MSG_SIZE => length($msg),
		KEYS => $handler->[2],
	);
	if ($handler->[1]) {
		@args{@{$handler->[2]}} = unpack("x2 $handler->[1]", $msg);
	}
	if (my $custom_parse = $self->can('parse_'.$handler->[0])) {
		$self->$custom_parse(\%args);
	}

	my $callback = $self->can($handler->[0]);
	if ($callback) {
		# Hook names can be made more uniform,
		# but the ones for Receive must be kept for compatibility anyway.
		if ($self->{hook_prefix} eq 'Network::Receive') {
			Plugins::callHook("packet_pre/$handler->[0]", \%args);
		} else {
			Plugins::callHook("$self->{hook_prefix}/packet_pre/$handler->[0]", \%args);
		}
		Misc::checkValidity("Packet: " . $handler->[0] . " (pre)");
		$self->$callback(\%args);
		Misc::checkValidity("Packet: " . $handler->[0]);
	} else {
		warning "Packet Parser: Unhandled Packet: $switch Handler: $handler->[0]\n";
		debug ("Unpacked: " . join(', ', @{\%args}{@{$handler->[2]}}) . "\n"), "packetParser", 2 if $handler->[2];
	}

	if ($self->{hook_prefix} eq 'Network::Receive') {
		Plugins::callHook("packet/$handler->[0]", \%args);
	} else {
		Plugins::callHook("$self->{hook_prefix}/packet/$handler->[0]", \%args);
	}
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
	my ($self, $messageID) = @_;
	if (Plugins::hasHook("$self->{hook_prefix}/willMangle")) {
		my $packet = $self->{packet_list}{$messageID};
		my $name;
		$name = $packet->[0] if ($packet);

		my %args = (
			messageID => $messageID,
			name => $name
		);
		Plugins::callHook("$self->{hook_prefix}/willMangle", \%args);
		return $args{return};
	} else {
		return undef;
	}
}

##
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

	Plugins::callHook("$self->{hook_prefix}/mangle", \%hook_args);
	return $hook_args{return};
}

1;

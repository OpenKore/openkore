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
# Please also read <a href="http://wiki.openkore.com/index.php/Network_subsystem">the
# network subsystem overview.</a>
package Network::PacketParser;

use strict;
use utf8;
use base qw(Exporter);
use Carp::Assert;
use Scalar::Util;
use Time::HiRes qw(time);

use Globals;
#use Settings;
use Log qw(message warning error debug);
#use FileParsers;
use I18N qw(bytesToString stringToBytes);
use Interface;
use Network;
use Network::MessageTokenizer;
use Misc;
use Plugins;
use Utils;
use Utils::Exceptions;
use Utils::Crypton;
use Translation;

our @EXPORT = qw(
	ACTION_ATTACK ACTION_ITEMPICKUP ACTION_SIT ACTION_STAND
	ACTION_ATTACK_NOMOTION ACTION_SPLASH ACTION_SKILL ACTION_ATTACK_REPEAT
	ACTION_ATTACK_MULTIPLE ACTION_ATTACK_MULTIPLE_NOMOTION
	ACTION_ATTACK_CRITICAL ACTION_ATTACK_LUCKY ACTION_TOUCHSKILL
	STATUS_STR STATUS_AGI STATUS_VIT STATUS_INT STATUS_DEX STATUS_LUK
);

### CATEGORY: Ragnarok Online constants

use constant {
	ACTION_ATTACK => 0x0,
	ACTION_ITEMPICKUP => 0x1, # pick up item
	ACTION_SIT => 0x2, # sit down
	ACTION_STAND => 0x3, # stand up
	ACTION_ATTACK_NOMOTION => 0x4, # reflected/absorbed damage?
	ACTION_SPLASH => 0x5,
	ACTION_SKILL => 0x6,
	ACTION_ATTACK_REPEAT => 0x7,
	ACTION_ATTACK_MULTIPLE => 0x8, # double attack
	ACTION_ATTACK_MULTIPLE_NOMOTION => 0x9, # don't display flinch animation (endure)
	ACTION_ATTACK_CRITICAL => 0xa, # critical hit
	ACTION_ATTACK_LUCKY => 0xb, # lucky dodge
	ACTION_TOUCHSKILL => 0xc,
	STATUS_STR => 0x0d,
	STATUS_AGI => 0x0e,
	STATUS_VIT => 0x0f,
	STATUS_INT => 0x10,
	STATUS_DEX => 0x11,
	STATUS_LUK => 0x12,
};

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
	$self->{bytesProcessed} = 0;

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
				if ($self->{packet_list}{$_} && $self->{packet_list}{$_}[0] eq $switch) {
					$self->{packet_lut}{$switch} = $_;
					last;
				}
			}
		}
		
		$switch = $self->{packet_lut}{$switch} || $switch;
	}

	unless ($self->{packet_list}{$switch}) {
		die "Can't reconstruct unknown packet: $switch";
	}

	my $packet = $self->{packet_list}{$switch};
	my ($name, $packString, $varNames) = @{$packet};

	if (my $custom_reconstruct = $self->can('reconstruct_'.$name)) {
		$self->$custom_reconstruct($args);
	}

	if (DEBUG && $config{debugAssertOnNetwork}) {
		# check if all values we're going to pack are defined
		for (@$varNames) {
			assert(defined $args->{$_}, "Argument $_ should be defined for packet $name");
		}
	}

	my $packet = pack("v $packString", hex $switch, $packString && @{$args}{@$varNames});
	
	if (exists $rpackets{$switch}) {
		if ($rpackets{$switch}{length} > 0) {
			# fixed length packet, pad/truncate to the correct length
			$packet = pack('a'.(0+$rpackets{$switch}{length}), $packet);
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
	my ($self, $msg, $handleContainer, @handleArguments) = @_;

	$lastSwitch = Network::MessageTokenizer::getMessageID($msg);
	my $handler = $self->{packet_list}{$lastSwitch};

	unless ($handler) {
		warning "Packet Parser: Unknown switch: $lastSwitch\n";
		return undef;
	}

	# $handler->[0] may be (re)binded to $switch here for current serverType
	# but all the distinct packets need a distinct names for that, even if they share the handler
	# like actor_display = actor_exists + actor_connected + actor_moved
	# if (DEBUG) {
	# 	unless ($self->{packet_lut}{$handler->[0]} eq $switch) {
	# 		$self->{packet_lut}{$handler->[0]} = $switch;
	# 		if ((grep { $_ && $_->[0] eq $handler->[0] } values %{$self->{packet_list}}) > 1) {
	# 			warning sprintf "Using %s to provide %s\n", $switch, $handler->[0];
	# 		}
	# 	}
	# }

	debug "Received packet: $lastSwitch Handler: $handler->[0]\n", "packetParser", 2;

	# RAW_MSG is the entire message, including packet switch
	my %args = (
		switch => $lastSwitch,
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

	my $callback = $handleContainer->can($handler->[0]);
	if ($callback) {
		# Hook names can be made more uniform,
		# but the ones for Receive must be kept for compatibility anyway.
		# TODO: restrict to $Globals::packetParser and $Globals::messageSender?
		if ($self->{hook_prefix} eq 'Network::Receive') {
			Plugins::callHook("packet_pre/$handler->[0]", \%args);
		} else {
			Plugins::callHook("$self->{hook_prefix}/packet_pre/$handler->[0]", \%args);
		}
		Misc::checkValidity("Packet: " . $handler->[0] . " (pre)");

		# If return is set in a packet_pre handler, the packet will be ignored.
		unless($args{return}) {
			$handleContainer->$callback(\%args, @handleArguments);
		}

		Misc::checkValidity("Packet: " . $handler->[0]);
	} else {
		$handleContainer->unhandledMessage(\%args, @handleArguments);
	}

	if ($self->{hook_prefix} eq 'Network::Receive') {
		Plugins::callHook("packet/$handler->[0]", \%args);
	} else {
		Plugins::callHook("$self->{hook_prefix}/packet/$handler->[0]", \%args);
	}
	return \%args;
}

sub unhandledMessage {
	my ($self, $args) = @_;
	
	warning "Packet Parser: Unhandled Packet: $args->{switch} Handler: $self->{packet_list}{$args->{switch}}[0]\n";
	debug ("Unpacked: " . join(', ', @{$args}{@{$args->{KEYS}}}) . "\n"), "packetParser", 2 if $args->{KEYS};
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
#
# You can also mangle packets by defining $args->{mangle} in other plugin hooks. The options avalable are:
# `l
# - 0 = no mangle
# - 1 = mangle (change packet and reconstruct)
# - 2 = drop
# `l`
# The following example will drop all public chat messages:
# <pre class="example">
# Plugins::addHook("packet_pre/public_chat", \&mangleChat);
#
# sub mangleChat
# {
#	my(undef, $args) = @_;
#	$args->{mangle} = 2;
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

sub process {
	my ($self, $tokenizer, $handleContainer, @handleArguments) = @_;
	
	my @result;
	my $type;
	while (my $message = $tokenizer->readNext(\$type)) {
		$handleContainer->{bytesProcessed} += length($message);
		$handleContainer->{lastPacketTime} = time;
		
		my $args;
		
		if ($type == Network::MessageTokenizer::KNOWN_MESSAGE) {
			my $switch = Network::MessageTokenizer::getMessageID($message);
			
			# FIXME?
			$self->parse_pre($handleContainer->{hook_prefix}, $switch, $message);
			
			my $willMangle = $handleContainer->can('willMangle') && $handleContainer->willMangle($switch);
			
			if ($args = $self->parse($message, $handleContainer, @handleArguments)) {
				$args->{mangle} ||= $willMangle && $handleContainer->mangle($args);
			} else {
				$args = {
					switch => $switch,
					RAW_MSG => $message,
					(mangle => 2) x!! $willMangle,
				};
			}
			
		} elsif ($type == Network::MessageTokenizer::ACCOUNT_ID) {
			$args = {
				RAW_MSG => $message
			};
			
		} elsif ($type == Network::MessageTokenizer::UNKNOWN_MESSAGE) {
			$args = {
				switch => Network::MessageTokenizer::getMessageID($message),
				RAW_MSG => $message,
				# RAW_MSG_SIZE => length($message),
			};
			$handleContainer->unknownMessage($args, @handleArguments);
			
		} else {
			die "Packet Tokenizer: Unknown type: $type";
		}
		
		unless ($args->{mangle}) {
			# Packet was not mangled
			push @result, $args->{RAW_MSG};
			#$result .= $args->{RAW_MSG};
		} elsif ($args->{mangle} == 1) {
			# Packet was mangled
			push @result, $self->reconstruct($args);
			#$result .= $self->reconstruct($args);
		} else {
			# Packet was suppressed
		}
	}
	
	# If we're running in X-Kore mode, pass messages back to the RO client.
	
	# It seems like messages can't be just concatenated safely
	# (without "use bytes" pragma or messing with unicode stuff)
	# http://perldoc.perl.org/perlunicode.html#The-%22Unicode-Bug%22
	return @result;
}

sub parse_pre {
	my ($self, $mode, $switch, $msg) = @_;
	my $values = {
		'Network::Receive' => ['<< Received packet:', 'received', 'Recv', 'parseMsg/pre'],
		'Network::ClientReceive' => ['<< Sent by RO client:', 'ro_sent', 'ROSend', 'RO_sendMsg_pre'],
	}->{$mode} or return;
	my ($title, $config_suffix, $desc_key, $hook) = @$values;
	
	if ($config{'debugPacket_'.$config_suffix} && !existsInList($config{'debugPacket_exclude'}, $switch) ||
		$config{'debugPacket_include_dumpMethod'} && existsInList($config{'debugPacket_include'}, $switch))
	{
		#my $label = $packetDescriptions{$desc_key}{$switch} ? " - $packetDescriptions{$desc_key}{$switch}" : '';
		my $label = $rpackets{$switch}{function}?" - ".$rpackets{$switch}{function}:($packetDescriptions{$desc_key}{$switch} ? " - $packetDescriptions{$desc_key}{$switch}" : '');
		if ($config{'debugPacket_'.$config_suffix} == 1) {
			debug sprintf("%-24s %-4s%s [%2d bytes]%s\n", $title, $switch, $label, length($msg)), 'parseMsg', 0;
		} elsif ($config{'debugPacket_'.$config_suffix} == 2) {
			Misc::visualDump($msg, sprintf('%-24s %-4s%s', $title, $switch, $label));
		}
		if ($config{debugPacket_include_dumpMethod} == 1) {
			debug sprintf("%-24s %-4s%s\n", $title, $switch, $label), "parseMsg", 0;
		} elsif ($config{debugPacket_include_dumpMethod} == 2) {
			Misc::visualDump($msg, sprintf('%-24s %-4s%s', $title, $switch, $label));
		} elsif ($config{debugPacket_include_dumpMethod} == 3) {
			Misc::dumpData($msg, 1);
		} elsif ($config{debugPacket_include_dumpMethod} == 4) {
			open my $dump, '>>', 'DUMP_LINE.txt';
			print $dump unpack('H*', $msg) . "\n";
		} elsif ($config{debugPacket_include_dumpMethod} == 5) {
			open my $dump, '>>', 'DUMP_HEAD.txt';
			print $dump sprintf("%-4s %2d %s%s\n", $switch, length($msg), $desc_key, $label);
		}
	}
	
	Plugins::callHook($hook, {switch => $switch, msg => $msg, msg_size => length($msg), realMsg => \$msg});
}

sub unknownMessage {
	my ($self, $args) = @_;
	
	# Unknown message - ignore it
	unless (existsInList($config{debugPacket_exclude}, $args->{switch})) {
		warning TF("Packet Tokenizer: Unknown switch: %s\n", $args->{switch}), 'connection';
		Misc::visualDump($args->{RAW_MSG}, "<< Received unknown packet") if $config{debugPacket_unparsed};
	}
	
	# Pass it along to the client, whatever it is
}

# Utility methods used by both Receive and Send

sub parseChat {
	my ($self, $args) = @_;
	$args->{message} = bytesToString($args->{message});
	if ($args->{message} =~ /^(.*?)\s{1,2}:\s{1,2}(.*)$/) {
		$args->{name} = $1;
		$args->{message} = $2;
		Misc::stripLanguageCode(\$args->{message});
	}
	if (exists $args->{ID}) {
		$args->{actor} = Actor::get($args->{ID});
	}
}

sub reconstructChat {
	my ($self, $args) = @_;
	$args->{message} = '|00' . $args->{message} if $masterServer->{chatLangCode};
	$args->{message} = stringToBytes($char->{name}) . ' : ' . stringToBytes($args->{message});
}

1;

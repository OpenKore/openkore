#########################################################################
#  OpenKore - Networking subsystem
#  This module contains functions for sending packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Conversion of byte stream to descrete messages.
#
# As explained by the <a href="http://wiki.openkore.com/index.php/Network_subsystem">
# network subsystem overview</a>, the Ragnarok Online protocol uses TCP, which means
# that all server messages are received as a byte stream.
# This class is specialized in extracting discrete RO server or client messages from a byte
# stream.
package Network::MessageTokenizer;

use strict;
use Carp::Assert;
use Modules 'register';
use bytes;
no encoding 'utf8';
use enum qw(KNOWN_MESSAGE UNKNOWN_MESSAGE ACCOUNT_ID);

##
# Network::MessageTokenizer->new(Hash* rpackets)
# rpackets: A reference to a hash containing the packet length database.
# Required: defined($rpackets)
#
# Create a new Network::MessageTokenizer object.
sub new {
	my ($class, $rpackets) = @_;
	assert(defined $rpackets) if DEBUG;
	#Log::warning (Data::Dumper::Dumper($rpackets)."\n");
	my %self = (
		
		rpackets => $rpackets,
		buffer => ''
	);
	return bless \%self, $class;
}

##
# void $Network_MessageTokenizer->add(Bytes data)
# Requires: defined($data)
#
# Add raw data to this tokenizer's buffer.
sub add {
	my ($self, $data) = @_;
	assert(defined $data) if DEBUG;
	$self->{buffer} .= $data;
}

##
# void $Network_MessageTokenizer->clear([int size])
# Requires: size >= 0
#
# Clear the internal buffer. If $size is given, only the first $size
# bytes are removed.
sub clear {
	my ($self, $size) = @_;
	if (defined $size) {
		substr($_[0]->{buffer}, 0, $size, '');
	} else {
		$_[0]->{buffer} = '';
	}
}

##
# void $Network_MessageTokenizer->nextMessageMightBeAccountID()
#
# Tell this tokenizer that the next message might be the account ID.
sub nextMessageMightBeAccountID {
	my ($self) = @_;
	$self->{nextMessageMightBeAccountID} = 1;
}

##
# String Network::MessageTokenizer::getMessageID(Bytes message)
# Requires: length($message) >= 2
#
# Extract the message ID (also known as the "packet switch") from the given message.
sub getMessageID {
	uc join '', unpack '@1H2 @0H2', $_[0]
}

##
# Bytes $Network->MessageTokenizer->getBuffer()
# Ensures: defined(result)
#
# Get the internal buffer.
sub getBuffer {
	return $_[0]->{buffer};
}

##
# Bytes $Network_MessageTokenizer->readNext(int* type)
#
# Read the next full message from the buffer, if there is one.
# If not, undef will be returned.
#
# The message's type will be returned via the type parameter.
# It will be one of:
# `l
# - KNOWN_MESSAGE - This is a known message, i.e. we know its length.
# - UNKNOWN_MESSAGE - This is an unknown message, i.e. we don't know its length.
# - ACCOUNT_ID - This is an account ID.
# `l`
sub readNext {
	my ($self, $type) = @_;
	my $buffer = \$self->{buffer};

	return undef if (length($$buffer) < 2);

	my $switch = getMessageID($$buffer);
	my $rpackets = $self->{rpackets};
	my $size = $rpackets->{$switch}{length};
	
	my $result;
	
	#Log::warning sprintf("Packet %s %d %d \n", $switch, $rpackets->{$switch}{length}, $size);

	my $nextMessageMightBeAccountID = $self->{nextMessageMightBeAccountID};
	$self->{nextMessageMightBeAccountID} = undef;

	if ($nextMessageMightBeAccountID) {
		if (length($$buffer) >= 4) {
			
		$result = substr($$buffer, 0, 4);
		if (unpack("V1",$result) == unpack("V1",$Globals::accountID)) {
				substr($$buffer, 0, 4, '');
				$$type = ACCOUNT_ID;
			} else {
				# Account ID is "hidden" in a packet (0283 is one of them)
				return $self->readNext($type);
			}
		
		} else {
			$self->{nextMessageMightBeAccountID} = $nextMessageMightBeAccountID;
		}

	} elsif ($size > 1) {
		# Static length message.
		if (length($$buffer) >= $size) {
			$result = substr($$buffer, 0, $size);
			substr($$buffer, 0, $size, '');
			$$type = KNOWN_MESSAGE;
		}

	} elsif (
		defined($size)
		and $size == 0 # old Kore convention
		|| $size == -1 # packet extractor v3
	) {
		# Variable length message.
		if (length($$buffer) >= 4) {
			$size = unpack("v", substr($$buffer, 2, 2));
			if (length($$buffer) >= $size) {
				$result = substr($$buffer, 0, $size, '');
				$$type = KNOWN_MESSAGE;
			}
		}

	} else {
		$result = $$buffer;
		$self->{buffer} = '';
		$$type = UNKNOWN_MESSAGE;
	}
	return $result;
}

# ragnarok servers
sub slicePacket {
	my ($self, $data, $additional_data) = @_;
	# temporary hack for new recvpackets format
	my $switch = getMessageID($data);
	my $real_length = $self->{rpackets}{$switch}{length};	
	my $packet;
	if (($real_length > 0) # packet size is not variable
			&& (length($data) > $real_length)) { 
		$packet = substr($data, 0, $real_length);
		$$additional_data = substr($data, $real_length); # sliced data
	} else { # packet is at correct size
		$packet = $data;
		$$additional_data = undef;
	}
	return $packet; # real packet
}

1;

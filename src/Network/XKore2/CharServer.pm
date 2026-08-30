#########################################################################
#  OpenKore - X-Kore Mode 2
#  Copyright (c) 2007 OpenKore developers
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Character server implementation.

package Network::XKore2::CharServer;

use strict;
use Globals qw($char $masterServer);
use Base::Ragnarok::CharServer;
use base qw(Base::Ragnarok::CharServer);
use Network::MessageTokenizer;

# The browser always requests character-list pages with 0x09A1.  Keep this
# client-facing request available even while the shared server metadata is
# being refreshed between account and character connections.
sub getClientPacketTable {
	my ($self) = @_;
	my %packets = %{ $self->SUPER::getClientPacketTable() || {} };
	$packets{'09A1'} = { length => 2 };
	if ($self->{sendPacketParser}
		&& !$self->{sendPacketParser}{packet_list}{'09A1'}) {
		$self->{sendPacketParser}{packet_list}{'09A1'} =
			['sync_received_characters'];
	}
	return \%packets;
}

# Overrided method.
sub getCharacters {
	my ($self, $session) = @_;
	my @chars;
	if (!$session->{dummy} && $char) {
		#for (my $i = 0; $i < 5; $i++) {
		#	push @chars, $char;
		#}
		push @chars, $char;
	} else {
		$session->{dummy} = 1;
		for (my $i = 0; $i < 5; $i++) {
			push @chars, Base::Ragnarok::CharServer::DUMMY_CHARACTER;
		}
	}
	return @chars;
}

sub charBlockSize {
	my ($self) = @_;
	if ($masterServer) {
		return $masterServer->{charBlockSize} || $self->{charBlockSize} || 106;
	} else {
		return $self->SUPER::charBlockSize();
	}
}

# A browser character page request can be classified as unknown when a custom
# recvpackets table is stale, or as known-but-unhandled when the sender table
# lacks the corresponding callback.  Both cases are recoverable in XKore2:
# the client is already authenticated and only needs the character page.
sub _recoverCharacterList {
	my ($self, $args, $client) = @_;
	return 0 unless $client && $client->{session};

	my $switch = uc($args && $args->{switch} ? $args->{switch} : '');
	my $selection_state = ($client->{session}{state} || '') eq 'About to select character';
	return 0 unless $switch eq '09A1' || ($selection_state && $self->modern_character_list_for_client($client));

	my $ok = eval {
		$self->sendCharInfo($args || {}, $client);
		1;
	};
	if (!$ok) {
		$client->{xkore2_last_charlist_error} = $@ || 'character list recovery failed';
		# Keep the client protocol synchronized even when the receive parser has
		# no usable character-layout metadata.  A zero-entry variable-length page
		# is legal and lets the client remain on the character screen so a later
		# retry can succeed; closing here would turn a recoverable parser fault
		# into a disconnect.
		my $fallback_switch = $self->character_list_switch_for_client($client);
		if ($fallback_switch eq '099D' || $fallback_switch eq '0B72') {
			$client->send(pack('v v', hex($fallback_switch), 4));
			$client->{xkore2_charlist_fallback} = 1;
			return 1;
		}
		return 0;
	}
	return 1;
}

# Keep an authenticated XKore2 character connection alive when a packet is
# not present in the active client table.  In the modern character-selection
# state, answer the page request immediately instead of letting the base class
# close the socket.
sub unknownMessage {
	my ($self, $args, $client) = @_;
	return if $self->_recoverCharacterList($args, $client);
	if ($client) {
		$client->{xkore2_last_unknown_switch} = uc($args && $args->{switch} ? $args->{switch} : '');
		$client->{xkore2_last_unknown_size} = length($args && $args->{RAW_MSG} ? $args->{RAW_MSG} : '');
	}
}

sub unhandledMessage {
	my ($self, $args, $client) = @_;
	return if $self->_recoverCharacterList($args, $client);
	if ($client) {
		$client->{xkore2_last_unhandled_switch} = uc($args && $args->{switch} ? $args->{switch} : '');
		$client->{xkore2_last_unhandled_size} = length($args && $args->{RAW_MSG} ? $args->{RAW_MSG} : '');
	}
}

# PacketParser exceptions used to escape Base::Server::iterate and leave the
# browser with a cleanly closed socket but no character data.  XKore2 keeps the
# connection usable, records the error for diagnostics, and retries the page
# response when the failing frame belongs to character selection.
sub onClientData {
	my ($self, $client, $data, @rest) = @_;
	my $ok = eval {
		$self->SUPER::onClientData($client, $data, @rest);
		1;
	};
	return if $ok;

	$client->{xkore2_last_parse_error} = $@ || 'client packet parser failed';
	$client->{tokenizer}->clear() if $client->{tokenizer};
	my $switch = length($data || '') >= 2
		? Network::MessageTokenizer::getMessageID($data)
		: '';
	$self->_recoverCharacterList({
		switch => $switch,
		RAW_MSG => $data,
	}, $client);
}

1;


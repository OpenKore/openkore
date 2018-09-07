#########################################################################
#  OpenKore - Network subsystem
#  This module contains functions for sending messages to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# tRO (Thai) for 2008-09-16Ragexe12_Th
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Send::ServerType21;

use strict;
use base qw(Network::Send::ServerType0);

use Log qw(debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %handlers = qw(
		character_move 0085
	);
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	return $self;
}

sub sendMove {
	my ($self, $x, $y) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'character_move',
		x => $x,
		y => $y,
		no_padding => 1,
	}));
	
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

sub sendHomunculusMove {
	my ($self, $homunID, $x, $y) = @_;
	
	$self->sendToServer($self->reconstruct({
		switch => 'actor_move',
		ID => $homunID,
		x => $x,
		y => $y,
		no_padding => 1,
	}));
	
	debug "Sent Homunculus move to: $x, $y\n", "sendPacket", 2;
}

1;
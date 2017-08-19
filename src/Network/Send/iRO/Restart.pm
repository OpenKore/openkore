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
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Send::iRO::Restart;

use strict;
use base qw(Network::Send::iRO);

sub new {
	my ( $class ) = @_;
	my $self = $class->SUPER::new( @_ );

	my %packets = (
		'48FF' => [ 'actor_info_request', 'a4', [qw(ID)] ],
		'49A3' => [ 'actor_look_at', 'v C', [qw(head body)] ],
		'49B0' => [ 'character_move', 'a3', [qw(coords)] ],
		'4AD0' => [ 'sync', 'V', [qw(time)] ],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_info_request 48FF
		actor_look_at 49A3
		character_move 49B0
		sync 4AD0
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{packet_sequence} = {
		'48FF' => [qw( 5EDF 0C7F )],
		'49B0' => [qw( 300D 69B0 )],
		'4AD0' => [qw( FC50 0E50 48D0 72D0 6AD0 )],
	};

	return $self;
}

1;

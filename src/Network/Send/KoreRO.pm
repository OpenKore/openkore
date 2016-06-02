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
package Network::Send::KoreRO;

use strict;

use Network::Send::iRO;
use base qw( Network::Send::iRO );

sub new {
    my ( $class ) = @_;
    my $self = $class->SUPER::new( @_ );

    my %packets = ();
    $self->{packet_list}{$_} = $packets{$_} for keys %packets;

    my %handlers = qw(
    );
    $self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

    return $self;
}

sub sendCharCreate {
    my ( $self, $slot, $name, $hair_style, $hair_color ) = @_;
    $hair_color ||= 1;
    $hair_style ||= 0;

    my $msg
        = pack( "C*", 0x70, 0x09 )
        . pack( "a24", stringToBytes( $name ) )
        . pack( "C*",  $slot )
        . pack( "v*",  $hair_color, $hair_style );
    $self->sendToServer( $msg );
}

1;

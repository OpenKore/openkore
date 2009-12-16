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

# this is an experimental class
# this serverType is used for kRO Sakray RE
# basically when we don't know where to put a new packet, we put it here and move it to the right class later

package Network::Receive::kRO::RagexeRE_0;

use strict;
use Network::Receive::kRO::RagexeRE_2009_11_03a;
use base qw(Network::Receive::kRO::RagexeRE_2009_11_03a);

use Log qw(message warning error debug);

use Globals qw($captcha_state);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		# HackShield alarm
		'0449' => ['hack_shield_alarm'],
	
		'07E6' => ['captcha_session_ID', 'v V', [qw(ID generation_time)]], # 8
	);
	
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

sub captcha_session_ID {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

=pod
07E5 8
07E6 8
07E7 32
07E8 0
07E9 5
=cut

1;
#########################################################################
#  OpenKore - Packet Receiveing
#  This module contains functions for Receiveing packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http:#//www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 6687 $
#  $Id: kRO.pm 6687 2009-04-19 19:04:25Z technologyguild $
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Receive::kRO::RagexeRE_2010_06_29a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2010_06_22a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'00AA' => ['equip_item', 'v3 C', [qw(index type viewID success)]], # 9
	);
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	# TODO: what is the unknown field? (related to the equipview system?)
	$self->{nested}{items_nonstackable}{type3} = {
		len => 28,
		types => 'v2 C2 v2 C2 a8 l v2',
		keys => [qw(index nameID type identified type_equip equipped broken upgrade cards expire bindOnEquipType unknown)],
	};

	return $self;
}
=pod
//2010-06-29aRagexeRE
0x00AA,9
//0x07F1,18
//0x07F2,8
//0x07F3,6
=cut

1;
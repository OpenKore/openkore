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

package Network::Receive::kRO::Sakexe_2008_11_26a;

use strict;
#use Network::Receive::kRO::Sakexe_2008_11_13a;
use base qw(Network::Receive::kRO::Sakexe_2008_11_13a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'01A2' => ['pet_info', 'Z24 C v5', [qw(name renameflag level hungry friendly accessory type)]], # 37
		# 0x0440,10
		# 0x0441,4
	);
	
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

=pod
//2008-11-26aSakexe
0x01a2,37
0x0440,10
0x0441,4
=cut

1;
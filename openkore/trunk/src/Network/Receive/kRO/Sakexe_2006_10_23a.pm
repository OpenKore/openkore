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

package Network::Receive::kRO::Sakexe_2006_10_23a;

use strict;
use Network::Receive::kRO::Sakexe_2006_03_27a;
use base qw(Network::Receive::kRO::Sakexe_2006_03_27a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new();
	$self->{packet_list} = {
		'006D' => ['character_creation_successful', 'a4 V9 v17 Z24 C6 v2', [qw(ID exp zeny exp_job lv_job opt1 opt2 option karma manner points_free hp hp_max sp sp_max walk_speed type hair_style weapon lv points_skill lowhead shield tophead midhead hair_color clothes_color name str agi vit int dex luk slot renameflag)]], # 110
	};
	return $self;
}

=pod
//2006-10-23aSakexe
0x006d,110
=cut

1;
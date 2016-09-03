#########################################################################
#  OpenKore - Packet Receiveing
#  This module contains functions for Receiveing packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Receive::kRO::RagexeRE_2014_10_22b;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2013_08_07a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0A18' => ['map_loaded', 'V a3 x2 v', [qw(syncMapSync coords unknown)]],
		'084B' => ['item_appeared', 'a4 v2 C v2 C2 v', [qw(ID nameID type identified x y subx suby amount)]],
		'08B9' => ['login_pin_code_request2', 'V a4 v', [qw(seed accountID flag)]],
		'006D' => ['character_creation_successful', 'a4 V9 v V2 v15 Z24 C6 v2 Z16 V5', [qw(ID exp zeny exp_job lv_job opt1 opt2 option stance manner points_free hp hp_max sp sp_max walk_speed type hair_style body weapon lv points_skill lowhead shield tophead midhead hair_color clothes_color name str agi vit int dex luk slot renameflag map deleteDate robe slotMove addons sex)]],
	);

	foreach my $switch (keys %packets) { $self->{packet_list}{$switch} = $packets{$switch}; }

	return $self;
}



1;
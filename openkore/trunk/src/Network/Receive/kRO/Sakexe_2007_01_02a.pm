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

package Network::Receive::kRO::Sakexe_2007_01_02a;

use strict;
use Network::Receive::kRO::Sakexe_2006_10_23a;
use base qw(Network::Receive::kRO::Sakexe_2006_10_23a);

use Log qw(message warning error debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		# 0x023e,8
		# 0x0277,84
		# 0x0278,2
		# 0x0279,2
		# 0x027a,-1
		# 0x027b,14
		# 0x027c,60
		# 0x027d,62
		# 0x027e,-1
		# 0x027f,8
		# 0x0280,12
		# 0x0281,4
		# 0x0282,284
		'0283' => ['account_id', 'V', [qw(accountID)]], # 6
		# 0x0284,14
		# 0x0285,6
		# 0x0286,4
		'0287' => ['cash_dealer'], # -1
		# 0x0288,6
		# 0x0289,8
		'028A' => ['character_status', 'a4 V3', [qw(ID option lv opt3)]], # 18
		# 0x028b,-1
		# 0x028c,46
		# 0x028d,34
		# 0x028e,4
		# 0x028f,6
		# 0x0290,4
		'0291' => ['message_string', 'v', [qw(msg_id)]], # 4

		'0293' => ['boss_map_info', 'C V2 v2 x4 Z40 C11', [qw(flag x y hours minutes name unknown)]], # 70
		'0294' => ['book_read', 'a4 a4', [qw(bookID page)]], # 10
		'0295' => ['inventory_items_nonstackable'], # -1
		'0296' => ['storage_items_nonstackable'], # -1
		'0297' => ['cart_items_nonstackable'], # -1
		'0298' => ['rental_time', 'v V', [qw(nameID seconds)]], # 8
		'0299' => ['rental_expired', 'v2', [qw(unknown nameID)]], # 6
		'029A' => ['inventory_item_added', 'v3 C3 a8 v C2 a4', [qw(index amount nameID identified broken upgrade cards type_equip type fail cards_ext)]], # 27
		# 0x029c,66
		'029D' => ['skills_list'], # -1 # mercenary skills
		# 0x029e,11

		# 0x02a0,0
		# 0x02a1,0
		# 0x02a2,8
	);
	
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

=pod
//2006-04-24aSakexe to 2007-01-02aSakexe
0x023e,8
0x0277,84
0x0278,2
0x0279,2
0x027a,-1
0x027b,14
0x027c,60
0x027d,62
0x027e,-1
0x027f,8
0x0280,12
0x0281,4
0x0282,284
0x0283,6
0x0284,14
0x0285,6
0x0286,4
0x0287,-1
0x0288,6
0x0289,8
0x028a,18
0x028b,-1
0x028c,46
0x028d,34
0x028e,4
0x028f,6
0x0290,4
0x0291,4
0x0292,2,autorevive,0
0x0293,70
0x0294,10
0x0295,-1
0x0296,-1
0x0297,-1
0x0298,8
0x0299,6
0x029a,27
0x029c,66
0x029d,-1
0x029e,11
0x029f,3,mermenu,0
0x02a0,0
0x02a1,0
0x02a2,8
=cut

1;
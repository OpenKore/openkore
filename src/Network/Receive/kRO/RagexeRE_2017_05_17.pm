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

package Network::Receive::kRO::RagexeRE_2017_05_17;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2015_12_02);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0AC4' => ['account_server_info', 'x2 a4 a4 a4 a4 a26 C x17 a*', [qw(sessionID accountID sessionID2 lastLoginIP lastLoginTime accountSex serverInfo)]],
		'0087' => ['character_moves', 'a4 a6', [qw(move_start_time coords)]], # 12
		'0A37' => ['inventory_item_added', 'a2 v2 C3 a8 V C2 a4 v a25', [qw(ID amount nameID identified broken upgrade cards type_equip type fail expire unknown options)]],
	);

	foreach my $switch (keys %packets) { $self->{packet_list}{$switch} = $packets{$switch}; }

	return $self;
}

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
########################################################################
package Network::Send::kRO::RagexeRE_2014_10_22b;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2013_08_07a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'093B' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'023B' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'094E' => ['item_take', 'a4', [qw(ID)]],
		'087D' => ['item_drop', 'v2', [qw(index amount)]],
		'0878' => ['storage_item_add', 'v V', [qw(index amount)]],
		'08AA' => ['storage_item_remove', 'v V', [qw(index amount)]],
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		map_login 093B
		skill_use_location 023B
		item_take 094E
		item_drop 087D
		storage_item_add 0878
		storage_item_remove 08AA
	);
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	$self->cryptKeys(688214506, 761751195, 731196533);

	return $self;
}

1;
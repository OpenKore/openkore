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
# tRO (Thai) for 2008-09-16Ragexe12_Th
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Send::twRO;

use strict;
use Globals;
use Network::Send::ServerType0;
use base qw(Network::Send::ServerType0);
use Log qw(error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'0819' => ['buy_bulk_buyer', 'x2 a4 a4 v a*', [qw(buyerID buyingStoreID zeny itemInfo)]],
		);
	
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}
	my %handlers = qw(
		character_move 035F
		sync 0360
		actor_look_at 0361
		item_take 0362
		item_drop 0363
		storage_item_add 0364
		storage_item_remove 0365
		skill_use_location 0366
		actor_info_request 0368
		buy_bulk_vender 0801
		party_setting 07D7
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	return $self;
}

1;
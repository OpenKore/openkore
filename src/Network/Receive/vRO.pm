#########################################################################
#  OpenKore - Network subsystem
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# vRO (Vietnam)
# Servertype overview: https://openkore.com/wiki/ServerType
package Network::Receive::vRO;

use strict;
use base qw(Network::Receive::ServerType0);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'009E' => ['item_appeared', 'a4 v2 C v2 C2 v', [qw(ID nameID type identified x y subx suby amount)]],
		'009D' => ['item_exists', 'a4 V C v3 C2', [qw(ID nameID identified x y amount subx suby)]],
		'0110' => ['skill_use_failed', 'v V2 C2', [qw(skillID btype nameID fail type)]],
		'0A0A' => ['storage_item_added', 'a2 V V C4 a16 a25', [qw(ID amount nameID type identified broken upgrade cards options)]],
		'0A37' => ['inventory_item_added', 'a2 v V C3 a16 V C2 a4 v a25 C v', [qw(ID amount nameID identified broken upgrade cards type_equip type fail expire unknown options favorite viewID)]],
		'0B07' => ['account_server_info', 'v a4 a4 a4 a4 a26 C a*', [qw(len sessionID accountID sessionID2 lastLoginIP lastLoginTime accountSex serverInfo)]],
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	my %handlers = qw(
		account_server_info 0B07
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{buying_store_items_list_pack} = "V v C V";
	$self->{npc_store_info_pack} = "V V C V";
	$self->{rodex_read_mail_item_pack} = "v V C3 a16 a4 C a4 a25";
	$self->{vender_items_list_item_pack} = 'V v2 C V C3 a16 a25 V v';

	return $self;
}

1;

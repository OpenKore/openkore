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

package Network::Receive::kRO::RagexeRE_2013_03_20;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2012_06_18a);
use Globals qw (%ai_v $char %charSvrSet %equipSlot_lut %equipSlot_rlut %equipTypes_lut $messageSender $net %timeout);
use Log qw (message warning);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'020D' => ['character_block_info', 'v2 a*', [qw(len unknown)]],
		'082D' => ['received_characters_info', 'x2 C5 x20', [qw(normal_slot premium_slot billing_slot producible_slot valid_slot)]],
		'084B' => ['item_appeared', 'a4 v2 C v4', [qw(ID nameID unknown1 identified x y unknown2 amount)]], # 19 TODO   provided by try71023, modified sofax222
		'0992' => ['inventory_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'0999' => ['equip_item', 'v V v C', [qw(index type viewID success)]], #11
		'099A' => ['unequip_item', 'v V C', [qw(index type success)]],#9
#		'099B' => ['map_property', 'v a*', [qw(type info_table)]], # -1 # int[] mapInfoTable 
		'09A0' => ['sync_received_characters', 'v a*', [qw(len sync_Count)]],
	);
	
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

sub sync_received_characters {
	my ($self, $args) = @_;

	$charSvrSet{sync_Count} = $args->{sync_Count} if (exists $args->{sync_Count});

	unless ($net->clientAlive) {
		for (1..$args->{sync_Count}) {
			$messageSender->sendToServer($messageSender->reconstruct({switch => 'sync_received_characters'}));
		}
	}
}
sub received_characters_info {
	my ($self, $args) = @_;

	$charSvrSet{normal_slot} = $args->{normal_slot} if (exists $args->{normal_slot});
	$charSvrSet{premium_slot} = $args->{premium_slot} if (exists $args->{premium_slot});
	$charSvrSet{billing_slot} = $args->{billing_slot} if (exists $args->{billing_slot});
	$charSvrSet{producible_slot} = $args->{producible_slot} if (exists $args->{producible_slot});
	$charSvrSet{valid_slot} = $args->{valid_slot} if (exists $args->{valid_slot});

	$timeout{charlogin}{time} = time;
}

sub parse_items_nonstackable {
	my ($self, $args) = @_;
	$self->parse_items($args, $self->items_nonstackable($args), sub {
		my ($item) = @_;
		$item->{amount} = 1 unless ($item->{amount});
#message "1 nameID = $item->{nameID}, flag = $item->{flag} >> ";
		if ($item->{flag} == 0) {
			$item->{broken} = $item->{identified} = 0;
		} elsif ($item->{flag} == 1 || $item->{flag} == 5) {
			$item->{broken} = 0;
			$item->{identified} = 1;
		} elsif ($item->{flag} == 3 || $item->{flag} == 7) {
			$item->{broken} = $item->{identified} = 1;
		} else {
			message T ("Warning: unknown flag!\n");
		}
#message "2 broken = $item->{broken}, identified = $item->{identified}\n";
	})
}

sub parse_items_stackable {
	my ($self, $args) = @_;
	$self->parse_items($args, $self->items_stackable($args), sub {
		my ($item) = @_;
		$item->{idenfitied} = $item->{identified} & (1 << 0);
		if ($item->{flag} == 0) {
			$item->{identified} = 0;
		} elsif ($item->{flag} == 1 || $item->{flag} == 3) {
			$item->{identified} = 1;
		} else {
			message T ("Warning: unknown flag!\n");
		}
	})
}

sub equip_item {
	my ($self, $args) = @_;
	my $item = $char->inventory->getByServerIndex($args->{index});
	if ($args->{success}) {
		message TF("You can't put on %s (%d)\n", $item->{name}, $item->{invIndex});
	} else {
		$item->{equipped} = $args->{type};
		if ($args->{type} == 10 || $args->{type} == 32768) {
			$char->{equipment}{arrow} = $item;
		} else {
			foreach (%equipSlot_rlut){
				if ($_ & $args->{type}){
					next if $_ == 10; # work around Arrow bug
					next if $_ == 32768;
					$char->{equipment}{$equipSlot_lut{$_}} = $item;
				}
			}
		}
		message TF("You equip %s (%d) - %s (type %s)\n", $item->{name}, $item->{invIndex},
			$equipTypes_lut{$item->{type_equip}}, $args->{type}), 'inventory';
	}
	$ai_v{temp}{waitForEquip}-- if $ai_v{temp}{waitForEquip};
}

1;

=pod
//2013-03-20Ragexe (Judas)
packet_ver: 30
0x01FD,15,repairitem,2
0x086D,26,friendslistadd,2
0x0897,5,hommenu,2:4
0x0947,36,storagepassword,0
//0x0288,-1,cashshopbuy,4:8
0x086F,26,partyinvite2,2
0x0888,19,wanttoconnection,2:6:10:14:18
0x08c9,4
0x088E,7,actionrequest,2:6
0x089B,10,useskilltoid,2:4:6
0x0881,5,walktoxy,2
0x0363,6,ticksend,2
0x093F,5,changedir,2:4
0x0933,6,takeitem,2
0x0438,6,dropitem,2:4
0x08AC,8,movetokafra,2:4
0x0874,8,movefromkafra,2:4
0x0959,10,useskilltopos,2:4:6:8
0x085A,90,useskilltoposinfo,2:4:6:8:10
0x0898,6,getcharnamerequest,2
0x094C,6,solvecharname,2
0x0907,5,moveitem,2:4
0x0908,5
0x08CF,10 //Amulet spirits
0x08d2,10
0x0977,14 //Monster HP Bar
0x0998,8,equipitem,2:4
//0x0281,-1,itemlistwindowselected,2:4:8
0x0938,-1,reqopenbuyingstore,2:4:8:9:89
//0x0817,2,reqclosebuyingstore,0
//0x0360,6,reqclickbuyingstore,2
0x0922,-1,reqtradebuyingstore,2:4:8:12
0x094E,-1,searchstoreinfo,2:4:5:9:13:14:15
//0x0835,2,searchstoreinfonextpage,0
//0x0838,12,searchstoreinfolistitemclick,2:6:10
=cut
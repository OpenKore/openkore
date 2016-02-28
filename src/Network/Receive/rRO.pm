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
# rRO-Phoenix (Russia)
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Receive::rRO;

use strict;
use base 'Network::Receive::ServerType0';
use Globals qw(%ai_v $char %equipSlot_lut %equipSlot_rlut %equipTypes_lut %items_lut);
use Log qw(message debug warning);
use Misc qw(center itemName);
use Translation;
use Utils qw(formatNumber swrite);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
		'0990' => ['inventory_item_added', 'v3 C3 a8 V C2 V v', [qw(index amount nameID identified broken upgrade cards type_equip type fail expire bindOnEquipType)]],#31
		'0991' => ['inventory_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'0992' => ['inventory_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'0993' => ['cart_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'0994' => ['cart_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'0995' => ['storage_items_stackable', 'v Z24 a*', [qw(len title itemInfo)]],#-1
		'0996' => ['storage_items_nonstackable', 'v Z24 a*', [qw(len title itemInfo)]],#-1
		'0908' => ['inventory_item_favorite', 'v C', [qw(index flag)]],#5
		'0997' => ['show_eq', 'v Z24 v7 v C a*', [qw(len name jobID hair_style tophead midhead lowhead robe hair_color clothes_color sex equips_info)]],#-1
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	$self->{nested} = {
		items_nonstackable => { # EQUIPMENTITEM_EXTRAINFO
			type6 => {
				len => 31,
				types => 'v2 C V2 C a8 l v2 C',
				keys => [qw(index nameID type type_equip equipped upgrade cards expire bindOnEquipType sprite_id flag)],
			},
		},
		items_stackable => { # ITEMLIST_NORMAL_ITEM
			type6 => {
				len => 24,
				types => 'v2 C v V a8 l C',
				keys => [qw(index nameID type amount type_equip cards expire flag)],
			},
		},
	};
	return $self;
}

sub items_nonstackable {
	my ($self, $args) = @_;

	my $items = $self->{nested}->{items_nonstackable};

	if ($args->{switch} eq '0992' ||# inventory
		$args->{switch} eq '0994' ||# cart
		$args->{switch} eq '0996'	# storage
	) {
		return $items->{type6};
	} else {
		warning "items_nonstackable: unsupported packet ($args->{switch})!\n";
	}
}

sub items_stackable {
	my ($self, $args) = @_;

	my $items = $self->{nested}->{items_stackable};

	if ($args->{switch} eq '0991' ||# inventory
		$args->{switch} eq '0993' ||# cart
		$args->{switch} eq '0995'	# storage
	) {
		return $items->{type6};

	} else {
		warning "items_stackable: unsupported packet ($args->{switch})!\n";
	}
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

sub inventory_item_favorite {
	my ($self, $args) = @_;
	my $item = $char->inventory->getByServerIndex($args->{index});
	if ($args->{flag}) {
		message TF("Inventory Item removed from favorite tab: %s\n", $item), "storage";
	} else {
		message TF("Inventory Item move to favorite tab: %s\n", $item), "storage";
	}
}

sub show_eq {
	my ($self, $args) = @_;
	my $jump = 31;
	my $unpack_string  = "v2 C V2 C a8 l v2 C";
	for (my $i = 0; $i < length($args->{equips_info}); $i += $jump) {
		my ($index, $ID, $type, $type_equip, $equipped, $upgrade, $cards,
			$expire, $bindOnEquipType, $sprite_id, $identified) = unpack($unpack_string, substr($args->{equips_info}, $i));

		my $item = {};
		$item->{index} = $index;
		$item->{nameID} = $ID;
		$item->{type} = $type;
		$item->{identified} = $identified;
		$item->{type_equip} = $type_equip;
		$item->{equipped} = $equipped;
		$item->{upgrade} = $upgrade;
		$item->{cards} = $cards;
		$item->{expire} = $expire;
		message sprintf("%-20s: %s\n", $equipTypes_lut{$item->{equipped}}, itemName($item)), "list";
		debug "$index, $ID, $type, $identified, $type_equip, $equipped, $upgrade, $cards, $expire\n";
	}
}

1;
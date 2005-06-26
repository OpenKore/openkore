#########################################################################
#  OpenKore - WxWidgets Interface
#  Player/monster/item list control
#
#  Copyright (c) 2004 OpenKore development team 
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#
#  $Revision$
#  $Id$
#
#########################################################################
package Interface::Wx::ItemList;

use strict;
use Wx ':everything';
use base qw(Wx::ListCtrl);
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED EVT_LIST_ITEM_RIGHT_CLICK);
use File::Spec;


our $monsterColor;
our $itemColor;
our $npcColor;


sub new {
	my $class = shift;
	my $parent = shift;
	my $self = $class->SUPER::new($parent, 622, wxDefaultPosition, wxDefaultSize,
		wxLC_REPORT | wxLC_VIRTUAL | wxLC_SINGLE_SEL);

	if (!$monsterColor) {
		$monsterColor = new Wx::Colour(200, 0, 0);
		$itemColor = new Wx::Colour(0, 0, 200);
		$npcColor = new Wx::Colour(103, 0, 162);
	}

	$self->{objectsID} = [];
	$self->{objects} = {};
	$self->InsertColumn(0, "Players, Monsters & Items");
	$self->SetColumnWidth(0, -2);# unless ($^O eq 'MSWin32');
	EVT_LIST_ITEM_ACTIVATED($self, 622, \&_onActivate);
	EVT_LIST_ITEM_RIGHT_CLICK($self, 622, \&_onRightClick);
	return $self;
}

sub _onActivate {
	my $self = shift;
	my $event = shift;
	if ($self->{activate}) {
		my $i = $event->GetIndex;
		my $ID = $self->{objectsID}[$i];
		$self->{activate}->($self->{class}, $ID, $self->{objects}{$ID}, $self->{objects}{$ID}{type});
	}
}

sub _onRightClick {
	my ($self, $event) = @_;
	my $ID = $self->{objectsID}[$event->GetIndex];

	if ($ID && $self->{rightClick}) {
		my $obj = $self->{objects}{$ID};
		$self->{rightClick}->($self->{rightClickClass}, $ID, $obj, $obj->{type}, $self, $event);
	}
}

sub onActivate {
	my $self = shift;
	($self->{activate}, $self->{class}) = @_;
}

sub onRightClick {
	my $self = shift;
	($self->{rightClick}, $self->{rightClickClass}) = @_;
}

sub OnGetItemText {
	my ($self, $item, $column) = @_;
	my $ID = $self->{objectsID}[$item];
	my $objects = $self->{objects};

	# Some people get a weird "can't coerce array into hash" error
	# for some reason, so check the reference type.
	if ($ID) {
		my $f;

		if ($objects && ref($objects) eq 'HASH' && $objects->{$ID} && ref($objects->{$ID}) eq 'HASH') {
			return $self->{objects}{$ID}{name};

		} else {
			my $file = File::Spec->catfile($Settings::logs_folder, "debug.txt");
			if (open($f, ">> $file")) {
				# Wrong type; why?? Write to debugging log.
				require Data::Dumper;
				print $f "index = $item\n";
				print $f "ID = " . unpack("L", $ID) . "\n";
				print $f "\n";
				print $f Data::Dumper::Dumper($objects);
				print $f "\n--------------------------\n\n";
				close $f;
				Log::warning("Internal error detected. Please submit a bug report and attach the file $file.\n");
				$::interface->{chatLog}->add("Internal error detected. Please submit a bug report and attach the file $file.\n", "warning");
			}
		}
	}
	return "";
}

sub OnGetItemAttr {
	my ($self, $item) = @_;
	my $ID = $self->{objectsID}[$item];

	my $attr = new Wx::ListItemAttr;
	if (!$ID || !$self->{objects} || ref($self->{objects}) ne 'HASH' || !$self->{objects}{$ID} || ref($self->{objects}{$ID}) ne 'HASH') {
		return $attr;
	} elsif ($self->{objects}{$ID}{type} eq 'm') {
		$attr->SetTextColour($monsterColor);
	} elsif ($self->{objects}{$ID}{type} eq 'i') {
		$attr->SetTextColour($itemColor);
	} elsif ($self->{objects}{$ID}{type} eq 'n') {
		$attr->SetTextColour($npcColor);
	}
	return $attr;
}

sub OnGetItemImage {
	return 0;
}

sub set {
	my $self = shift;

	my @objectsID;
	my %objects;

	my $r_playersID = shift;
	my $players = shift;
	foreach (@{$r_playersID}) {
		next if (!$_ || !$players->{$_});
		push @objectsID, $_;
		$objects{$_} = {%{$players->{$_}}};
		$objects{$_}{type} = 'p';
	}

	my $r_monstersID = shift;
	my $monsters = shift;
	foreach (@{$r_monstersID}) {
		next if (!$_ || !$monsters->{$_});
		push @objectsID, $_;
		$objects{$_} = {%{$monsters->{$_}}};
		$objects{$_}{type} = 'm';
	}

	my $r_itemsID = shift;
	my $items = shift;
	foreach (@{$r_itemsID}) {
		next if (!$_ || !$items->{$_});
		push @objectsID, $_;
		$objects{$_} = {%{$items->{$_}}};
		$objects{$_}{type} = 'i';
	}

	my $r_npcsID = shift;
	my $npcs = shift;
	foreach (@{$r_npcsID}) {
		next if (!$_ || !$npcs->{$_});
		push @objectsID, $_;
		$objects{$_} = {%{$npcs->{$_}}};
		$objects{$_}{type} = 'n';
	}

	$self->{objectsID} = \@objectsID;
	$self->{objects} = \%objects;
	$self->SetItemCount(scalar(@objectsID)) if (scalar(@objectsID) != $self->GetItemCount);
	$self->RefreshItems(0, -1);
}

1;

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
use Scalar::Util;

use Translation qw/T TF/;

sub new {
	my $class = shift;
	my $parent = shift;
	my $self = $class->SUPER::new($parent, 622, wxDefaultPosition, wxDefaultSize,
		wxLC_REPORT | wxLC_VIRTUAL | wxLC_SINGLE_SEL);

	$self->InsertColumn(0, T("Players, Monsters & Items"));
	$self->SetColumnWidth(0, -2);
	EVT_LIST_ITEM_ACTIVATED($self, 622, \&_onActivate);
	EVT_LIST_ITEM_RIGHT_CLICK($self, 622, \&_onRightClick);
	return $self;
}

sub DESTROY {
	my $lists = $_[0]->{lists};
	foreach my $l (@{$lists}) {
		my $actorList = $l->{actorList};
		$actorList->onAdd()->remove($l->{addID});
		$actorList->onRemove()->remove($l->{removeID});
		$actorList->onClearBegin()->remove($l->{clearBeginID});
		$actorList->onClearEnd()->remove($l->{clearEndID});
	}
}

sub init {
	my $self = shift;
	my @lists;
	for (my $i = 0; $i < @_; $i += 2) {
		my $actorList = $_[$i];
		my $color = $_[$i + 1];
		my $addID = $actorList->onAdd()->add($self, \&_onAdd);
		my $removeID = $actorList->onRemove()->add($self, \&_onRemove);
		my $clearBeginID = $actorList->onClearBegin()->add($self, \&_onClearBegin);
		my $clearEndID = $actorList->onClearEnd()->add($self, \&_onClearEnd);
		push @lists, { actorList => $actorList, color => $color,
			       addID => $addID, removeID => $removeID,
			       clearBeginID => $clearBeginID, clearEndID => $clearEndID };
	}
	$self->{lists} = \@lists;
	$self->{onNameChangeCallbacks} = {};
}

# Set the item count of this list to the total number of actors in the observed ActorLists.
sub _setItemCount {
	my ($self) = @_;
	my $actorCount = 0;
	my $lists = $_[0]->{lists};

	foreach my $l (@{$lists}) {
		$actorCount += $l->{actorList}->size();
	}

	$self->SetItemCount($actorCount) if ($actorCount != $self->GetItemCount);
}

# Return the Actor that is associated with index $index in this list.
sub _getActorForIndex {
	my ($self, $index) = @_;
	my $minIndex = 0;
	my $lists = $_[0]->{lists};

	foreach my $l (@{$lists}) {
		my $actorList = $l->{actorList};
		if ($index >= $minIndex && $index < $minIndex + $actorList->size()) {
			return $actorList->getItems()->[$index - $minIndex];
		} else {
			$minIndex += $actorList->size();
		}
	}
	return undef;
}


sub _onAdd {
	my ($self, undef, $arg) = @_;
	my ($actor, $index) = @{$arg};
	my $addr = Scalar::Util::refaddr($actor);
	$self->DeleteAllItems;
	my $ID = $actor->onNameChange->add($self, \&_onNameChange);
	$self->{onNameChangeCallbacks}{$addr} = $ID;

	$self->_setItemCount();
	$self->RefreshItems(0, -1);
}

sub _onRemove {
	my ($self, undef, $arg) = @_;
	my ($actor, $index) = @{$arg};
	my $addr = Scalar::Util::refaddr($actor);
	$self->DeleteAllItems;
	my $ID = $self->{onNameChangeCallbacks}{$addr};
	$actor->onNameChange->remove($ID);
	delete $self->{onNameChangeCallbacks}{$addr};

	$self->_setItemCount();
	$self->RefreshItems(0, -1);
}

sub _onClearBegin {
	my ($self, $actorList) = @_;
	my $actors = $actorList->getItems();

	foreach my $actor (@{$actors}) {
		my $addr = Scalar::Util::refaddr($actor);
		my $ID = $self->{onNameChangeCallbacks}{$addr};
		$actor->onNameChange->remove($ID);
		delete $self->{onNameChangeCallbacks}{$addr};
	}
}

sub _onClearEnd {
	my ($self) = @_;
	$self->_setItemCount();
	$self->RefreshItems(0, -1);
}

sub _onNameChange {
	my ($self) = @_;
	$self->_setItemCount();
	$self->RefreshItems(0, -1);
}


sub _onActivate {
	my ($self, $event) = @_;
	if ($self->{activate}) {
		my $i = $event->GetIndex;
		my $actor = $self->_getActorForIndex($i);
		$self->{activate}->($self->{class}, $actor);
	}
}

sub _onRightClick {
	my ($self, $event) = @_;
	my $actor = $self->_getActorForIndex($event->GetIndex);

	if ($actor && $self->{rightClick}) {
		$self->{rightClick}->($self->{rightClickClass}, $actor, $self, $event);
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
	my $actor = $self->_getActorForIndex($item);
	my $acnam = "$actor->{name}";
	if ($acnam eq "") {
		$acnam = $actor->name;
	}
	my $info = "$acnam($actor->{pos_to}{x},$actor->{pos_to}{y})";
	if ($actor) {
		return $info;
	} else {
		return "";
	}
}

sub OnGetItemAttr {
	my ($self, $item) = @_;
	my $attr = new Wx::ListItemAttr;
	my $actor = $self->_getActorForIndex($item);

	if ($actor) {
		foreach my $l (@{$self->{lists}}) {
			my $actorList = $l->{actorList};
			if ($actorList->getByID($actor->{ID})) {
				$attr->SetTextColour($l->{color}) if ($l->{color});
				last;
			}
		}
	}
	return $attr;
}

sub OnGetItemImage {
	return 0;
}

1;

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

use Globals qw/%equipTypes_lut/;

use Translation qw/T TF/;

sub new {
	my ($class, $parent, $title) = @_;
	my $self = $class->SUPER::new($parent, wxID_ANY, wxDefaultPosition, wxDefaultSize,
		wxLC_REPORT | wxLC_VIRTUAL | wxLC_SINGLE_SEL | wxLC_NO_HEADER);

	$self->InsertColumn (0, T('ID'));
	$self->InsertColumn (1, $title || T('Actors'));
	$self->SetColumnWidth (0, 44);
	$self->SetColumnWidth (1, 350);
	EVT_LIST_ITEM_ACTIVATED($self, $self->GetId, \&_onActivate);
	EVT_LIST_ITEM_RIGHT_CLICK($self, $self->GetId, \&_onRightClick);
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

	if ($self->{lists}) {
		$self->DESTROY;
	}

	$self->{lists} = [];
	$self->{onNameChangeCallbacks} = {};
	for (my $i = 0; $i < @_; $i += 2) {
		my $actorList = $_[$i];
		my $color = $_[$i + 1];
		my $addID = $actorList->onAdd()->add($self, \&_onAdd);
		my $removeID = $actorList->onRemove()->add($self, \&_onRemove);
		my $clearBeginID = $actorList->onClearBegin()->add($self, \&_onClearBegin);
		my $clearEndID = $actorList->onClearEnd()->add($self, \&_onClearEnd);
		push @{$self->{lists}}, { actorList => $actorList, color => $color,
			       addID => $addID, removeID => $removeID,
			       clearBeginID => $clearBeginID, clearEndID => $clearEndID };

		# add already existing actors
		for my $actor (@{$actorList->getItems}) {
			$self->_onAdd(undef, [$actor, $actor->{binID}]);
		}
	}
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
			return $actorList->[$index - $minIndex];
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
	my $ID = $actor->onNameChange->add($self, \&_onChange);
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

	foreach my $actor (@$actorList) {
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

sub _onChange {
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
	return '' unless $actor;

	my $info = '';

	if ($column == 0) {
		$info = $actor->{binID};
	} elsif ($column == 1) {
		$info = $actor->name;

		if ($actor->{pos_to}) {
			$info = "$info ($actor->{pos_to}{x},$actor->{pos_to}{y})";
		}

		if ($actor->{equipped}) {
			$info = TF("%s (equipped as %s)", $info, $equipTypes_lut{$actor->{equipped}} || $actor->{equipped});
		}

		if (defined $actor->{identified} and !$actor->{identified}) {
			$info = TF("%s (not identified)", $info);
		}

		if (defined $actor->{amount}) {
			# Translation Comment: Item with amount ("10 x Blue Herb...")
			$info = TF("%d x %s", $actor->{amount}, $info);
		}
	}

	$info
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

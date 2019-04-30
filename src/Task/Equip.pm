#########################################################################
#  OpenKore - Equip item task
#  Copyright (c) 2019 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Equip item task.
#
# This task is specialized in equipping one or more items
# - Retry to use the skill if it doesn't start within a time limit.
# - Handle errors gracefully.

package Task::Equip;

use strict;
use Scalar::Util;

use Globals qw(%timeout $net);
use Log qw(debug);
use Plugins;
use Task;
use Translation qw(T TF);

use base qw(Task);

use enum qw(
	MAX_ATTEMPTS
	ITEM_MISSING
);

sub new {
	my ($class, $args) = @_;
	
	assert($args->{item}, "Can't spawn new Task::Equip without an Item to equip");
	assertClass($args->{item}, "Actor::Item");
	assert($args->{item}->equippable(), sprintf("Item %s is not equippable", $args->{item}->nameString()));
	
	my $self = $class->SUPER::new($args);
	
	$self->{item} = Scalar::Util::weaken($args->{item});
	$self->{slot} = $args->{slot} if $args->{slot};
	$self->{retry} = $args->{retry} || 3;
	$self->{timeout}->{timeout} = $args->{timeout} || 1.5;
	
	return $self;
}

sub activate {
	my ($self) = @_;
	
	my $weakSelf = Scalar::Util::weaken($self);
	
	$self->{equippedItemHook} = Plugins::addHook('equipped_item', \&equippedItem, $weakSelf) unless exists $self->{equippedItemHook};
	$self->{equipFailHook} = Plugins::addHook('equip_item_fail', \&equipFail, $weakSelf) unless exists $self->{equipFailHook};
	
	$self->{attempts} = 0;
	
	$self->SUPER::activate();
}

sub stop {
	my ($self) = @_;
	
	Plugins::delHook($self->{equippedItemHook}) if exists $self->{equippedItemHook};
	Plugins::delHook($self->{equipFailHook}) if exists $self->{equipFailHook}; 
	
	$self->SUPER::stop();
}

sub DESTROY {
	my ($self) = @_;
	
	Plugins::delHook($self->{equippedItemHook}) if exists $self->{equippedItemHook};
	Plugins::delHook($self->{equipFailHook}) if exists $self->{equipFailHook};
	
	$self->SUPER::DESTROY();
}

sub equippedItem {
	my ($hookName, $args, $self) = @_;
	
	return unless $args->{item} == $self->{item};
	
	$self->setDone();
}

sub equipFail {
	my ($hookName, $args, $self) = @_;
	
	return unless $args->{item} == $self->{item};
	
	++$self->{attempts};
	
	if ($self->{attempts} > $self->{retry}) {
		$self->setError(MAX_ATTEMPTS, TF("Failed to equip %s after %d attempts", $args->{item}->nameString(), $self->{attempts}));
	}
}

sub iterate {
	my ($self) = @_;
	
	return unless ($self->SUPER::iterate() && $net->getState() == Network::IN_GAME);
	
	unless ($self->{item} && $self->{item}->isa("Actor::Item")) {
		$self->setError(ITEM_MISSING, T("Failed to equip item, Actor went missing"));
		return;
	}
	
	if ($self->{item}->{equipped}) {
		$self->setDone();
		return;
	}
	
	if ($self->{attempts} > $self->{retry}) {
		$self->setError(MAX_ATTEMPTS, TF("Failed to equip %s after %d attempts", $self->{item}->nameString(), $self->{attempts}));
		return;
	}
	
	if (!$self->{timeout}->{time} || timeOut($self->{timeout})) {
		debug sprintf("Trying to equip %s (attempt: %d)\n", $self->{item}->nameString(), $self->{attempts});
		
		($self->{slot}) ? $self->{item}->equipInSlot($self->{slot}) : $self->{item}->equip();
		$self->{timeout}->{time} = time;
		++$self->{attempts};
		
		return;
	}
}

1;
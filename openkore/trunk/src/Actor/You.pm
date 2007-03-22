#########################################################################
#  OpenKore - You actor object
#  Copyright (c) 2005 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################
##
# MODULE DESCRIPTION: You actor object
#
# $char is of the Actor::You class. This class represents the your own character.
#
# @MODULE(Actor) is the base class for this class.
package Actor::You;

use strict;
use Globals;
use Log qw(message);
use base qw(Actor);

##
# Skill $char->{permitSkill}
#
# When you use certain items, the server temporarily permits you to use a skill.
# For example, when you use an Yggdrasil Leaf, the server temporarily lets you
# to use Resurrection.
#
# This member specifies which skill is currently temporarily permitted. It is undef
# when there is no temporarily permitted skill.
# The temporary permission is removed once you have used the skill, or when you have
# changed map server. (TODO: are these really all the cases?)

##
# Hash<String, Hash> $char->{skills}
#
# Contains a set of skills that the character has. The keys of the hash
# are the skill handles, and the values are a hash containing the following
# items:
# `l
# - ID - The skill ID.
# - lv - The maximum level of this skill.
# - sp - The amount of SP that this skill needs, when used at the maximum level.
# - range - The range of this skill, in blocks.
# - up - Whether this skill can be leveled up further.
# - targetType - ??? Probably related to %skillsArea
# `l`

##
# Bytes $char->{charID}
#
# A unique character ID for this character (not the same as the account ID, or $char->{ID}).

sub new {
	my ($class) = @_;
	return $class->SUPER::new('You');
}

sub nameString {
	my ($self, $otherActor) = @_;

	return 'yourself' if $self->{ID} eq $otherActor->{ID};
	return 'you' if UNIVERSAL::isa($otherActor, 'Actor');
	return 'You';
}

##
# int $char->getSkillLevel(Skill skill)
# Ensures: result >= 0
#
# Returns the maximum level of the specified skill. If the character doesn't
# have that skill, the 0 is returned.
sub getSkillLevel {
	my ($self, $skill) = @_;
	my $handle = $skill->getHandle();
	if ($self->{skills}{$handle}) {
		return $self->{skills}{$handle}{lv};
	} else {
		return 0;
	}
}

##
# float $char->weight_percent()
#
# Returns your weight percentage (between 0 and 100).
sub weight_percent {
	my ($self) = @_;

	return main::percent_weight($self);
}

##
# float $char->hp_percent()
#
# Returns your HP percentage (between 0 and 100).
sub hp_percent {
	my ($self) = @_;

	return main::percent_hp($self);
}

##
# float $char->sp_percent()
#
# Returns your SP percentage (between 0 and 100).
sub sp_percent {
	my ($self) = @_;

	return main::percent_sp($self);
}

##
# float $char->weight_percent()
#
# Returns your weight percentage (between 0 and 100).
sub weight_percent {
	my ($self) = @_;

	return $self->{weight} / $self->{weight_max} * 100;
}


##
# float $char->master()
#
# Returns your master (if any).
#
# FIXME: Should eventually ensure that either an @MODULE(Actor::Party) (party member who
# is not near you) or @MODULE(Actor::Player) (would be ensured if %players hash was
# guaranteed to be clean) is returned.
sub master {
	my ($self) = @_;

	# Stop if we have no master
	return unless $config{follow} && $config{followTarget};

	# Search through visible players
	keys %players;
	while (my ($ID, $player) = each %players) {
		return $player if $player->{name} eq $config{followTarget};
	}

	# Stop if we have no party
	return unless $char->{party} && %{$char->{party}};

	# Search through party members
	keys %{$char->{party}{users}};
	while (my ($ID, $player) = each %{$char->{party}{users}}) {
		return $player if $player->{name} eq $config{followTarget};
	}

	# Master is not visible and not in party
	return undef;
}

1;

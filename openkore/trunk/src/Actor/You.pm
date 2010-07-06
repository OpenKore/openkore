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
use InventoryList;
use Translation;
use Utils;

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
# Actor::Homunculus $char->{homunculus}
#
# If the character has a homunculus, and the homunculus is currently online, then this
# member points to character's homunculus object.

##
# Bytes $char->{charID}
#
# A unique character ID for this character (not the same as the account ID, or $char->{ID}).

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new('You');
	$self->{__inventory} = new InventoryList();
	$self->{configPrefix} = '';

	return $self;
}

sub nameString {
	my ($self, $otherActor) = @_;

	return T('yourself') if $self->{ID} eq $otherActor->{ID};
	return T('you') if UNIVERSAL::isa($otherActor, 'Actor');
	return T('You');
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
	} elsif ($self->{permitSkill} && $self->{permitSkill}->getHandle eq $handle) {
		return $self->{permitSkill}->getLevel;
	} else {
		return 0;
	}
}

##
# InventoryList $char->inventory()
# Ensures: defined(result)
#
# Get the inventory list for this character.
sub inventory {
	return $_[0]->{__inventory};
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

sub action { shift; goto &AI::action }
sub args { shift; goto &AI::args }
sub queue { shift; goto &AI::queue }
sub dequeue { shift; goto &AI::dequeue }

sub attack {
	my ($self, $targetID) = @_;
	
	return unless $self->SUPER::attack($targetID);
	
	my $target = Actor::get($targetID);
	
	$startedattack = 1;

	Plugins::callHook('attack_start', {ID => $targetID});

	#Mod Start
	AUTOEQUIP: {
		last AUTOEQUIP if (UNIVERSAL::isa($target, 'Actor::Player'));


		my $i = 0;
		my $Lequip = 0;
		my $Runeq =0;
		my (%eq_list,$Req,$Leq,$arrow,$j);
		while (exists $config{"autoSwitch_$i"}) {
			if (!$config{"autoSwitch_$i"}) {
				$i++;
				next;
			}

			if (existsInList($config{"autoSwitch_$i"}, $monsters{$targetID}{'name'})) {
				message TF("Encounter Monster : %s\n", $monsters{$targetID}{'name'});
				if ($config{"autoSwitch_$i"."_rightHand"}) {

					if ($config{"autoSwitch_$i"."_rightHand"} eq "[NONE]" && $char->{equipment}{'rightHand'}) {
						$Runeq = 1;
						message TF("Auto UnEquiping [R]: %s\n", $config{"autoSwitch_$i"."_rightHand"}), "equip";
						$char->{equipment}{'rightHand'}->unequip();
					}
					$Req = $char->inventory->getByName($config{"autoSwitch_${i}_rightHand"});
					if ($Req && !$Req->{equipped}){
						message TF("Auto Equiping [R]: %s\n", $config{"autoSwitch_$i"."_rightHand"}), "equip";
						%eq_list = (rightHand => $Req->{invIndex});
					}

				}

				if ($config{"autoSwitch_${i}_leftHand"}) {
					if ($config{"autoSwitch_${i}_leftHand"} eq "[NONE]" && $char->{equipment}{leftHand}) {
						if (!($Runeq && $char->{equipment}{rightHand} == $char->{equipment}{leftHand})) {
							message TF("Auto UnEquiping [L]: %s\n", $config{"autoSwitch_${i}_rightHand"}), "equip";
							$char->{equipment}{leftHand}->unequip();
						}
					}
					$Leq = $char->inventory->getByName($config{"autoSwitch_${i}_leftHand"});
					if ($Leq && !$Leq->{equipped}) {
						if ($Req == $Leq) {
							undef $Leq;
							foreach my $item (@{$char->inventory->getItems()}) {
								if ($item->{name} eq $config{"autoSwitch_${i}_leftHand"} && $item != $Req) {
									$Leq = $item;
									last;
								}
							}
						}

						if ($Leq) {
							message TF("Auto Equiping [L]: %s (%s)\n", $config{"autoSwitch_$i"."_leftHand"}, $Leq), "equip";
							$eq_list{leftHand} = $Leq->{invIndex};
						}
					}
				}
				if (%eq_list) {
					Actor::Item::bulkEquip(\%eq_list);
				}

				$arrow = $char->inventory->getByName($config{"autoSwitch_${i}_arrow"}) if ($config{"autoSwitch_${i}_arrow"});
				if ($arrow && !$arrow->{equipped}) {
					message TF("Auto Equiping [A]: %s\n", $config{"autoSwitch_$i"."_arrow"}), "equip";
					$arrow->equip();
				}
				if ($config{"autoSwitch_$i"."_distance"} && $config{"autoSwitch_$i"."_distance"} != $config{'attackDistance'}) {
					$ai_v{'attackDistance'} = $config{'attackDistance'};
					$config{'attackDistance'} = $config{"autoSwitch_$i"."_distance"};
					message TF("Change Attack Distance to : %s\n", $config{'attackDistance'}), "equip";
				}
				if ($config{"autoSwitch_$i"."_useWeapon"} ne "") {
					$ai_v{'attackUseWeapon'} = $config{'attackUseWeapon'};
					$config{'attackUseWeapon'} = $config{"autoSwitch_$i"."_useWeapon"};
					message TF("Change Attack useWeapon to : %s\n", $config{'attackUseWeapon'}), "equip";
				}
				last AUTOEQUIP;
			}
			$i++;
		}


		undef $Leq;
		undef $Req;

		if ($config{"autoSwitch_default_rightHand"}) {

			if ($config{"autoSwitch_default_rightHand"} eq "[NONE]" && $char->{equipment}{'rightHand'}) {
				$Runeq = 1;
				message TF("Auto UnEquiping [R]: %s\n", $config{"autoSwitch_default_rightHand"}), "equip";
				$char->{equipment}{'rightHand'}->unequip();
			}
			$Req = $char->inventory->getByName($config{"autoSwitch_default_rightHand"});
			if ($Req && !$Req->{equipped}){
				message TF("Auto Equiping [R]: %s\n", $config{"autoSwitch_default_rightHand"}), "equip";
				%eq_list = (rightHand => $Req->{invIndex});
			}

		}

		if ($config{"autoSwitch_default_leftHand"}) {
			if ($config{"autoSwitch_default_leftHand"} eq "[NONE]" && $char->{equipment}{'leftHand'}) {
				if (!($Runeq && $char->{equipment}{'rightHand'} == $char->{equipment}{'leftHand'})) {
					message TF("Auto UnEquiping [L]: %s\n", $config{"autoSwitch_default_leftHand"}), "equip";
					$char->{equipment}{'leftHand'}->unequip();
				}
			}
			$Leq = $char->inventory->getByName($config{"autoSwitch_default_leftHand"});

			if ($Leq && !$Leq->{equipped}) {
				if ($Req == $Leq) {
					undef $Leq;
					foreach my $item (@{$char->inventory->getItems()}) {
						if ($item->{name} eq $config{"autoSwitch_default_leftHand"} && $item != $Req) {
							$Leq = $item;
							last;
						}
					}
				}

				if ($Leq) {
					message TF("Auto Equiping [L]: %s\n", $config{"autoSwitch_default_leftHand"}), "equip";
					$eq_list{leftHand} = $Leq->{invIndex};
				}
			}
		}
		if (%eq_list) {
			Actor::Item::bulkEquip(\%eq_list);
		}


		if ($config{'autoSwitch_default_arrow'}) {
			$arrow = $char->inventory->getByName($config{"autoSwitch_default_arrow"});
			if ($arrow && !$arrow->{equipped}) {
				message TF("Auto equiping default [A]: %s\n", $config{'autoSwitch_default_arrow'}), "equip";
				$arrow->equip();
			}
		}
		if ($ai_v{'attackDistance'} && $config{'attackDistance'} != $ai_v{'attackDistance'}) {
			$config{'attackDistance'} = $ai_v{'attackDistance'};
			message TF("Change Attack Distance to Default : %s\n", $config{'attackDistance'}), "equip";
		}
		if ($ai_v{'attackUseWeapon'} ne "" && $config{'attackUseWeapon'} != $ai_v{'attackUseWeapon'}) {
			$config{'attackUseWeapon'} = $ai_v{'attackUseWeapon'};
			message TF("Change Attack useWeapon to default : %s\n", $config{'attackUseWeapon'}), "equip";
		}
	} #END OF BLOCK AUTOEQUIP
}

sub stopAttack {
	my ($self) = @_;
	
	$messageSender->sendMove(@{Utils::calcPosition($self)}{qw(x y)});
}

sub sendMove { $messageSender->sendMove(@_[1, 2]) }

1;

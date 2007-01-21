#########################################################################
#  OpenKore - Conversion between skill identifiers
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
# MODULE DESCRIPTION: Conversion between skill identifiers
#
# Skills have 3 different identifiers:
# `l
# - The full name ("Increase AGI").
# - The handle, or internal name ("AL_INCAGI").
# - The skill ID (29).
# `l`
#
# The skill ID is send to the server when sending a skill use packet.
# Different parts of Kore require a different skill identifier. Looking
# up skill information was a mess.
# This class provides an easy-to-use interface for conversion between those
# identifiers, so you can easily look up information about skills.
#
# See Skills->new() for an example about how to use this class.
#
# <h3>2004-10-11 BACKWARD COMPATIBILITY NOTE</h3>
# %skills_lut, %skills_rlut, %skillsID_lut and %skillsID_rlut are deprecated.
# New code should not use these structures, and eventually, all references to
# these structures should be replaced by the appropriate calls to this module.

package Skills;

use strict;
use Globals qw($accountID $net $char %skillsSP_lut $messageSender);
use vars qw(%skills);
use Log qw(warning);

use overload '""' => \&name;

# use SelfLoader; 1;
# __DATA__


# These data structures work as follows:
#
# %skills = (
#     'id' => (
#         '1' => (
#             'handle' => 'NV_BASIC',
#             'name' => 'Basic Skill'
#         )
#         '2' => (
#             'handle' => 'SM_SWORD',
#             'name' => 'Sword Mastery'
#         )
#         '3' => (
#             'handle' => 'SM_TWOHAND',
#             'name' => 'Two-Handed Sword Mastery'
#         )
#         ...
#     )
#     'handle' => (
#         'NV_BASIC' => 1,
#         'SM_SWORD' => 2,
#         'SM_TWOHAND' => 3,
#         ...
#     )
#     'name' => (
#         'basic skill' => 1,
#         'sword mastery' => 2,
#         'two-handed sword mastery' => 3,
#         ...
#     )
# );
#

##############################
### CATEGORY: Constructor
##############################

##
# Skills->new(key => value)
# key: id, handle, name or auto.
#
# Creates a new Skills object.
#
# Example:
# # All of these create the same object
# my $heal = Skills->new(id => 28);
# my $heal = Skills->new(handle => 'AL_HEAL');
# my $heal = Skills->new(name => 'heal');
# my $heal = Skills->new(auto => 'Heal');
# my $heal = Skills->new(auto => 'AL_HEAL');
# my $heal = Skills->new(auto => 28);
#
# $heal->id;     # returns 28
# $heal->handle; # returns 'AL_HEAL'
# $heal->name;   # returns 'Heal'
sub new {
	my ($class, $key, $value) = @_;

	my %self;
	if ($key eq 'id' || ($key eq 'auto' && $value =~ /^\d+$/)) {
		$self{id} = $value if defined($skills{id});
	} elsif ($key eq 'handle' || ($key eq 'auto' && uc($value) eq $value)) {
		$self{id} = $skills{handle}{$value};
	} elsif ($key eq 'name' || $key eq 'auto') {
		$self{id} = $skills{name}{lc($value)};
	}
	return bless \%self, $class;
}

##############################
### CATEGORY: Class Methods
##############################

sub useSkill {
	my ($skillName,$target,$lvl) = @_;

	my $skill = new Skills(auto => $skillName);
	$skill->use($target,$lvl);
}

sub checkLevel {
	my $skillName = shift;

	my $skill = new Skills(auto => $skillName);
	return $skill->level();
}

##############################
### CATEGORY: Methods
##############################

##
# $Skill->id()
#
# Returns the ID number of the skill.
sub id {
	my $self = shift;
	return $self->{id};
}

##
# $Skill->handle()
#
# Returns the handle of the skill.
sub handle {
	my $self = shift;
	return $skills{id}{$self->{id}}{handle};
}

##
# String $Skill->name()
#
# Returns the name of the skill.
sub name {
	my $self = shift;
	return $skills{id}{$self->{id}}{name} || "Unknown ".$self->{id};
}

sub complete {
	my $name = quotemeta(shift);
	my @matches;
	foreach my $skill (values %{$skills{id}}) {
		if ($skill->{name} =~ /^$name/i) {
			push @matches, $skill->{name};
		}
	}
	return @matches;
}

##
# $Skill->use([target] [lvl])
# target: skill target
# lvl: level of the skill
#
# Uses skill on target.
sub use {
	my ($self,$target,$lvl) = @_;
	$target = $accountID unless $target;
	$lvl = 10 unless $lvl;
	$messageSender->sendSkillUse($self->id, $lvl, $target);
}

##
# $Skill->level()
# Return: SkillLvl
#
sub level {
	my $self = shift;
	return 0 unless $char->{skills}{$self->handle};
	return $char->{skills}{$self->handle}{lv};
}

##
# $Skill->sp([lvl])
# lvl: of the skill
# Return: sp cost
#
sub sp {
	my ($self,$lvl) = @_;

	$lvl = $self->level unless $lvl;

	return 0 unless $lvl;

	my $handle = $self->handle;
	if ($skillsSP_lut{$handle}) {
		return $skillsSP_lut{$handle}{$lvl};
	} elsif ($char->{skills}{$handle}) {
		return $char->{skills}{$handle}{sp};
	}
}

##
# $Skill->checkSp([lvl])
# lvl: of the skill
# Return: can use or not
#
# checks whether the char can use the skill
# right now
sub checkSp {
	my ($self,$lvl) = @_;
	return $char->{sp} >= $self->sp($lvl);
}

1;

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
use Globals qw($accountID $remote_socket $char %skillsSP_lut);
use Network::Send qw(sendSkillUse);
use vars qw(@skills %handles %names);

use overload '""' => \&name;

# use SelfLoader; 1;
# __DATA__


# These data structures work as follows:
#
# @skill = (
#     ['NV_BASIC', 'Basic Skill'],
#     ['SM_SWORD', 'Sword Mastery'],
#     ['SM_TWOHAND', 'Two-Handed Sword Mastery'],
#     ...
# );
#
# %handle = (
#     'NV_BASIC' => 0,
#     'SM_SWORD' => 1,
#     'SM_TWOHAND' => 2,
#     ...
# );
#
# %name = (
#     'basic skill' => 0,
#     'sword mastery' => 1,
#     'two-handed sword mastery' => 2,
#     ...
# );
#
# Skills->init()
#
# Initializes %handles and %names after @skills has been set.
# Called automatically by FileParsers::parseSkills().

sub init {
	for (my $id = 0; $id <= $#skills; $id++) {
		$handles{$skills[$id][0]} = $id;
		$names{lc($skills[$id][1])} = $id;
	}
}


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
		$self{id} = $value if $skills[$value];
	} elsif ($key eq 'handle' || ($key eq 'auto' && uc($value) eq $value)) {
		$self{id} = $handles{$value};
	} elsif ($key eq 'name' || $key eq 'auto') {
		$self{id} = $names{lc($value)};
	}
	bless \%self, $class;
	return \%self;
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
# $skill->id()
#
# Returns the ID number of the skill.
sub id {
	my $self = shift;
	return $self->{id};
}

##
# $skill->handle()
#
# Returns the handle of the skill.
sub handle {
	my $self = shift;
	return $skills[$self->{id}][0];
}

##
# $skill->name()
#
# Returns the name of the skill.
sub name {
	my $self = shift;
	return $skills[$self->{id}][1];
}

sub complete {
	my $name = quotemeta(shift);
	my @matches;
	foreach my $skill (@skills) {
		if ($skill->[1] =~ /^$name/i) {
			push @matches, $skill->[1];
		}
	}
	return @matches;
}

##
# use([target] [lvl])
# target: skill target
# lvl: level of the skill
#
# uses skill on target
sub use {
	my ($self,$target,$lvl) = @_;
	$target = $accountID unless $target;
	$lvl = 10 unless $lvl;
	sendSkillUse(\$remote_socket, $self->id, $lvl, $target);
}

##
# level()
# Return: SkillLvl
#
sub level {
	my $self = shift;
	return 0 unless $char->{skills}{$self->handle};
	return $char->{skills}{$self->handl}{lv};
}

##
# sp([lvl])
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
	} else {
		return $char->{skills}{$handle}{sp};
	}
}

##
# checkSp([lvl])
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

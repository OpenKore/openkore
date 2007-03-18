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
# MODULE DESCRIPTION: Character skill
#
# This class models a character skill (for example, Heal, Bash, Flee, Twohand Quicken, etc.).
#
# Skills have 3 different identifiers:
# `l
# - The full name (e.g. "Increase AGI").
# - The handle, or internal name (e.g. "AL_INCAGI").
# - The skill ID (29).
# `l`
# When sending a "use skill" message to the RO server, the skill ID is used.
# When your character logs in, the server sends a list of available skills of the character,
# as well as the associated handles and other information. The RO client has a data file which
# translates skill handles into a full name.
#
# OpenKore has a database file which contains information about skills. It associates different
# skill identifiers with each other. During runtime, the in-memory version of this database
# is dynamically updated as the server sends up-to-date information about skills.
package Skills;

use strict;
use Modules 'register';
use Globals qw($accountID $char %skillsSP_lut $messageSender);
use Log qw(warning);
use Utils::TextReader;
use Utils::Exceptions;

use overload '""' => \&name;

use constant {
	# Passive skill; cannot be used.
	TARGET_PASSIVE => 0,

	# Used on enemies (i.e. monsters, and also people when in WoE/PVP).
	TARGET_ENEMY => 1,

	# Used on locations.
	TARGET_LOCATION => 2,

	# Always used on yourself, there's no targeting involved. Though some
	# of these skills (like Gloria) have effect on the entire party.
	TARGET_SELF => 4,

	# Can be used on all actors.
	TARGET_ACTORS => 16
};


# %skills is a database which contains information about skills. It has several
# indexes, which allow you to quickly lookup skill information with any skill identifier.
#
# %skills = {
#     id => {
#         1 => {
#             handle => 'NV_BASIC',
#             name   => 'Basic Skill'
#         },
#         2 => {
#             handle => 'SM_SWORD',
#             name   => 'Sword Mastery'
#         },
#         3 => {
#             handle => 'SM_TWOHAND',
#             name   => 'Two-Handed Sword Mastery'
#         },
#         ...
#     },
#     handle => {
#         NV_BASIC   => 1,
#         SM_SWORD   => 2,
#         SM_TWOHAND => 3,
#         ...
#     },
#     name => {
#         'basic skill' => 1,
#         'sword mastery' => 2,
#         'two-handed sword mastery' => 3,
#         ...
#     }
# };
our %skills;

##
# Skills->new(options...)
#
# Creates a new Skills object. In the options, you must specify an identifier
# for a skill.
#
# To specificy a skill identifier, use one of the following keys:
# `l`
# - id - A skill ID.
# - name - A skill name. This is case-<b>in</b>sensitive.
# - handle - A skill handle. This is case-sensitive.
# - auto - Attempt to autodetect the value.
# `l
# For example, all of the following constructors create identical Skills objects:
# <pre class="example">
# $heal = new Skills(id => 28);
# $heal = new Skills(handle => 'AL_HEAL');
# $heal = new Skills(name => 'heal');
# $heal = new Skills(auto => 'Heal');
# $heal = new Skills(auto => 'AL_HEAL');
# $heal = new Skills(auto => 28);
#
# $heal->id();     # returns 28
# $heal->handle(); # returns 'AL_HEAL'
# $heal->name();   # returns 'Heal'
# </pre>
#
# The following options are also allowed, and are optional:
# `l
# - level - The skill level. The default is 1.
# - sp
# - range
# `l`
#
# You may also specify a 'level' option to set the skill level. If you don't
# specify this parameter, then a level of 1 is assumed. For example:
# <pre class="example">
# $heal = new Skills(name => 'Heal');
# $heal->level();  # returns 1
#
# $heal = new Skills(name => 'Heal', level => 5);
# $heal->level();  # returns 5
# </pre>
sub new {
	my $class = shift;
	my %args = @_;
	my %self;

	if (defined $args{auto}) {
		if ($args{auto} =~ /^\d+$/) {
			$args{id} = $args{auto};
		} elsif (uc($args{auto}) eq $args{auto}) {
			$args{handle} = $args{auto};
		} else {
			$args{name} = $args{auto};
		}
	}

	if (defined $args{id}) {
		$self{id} = $args{id};
	} elsif (defined $args{handle}) {
		$self{id} = $skills{handle}{$args{handle}};
	} elsif (defined $args{name}) {
		$self{id} = $skills{name}{lc($args{name})};
	} else {
		ArgumentException->throw("No valid skill identifier specified.");
	}

	$self{level} = defined($args{level}) ? $args{level} : 1;

	return bless \%self, $class;
}

##
# int $Skill->id()
#
# Returns the ID number of the skill.
sub id {
	return $_[0]->{id};
}

##
# String $Skill->handle()
#
# Returns the handle of the skill.
sub handle {
	my ($self) = @_;
	return $skills{id}{$self->{id}}{handle};
}

##
# String $Skill->name()
#
# Returns the name of the skill.
sub name {
	my $self = shift;
	return $skills{id}{$self->{id}}{name} || "Unknown $self->{id}";
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
# int $Skill->level()
# Ensures: result > 0
#
# Returns the level of this skill.
sub level {
	return $_[0]->{level};
}

##
# int $Skill->sp($level)
#
# Returns the SP required for level $level of this skill.
sub sp {
	my ($self, $level) = @_;
	my $handle = $self->handle();
	if ($skillsSP_lut{$handle}) {
		return $skillsSP_lut{$handle}{$level};
	} elsif ($char && $char->{skills} && $char->{skills}{$handle}) {
		return $char->{skills}{$handle}{sp};
	}
}


#######################################


sub parseSkillsDatabase {
	my ($file, $hash) = @_;
	my $reader = new Utils::TextReader($file);
	%{$hash} = ();
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		next if ($line =~ /^\/\//);
		$line =~ s/[\r\n]//g;
		$line =~ s/\s+$//g;
		my ($id, $handle, $name) = split(' ', $line, 3);
		if ($id && $handle ne "" && $name ne "") {
			$hash->{id}{$id}{handle} = $handle;
			$hash->{id}{$id}{name} = $name;
			$hash->{handle}{$handle} = $id;
			$hash->{name}{lc($name)} = $id;
		}
	}
	return 1;
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

1;

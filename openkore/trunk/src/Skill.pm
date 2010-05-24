#########################################################################
#  OpenKore - Character skill
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 5532 $
#  $Id: Skills.pm 5532 2007-03-18 16:57:38Z vcl_kore $
#
#########################################################################
##
# MODULE DESCRIPTION: Character skill model.
#
# This class models a character skill (for example, Heal, Bash, Flee, Twohand Quicken, etc.).
# In our model, a skill always has the following properties:
# <ul>
# <li>
#     A skill identifier. This identifier has multiple forms:
#     <ul>
#     <li>A full name, e.g. "Increase AGI".</li>
#     <li>A handle, or internal name, e.g. "AL_INCAGI".</li>
#     <li>A skill Identifier Number (IDN). In case case of Increase AGI, this is 29.</li>
#     </ul>
# </li>
# <li>
#    A skill level. This may not always be necessary, depending on the situation.
#    For example, when you want to use a skill, then it's necessary to know the associated level.
#    But when the programmer just wants to query the maximum level of a skill, only
#    a skill identifier is required.
# </li>
# </ul>
#
# A skill may also have the following properties, which is updated on-the-fly as the RO
# server sends us the information:
# `l
# - The SP usage.
# - The maximum available skill level at the moment.
# - The skill range.
# - The skill's target type (whether it's used on yourself, on a location, on a monster, etc.)
# - The skill's owner type: whether the skill is a character skill or homunculus skill.
# `l`
package Skill;

use strict;
use Modules 'register';
use Carp::Assert;
use Utils::TextReader;
use Utils::Exceptions;

# Target type constants. See $Skill->getTargetType() for description.
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

# Owner type constants. See $Skill->getOwnerType() for description.
use enum qw(OWNER_CHAR OWNER_HOMUN OWNER_MERC);


##
# Skill->new(options...)
#
# Creates a new Skills object. In the options, you must specify an identifier
# for a skill.
#
# To specificy a skill identifier, use one of the following keys:
# `l
# - idn - A skill Identifier Number (IDN).
# - name - A skill name. This is case-<b>in</b>sensitive.
# - handle - A skill handle. This is case-sensitive.
# - auto - Attempt to autodetect the value.
# `l`
#
# For example, all of the following constructors create identical Skill objects:
# <pre class="example">
# $heal = new Skill(idn => 28);
# $heal = new Skill(handle => 'AL_HEAL');
# $heal = new Skill(name => 'heal');
# $heal = new Skill(auto => 'Heal');
# $heal = new Skill(auto => 'AL_HEAL');
# $heal = new Skill(auto => 28);
#
# $heal->getIDN();        # returns 28
# $heal->getHandle();     # returns 'AL_HEAL'
# $heal->getName();       # returns 'Heal'
# </pre>
#
# You may also specify a 'level' option to set the skill level.
#
# Example:
# $heal = new Skill(name => 'Heal');
# $heal->level();  # returns undef
#
# $heal = new Skill(name => 'Heal', level => 5);
# $heal->level();  # returns 5
sub new {
	my $class = shift;
	my %args = @_;
	my %self;

	if (defined $args{auto}) {
		if ($args{auto} =~ /^\d+$/) {
			$args{idn} = $args{auto};
		#} elsif (uc($args{auto}) eq $args{auto} && lc($args{auto}) ne $args{auto}) {	# without second check, korean|chinese skills would get recognized as handle
		} elsif (uc($args{auto}) eq $args{auto} && $args{auto} =~ /^[A-Z0-9_]*$/) {	# better check (would still fail if skillname with HANDLE format was used)
			$args{handle} = $args{auto};
		} else {
			$args{name} = $args{auto};
		}
	}
	
	if (defined $args{idn}) {
		$self{idn} = $args{idn};
	} elsif (defined $args{handle}) {
		$self{idn} = lookupIDNByHandle($args{handle});
	} elsif (defined $args{name}) {
		$self{idn} = lookupIDNByName($args{name});
	} else {
		ArgumentException->throw("No valid skill identifier specified.");
	}

	$self{level} = $args{level};
	return bless \%self, $class;
}

##
# int $Skill->getIDN()
#
# Returns this skill's Identifier Number (IDN).
sub getIDN {
	return $_[0]->{idn};
}

##
# String $Skill->getHandle()
#
# Returns the skill's handle.
sub getHandle {
	my ($self) = @_;
	my $idn = $self->{idn};
	if (defined $idn) {
		my $entry = $Skill::DynamicInfo::skills{$idn} || $Skill::StaticInfo::ids{$idn};
		return $entry->{handle} if ($entry);
	}
	return undef;
}

##
# String $Skill->getName()
# Ensures: defined(result)
#
# Returns the skill's name.
sub getName {
	my ($self) = @_;
	my $idn = $self->{idn};
	if (defined $idn) {
		my $entry = $Skill::StaticInfo::ids{$idn};
		if ($entry && $entry->{name} ne "") {
			return $entry->{name};
		} else {
			my $handle = $self->getHandle();
			if ($handle) {
				return handleToName($handle);
			} else {
				return "Unknown $idn";
			}
		}
	} else {
		return "Unknown";
	}
}

##
# int $Skill->getLevel()
#
# Returns the skill level. The value may be undef, if no skill level was set.
sub getLevel {
	return $_[0]->{level};
}

##
# int $Skill->getSP(int level)
# Requires: $level > 0
#
# Returns the SP required for level $level of this skill, or undef if that's unknown.
sub getSP {
	my ($self, $level) = @_;
	assert($level > 0) if DEBUG;

	my $targetType = $self->getTargetType();
	if (defined $targetType && $targetType == TARGET_PASSIVE) {
		print "PASSIVE! $targetType\n";
		return 0;
	} else {
		my $idn = $self->{idn};

		# First check dynamic database.
		my $entry = $Skill::DynamicInfo::skills{$idn};
		if ($entry && $entry->{level} == $level) {
			return $entry->{sp};
		}

		# No luck, check static database.
		my $handle = $self->getHandle();
		$entry = $Skill::StaticInfo::sps{$handle};
		if ($entry) {
			return $entry->[$level - 1];
		} else {
			return undef;
		}
	}
}

##
# int $Skill->getRange()
#
# Returns the skill's range.
sub getRange {
	my ($self) = @_;
	my $entry = $Skill::DynamicInfo::skills{$self->{idn}};
	if ($entry) {
		return $entry->{range};
	} else {
		return 1.42; # sqrt(2)
	}
}

##
# int $Skill->getTargetType()
#
# Returns the skill's target type, which specifies on what kind of target
# this skill can be used. Returns one of:
# `l
# - Skill::TARGET_PASSIVE  - Passive skill; cannot be used.
# - Skill::TARGET_ENEMY    - Used on enemies (i.e. monsters, and also people when in WoE/PVP).
# - Skill::TARGET_LOCATION - Used on locations.
# - Skill::TARGET_SELF     - Always used on yourself, there's no targeting involved. Though
#                            some of these skills (like Gloria) have effect on the entire party.
# - Skill::TARGET_ACTORS   - Can be used on all actors.
# `l`
sub getTargetType {
	my ($self) = @_;
	if (!defined $self->{idn}) {
		return undef;
	} else {
		my $entry = $Skill::DynamicInfo::skills{$self->{idn}};
		return $entry->{targetType} if ($entry);

		# TODO: use skillsarea.txt
		# Do we even need this file? All the info is already given by the server.

		# We don't know the target type so we just assume that it's used on
		# an enemy (which is usually correct).
		return TARGET_ENEMY;
	}
}

##
# int $Skill->getOwnerType()
#
# Returns the skill's owner type, which specifies whether this skill belongs to the character
# or to the homunculus. Returns one of:
# `l
# - Skill::OWNER_CHAR  - This skill belongs to the character.
# - Skill::OWNER_HOMUN - This skill belongs to the character's homunculus.
# - Skill::OWNER_MERC - This skill belongs to the character's mercenary.
# `l`
sub getOwnerType {
	my ($self) = @_;
	if (defined $self->{idn}) {
		my $entry = $Skill::DynamicInfo::skills{$self->{idn}};
		return $entry->{ownerType} if ($entry);
	}
	# Just assume that this is a character skill. This is usually the case.
	return OWNER_CHAR;
}

sub getOwner {
	my ($self) = @_;
	
	my $type = $self->getOwnerType ();
	
	if ($Globals::char) {
		return $Globals::char->{homunculus} if $type == OWNER_HOMUN && $Globals::char->{homunculus};
		return $Globals::char->{mercenary} if $type == OWNER_MERC && $Globals::char->{mercenary};
	}
	return $Globals::char;
}

# Lookup an IDN by skill handle.
sub lookupIDNByHandle {
	my ($handle) = @_;
	my $idn = $Skill::DynamicInfo::handles{$handle};
	if (defined $idn) {
		return $idn;
	} else {
		return $Skill::StaticInfo::handles{$handle};
	}
}

# Lookup an IDN by full skill name.
sub lookupIDNByName {
	my ($name) = @_;
	my $idn;
	if (ref($Skill::StaticInfo::names{lc($name)}) eq 'ARRAY') {	# we have multiple ID's for the skillname
		foreach (@{$Skill::StaticInfo::names{lc($name)}}) {
			if (exists $Skill::DynamicInfo::skills{$_}) {		# search in dynamic
				$idn = $_;
				last;
			} else {
				$idn = $_ unless defined $idn;					# if in the end no dynamic was found, use first static
			}
		}
	} else {
		$idn = $Skill::StaticInfo::names{lc($name)};
	}
	if (defined $idn) {
		return $idn;
	} else {
		# This case is probably rare so the lookup is not indexed,
		# in order to save memory. We use a 'slow' linear search instead.
		foreach my $handle (keys %Skill::DynamicInfo::handles) {
			my $convertedName = handleToName($handle);
			if ($name eq $convertedName) {
				return $Skill::DynamicInfo::handles{$handle};
			}
		}
		return undef;
	}
}

# Attempt to convert handle name to human readable name.
sub handleToName {
	my ($handle) = @_;
	$handle =~ s/^[A-Z]+_//;	# Remove prefix (WIZ_)
	$handle =~ s/_+/ /g;		# Replace underscores with spaces.
	$handle = lc($handle);		# Convert to lowercase.
	# Change first character and every character
	# that follows a space, to uppercase.
	$handle =~ s/(^| )([a-z])/$1 . uc($2)/ge;
	return $handle;
}


#############################################################
# Static information database. Information in this database
# is loaded from a file on disk.
#############################################################
package Skill::StaticInfo;

# The following variables contain information about skills, but indexed differently.
# This allow you to quickly lookup skill information with any skill identifier form.
#
# %ids = (
#     1 => {
#         handle => 'NV_BASIC',
#         name   => 'Basic Skill'
#     },
#     2 => {
#         handle => 'SM_SWORD',
#         name   => 'Sword Mastery'
#     },
#     3 => {
#         handle => 'SM_TWOHAND',
#         name   => 'Two-Handed Sword Mastery'
#     },
#     ...
# );
#
# %handles = (
#     NV_BASIC   => 1,
#     SM_SWORD   => 2,
#     SM_TWOHAND => 3,
#     ...
# );
#
# %names = (
#     'basic skill' => 1,
#     'sword mastery' => 2,
#     'two-handed sword mastery' => 3,
#     ...
# );
our %ids;
our %handles;
our %names;

# Contains SP usage information.
# %sps = (
#     SM_BASH => [
#         8,     # SP usage for level 1
#         8,     # SP usage for level 2
#         ...
#         15,    # SP usage for level 6
#         ...
#     ],
#     SM_PROVOKE => [
#         4,     # SP usage for level 1
#         5,     # SP usage for level 2
#         ...
#     ],
#     ...
# );
our %sps;

# load first
# id <-> handle
sub parseSkillsDatabase_id2handle {
	my ($file) = @_;
	my $reader = new Utils::TextReader($file);
	%ids = ();
	%handles = ();

	while (!$reader->eof()) {
		my $line = $reader->readLine();
		next if ($line =~ /^\/\//);
		$line =~ s/[\r\n]//g;
		$line =~ s/\s+$//g;
		my ($id, $handle) = split(' ', $line, 2);
		#Log::debug "$id $handle\n";
		if ($id && $handle ne "") {
			$ids{$id}{handle} = $handle;
			$handles{$handle} = $id;
		}
	}
	return 1;
}

# load second
# id <-> name
sub parseSkillsDatabase_handle2name {
	my ($file) = @_;
	my $reader = new Utils::TextReader($file);
	%names = ();

	while (!$reader->eof()) {
		my $line = $reader->readLine();
		next if ($line =~ /^\/\//);
		$line =~ s/[\r\n]//g;
		$line =~ s/\s+$//g;
		my ($handle, $name) = split('#', $line, 3);
		$name =~ s/_/ /g;
		#Log::debug "$handle $name\n";
		my $id = $handles{$handle};
		if ($id && $handle ne "" && $name ne "") {
			my $name_lc = lc($name);
			if (!exists $names{$name_lc}) {				# doesn't exist yet
				$names{$name_lc} = $id;
				$ids{$id}{name} = $name;
			} else {
				$ids{$id}{name} = $name . ' (' . $handle . ')';
				if (ref($names{$name_lc}) eq 'ARRAY') {	# is an array
					push @{$names{$name_lc}}, $id;
					#Log::warning "pushed $id $name\n";
				} else {								# exists but is not an array
					$names{$name_lc} = [$names{$name_lc}, $id];
					#Log::warning "start array $id $name\n";
				}
			}
=pod
			if(exists $names{lc($name)}) { # skillname is not an unique identifier, there could already be an entry with given skillname
				Log::warning("Duplicate skillname: $id $handle $name\n");
				$names{lc($name)} = @{$names{lc($name)}};
			} else {
				$names{lc($name)} = $id;
			}
=cut
		}
	}
	return 1;
}

sub parseSPDatabase {
	my ($file) = @_;
	my $reader = new Utils::TextReader($file);
	my $ID;

	while (!$reader->eof()) {
		my $line = $reader->readLine();
		if ($line =~ /^\@/) {
			undef $ID;
		} elsif (!$ID) {
			($ID) = $line =~ /(.*)#/;
			$sps{$ID} = [];
		} else {
			my ($sp) = $line =~ /(\d+)#/;
			push @{$sps{$ID}}, $sp;
		}
	}
	return 1;
}


#############################################################
# Dynamic information database. Information in this database
# is sent by the RO server.
#############################################################
package Skill::DynamicInfo;

# The skills information as sent by the RO server. This variable maps a skill IDN
# to another hash, with the following members:
# - handle     - Handle name.
# - level      - Character's current maximum skill level.
# - sp         - The SP usage for the current maximum level.
# - range      - Skill range.
# - targetType - The skill's target type.
our %skills;

# Maps handle names to skill IDNs.
our %handles;

sub add {
	my ($idn, $handle, $level, $sp, $range, $targetType, $ownerType) = @_;
	$skills{$idn} = {
		handle     => $handle,
		level      => $level,
		sp         => $sp,
		range      => $range,
		targetType => $targetType,
		ownerType  => $ownerType
	};
	$handles{$handle} = $idn;
}

sub clear {
	%skills = ();
	%handles = ();
}

1;

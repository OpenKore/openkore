package Skills;

use strict;

# 2004-10-11 BACKWARD COMPATIBILITY NOTE: %skills_lut, %skills_rlut,
# %skillsID_lut and %skillsID_rlut are deprecated. New code should not use
# these structures, and eventually, all references to these structures should
# be replaced by the appropriate calls to this module.

# A skill can be represented by its ID (e.g. 28), its HANDLE (e.g. 'AL_HEAL')
# or its NAME (e.g. 'Heal'). This package provides methods to convert between
# these representations. Example usage:
#
# # All of these create the same object
# my $heal = Skills->new(id => 28);
# my $heal = Skills->new(handle => 'AL_HEAL');
# my $heal = Skills->new(name => 'heal');
#
# $heal->id;     # returns 28
# $heal->handle; # returns 'AL_HEAL'
# $heal->name;   # returns 'Heal'

use vars qw(@skills %handles %names);

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

# Skills->new(<key> => <value>)
#
# Examples:
# my $heal = Skills->new(id => 28);
# my $heal = Skills->new(handle => 'AL_HEAL');
# my $heal = Skills->new(name => 'heal');
sub new {
	my ($type, $key, $value) = @_;

	my $self = bless({});
	if ($key eq 'id') {
		$self->{id} = $value if $skills[$value];
	} elsif ($key eq 'handle') {
		$self->{id} = $handles{$value};
	} elsif ($key eq 'name') {
		$self->{id} = $names{lc($value)};
	}
	return $self;
}

# $skill->id: Returns the ID number of the skill.
sub id {
	my $self = shift;
	return $self->{id};
}

# $skill->handle: Returns the handle of the skill.
sub handle {
	my $self = shift;
	return $skills[$self->{id}][0];
}

# $skill->name: Returns the name of the skill.
sub name {
	my $self = shift;
	return $skills[$self->{id}][1];
}

1;

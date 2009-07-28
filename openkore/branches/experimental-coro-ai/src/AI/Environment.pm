#########################################################################
#  OpenKore - AI framework
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Abstract AI Environment Listener base class.
#
# This is the abstract base class for all AI Environment Listener.
#
package AI::Environment;

# Make all References Strict
use strict;

# Coro Support
use Coro;

# Others (Kore related)
use Utils::Set;

####################################
### CATEGORY: Constructor
####################################

##
# Environment->new(options...)
#
# Create a new Environment Listener object. The following options are allowed:
# `l
# - <tt>name</tt> - A name of the environment message. $Environment->getName() will return this name.
#                   If not specified, the class's name (excluding the "AI::Environment::" prefix) will be used as name.
# `l`
#
sub new {
	my $class = shift;
	my %args = @_;
	my %self;

	my $allowed = new Utils::Set("msg_name");

	foreach my $key (keys %args) {
		if ($allowed->has($key)) {
			$self{"T_$key"} = $args{$key};
		}
	}

	# Set default name, if none specified.
	if (!defined $self{T_msg_name}) {
		$self{T_msg_name} = $class;
		$self{T_msg_name} =~ s/.*:://;
	}

	return bless \%self, $class;
}

####################################
### CATEGORY: Destructor
####################################

sub DESTROY {
	my ($self) = @_;
	$self->SUPER::DESTROY() if ($self->can("SUPER::DESTROY"));
}

####################################
### CATEGORY: Queries
####################################

##
# String $Environment->getName()
# Ensures: $result ne ""
#
# Returns a human-readable name for this environment message.
#
sub getName {
	return $_[0]->{T_msg_name};
}

#####################################
### CATEGORY: Public commands
#####################################

##
# Hash $Environment->parse_msg(object)
# object: message from Environment Queue
#
# Run the Environment Message parser.
# Returns a full_object with all the childrens, or undef.
#
sub parse_msg {
	
}

1;

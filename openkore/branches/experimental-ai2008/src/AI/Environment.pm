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
# MODULE DESCRIPTION: Abstract AI Environment Lisner base class.
#
# This is the abstract base class for all AI Environment Lisner.
#

package AI::Environment;

####################################
### CATEGORY: Constructor
####################################

##
# Environment->new(options...)
#
# Create a new Environment Lisner object. The following options are allowed:
# `l
# - <tt>name</tt> - A name of the environment message. $AIModule->getName() will return this name.
#                   If not specified, the class's name (excluding the "AI::Environment::" prefix) will be used as name.
# `l`
sub new {
	my $class = shift;
	my %args = @_;
	my %self;

	my $allowed = new Set("msg_name");

	foreach my $key (keys %args) {
		if ($allowed->has($key)) {
			$self{"T_$key"} = $args{$key};
		}
	}

	# Set default name, if none specifed.
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
	$self->SUPER::DESTROY();
}

####################################
### CATEGORY: Queries
####################################

##
# String $Environment->getMsgName()
# Ensures: $result ne ""
#
# Returns a human-readable name for this task.
sub getName {
	return $_[0]->{T_msg_name};
}

#####################################
### CATEGORY: Events
#####################################

##
# CallbackList $Environment->onEnvironmentMsg()
#
# This event is triggered when the Environment Queue gets message, that is parsed and interpretted by this module.
# Users could use this Event to interpret messages by their plugins.
sub onEnvironmentMsg {
	return $_[0]->{T_onEnvironmentMsg};
}

#####################################
### CATEGORY: Public commands
#####################################

##
# void $Environment->parse_msg()
#
# Run the Environment Message parser.
sub parse_msg {
	
}

1;

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
# MODULE DESCRIPTION: AI Environment Queue Manager.
#
# This is the AI Environment Queue Manager, that autoregisters all the 
# Envionment Listner's and manages Smart Matching for registered External events.
#

package AI::EnvironmentQueue;

# Make all Referances Strict
use strict;

# MutiThreading Support
use threads;
use threads::shared;
use Thread::Queue::Any;

# Others (Perl Related)
no warnings qw(redefine uninitialized);
use FindBin qw($RealBin);
use Time::HiRes qw(time);
use Scalar::Util qw(reftype refaddr blessed); 

# Others (Kore related)
use Modules 'register';
use Log qw(message debug error warning);
use Translation;
use I18N qw(stringToBytes);

####################################
### CATEGORY: Constructor
####################################

##
# EnvironmentQueue->new()
#
# Create a new Environment Queue Manager object.
#
sub new {
	my $class = shift;
	my %args = @_;
	my %self;

	$self{listners} = {};			# Registered Listners
	$self{events} = {};			# Registered Smart Events
	$self{queue} = Thread::Queue::Any->new;	# Used for Queue

	# TODO: Add loading and registering of all default Environment Queue listners

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
### CATEGORY: Public
####################################

##
# EnvironmentQueue->itterate()
#
# Called Every time (can be called even in infinite loop)
# Used to check Whatever new 
#
sub itterate {
	my ($self) = @_;
	lock ($self) if (is_shared($self));

	while ($self->{queue}->pending > 0) {
		# TODO:
		# Add parsing Queue by 'name'
		# Add check for Smart Event mutch
		# Check if Matched Event registered by some Task, check whatever that Task exists.
		# Check if Matched Event registered by Plugin, check whatever that Plugin actually Loded.
		# Add Warning for NonRegistered Environment Queue message
	};
}

##
# EnvironmentQueue->register_listner(name, listner_sub)
# Return: listner ID.
#
# Register new Enviromnet Listner object.
#
sub register_listner {
	my ($self, $name, $listner_sub) = @_;
	lock ($self) if (is_shared($self));

	# TODO:
	# Make Registering Queue Listner actually work.
	
}

##
# EnvironmentQueue->unregister_listner(ID)
#
# UnResgister Listner Object by given ID.
#
sub unregister_listner {
	my ($self, $name, $listner_sub) = @_;
	lock ($self) if (is_shared($self));
	
	# Make UnRegistering Queue Listner actually work.
}

##
# EnvironmentQueue->register_event(name, rules, event_sub, params)
# Return: event ID
#
# Resgister Smart Event Object.
#
sub register_event {
	my ($self, $name, $rules, $event_sub, $params) = @_;
	lock ($self) if (is_shared($self));

	# TODO:
	# Decide the rules format
	# Make Registering Smart Events actually work.

}

##
# EnvironmentQueue->unregister_event(ID)
# Return: event ID
#
# UnResgister Smart Event Object by given ID.
#
sub register_event {
	my ($self, $name, $rules, $event_sub, $params) = @_;
	lock ($self) if (is_shared($self));

	# TODO:
	# Make UnRegistering Smart Events actually work.

}

####################################
### CATEGORY: Private
####################################


1;

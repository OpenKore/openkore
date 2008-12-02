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
use warnings;
no warnings 'redefine';
use FindBin qw($RealBin);
use Time::HiRes qw(time);
use Scalar::Util qw(reftype refaddr blessed); 

# Others (Kore related)
use Modules 'register';
use Log qw(message warning error debug);
use Translation;
use I18N qw(stringToBytes);
use Utils::CallbackList;
use Utils::SmartCallbackList;

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
	$self{smart_events} = {};		# Registered Smart Events
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
# EnvironmentQueue->queue_add(name, params)
#
# Add some structure to Queue.
#
sub queue_add {
	my ($self, $name, $params) = @_;
	lock ($self) if (is_shared($self));
	my $obj = {};
	$obj->{name} = $name;
	$obj->{params} = $params;
	$self->{queue}->enqueue(\$obj);
}

##
# EnvironmentQueue->itterate()
#
# Called Every time (can be called even in infinite loop)
# Used to check Whatever new Object apeared in Queue
#
sub itterate {
	my ($self) = @_;
	lock ($self) if (is_shared($self));

		# TODO:
		# Add parsing Queue by 'name'
		# Add check for Smart Event mutch
		# Check if Matched Event registered by some Task, check whatever that Task exists.
		# Check if Matched Event registered by Plugin, check whatever that Plugin actually Loded.
		# Add Warning for NonRegistered Environment Queue message

		# my $listner_object_class = blessed($self->{listners}->{$object->{name}})

	while ($self->{queue}->pending > 0) {
		my $object = $self->{queue}->dequeue;
		my $full_object;
		if ((defined $object->{name})&&(defined $object->{params})) {
			# Check for Environment Listner
			if (defined $self->{listners}->{$object->{name}}) {
				$self->{listners}->{$object->{name}}->call($self, $object->{params});
			} else {
				warning T("Warning!!! Unknown Environment message found: \"" . $object->{name} . "\".\n");
				next;
			};
			# Check for Smart Events
			# TODO:
			# Sometimes, it needs full Object. So decide, How can we get it??? and whatever we whant it.
			if (defined $self->{smart_events}->{$object->{name}}) {
				$self->{smart_events}->{$object->{name}}->call($self, $object->{params});
			};
		} else {
			warning T("Warning!!! Unknown Environment Object Received.\n");
			next;
		};
	};
}

##
# EnvironmentQueue->register_listner(name, listner_sub, lisner_self, [params, ...])
# Return: listner ID.
#
# Register new Enviromnet Listner object.
#
# Example:
# my $ID = $environmentQueue->register("my_command", \&my_callback, \$self, $params);
sub register_listner {
	my $self = shift;
	my $name = shift;
	my $listner_sub = shift;
	my $lisner_self = shift;
	my $params = @_;

	lock ($self) if (is_shared($self));
	lock ($lisner_self) if ((defined $lisner_self) && (is_shared($lisner_self)));

	# There is no such listner yet. So we create it
	if (!defined $self->{listners}->{$name}) {
		my $new_listner = CallbackList->new($name);
		$new_listner = shared_clone($new_listner) if (is_shared($self));
		$self->{listners}->{$name} = $new_listner;
	}

	# Now we have an empty listner object, or allready made. So we add our callback there.
	$lisner_self = undef if (!defined $lisner_self);
	return $self->{listners}->{$name}->add($lisner_self, $listner_sub, $params); 
}

##
# EnvironmentQueue->unregister_listner(name, ID)
#
# UnResgister Listner Object by given name and ID.
#
sub unregister_listner {
	my ($self, $name, $id) = @_;
	lock ($self) if (is_shared($self));
	
	if (defined $self->{listners}->{$name}) {
		$self->{listners}->{$name}->remove($id);
	}
}

##
# EnvironmentQueue->register_event(name, rules, event_sub, event_self, [params, ...])
# Return: event ID
#
# Resgister Smart Event Object.
#
sub register_event {
	my $self = shift;
	my $name = shift;
	my $rules= shift;
	my $event_sub = shift;
	my $event_self = shift;
	my $params = @_;

	# TODO:
	# Document rules format

	lock ($self) if (is_shared($self));
	lock ($event_self) if ((defined $event_self) && (is_shared($event_self)));

	# There is no such smart event yet. So we create it
	if (!defined $self->{smart_events}->{$name}) {
		my $new_smart_event = SmartCallbackList->new($name);
		$new_smart_event = shared_clone($new_smart_event) if (is_shared($self));
		$self->{smart_events}->{$name} = $new_smart_event;
	}

	# Now we have an empty smart event object, or allready made. So we add our callback there.
	$event_self = undef if (!defined $event_self);

	return $self->{smart_events}->{$name}->add($event_self, $rules, $event_sub, $params); 
}

##
# EnvironmentQueue->unregister_event(ID)
#
# UnResgister Smart Event Object by given ID.
#
sub register_event {
	my ($self, $name, $id) = @_;
	lock ($self) if (is_shared($self));
	
	if (defined $self->{smart_events}->{$name}) {
		$self->{smart_events}->{$name}->remove($id);
	}
}

####################################
### CATEGORY: Private
####################################


1;

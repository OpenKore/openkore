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
# Environment Listener's and manages Smart Matching for registered External events.
#
package AI::EnvironmentQueue;

# Make all References Strict
use strict;

# MultiThreading Support
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

# TODO:
# Check if Event is some Task, check whatever that Task exists.
# Check if Event is some AI module, check whatever that Task exists.

##
# EnvironmentQueue->new()
#
# Create a new Environment Queue Manager object.
#
sub new {
	my $class = shift;
	my %args = @_;
	my $dir = "$RealBin/src/AI/Environment/";
	my $self  = {};
	bless $self, $class;
		
	$self->{listeners} = {};					# Registered Listeners
	$self->{smart_events} = {};					# Registered Smart Events
	# $self->{smart_ai_events} = {};			# Registered Smart Events by AI
	# $self->{smart_task_events} = {};			# Registered Smart Events by Tasks
	$self->{queue} = Thread::Queue::Any->new;	# Used for Queue

	# Read Directory with Environment parsers.
	return if ( !opendir( DIR, $dir ) );
	my @items;
	@items = readdir DIR;
	closedir DIR;

	# Add all available Environment parsers.
	foreach my $file (@items) {
		if ( -f "$dir/$file" && $file =~ /\.(pm)$/ ) {
			$file =~ s/\.(pm)$//;
			my $module = "AI::Environment::$file";
			eval "use $module;";
			if ($@) {
				warning TF("Cannot load Environment parser \"%s\".\nError Message: \n%s", $module, $@ );
				next;
			}
			my $constructor = UNIVERSAL::can( $module, 'new' );
			if ( !$constructor ) {
				warning TF( "Environment parser \"%s\" has no constructor.\n", $module );
				next;
			}
			my $parse_msg = UNIVERSAL::can( $module, 'parse_msg' );
			if ( !$parse_msg ) {
				warning TF( "Environment parser \"%s\" has no parsing function.\n", $module );
				next;
			}
			# call "$module::new($self). So that module can use our functions
			my $env_parser = $constructor->( $module, $self );


			if (!defined $self->{listeners}->{$env_parser->getName()}) {
				$self->{listeners}->{$env_parser->getName()} = $env_parser;
			} else {
				warning TF( "Environment parser name \"%s\" is already registered.\n", $env_parser->getName() );
				next;
			}
			
		}
	}

	return $self;
}

####################################
### CATEGORY: Destructor
####################################

sub DESTROY {
	my ($self) = @_;
	$self->SUPER::DESTROY() if ($self->can("SUPER::DESTROY"));
}


####################################
### CATEGORY: Public
####################################

##
# $EnvironmentQueue->queue_add(name, params)
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
# $EnvironmentQueue->iterate()
#
# Called Every time (can be called even in infinite loop)
# Used to check Whatever new Object appeared in Queue
#
sub iterate {
	my ($self) = @_;
	lock ($self) if (is_shared($self));

	while ($self->{queue}->pending > 0) {
		my $object = $self->{queue}->dequeue;
		my $full_object;
		if ((defined $object->{name})&&(defined $object->{params})) {
			# Check for Environment Listener
			if (defined $self->{listeners}->{$object->{name}}) {
				# Get Listener class.
				my $class = blessed($self->{listeners}->{$object->{name}});
				$class =~ s/.*:://;

				# If it's registered true "register_listener" then it cannot return $full_object becouse it's CallbackList
				if ($class eq "CallbackList") {
					$self->{listeners}->{$object->{name}}->call($self, $object->{params});
				} else {
					$full_object = $self->{listeners}->{$object->{name}}->parse_msg($self, $object->{params});
				};
			} else {
				warning T("Warning!!! Unknown Environment message found: \"" . $object->{name} . "\".\n");
				next;
			};
			# If $full_object is still empty, then we fill it.
			$full_object = $object->{params} if (!defined $full_object);
			# Check for Smart Events
			if (defined $self->{smart_events}->{$object->{name}}) {
				$self->{smart_events}->{$object->{name}}->call($self, $full_object);
			};
		} else {
			warning T("Warning!!! Unknown Environment Object Received.\n");
			next;
		};
	};
}

##
# $EnvironmentQueue->register_listener(name, listener_sub, listener_self, [params, ...])
# Return: listener ID.
#
# Register new Environment Listener object.
#
# Example:
# my $ID = $environmentQueue->register_listener("my_listener", \&my_callback, \$self, $params);
#
sub register_listener {
	my $self = shift;
	my $name = shift;
	my $listener_sub = shift;
	my $listener_self = shift;
	my $params = @_;

	lock ($self) if (is_shared($self));
	lock ($listener_self) if ((defined $listener_self) && (is_shared($listener_self)));

	# There is no such listener yet. So we create it.
	# If there is one, and it's not registered trough 'register_listener'
	if (!defined $self->{listeners}->{$name}) {
		my $new_listener = CallbackList->new($name);
		$new_listener = shared_clone($new_listener) if (is_shared($self));
		$self->{listeners}->{$name} = $new_listener;
	}

	my $class = blessed($self->{listeners}->{$name});
	$class =~ s/.*:://;

	# If it's registered true "register_listener" then it will be Registered
	# else we show Warning message!
	if ($class eq "CallbackList") {
		# Now we have an empty listener object, or already made. So we add our callback there.
		$listener_self = undef if (!defined $listener_self);
		return $self->{listeners}->{$name}->add($listener_self, $listener_sub, $params); 
	} else {
		warning TF( "Default Environment parser name \"%s\" cannot be Reregistered.\n", $name );
	}
	return undef;
}

##
# $EnvironmentQueue->unregister_listener(name, ID)
#
# UnRegister Listener Object by given name and ID.
#
sub unregister_listener {
	my ($self, $name, $id) = @_;
	lock ($self) if (is_shared($self));
	
	if (defined $self->{listeners}->{$name}) {
		my $class = blessed($self->{listeners}->{$name});
		$class =~ s/.*:://;

		# If it's registered trough "register_listener" then it can be UnRegistered
		# else we show Warning message!
		if ($class eq "CallbackList") {
			$self->{listeners}->{$name}->remove($id);
		} else {
			warning TF( "Default Environment parser name \"%s\" cannot be UnReregistered.\n", $name );
		}
	}
}

##
# $EnvironmentQueue->register_event(name, rules, event_sub, event_self, [params, ...])
# Return: event ID
#
# Register Smart Event Object.
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

	# Now we have an empty smart event object, or already made. So we add our callback there.
	$event_self = undef if (!defined $event_self);

	return $self->{smart_events}->{$name}->add($event_self, $rules, $event_sub, $params); 
}

##
# $EnvironmentQueue->unregister_event(ID)
#
# UnRegister Smart Event Object by given ID.
#
sub unregister_event {
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

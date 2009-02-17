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
# MODULE DESCRIPTION: AI Module Manager.
package AI::AImoduleManager;

# Make all References Strict
use strict;

# MultiThreading Support
use threads;
use threads::shared;

# Others (Perl Related)
use Carp::Assert;
use FindBin qw($RealBin);
use List::Util qw(first);

# Others (Kore related)
use Modules 'register';
use AI::AImodule;
use Utils::Set;
use Utils::CallbackList;
use Utils qw(timeOut);
use Log qw(warning debug);
use Translation qw(TF);

####################################
### CATEGORY: Constructor
####################################

##
# AI::AImoduleManager->new()
#
# Create a new AI::AImoduleManager.
sub new {
	my ($class) = @_;
	my $dir = "$RealBin/src/AI/AImodule";
	my $self = {};
	bless $self, $class;

	# Utils::Set<AI::AImodule>
	# Indexed set of currently active modules.
	$self->{activeModules} = new Utils::Set();

	# Array of IDs, that show in which order to check AI::AIModules.
	$self->{modules_list} = [];

	# Postponed mutex list
	# Every mutex has time, to reactivate.
	$self->{pospone_mutex_list} = {};

	# Hash of IDs and corresponding index in activeModules Set.
	$self->{cache_modules_id} = {};

	# Whatever there is active AI module with exlusive marker.
	# If it's not -1, then it's module ID running Exclusive Task.
	$self->{activeExlusiveTask} = -1;

	# Last generated ID.
	$self->{lastID} = 0;

	######
	#
	# Load default modules

	# Read Directory with AI::AIModule's.
	return if ( !opendir( DIR, $dir ) );
	my @items = readdir DIR;
	closedir DIR;

	# Add all available AI::AIModule's.
	foreach my $file (@items) {
		if ( -f "$dir/$file" && $file =~ /\.(pm)$/ ) {
			$file =~ s/\.(pm)$//;
			my $module = "AI::AImodule::$file";
			eval "use $module;";
			if ($@) {
				warning TF("Cannot load AI Module \"%s\".\nError Message: \n%s", $module, $@ );
				next;
			}
			my $constructor = UNIVERSAL::can( $module, 'new' );
			if ( !$constructor ) {
				warning TF( "AI Module \"%s\" has no constructor.\n", $module );
				next;
			}
			my $parse_msg = UNIVERSAL::can( $module, 'check' );
			if ( !$parse_msg ) {
				warning TF( "AI Module \"%s\" is not default.\n", $module );
				next;
			}
			# call "$module::new($self). So that module can use our functions
			my $ai_module = $constructor->( $module, $self );

			$self->add($ai_module);
		};
	};

	return $self;
}

####################################
### CATEGORY: Destructor
####################################

sub DESTROY {
	my ($self) = @_;
	if ($self->can("SUPER::DESTROY")) {
		debug "Destroying: ".__PACKAGE__."!\n";
		$self->SUPER::DESTROY();
	}
}

#####################################
### CATEGORY: Public
#####################################

##
# int $AImoduleManager->add(AI::AImodule module)
#
# Add a new AI module to this AI module manager.
sub add {
	my ($self, $module) = @_;
	assert(defined $module) if DEBUG;

	# MultiThreading Support
	lock ($self) if (is_shared($self));
	lock ($module) if (is_shared($module));

	# Avoid adding already existing module phase 1
	if ($self->{activeModules}->has($module)) {
		return 0;
	};


	# Avoid adding already existing module phase 2
	if ($module->{T_ID} > 0) {
		# We do not allow adding already added modules
		return 0;
	}

	# Generate module ID.
	my $module_id = $self->_gen_id();
	$module->{T_ID} = $module_id;

	# Add our Event handler, to controll AI modules workflow.
	# $module->onStop->add($self, \&onTaskFinished, $module->{T_ID});

	# Add module to Set
	$self->{activeModules}->add($module);
	
	# ReForm our Cache for better performance.
	$self->_cache_id();
	
	# Calculate Priorities, and Order all modules
	$self->_calc_priority();

	# Return module ID
	return $module_id;
}

##
# bool $AImoduleManager->delete(int ID)
#
# Remove AI module from AI module manager Modules List by given ID.
sub remove {
	my ($self, $id) = @_;
	assert(defined $id) if DEBUG;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	if ($id > 0) {
		my $index = $self->_get_index_by_id($id);
		if ($index >= 0) {
			my $module = $self->{activeModules}->get($index);
			# Re check module ID
	     		if ($module->getID() == $id) {
				# Check if given module has non finished tasks
				if ($self->_check_module($id) > 0) {
					return 0;
				};
				
				# Remove module from Set.
				$self->{activeModules}->remove($module);

				# ReForm our Cache for better performance.
				$self->_cache_id();

				# Calculate Priorities, and Order all modules.
				$self->_calc_priority();

				# Return
				return 1;
			};
		};
	};

	# Callers should take actions, if we return 0.
	return 0;
}

##
# bool $AImoduleManager->has(int ID)
#
# Return 1, if we have that module inside out Set.
sub has {
	my ($self, $id) = @_;
	assert(defined $id) if DEBUG;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	my $index = $self->_get_index_by_id($id);
	if ($index >= 0) {
		return 1;
	};
	return 0;
}

##
# void $AImoduleManager->postpone(String mutex, int timeout)
#
# Postpone modules with given mutex name for some time
# If timeout == 0 then that mutex will be permanently postponed 
sub postpone {
	my ($self, $mutex, $timeout) = @_;
	assert(defined $mutex) if DEBUG;
	assert(defined $timeout) if DEBUG;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	my %time;
	$time{time} = time;
	$time{timeout} = $timeout;

	# MultiThreading Support
	%time = shared_clone(%time) if (is_shared($self));

	$self->{pospone_mutex_list}->{$mutex} = %time;

	# Calculate Priorities, and Order all modules.
	$self->_calc_priority();
};

##
# void $AImoduleManager->iterate() 
#
# Check all AI::AImodule's for spawning Tasks.
# If an AI::AImodule with Exclusive marker spawns a task
# we will stop checking other module's until the module with
# the Exclusive marker, tells that it's finished.
sub iterate {
	my ($self) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	# We have Exclusive Task, So just check it
	if ($self->{activeExlusiveTask} > -1) {
		my $id = $self->{activeExlusiveTask};
		# Check if we Really have it
		if ($self->has($id) > 0) {
			# Just wait to finish that module's tasks.
			return;
		} else {
			# ToDo
			# Trow Error
		};
	};

	# Check every module, until all modules are checked,
	# or a module with exclusive marker pops up.
	my @mutex_lock;
	foreach my $id (@{$self->{modules_list}}) {
		my $index = $self->_get_index_by_id($id);
		my $module = $self->{activeModules}->get($index);

		# Block running module with locked mutexes
		my $found_mutex = undef;
		foreach my $mutex (@{$module->getMutex()}) {
			$found_mutex = first { $_ eq $mutex } @mutex_lock;
			last if (defined $found_mutex);
		};
		next if (defined $found_mutex);

		# run module
		if ($self->_run_module($id) > 0) {
			# Add mutexes to mutex_lock array
			push @mutex_lock, [$module->getMutex()];

			# Out module with Exclusive marker produced a Task
			# So just finish doing stuff
			if ($self->{activeExlusiveTask} == $id) {
				return;
			};
		};
	};

	# Do we need to recalc modules run list?
	if ($self->_check_mutex_postpone_timeout() > 0) {
		$self->_calc_priority();
	};
}

#####################################
### CATEGORY: Private
#####################################

# calculate which module to check
# store their id's inside $self->{modules_list}
# block any module remove attempt
sub _calc_priority {
	my ($self) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	# Check out postponed mutexes
	$self->_check_mutex_postpone_timeout();

	# Place holder for our active modules
	my @active_modules;

	# add all ID's to our cache id's array	
	foreach my $id (keys %{$self->{cache_modules_id}}) {
		my $index = $self->_get_index_by_id($id);
		my $module = $self->{activeModules}->get($index);

		my $found_mutex = undef;
		foreach my $mutex (@{$module->getMutex()}) {
			$found_mutex = 1 if (exists $self->{pospone_mutex_list}->{$mutex});
			last if (defined $found_mutex);
		};
		next if (defined $found_mutex);

		push(@active_modules, $id);
	};

	# now sort active modules by their priority. (The bigger one wins).
	@{$self->{modules_list}} = sort {$self->{activeModules}->get($self->_get_index_by_id($a))->getPriority() <=> $self->{activeModules}->get($self->_get_index_by_id($b))->getPriority()} @active_modules;
}

# generate new module ID
sub _gen_id {
	my ($self) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	$self->{lastID} = $self->{lastID} + 1;
	return $self->{lastID};
}

# run module by given id
sub _run_module {
	my ($self, $id) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	my $index = $self->_get_index_by_id($id);
	if ($index >= 0) {
		my $module = $self->{activeModules}->get($index);
		$module->check();
			
		my $task = $module->get_task();
		if (defined $task) {
			$module->{T_task_count}++;

			# Add our Event handler, to control AI modules workflow.
			$task->onStop->add($self, \&onTaskFinished, $module->{T_ID});

			if ($module->getExclusive() > 0) {
				$self->{activeExlusiveTask} = $module->{T_ID};
			};

			# ToDo
			# Actually add task to TaskManager
			# $AI->{task_mgr}->add($task);

			# Return 1 because that module is running. Weeee!!!
			return 1;
		};
	};
	return 0;
}

# check if module with given ID is still working
# return 1 if tasks spawned by module with given ID are still working.
sub _check_module {
	my ($self, $id) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	my $index = $self->_get_index_by_id($id);
	if ($index >= 0) {
		my $module = $self->{activeModules}->get($index);
		if ($module->{T_task_count} > 0) {
			return 1;
		};
	};
	return 0;
}

# Cache all IDs for better performance
# Should rebuild upon adding or removing dmodule
sub _cache_id {
	my ($self, $id) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	# Empty our Hash
	foreach my $member (keys %{$self->{cache_modules_id}}) {
		delete $self->{cache_modules_id}->{$member};
	};
	
	# Fill our Cache
	foreach my $module (@{\%{$self->{activeModules}}}) {
		my $index = $self->{activeModules}->find($module);
		my $id = $module->getID();
		$self->{cache_modules_id}->{$id} = $index;
	}
}

# Return index inside Set, or -1 if none found
sub _get_index_by_id {
	my ($self, $id) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	# We have cached our ID?
	if ((exists $self->{cache_modules_id}->{$id})&&($self->{cache_modules_id}->{$id} >= 0)) {
		my $module = $self->{activeModules}->get($self->{cache_modules_id}->{$id});
		# Re check module ID
     		if ($module->getID() == $id) {
			my $index = $self->{activeModules}->find($module);
			return $index;
		};
	};

	# OOps. None found???
	foreach my $module (@{\%{$self->{activeModules}}}) {
     		if ($module->getID() == $id) {
			my $index = $self->{activeModules}->find($module);
			return $index;
		};
	};

	return -1;
}

# Return, whatever we need to recalculate modules order
sub _check_mutex_postpone_timeout {
	my ($self) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	my $result;
	$result = 0;

	foreach my $mutex (keys %{$self->{pospone_mutex_list}}) {
		my %time = $self->{pospone_mutex_list}->{$mutex};
		if (($time{timeout} == 0)||(timeOut(\%time))) {
			delete $self->{pospone_mutex_list}->{$mutex};
			$result = 1;
		};
	};
	return $result;
}

#####################################
### CATEGORY: Events
#####################################

##
# void $AImoduleManager->onTaskFinished()
#
# This event is triggered when a task spawned by AI module is finished, either successfully
# or with an error.
#
sub onTaskFinished {
	my ($self, $id) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	my $index = $self->_get_index_by_id($id);
	if ($index >= 0) {
		my $module = $self->{activeModules}->get($index);

		# Adjust module Tasks counter
		$module->{T_task_count}--;
		$module->{T_task_count} = 0 if ($module->{T_task_count} < 0);

		# Adjust Exclusive task marker
		if ($self->{activeExlusiveTask} == $id) {
			if ($module->{T_task_count} <= 0) {
				$self->{activeExlusiveTask} = -1;
			};
		};
	} else {
		# O_o. Something wrong. Why we landed here???
	};
}

1;

package eventMacro::Core;

use strict;
use Globals;
use Log qw(message error warning);
use Utils;

use eventMacro::Core;
use eventMacro::Data;
use eventMacro::Lists;
use eventMacro::Automacro;
use eventMacro::FileParser;
use eventMacro::Macro;
use eventMacro::Utilities qw(ai_isIdle processCmd);
use eventMacro::Runner;
use eventMacro::Parser;

use Data::Dumper;

use constant {
	CHECKING => 0,
	EXECUTING => 1
};

use constant {
	NOT_PAUSED => 0,
	PAUSED => 1
};

sub new {
	my ($class, $file) = @_;
	my $self = bless {}, $class;
	
	my $parse_result = parseMacroFile($file, 0);
	return undef unless ($parse_result);
	
	$self->{macro_list} = new eventMacro::Lists;
	$self->create_macro_list($parse_result->{macros});
	
	$self->{automacro_list} = new eventMacro::Lists;
	$self->create_automacro_list($parse_result->{automacros});
	
	$self->{status} = CHECKING;
	$self->{paused} = NOT_PAUSED;
	
	$self->{index_priority_list} = [];
	$self->create_priority_list();
	
	$self->{event_related_variables} = {};
	$self->{event_related_hooks} = {};
	$self->{hook_handles} = [];
	$self->create_callbacks();
	
	$self->{macro_runner} = undef;
	$self->{mainLoop_hook_handle} = undef;
	
	$self->{variable_list_hash} = {};
	
	return $self;
}

sub unload {
	my ($self) = @_;
	$self->clearQueue();
	$self->cleanHooks();
}

sub cleanHooks {
	my ($self) = @_;
	foreach (@{$self->{hook_handles}}) {Plugins::delHook($_)}
}

sub is_paused {
	my ($self) = @_;
	return ( $self->{paused} ? 1 : 0 );
}

sub is_executing {
	my ($self) = @_;
	return ( $self->{status} ? 1 : 0 );
}

sub pause {
	my ($self) = @_;
	$self->{paused} = PAUSED;
}

sub unpause {
	my ($self) = @_;
	$self->{paused} = NOT_PAUSED;
}

sub create_priority_list {
	my ($self) = @_;
	
	my %priority_hash;
	foreach my $automacro (@{$self->{automacro_list}->getItems()}) {
		$priority_hash{$automacro->{listIndex}} = $automacro->get_parameter('priority');
	}
	@{$self->{index_priority_list}} = sort { $priority_hash{$a} <=> $priority_hash{$b} } keys %priority_hash;
}

sub create_macro_list {
	my ($self, $macro) = @_;
	while (my ($name,$lines) = each %{$macro}) {
		my $currentMacro = new eventMacro::Macro($name, $lines);
		$self->{macro_list}->add($currentMacro);
	}
}

sub create_automacro_list {
	my ($self, $automacro) = @_;
	my %modulesLoaded;
	AUTOMACRO: while (my ($name,$value) = each %{$automacro}) {
		my ($currentAutomacro, %currentConditions, %currentParameters);
		
		####################################
		#####No Conditions Check
		####################################
		if (!exists $value->{'conditions'} || !@{$value->{'conditions'}}) {
			print AUTO "Ignoring automacro '$name' (munch, munch, no condition set)\n";
			next AUTOMACRO;
		}
	
		####################################
		#####No Parameters Check
		####################################
		if (!exists $value->{'parameters'} || !@{$value->{'parameters'}}) {
			print AUTO "Ignoring automacro '$name' (munch, munch, no parameter set)\n";
			next AUTOMACRO;
		}
		
		PARAMETER: foreach my $parameter (@{$value->{'parameters'}}) {
		
			###Check Duplicate Parameter
			if (exists $currentParameters{$parameter->{'key'}}) {
				warning "Ignoring automacro '$name' (parameter ".$parameter->{'key'}." duplicate)\n";
				next AUTOMACRO;
			}
			###Parameter: call
			if ($parameter->{'key'} eq "call" && !$self->{macro_list}->getByName($parameter->{'value'})) {
				warning "Ignoring automacro '$name' (call '".$parameter->{'value'}."' is not a valid macro name)\n";
				next AUTOMACRO;
			
			###Parameter: delay
			} elsif ($parameter->{'key'} eq "delay" && $parameter->{'value'} !~ /\d+/) {
				print AUTO "Ignoring automacro '$name' (delay parameter should be a number)\n";
				next AUTOMACRO;
			
			###Parameter: run-once
			} elsif ($parameter->{'key'} eq "run-once" && $parameter->{'value'} !~ /[01]/) {
				print AUTO "Ignoring automacro '$name' (run-once parameter should be '0' or '1')\n";
				next AUTOMACRO;
			
			###Parameter: disabled
			} elsif ($parameter->{'key'} eq "disabled" && $parameter->{'value'} !~ /[01]/) {
				print AUTO "Ignoring automacro '$name' (disabled parameter should be '0' or '1')\n";
				next AUTOMACRO;
			
			###Parameter: overrideAI
			} elsif ($parameter->{'key'} eq "overrideAI" && $parameter->{'value'} !~ /[01]/) {
				print AUTO "Ignoring automacro '$name' (overrideAI parameter should be '0' or '1')\n";
				next AUTOMACRO;
			
			###Parameter: exclusive
			} elsif ($parameter->{'key'} eq "exclusive" && $parameter->{'value'} !~ /[01]/) {
				print AUTO "Ignoring automacro '$name' (exclusive parameter should be '0' or '1')\n";
				next AUTOMACRO;
			
			###Parameter: priority
			} elsif ($parameter->{'key'} eq "priority" && $parameter->{'value'} !~ /\d+/) {
				print AUTO "Ignoring automacro '$name' (priority parameter should be a number)\n";
				next AUTOMACRO;
			
			###Parameter: macro_delay
			} elsif ($parameter->{'key'} eq "macro_delay" && $parameter->{'value'} !~ /(\d+|\d+\.\d+)/) {
				print AUTO "Ignoring automacro '$name' (macro_delay parameter should be a number (decimals are accepted))\n";
				next AUTOMACRO;
			
			###Parameter: orphan
			} elsif ($parameter->{'key'} eq "orphan" && $parameter->{'value'} !~ /(terminate|reregister|reregister_safe)/) {
				print AUTO "Ignoring automacro '$name' (orphan parameter should be 'terminate', 'reregister' or 'reregister_safe')\n";
				next AUTOMACRO;
			} else {
				$currentParameters{$parameter->{'key'}} = $parameter->{'value'};
			}
		}
		
		###Recheck Parameter call
		if (!exists $currentParameters{'call'}) {
			warning "Ignoring automacro '$name' (all automacros must have a macro call)\n";
			next AUTOMACRO;
		}
		
		####################################
		#####Conditions Check
		####################################
		CONDITION: foreach my $condition (@{$value->{'conditions'}}) {
			my ($conditionObject, $autoModule);
			$autoModule = "eventMacro::Condition::".ucfirst($condition->{'key'});
			if (!exists $modulesLoaded{$autoModule}) {
				undef $@;
				message "[Macro] Loading module $autoModule\n";
				eval "use $autoModule";
				if ($@ =~ /^Can't locate /s) {
					FileNotFoundException->throw("Cannot load automacro module ".$autoModule." for condition ".$condition->{'key'}.". Ignoring automacro ".$name.".");
					next AUTOMACRO;
				} elsif ($@) {
					ModuleLoadException->throw("An error occured while loading the automacro condition ".$condition->{'key'}.":".$@.". Ignoring automacro ".$name.".");
					next AUTOMACRO;
				}
				$modulesLoaded{$autoModule} = 1;
			}
			$conditionObject = $autoModule->new($condition->{'value'});
			next AUTOMACRO if (!$conditionObject);
			next AUTOMACRO if (exists $currentConditions{$autoModule} && $conditionObject->is_unique_condition());
			push(@{$currentConditions{$autoModule}}, $condition->{'value'});
		}
		
		####################################
		#####Automacro Object Creation
		####################################
		$currentAutomacro = new eventMacro::Automacro($name, \%currentConditions, \%currentParameters);
		$self->{automacro_list}->add($currentAutomacro);
	}
}

sub create_callbacks {
	my ($self) = @_;
	
	foreach my $automacro (@{$self->{automacro_list}->getItems()}) {
		my $automacro_index = $automacro->{listIndex};
		
		foreach my $hook_name (keys %{$automacro->{hooks}}) {
			my $conditions_indexes = $automacro->{hooks}->{$hook_name};
			foreach my $condition_index (@{$conditions_indexes}) {
				push (@{$self->{event_related_hooks}{$hook_name}{$automacro_index}}, $condition_index);
			}
		}
		
		foreach my $variable_name (keys %{$automacro->{variables}}) {
			my $conditions_indexes = $automacro->{variables}->{$variable_name};
			foreach my $condition_index (@{$conditions_indexes}) {
				push (@{$self->{event_related_variables}{$variable_name}{$automacro_index}}, $condition_index);
			}
		}
		
	}
	
	my $ai_sub = sub { $self->AI_pre_checker(); };
	push( @{ $self->{hook_handles} }, Plugins::addHook( 'AI_pre', $ai_sub, undef ) );
	
	
	my $event_sub = sub { $self->manage_event_callbacks(shift, shift); };
	foreach my $hook_name (keys %{$self->{event_related_hooks}}) {
		push( @{ $self->{hook_handles} }, Plugins::addHook( $hook_name, $event_sub, undef ) );
	}
}

sub get_var {
	my ($self, $variable_name) = @_;
	return $self->{variable_list_hash}{$variable_name} if (exists $self->{variable_list_hash}{$variable_name});
	return undef;
}

sub set_var {
	my ($self, $variable_name, $variable_value) = @_;
	if ($variable_value eq 'undef') {
		$self->{variable_list_hash}{$variable_name} = undef;
	} else {
		$self->{variable_list_hash}{$variable_name} = $variable_value;
	}
	if (exists $self->{event_related_variables}{$variable_name}) {
		$self->manage_event_callbacks("variable_event", {variable_name => $variable_name, variable_value => $variable_value});
	}
}

sub is_var_defined {
	my ($self, $variable_name) = @_;
	return (defined $self->{variable_list_hash}{$variable_name});
}

sub exists_var {
	my ($self, $variable_name) = @_;
	return (exists $self->{variable_list_hash}{$variable_name});
}

sub manage_event_callbacks {
	my $self = shift;
	my $event_name = shift;
	my $args = shift;
	
	message "[eventMacro] Event Happenned '".$event_name."'\n","system";
	my $check_list_hash;
	
	if ($event_name eq 'variable_event') {
		$check_list_hash = $self->{'event_related_variables'}{$args->{'variable_name'}};
	} else {
		$check_list_hash = $self->{'event_related_hooks'}{$event_name};
	}
	
	foreach my $automacro_index (keys %{$check_list_hash}) {
		my ($automacro, $conditions_indexes_array, $need_to_check) = ($self->{automacro_list}->get($automacro_index), $check_list_hash->{$automacro_index}, 0);
		
		message "[eventMacro] automacro index: '".$automacro_index."' name: '".$automacro->{name}."'\n","system";
		
		foreach my $condition_index (@{$conditions_indexes_array}) {
			my $condition = $automacro->{conditionList}->get($condition_index);
			
			#Does this actually change cpu use?
			my $pre_check_status = $condition->is_fulfilled();
			
			message "[eventMacro] Checking condition '".$condition->{name}."' index '".$condition->{listIndex}."'\n","system";
			
			$condition->validate_condition_status($event_name,$args);
			
			#Does this actually change cpu use?(cont from above)
			if (!$need_to_check && $pre_check_status != $condition->is_fulfilled()) {
				$need_to_check = 1;
			}
		}
		
		#same here (if check)
		$automacro->validate_automacro_status() if ($need_to_check);
	}
}

sub AI_pre_checker {
	my ($self) = @_;
	
	#maybe we should have a list of fulfilled automacros instead of checking for it each AI_pre cycle
	#would using a binary heap to extract and add members to above said list benefit cpu use?
	
	#should AI_pre only be hooked when we are sure there are automacros with conditions fulfilled?
	
	#message "[eventMacro] AI PRE 11\n","system";
	
	return if (defined $self->{macro_runner} && !$self->{macro_runner}->interruptible());
	
	#message "[eventMacro] AI PRE 22\n","system";
	
	foreach my $index (@{$self->{index_priority_list}}) {
	
		my $automacro = $self->{automacro_list}->get($index);
		
		next if $automacro->is_disabled();
		
		next unless $automacro->is_timed_out();
		
		next unless $automacro->are_conditions_fulfilled();
		
		message "[eventMacro] Conditions met for automacro '".$automacro->{name}."', calling macro '".$automacro->get_parameter('call')."'\n","system";
		
		$self->callMacro($automacro);
		
		return;
	}
}

#sub hook_dependent_automacro_checker {
#		
#}

sub callMacro {
	my ($self, $automacro) = @_;
	
	if (defined $self->{macro_runner}) {
		$self->clearQueue();
	}
	
	message "[eventMacro] automacro '".$automacro->{name}."', status pre: '".$automacro->is_disabled()."'\n","system";
	
	$automacro->set_timeout_time(time);
	$automacro->disable() if $automacro->get_parameter('run-once');
	
	message "[eventMacro] automacro '".$automacro->{name}."', status pos: '".$automacro->is_disabled()."'\n","system";
	
	$self->{macro_runner} = new eventMacro::Runner($automacro->get_parameter('call'));
	
	if (defined $self->{macro_runner}) {
		$self->{macro_runner}->overrideAI($automacro->get_parameter('overrideAI'));
		$self->{macro_runner}->interruptible($automacro->get_parameter('exclusive') ? 0 : 1);#inversed
		$self->{macro_runner}->orphan($automacro->get_parameter('orphan'));
		$self->{macro_runner}->timeout($automacro->get_parameter('delay'));
		$self->{macro_runner}->setMacro_delay($automacro->get_parameter('macro_delay'));
		$self->set_var('.caller', $automacro->{name});
		$self->unpause();
		my $iterateMacro_sub = sub { $self->iterateMacro(); };
		$self->{mainLoop_hook_handle} = Plugins::addHook( 'mainLoop_pre', $iterateMacro_sub, undef );
	} else {
		error "unable to create macro queue.\n"
	}
}

# macro/script
sub iterateMacro {
	my $self = shift;
	if ( !defined $self->{macro_runner} ) {
		message "[eventMacro] Macro '".$self->{macro_runner}->{name}."' was finished in a bad way\n","system";
		$self->clearQueue();
		return;
	} elsif ($self->{macro_runner}->finished) {
		message "[eventMacro] Macro '".$self->{macro_runner}->{name}."' was finished successfully\n","system";
		$self->clearQueue();
		return;
	}
	return if $self->is_paused();
	my %tmptime = $self->{macro_runner}->timeout;
	unless ($self->{macro_runner}->registered || $self->{macro_runner}->overrideAI) {
		if (timeOut(\%tmptime)) {$self->{macro_runner}->register}
		else {return}
	}
	if (timeOut(\%tmptime) && ai_isIdle()) {
		do {
			last unless processCmd $self->{macro_runner}->next;
			Plugins::callHook ('macro/callMacro/process');
		} while $self->{macro_runner} && !$self->is_paused() && $self->{macro_runner}->macro_block;
		
=pod
		# crashes when error inside macro_block encountered and $self->{macro_runner} becomes undefined
		my $command = $self->{macro_runner}->next;
		if ($self->{macro_runner}->macro_block) {
			while ($self->{macro_runner}->macro_block) {
				$command = $self->{macro_runner}->next;
				processCmd($command)
			}
		} else {
			processCmd($command)
		}
=cut
	}
}

sub clearQueue {
	my ($self) = @_;
	message "[eventMacro] Clearing queue\n","system";
	$self->{macro_runner} = undef;
	Plugins::delHook($self->{mainLoop_hook_handle}) if (defined $self->{mainLoop_hook_handle});
	$self->{mainLoop_hook_handle} = undef;
}


1;

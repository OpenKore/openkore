package eventMacro::Core;

use strict;
use Globals;
use Log qw(message error warning debug);
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
use eventMacro::Condition;

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
	
	$self->{Macro_List} = new eventMacro::Lists;
	$self->create_macro_list($parse_result->{macros});
	
	$self->{Automacro_List} = new eventMacro::Lists;
	$self->{Condition_Modules_Loaded} = {};
	$self->create_automacro_list($parse_result->{automacros});
	
	$self->{Status} = CHECKING;
	$self->{Paused} = NOT_PAUSED;
	
	$self->{Index_Priority_List} = [];
	$self->create_priority_list();
	
	$self->{Event_Related_Variables} = {};
	$self->{Event_Related_Hooks} = {};
	$self->{Hook_Handles} = [];
	$self->create_callbacks();
	
	$self->{Macro_Runner} = undef;
	$self->{mainLoop_Hook_Handle} = undef;
	
	$self->{Variable_List_Hash} = {};
	
	return $self;
}

sub unload {
	my ($self) = @_;
	$self->clear_queue();
	$self->clean_hooks();
}

sub clean_hooks {
	my ($self) = @_;
	foreach (@{$self->{Hook_Handles}}) {Plugins::delHook($_)}
}

sub is_paused {
	my ($self) = @_;
	return ( $self->{Paused} ? 1 : 0 );
}

sub is_executing {
	my ($self) = @_;
	return ( $self->{Status} ? 1 : 0 );
}

sub pause {
	my ($self) = @_;
	$self->{Paused} = PAUSED;
}

sub unpause {
	my ($self) = @_;
	$self->{Paused} = NOT_PAUSED;
}

sub create_priority_list {
	my ($self) = @_;
	
	my %priority_hash;
	foreach my $automacro (@{$self->{Automacro_List}->getItems()}) {
		$priority_hash{$automacro->{listIndex}} = $automacro->get_parameter('priority');
	}
	@{$self->{Index_Priority_List}} = sort { $priority_hash{$a} <=> $priority_hash{$b} } keys %priority_hash;
}

sub create_macro_list {
	my ($self, $macro) = @_;
	while (my ($name,$lines) = each %{$macro}) {
		my $currentMacro = new eventMacro::Macro($name, $lines);
		$self->{Macro_List}->add($currentMacro);
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
			error "[eventMacro] Ignoring automacro '$name'. There are no conditions set it in\n";
			next AUTOMACRO;
		}
	
		####################################
		#####No Parameters Check
		####################################
		if (!exists $value->{'parameters'} || !@{$value->{'parameters'}}) {
			error "[eventMacro] Ignoring automacro '$name'. There are no parameters set in it\n";
			next AUTOMACRO;
		}
		
		PARAMETER: foreach my $parameter (@{$value->{'parameters'}}) {
		
			###Check Duplicate Parameter
			if (exists $currentParameters{$parameter->{'key'}}) {
				warning "[eventMacro] Ignoring automacro '$name' (parameter ".$parameter->{'key'}." duplicate)\n";
				next AUTOMACRO;
			}
			###Parameter: call
			if ($parameter->{'key'} eq "call" && !$self->{Macro_List}->getByName($parameter->{'value'})) {
				warning "[eventMacro] Ignoring automacro '$name' (call '".$parameter->{'value'}."' is not a valid macro name)\n";
				next AUTOMACRO;
			
			###Parameter: delay
			} elsif ($parameter->{'key'} eq "delay" && $parameter->{'value'} !~ /\d+/) {
				error "[eventMacro] Ignoring automacro '$name' (delay parameter should be a number)\n";
				next AUTOMACRO;
			
			###Parameter: run-once
			} elsif ($parameter->{'key'} eq "run-once" && $parameter->{'value'} !~ /[01]/) {
				error "[eventMacro] Ignoring automacro '$name' (run-once parameter should be '0' or '1')\n";
				next AUTOMACRO;
			
			###Parameter: disabled
			} elsif ($parameter->{'key'} eq "disabled" && $parameter->{'value'} !~ /[01]/) {
				error "[eventMacro] Ignoring automacro '$name' (disabled parameter should be '0' or '1')\n";
				next AUTOMACRO;
			
			###Parameter: overrideAI
			} elsif ($parameter->{'key'} eq "overrideAI" && $parameter->{'value'} !~ /[01]/) {
				error "[eventMacro] Ignoring automacro '$name' (overrideAI parameter should be '0' or '1')\n";
				next AUTOMACRO;
			
			###Parameter: exclusive
			} elsif ($parameter->{'key'} eq "exclusive" && $parameter->{'value'} !~ /[01]/) {
				error "[eventMacro] Ignoring automacro '$name' (exclusive parameter should be '0' or '1')\n";
				next AUTOMACRO;
			
			###Parameter: priority
			} elsif ($parameter->{'key'} eq "priority" && $parameter->{'value'} !~ /\d+/) {
				error "[eventMacro] Ignoring automacro '$name' (priority parameter should be a number)\n";
				next AUTOMACRO;
			
			###Parameter: macro_delay
			} elsif ($parameter->{'key'} eq "macro_delay" && $parameter->{'value'} !~ /(\d+|\d+\.\d+)/) {
				error "[eventMacro] Ignoring automacro '$name' (macro_delay parameter should be a number (decimals are accepted))\n";
				next AUTOMACRO;
			
			###Parameter: orphan
			} elsif ($parameter->{'key'} eq "orphan" && $parameter->{'value'} !~ /(terminate|reregister|reregister_safe)/) {
				error "[eventMacro] Ignoring automacro '$name' (orphan parameter should be 'terminate', 'reregister' or 'reregister_safe')\n";
				next AUTOMACRO;
			} else {
				$currentParameters{$parameter->{'key'}} = $parameter->{'value'};
			}
		}
		
		###Recheck Parameter call
		if (!exists $currentParameters{'call'}) {
			warning "[eventMacro] Ignoring automacro '$name' (all automacros must have a macro call)\n";
			next AUTOMACRO;
		}
		
		####################################
		#####Conditions Check
		####################################
		CONDITION: foreach my $condition (@{$value->{'conditions'}}) {
		
			my ($condition_object, $condition_module);
			
			$condition_module = "eventMacro::Condition::".$condition->{'key'};
			
			if (!exists $self->{Condition_Modules_Loaded}{$condition_module}) {
				unless ($self->load_condition_module($condition_module)) {
					warning "[eventMacro] Ignoring automacro '".$name."' (could not load condition module)\n";
					next AUTOMACRO;
				}
			}
			
			$condition_object = $condition_module->new($condition->{'value'});
			
			unless (defined $condition_object) {
				warning "[eventMacro] Ignoring automacro '$name' (bad condition syntax)\n";
				next AUTOMACRO;
			}
			
			if (exists $currentConditions{$condition_module} && $condition_object->is_unique_condition()) {
				error "[eventMacro] Condition '".$condition->{'key'}."' cannot be used more than once in an automacro. It was used twice (or more) in automacro '".$name."'\n";
				warning "[eventMacro] Ignoring automacro '$name' (multiple unique condition)\n";
				next AUTOMACRO;
			}
			
			push( @{ $currentConditions{$condition_module} }, $condition->{'value'} );
			
		}
		
		####################################
		#####Automacro Object Creation
		####################################
		$currentAutomacro = new eventMacro::Automacro($name, \%currentConditions, \%currentParameters);
		$self->{Automacro_List}->add($currentAutomacro);
	}
}

sub load_condition_module {
	my ($self, $condition_module) = @_;
	undef $@;
	debug "[Macro] Loading module $condition_module\n", "eventMacro", 2;
	eval "use $condition_module";
	if ($@ =~ /^Can't locate /s) {
		FileNotFoundException->throw("Cannot locate automacro module ".$condition_module.".");
	} elsif ($@) {
		ModuleLoadException->throw("An error occured while loading condition module ".$condition_module.":".$@.".");
	} else {
		$self->{Condition_Modules_Loaded}{$condition_module} = 1;
	}
}

sub create_callbacks {
	my ($self) = @_;
	
	debug "[eventMacro] create_callback called\n", "eventMacro", 2;
	
	foreach my $automacro (@{$self->{Automacro_List}->getItems()}) {
	
		debug "[eventMacro] Creating callback for automacro '".$automacro->get_name()."'\n", "eventMacro", 2;
		
		my $automacro_index = $automacro->{listIndex};
		
		foreach my $hook_name ( keys %{ $automacro->get_hooks() } ) {
		
			my $conditions_indexes = $automacro->{Hooks}->{$hook_name};
			
			foreach my $condition_index (@{$conditions_indexes}) {
				push (@{$self->{Event_Related_Hooks}{$hook_name}{$automacro_index}}, $condition_index);
			}
			
		}
		
		foreach my $variable_name ( keys %{ $automacro->get_variables() } ) {
		
			my $conditions_indexes = $automacro->{Variables}->{$variable_name};
			
			foreach my $condition_index (@{$conditions_indexes}) {
				push (@{$self->{Event_Related_Variables}{$variable_name}{$automacro_index}}, $condition_index);
			}
			
		}
		
	}
	
	my $ai_sub = sub { $self->AI_pre_checker(); };
	push( @{ $self->{Hook_Handles} }, Plugins::addHook( 'AI_pre', $ai_sub, undef ) );
	
	
	my $event_sub = sub { $self->manage_event_callbacks(shift, shift); };
	foreach my $hook_name (keys %{$self->{Event_Related_Hooks}}) {
		push( @{ $self->{Hook_Handles} }, Plugins::addHook( $hook_name, $event_sub, undef ) );
	}
}

sub get_var {
	my ($self, $variable_name) = @_;
	return $self->{Variable_List_Hash}{$variable_name} if (exists $self->{Variable_List_Hash}{$variable_name});
	return undef;
}

sub set_var {
	my ($self, $variable_name, $variable_value) = @_;
	if ($variable_value eq 'undef') {
		$self->{Variable_List_Hash}{$variable_name} = undef;
	} else {
		$self->{Variable_List_Hash}{$variable_name} = $variable_value;
	}
	if (exists $self->{Event_Related_Variables}{$variable_name}) {
		$self->manage_event_callbacks("variable_event", {variable_name => $variable_name, variable_value => $variable_value});
	}
}

sub is_var_defined {
	my ($self, $variable_name) = @_;
	return (defined $self->{Variable_List_Hash}{$variable_name});
}

sub exists_var {
	my ($self, $variable_name) = @_;
	return (exists $self->{Variable_List_Hash}{$variable_name});
}

sub manage_event_callbacks {
	my $self = shift;
	my $event_name = shift;
	my $args = shift;
	
	debug "[eventMacro] Event Happenned '".$event_name."'\n", "eventMacro", 2;
	
	my $check_list_hash;
	
	if ($event_name eq 'variable_event') {
		$check_list_hash = $self->{'Event_Related_Variables'}{$args->{'variable_name'}};
	} else {
		$check_list_hash = $self->{'Event_Related_Hooks'}{$event_name};
	}
	
	foreach my $automacro_index (keys %{$check_list_hash}) {
		my ($automacro, $conditions_indexes_array, $need_to_check) = ($self->{Automacro_List}->get($automacro_index), $check_list_hash->{$automacro_index}, 0);
		
		debug "[eventMacro] automacro index: '".$automacro_index."' name: '".$automacro->get_name()."'\n", "eventMacro", 2;
		
		foreach my $condition_index (@{$conditions_indexes_array}) {
			my $condition = $automacro->{conditionList}->get($condition_index);
			
			#Does this actually change cpu use?
			my $pre_check_status = $condition->is_fulfilled();
			
			debug "[eventMacro] Checking condition '".$condition->get_name()."' index '".$condition->{listIndex}."'\n", "eventMacro", 2;
			
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
	
	return if (defined $self->{Macro_Runner} && !$self->{Macro_Runner}->interruptible());
	
	foreach my $index (@{$self->{Index_Priority_List}}) {
	
		my $automacro = $self->{Automacro_List}->get($index);
		
		next if $automacro->is_disabled();
		
		next unless $automacro->is_timed_out();
		
		next unless $automacro->are_conditions_fulfilled();
		
		message "[eventMacro] Conditions met for automacro '".$automacro->get_name()."', calling macro '".$automacro->get_parameter('call')."'\n", "system";
		
		$self->call_macro($automacro);
		
		return;
	}
}

#sub hook_dependent_automacro_checker {
#		
#}

sub call_macro {
	my ($self, $automacro) = @_;
	
	if (defined $self->{Macro_Runner}) {
		$self->clear_queue();
	}
	
	$automacro->set_timeout_time(time);
	$automacro->disable() if $automacro->get_parameter('run-once');
	
	$self->{Macro_Runner} = new eventMacro::Runner($automacro->get_parameter('call'));
	
	if (defined $self->{Macro_Runner}) {
		$self->{Macro_Runner}->overrideAI($automacro->get_parameter('overrideAI'));
		$self->{Macro_Runner}->interruptible($automacro->get_parameter('exclusive') ? 0 : 1);#inversed
		$self->{Macro_Runner}->orphan($automacro->get_parameter('orphan'));
		$self->{Macro_Runner}->timeout($automacro->get_parameter('delay'));
		$self->{Macro_Runner}->setMacro_delay($automacro->get_parameter('macro_delay'));
		$self->set_var('.caller', $automacro->get_name());
		$self->unpause();
		my $iterate_macro_sub = sub { $self->iterate_macro(); };
		$self->{mainLoop_Hook_Handle} = Plugins::addHook( 'mainLoop_pre', $iterate_macro_sub, undef );
	} else {
		error "[eventMacro] unable to create macro queue.\n"
	}
}

# macro/script
sub iterate_macro {
	my $self = shift;
	if ( !defined $self->{Macro_Runner} ) {
		#Something used undef in $self->{Macro_Runner} without unregistering it
		debug "[eventMacro] Macro was finished in a bad way\n", "eventMacro", 2;
		$self->clear_queue();
		return;
	} elsif ($self->{Macro_Runner}->finished) {
		#Actually it should never get here, eventMacro::Runner should clear queue when macro finishes
		debug "[eventMacro] Macro '".$self->{Macro_Runner}->get_name()."' was finished successfully\n", "eventMacro", 2;
		$self->clear_queue();
		return;
	}
	return if $self->is_paused();
	my $tmptime = $self->{Macro_Runner}->timeout;
	unless ($self->{Macro_Runner}->registered || $self->{Macro_Runner}->overrideAI) {
		if (timeOut($tmptime)) {$self->{Macro_Runner}->register}
		else {return}
	}
	if (timeOut($tmptime) && ai_isIdle()) {
		do {
			last unless processCmd $self->{Macro_Runner}->next;
		} while $self->{Macro_Runner} && !$self->is_paused() && $self->{Macro_Runner}->macro_block;
	}
}

sub clear_queue {
	my ($self) = @_;
	debug "[eventMacro] Clearing queue\n", "eventMacro", 2;
	$self->{Macro_Runner} = undef;
	Plugins::delHook($self->{mainLoop_Hook_Handle}) if (defined $self->{mainLoop_Hook_Handle});
	$self->{mainLoop_Hook_Handle} = undef;
}


1;

package eventMacro::Core;

use strict;
use Globals;
use Log qw(message error warning debug);
use Utils;
use AI;

use eventMacro::Core;
use eventMacro::Data;
use eventMacro::Lists;
use eventMacro::Automacro;
use eventMacro::FileParser;
use eventMacro::Macro;
use eventMacro::Runner;
use eventMacro::Condition;
use eventMacro::Utilities qw(find_variable get_key_or_index);

sub new {
	my ($class, $file) = @_;
	my $self = bless {}, $class;

	$self->{file} = $file;

	$self->{Macro_List} = new eventMacro::Lists;
	$self->{Automacro_List} = new eventMacro::Lists;
	$self->{Condition_Modules_Loaded} = {};
	$self->{automacros_index_to_AI_check_state} = {};

	$self->{Event_Related_Hooks} = {};
	$self->{Hook_Handles} = {};

	$self->{Event_Related_Static_Variables} = {};

	$self->{Dynamic_Variable_Complements} = {};
	$self->{Dynamic_Variable_Sub_Callbacks} = {};
	$self->{Event_Related_Dynamic_Variables} = {};

	$self->{Scalar_Variable_List_Hash} = {};
	$self->{Array_Variable_List_Hash} = {};
	$self->{Hash_Variable_List_Hash} = {};

	#must add a sorting algorithm here later
	$self->{triggered_prioritized_automacros_index_list} = [];

	$self->{automacro_index_to_queue_index} = {};

	my $parse_result = parseMacroFile($file, 0);
	if ( !$parse_result ) {
		$self->{parse_failed} = 1;
		return $self;
	}

	$self->create_macro_list($parse_result->{macros});

	$self->create_automacro_list($parse_result->{automacros});

	$self->{subs_list} = $parse_result->{subs};

	$self->define_automacro_check_state;

	$self->{AI_state_change_Hook_Handle} = Plugins::addHook( 'AI_state_change',  sub { my $state = $_[1]->{new}; $self->adapt_to_AI_state($state); }, undef );

	$self->{Currently_AI_state_Adapted_Automacros} = undef;

	$self->adapt_to_AI_state(AI::state);

	$self->{AI_start_Macros_Running_Hook_Handle} = undef;
	$self->{AI_start_Automacros_Check_Hook_Handle} = undef;
	$self->set_automacro_checking_status();

	$self->create_callbacks();

	$self->{Macro_Runner} = undef;

	$self->{number_of_triggered_automacros} = 0;

	$self->set_arrays_size_to_zero();
	$self->set_hashes_size_to_zero();

	return $self;
}

sub adapt_to_AI_state {
	my ($self, $state) = @_;

	$self->{Currently_AI_state_Adapted_Automacros} = undef;

	foreach my $automacro (@{$self->{Automacro_List}->getItems()}) {
		my $automacro_index = $automacro->get_index;

		if ($self->{automacros_index_to_AI_check_state}{$automacro_index}{$state} == 1) {

			$self->{Currently_AI_state_Adapted_Automacros}{$automacro_index} = 1;
			if (!$automacro->running_status && $automacro->can_be_added_to_queue) {
				$self->add_to_triggered_prioritized_automacros_index_list($automacro);
			}

		} else {
			if ($automacro->running_status) {
				$self->remove_from_triggered_prioritized_automacros_index_list($automacro);
			}
		}
	}
}

sub unload {
	my ($self) = @_;
	$self->clear_queue();
	$self->clean_hooks();
	Plugins::delHook($self->{AI_start_Automacros_Check_Hook_Handle}) if ($self->{AI_start_Automacros_Check_Hook_Handle});
	Plugins::delHook($self->{AI_state_change_Hook_Handle}) if ($self->{AI_state_change_Hook_Handle});
}

sub clean_hooks {
	my ($self) = @_;
	foreach (values %{$self->{Hook_Handles}}) {Plugins::delHook($_)}
}

sub set_automacro_checking_status {
	my ($self, $status) = @_;

	if (!defined $self->{Automacros_Checking_Status}) {
		debug "[eventMacro] Initializing automacro checking by default.\n", "eventMacro", 2;
		$self->{Automacros_Checking_Status} = CHECKING_AUTOMACROS;
		$self->{AI_start_Automacros_Check_Hook_Handle} = Plugins::addHook( 'AI_start', sub { my $state = $_[1]->{state}; $self->AI_start_checker($state); }, undef );
		return;
	} elsif ($self->{Automacros_Checking_Status} == $status) {
		debug "[eventMacro] automacro checking status is already $status.\n", "eventMacro", 2;
	} else {
		debug "[eventMacro] Changing automacro checking status from '".$self->{Automacros_Checking_Status}."' to '".$status."'.\n", "eventMacro", 2;
		if (
		  ($self->{Automacros_Checking_Status} == CHECKING_AUTOMACROS || $self->{Automacros_Checking_Status} == CHECKING_FORCED_BY_USER) &&
		  ($status == PAUSED_BY_EXCLUSIVE_MACRO || $status == PAUSE_FORCED_BY_USER)
		) {
			if (defined $self->{AI_start_Automacros_Check_Hook_Handle}) {
				debug "[eventMacro] Deleting AI_start hook.\n", "eventMacro", 2;
				Plugins::delHook($self->{AI_start_Automacros_Check_Hook_Handle});
				$self->{AI_start_Automacros_Check_Hook_Handle} = undef;
			} else {
				error "[eventMacro] Tried to delete AI_start hook and for some reason it is already undefined.\n";
			}
		} elsif (
		  ($self->{Automacros_Checking_Status} == PAUSED_BY_EXCLUSIVE_MACRO || $self->{Automacros_Checking_Status} == PAUSE_FORCED_BY_USER) &&
		  ($status == CHECKING_AUTOMACROS || $status == CHECKING_FORCED_BY_USER)
		) {
			if (defined $self->{AI_start_Automacros_Check_Hook_Handle}) {
				error "[eventMacro] Tried to add AI_start hook and for some reason it is already defined.\n";
			} else {
				debug "[eventMacro] Adding AI_start hook.\n", "eventMacro", 2;
				$self->{AI_start_Automacros_Check_Hook_Handle} = Plugins::addHook( 'AI_start',  sub { my $state = $_[1]->{state}; $self->AI_start_checker($state); }, undef );
			}
		}
		$self->{Automacros_Checking_Status} = $status;
	}
}

sub get_automacro_checking_status {
	my ($self) = @_;
	return $self->{Automacros_Checking_Status};
}

sub create_macro_list {
	my ($self, $macro) = @_;
	foreach my $name (keys %{$macro}) {
		####################################
		#####Bad Name Check
		####################################
		if ($name =~ /\s/) {
			error "[eventMacro] Ignoring macro '$name'. You cannot use spaces in macro names.\n";
			next;
		}

		####################################
		#####Duplicated Name Check
		####################################
		if (exists $macro->{$name}{'duplicatedMacro'}) {
			error "[eventMacro] Ignoring macro '$name'. Macros can't have same name.\n";
			next;
		}
		my $currentMacro = new eventMacro::Macro($name, $macro->{$name}{lines});
		$self->{Macro_List}->add($currentMacro);
	}
}

sub create_automacro_list {
	my ($self, $automacro) = @_;
	my %modulesLoaded;
	AUTOMACRO: while (my ($name,$value) = each %{$automacro}) {
		my ($currentAutomacro, %currentConditions, %currentParameters, $has_event_type_condition, $event_type_condition_name);
		$has_event_type_condition = 0;
		$event_type_condition_name = undef;

		####################################
		#####Bad Name Check
		####################################
		if ($name =~ /\s/) {
			error "[eventMacro] Ignoring automacro '$name'. You cannot use spaces in automacro names.\n";
			next AUTOMACRO;
		}

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

		######################################
		#####Duplicated name Check
		######################################
		if (exists $value->{'duplicatedAutomacro'}) {
			error "[eventMacro] Ignoring automacro '$name'. Automacros can't have same name\n";
			next AUTOMACRO;
		}

		PARAMETER: foreach my $parameter (@{$value->{'parameters'}}) {
			###Check Duplicate Parameter
			if (exists $currentParameters{$parameter->{'key'}}) {
				error "[eventMacro] Ignoring automacro '$name' (parameter ".$parameter->{'key'}." duplicate)\n";
				next AUTOMACRO;
			}
			###Parameter: call with or without param
			if ($parameter->{'key'} eq "call" && $parameter->{'value'} =~ /(\S+)\s+(.*)?/) {
				my ($macro_name, $params) = ($1 , $2);

				if (!$self->{Macro_List}->getByName($macro_name) ) {
					error "[eventMacro] Ignoring automacro '$name' (call '".$macro_name."' is not a valid macro name)\n";
					next AUTOMACRO;
				} else {
					unless (defined $params) {
						$parameter->{'value'} = $macro_name;
					}
					$currentParameters{$parameter->{'key'}} = $parameter->{'value'};
				}
			###Parameter: delay
			} elsif ($parameter->{'key'} eq "delay" && $parameter->{'value'} !~ /^[\d\.]*\d+$/) {
				error "[eventMacro] Ignoring automacro '$name' (delay parameter should be a number)\n";
				next AUTOMACRO;
			###Parameter: run-once
			} elsif ($parameter->{'key'} eq "run-once" && $parameter->{'value'} !~ /^[01]$/) {
				error "[eventMacro] Ignoring automacro '$name' (run-once parameter should be '0' or '1')\n";
				next AUTOMACRO;

			###Parameter: CheckOnAI
			} elsif ($parameter->{'key'} eq "CheckOnAI" && $parameter->{'value'} !~ /^(auto|off|manual)(\s*,\s*(auto|off|manual))*$/) {
				error "[eventMacro] Ignoring automacro '$name' (CheckOnAI parameter should be a list containing only the values 'auto', 'manual' and 'off')\n";
				next AUTOMACRO;

			###Parameter: disabled
			} elsif ($parameter->{'key'} eq "disabled" && $parameter->{'value'} !~ /^[01]$/) {
				error "[eventMacro] Ignoring automacro '$name' (disabled parameter should be '0' or '1')\n";
				next AUTOMACRO;

			###Parameter: overrideAI
			} elsif ($parameter->{'key'} eq "overrideAI" && $parameter->{'value'} !~ /^[01]$/) {
				error "[eventMacro] Ignoring automacro '$name' (overrideAI parameter should be '0' or '1')\n";
				next AUTOMACRO;

			###Parameter: exclusive
			} elsif ($parameter->{'key'} eq "exclusive" && $parameter->{'value'} !~ /^[01]$/) {
				error "[eventMacro] Ignoring automacro '$name' (exclusive parameter should be '0' or '1')\n";
				next AUTOMACRO;

			###Parameter: self_interruptible
			} elsif ($parameter->{'key'} eq "self_interruptible" && $parameter->{'value'} !~ /^[01]$/) {
				error "[eventMacro] Ignoring automacro '$name' (self_interruptible parameter should be '0' or '1')\n";
				next AUTOMACRO;

			###Parameter: priority
			} elsif ($parameter->{'key'} eq "priority" && $parameter->{'value'} !~ /^\d+$/) {
				error "[eventMacro] Ignoring automacro '$name' (priority parameter should be a number)\n";
				next AUTOMACRO;

			###Parameter: macro_delay
			} elsif ($parameter->{'key'} eq "macro_delay" && $parameter->{'value'} !~ /^[\d\.]*\d+$/) {
				error "[eventMacro] Ignoring automacro '$name' (macro_delay parameter should be a number (decimals are accepted))\n";
				next AUTOMACRO;

			###Parameter: orphan
			} elsif ($parameter->{'key'} eq "orphan" && $parameter->{'value'} !~ /^(terminate|terminate_last_call|reregister|reregister_safe)$/) {
				error "[eventMacro] Ignoring automacro '$name' (orphan parameter should be 'terminate', 'terminate_last_call', 'reregister' or 'reregister_safe'. Given value: '$parameter->{'value'}')\n";
				next AUTOMACRO;
			###Parameter: repeat
			} elsif ($parameter->{'key'} eq "repeat" && $parameter->{'value'} !~ /^\d+$/) {
				error "[eventMacro] Ignoring automacro '$name' (repeat parameter should be a number)\n";
				next AUTOMACRO;
			} else {
				$currentParameters{$parameter->{'key'}} = $parameter->{'value'};
			}
		}

		###Recheck Parameter call
		if (!exists $currentParameters{'call'}) {
			error "[eventMacro] Ignoring automacro '$name' (all automacros must have a macro call)\n";
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

			if (defined $condition_object->error) {
				warning "[eventMacro] Ignoring automacro '".$name."'\n".
				        "[eventMacro] Error in condition '".$condition->{'key'}."'\n".
				        "[eventMacro] Error type: Wrong condition syntax ('".$condition->{'value'}."')\n".
				        "[eventMacro] Error code: '".$condition_object->error."'.\n";
				next AUTOMACRO;
			}

			if (exists $currentConditions{$condition_module} && $condition_object->is_unique_condition()) {
				error "[eventMacro] Condition '".$condition->{'key'}."' cannot be used more than once in an automacro. It was used twice (or more) in automacro '".$name."'\n";
				warning "[eventMacro] Ignoring automacro '$name' (multiple unique condition)\n";
				next AUTOMACRO;
			}

			if ($condition_object->condition_type == EVENT_TYPE) {
				if ($has_event_type_condition) {
					error "[eventMacro] Conditions '".$condition->{'key'}."' and '".$event_type_condition_name."' are of the event type and can only be used once per automacro.\n";
					warning "[eventMacro] Ignoring automacro '$name' (multiple event type conditions)\n";
					next AUTOMACRO;
				} else {
					$has_event_type_condition = 1;
					$event_type_condition_name = $condition->{'key'};
				}
			}

			push( @{ $currentConditions{$condition_module} }, $condition->{'value'} );

		}

		####################################
		#####Automacro Object Creation
		####################################
		$currentAutomacro = new eventMacro::Automacro($name, \%currentParameters);
		my $new_index = $self->{Automacro_List}->add($currentAutomacro);
		$self->{Automacro_List}->get($new_index)->parse_and_create_conditions(\%currentConditions);
	}
}

sub load_condition_module {
	my ($self, $condition_module) = @_;
	undef $@;
	debug "[eventMacro] Loading module '".$condition_module."'\n", "eventMacro", 2;
	eval "use $condition_module";
	if ($@ =~ /^Can't locate /s) {
		FileNotFoundException->throw("Cannot locate automacro module ".$condition_module.".");
	} elsif ($@) {
		ModuleLoadException->throw("An error occured while loading condition module ".$condition_module.":".$@.".");
	} else {
		$self->{Condition_Modules_Loaded}{$condition_module} = 1;
	}
}

sub define_automacro_check_state {
	my ($self) = @_;
	foreach my $automacro (@{$self->{Automacro_List}->getItems()}) {
		my $automacro_index = $automacro->get_index;
		my $parameter = $automacro->{check_on_ai_state};
		$self->{automacros_index_to_AI_check_state}{$automacro_index}{AI::OFF} = exists $parameter->{'off'} ? 1 : 0;
		$self->{automacros_index_to_AI_check_state}{$automacro_index}{AI::MANUAL} = exists $parameter->{'manual'} ? 1 : 0;
		$self->{automacros_index_to_AI_check_state}{$automacro_index}{AI::AUTO} = exists $parameter->{'auto'} ? 1 : 0;
	}
}

sub create_callbacks {
	my ($self) = @_;

	debug "[eventMacro] create_callback called\n", "eventMacro", 2;

	AUTO: foreach my $automacro (@{$self->{Automacro_List}->getItems()}) {

		debug "[eventMacro] Creating callback for automacro '".$automacro->get_name()."'\n", "eventMacro", 2;

		my $automacro_index = $automacro->get_index;

		# Hooks
		foreach my $hook_name ( keys %{ $automacro->get_hooks() } ) {
			my $conditions_indexes = $automacro->{hooks}->{$hook_name};
			foreach my $condition_index (@{$conditions_indexes}) {
				$self->{Event_Related_Hooks}{$hook_name}{$automacro_index}{$condition_index} = 1;
			}

		}

		# Scalars
		foreach my $var ( keys %{ $automacro->get_scalar_variables } ) {
			my $conditions_indexes = $automacro->{scalar_variables}->{$var};
			foreach my $condition_index (@{$conditions_indexes}) {
				$self->{Event_Related_Static_Variables}{scalar}{$var}{$automacro_index}{$condition_index} = 1;
			}
		}

		# Arrays
		foreach my $var ( keys %{ $automacro->get_array_variables } ) {
			my $conditions_indexes = $automacro->{array_variables}->{$var};
			foreach my $condition_index (@{$conditions_indexes}) {
				$self->{Event_Related_Static_Variables}{array}{$var}{$automacro_index}{$condition_index} = 1;
			}
		}

		# Hashes
		foreach my $var ( keys %{ $automacro->get_hash_variables } ) {
			my $conditions_indexes = $automacro->{hash_variables}->{$var};
			foreach my $condition_index (@{$conditions_indexes}) {
				$self->{Event_Related_Static_Variables}{hash}{$var}{$automacro_index}{$condition_index} = 1;
			}
		}

		# Accessed arrays
		foreach my $var ( keys %{ $automacro->get_accessed_array_variables } ) {

			my $array = $automacro->{accessed_array_variables}->{$var};

			foreach my $array_complement (keys %{$array}) {
				my $cond_indexes = $array->{$array_complement};

				next unless (defined $cond_indexes);

				if ($array_complement =~ /^\d+$/) {
					foreach my $condition_index (@{$cond_indexes}) {
						$self->{Event_Related_Static_Variables}{accessed_array}{$var}{$array_complement}{$automacro_index}{$condition_index} = 1;
					}

				} elsif (my $complement_var = find_variable($array_complement)) {
					my @nested_array;
					push(@nested_array, {type => 'accessed_array', name => $var, complement => $array_complement});

					while ($complement_var) {
						if (exists $complement_var->{complement}) {
							$nested_array[-1]{complement_is_var} = 1;
							push(@nested_array, {type => $complement_var->{type}, name => $complement_var->{real_name}, complement => $complement_var->{complement}});
							$complement_var = find_variable($complement_var->{complement});
						} else {
							$nested_array[-1]{complement_is_var} = 1;
							push(@nested_array, {type => $complement_var->{type}, name => $complement_var->{real_name}});
							last;
						}
					}

					$self->manage_nested_automacro_var(\@nested_array, $automacro_index, $cond_indexes);

				} else {
					error "[eventMacro] '".$array_complement."' is not a valid array index in array '".$var."'. Ignoring automacro '".$automacro->get_name()."'.\n";
					next AUTO;
				}
			}
		}

		# Accessed hashes
		foreach my $var ( keys %{ $automacro->get_accessed_hash_variables } ) {
			my $hash = $automacro->{accessed_hash_variables}->{$var};
			foreach my $hash_complement (keys %{$hash}) {
				my $cond_indexes = $hash->{$hash_complement};

				next unless (defined $cond_indexes);

				if ($hash_complement =~ /^[a-zA-Z\d_]+$/) {
					foreach my $condition_index (@{$cond_indexes}) {
						$self->{Event_Related_Static_Variables}{accessed_hash}{$var}{$hash_complement}{$automacro_index}{$condition_index} = 1;
					}

				} elsif (my $complement_var = find_variable($hash_complement)) {
					my @nested_array;
					push(@nested_array, {type => 'accessed_hash', name => $var, complement => $hash_complement});

					while ($complement_var) {
						if (exists $complement_var->{complement}) {
							$nested_array[-1]{complement_is_var} = 1;
							push(@nested_array, {type => $complement_var->{type}, name => $complement_var->{real_name}, complement => $complement_var->{complement}});
							$complement_var = find_variable($complement_var->{complement});
						} else {
							$nested_array[-1]{complement_is_var} = 1;
							push(@nested_array, {type => $complement_var->{type}, name => $complement_var->{real_name}});
							last;
						}
					}

					$self->manage_nested_automacro_var(\@nested_array, $automacro_index, $cond_indexes);

				} else {
					error "[eventMacro] '".$hash_complement."' is not a valid hash key in hash '".$var."'. Ignoring automacro '".$automacro->get_name()."'.\n";
					next AUTO;
				}
			}
		}

	}

	my $event_sub = sub {
		my $name = shift;
		my $args = shift;
		my $check_list_hash = $self->{Event_Related_Hooks}{$name};
		$self->manage_event_callbacks('hook', $name, $args, $check_list_hash);
	};
	foreach my $hook_name (keys %{$self->{Event_Related_Hooks}}) {
		$self->{Hook_Handles}{$hook_name} = Plugins::addHook( $hook_name, $event_sub, undef );
	}
}

sub manage_nested_automacro_var {
	my ($self, $array, $automacro_index, $cond_indexes) = @_;

	foreach my $nest_index (0..$#{$array}) {
		my $variable = $array->[$nest_index];

		if (exists $variable->{complement}) {
			$self->{Dynamic_Variable_Complements}{$variable->{type}}{$variable->{name}}{$variable->{complement}}{defined} = 0;
			$self->{Dynamic_Variable_Complements}{$variable->{type}}{$variable->{name}}{$variable->{complement}}{full_nest} = '$'.$variable->{name}.($variable->{type} eq 'accessed_array' ? '[' : '{').$variable->{complement}.($variable->{type} eq 'accessed_array' ? ']' : '}');

			if ($nest_index == 0) {
				$self->{Dynamic_Variable_Complements}{$variable->{type}}{$variable->{name}}{$variable->{complement}}{last_nested} = 1;
				foreach my $condition_index (@{$cond_indexes}) {
					$self->{Dynamic_Variable_Complements}{$variable->{type}}{$variable->{name}}{$variable->{complement}}{auto_indexes}{$automacro_index}{$condition_index} = 1;
				}
			} else {
				$self->{Dynamic_Variable_Complements}{$variable->{type}}{$variable->{name}}{$variable->{complement}}{last_nested} = 0;
				my $next_var = $array->[$nest_index-1];
				push(@{$self->{Dynamic_Variable_Complements}{$variable->{type}}{$variable->{name}}{$variable->{complement}}{call_to}}, {type => $next_var->{type}, name => $next_var->{name}, complement => $next_var->{complement}});
			}

			if (!exists $variable->{complement_is_var}) {
				$self->{Dynamic_Variable_Sub_Callbacks}{$variable->{type}}{$variable->{name}}{$variable->{complement}} = 1;
			}

		} else {
			$self->{Dynamic_Variable_Complements}{$variable->{type}}{$variable->{name}}{last_nested} = 0;
			$self->{Dynamic_Variable_Complements}{$variable->{type}}{$variable->{name}}{defined} = 0;
			$self->{Dynamic_Variable_Complements}{$variable->{type}}{$variable->{name}}{full_nest} = '$'.$variable->{name};
			my $next_var = $array->[$nest_index-1];
			push(@{$self->{Dynamic_Variable_Complements}{$variable->{type}}{$variable->{name}}{call_to}}, {type => $next_var->{type}, name => $next_var->{name}, complement => $next_var->{complement}});

			$self->{Dynamic_Variable_Sub_Callbacks}{$variable->{type}}{$variable->{name}} = 1;
		}
	}
}

sub sub_callback_variable_event {
	my ($self, $variable_type, $variable_name, $before_value, $value, $complement) = @_;
	return unless (exists $self->{Dynamic_Variable_Sub_Callbacks}{$variable_type});
	return unless (exists $self->{Dynamic_Variable_Sub_Callbacks}{$variable_type}{$variable_name});

	my $dynamic_complements;
	if (defined $complement) {
		return unless (exists $self->{Dynamic_Variable_Sub_Callbacks}{$variable_type}{$variable_name}{$complement});

		foreach my $sub_complement (values %{$self->{Dynamic_Variable_Sub_Callbacks}{$variable_type}{$variable_name}{$complement}}) {
			$dynamic_complements = $self->{Dynamic_Variable_Complements}{$variable_type}{$variable_name}{$sub_complement};
			my $pre_defined = $dynamic_complements->{defined};
			if (defined $value) {
				if ($pre_defined) {
					$self->change_sub_callback($variable_type, $variable_name, $before_value, $value, $complement, $sub_complement);
				} else {
					$self->activated_sub_callback($variable_type, $variable_name, $value, $complement, $sub_complement);
				}
			} else {
				if ($pre_defined) {
					$self->deactivated_sub_callback($variable_type, $variable_name, $before_value, $complement, $sub_complement);
				}
			}
		}

	} else {
		$dynamic_complements = $self->{Dynamic_Variable_Complements}{$variable_type}{$variable_name};
		my $pre_defined = $dynamic_complements->{defined};
		if (defined $value) {
			if ($pre_defined) {
				$self->change_sub_callback($variable_type, $variable_name, $before_value, $value);
			} else {
				$self->activated_sub_callback($variable_type, $variable_name, $value);
			}
		} else {
			if ($pre_defined) {
				$self->deactivated_sub_callback($variable_type, $variable_name, $before_value);
			}
		}
	}
}

sub change_sub_callback {
	my ($self, $variable_type, $variable_name, $before_value, $value, $complement, $nest_complement) = @_;

	$self->deactivated_sub_callback($variable_type, $variable_name, $before_value, $complement, $nest_complement);
	$self->activated_sub_callback($variable_type, $variable_name, $value, $complement, $nest_complement);
}

sub activated_sub_callback {
	my ($self, $variable_type, $variable_name, $value, $complement, $nest_complement) = @_;

	my $var_hash = $self->{Dynamic_Variable_Complements}{$variable_type}{$variable_name};
	if (defined $complement) {
		$var_hash = $var_hash->{$nest_complement};
	}

	$var_hash->{defined} = 1;
	$var_hash->{value} = $value;
	my $calls = $var_hash->{call_to};

	if ($var_hash->{last_nested}) {
		my @auto_indexes = keys %{$var_hash->{auto_indexes}};
		foreach my $automacro_index (@auto_indexes) {
			my @cond_indexes = keys %{$var_hash->{auto_indexes}{$automacro_index}};
			foreach my $condition_index (@cond_indexes) {
				$self->{Event_Related_Dynamic_Variables}{$variable_type}{$variable_name}{$complement}{$nest_complement}{$automacro_index}{$condition_index} = 1;
			}
		}
		$self->manage_event_callbacks('variable', $variable_name, $value, $self->{Event_Related_Dynamic_Variables}{$variable_type}{$variable_name}{$complement}{$nest_complement}, $variable_type, $nest_complement);
		return;
	}

	foreach my $call (@{$calls}) {

		if ($call->{type} eq 'accessed_array') {
			next if ($value !~ /^\d+$/);
		} elsif ($call->{type} eq 'accessed_hash') {
			next if ($value !~ /^[a-zA-Z\d_]+$/);
		}

		my $call_complements = $self->{Dynamic_Variable_Complements}{$call->{type}}{$call->{name}}{$call->{complement}};
		$call_complements->{complement_defined} = 1;

		my $sub_callback_index = ((scalar keys %{$self->{Dynamic_Variable_Sub_Callbacks}{$call->{type}}{$call->{name}}{$value}}) + 1);
		$call->{sub_callback_index} = $sub_callback_index;
		$self->{Dynamic_Variable_Sub_Callbacks}{$call->{type}}{$call->{name}}{$value}{$sub_callback_index} = $call->{complement};

		if ($self->defined_var($call->{type}, $call->{name}, $value)) {
			my $new_value = $self->get_var($call->{type}, $call->{name}, $value);
			$self->activated_sub_callback($call->{type}, $call->{name}, $new_value, $value, $var_hash->{full_nest});
		}
	}
}

use Data::Dumper;

sub deactivated_sub_callback {
	my ($self, $variable_type, $variable_name, $before_value, $complement, $nest_complement) = @_;

	my $var_hash = $self->{Dynamic_Variable_Complements}{$variable_type}{$variable_name};
	if (defined $complement) {
		$var_hash = $var_hash->{$nest_complement};
	}

	$var_hash->{defined} = 0;
	delete $var_hash->{value};
	my $calls = $var_hash->{call_to};

	if ($var_hash->{last_nested}) {
		my @auto_indexes = keys %{$var_hash->{auto_indexes}};
		foreach my $automacro_index (@auto_indexes) {
			my @cond_indexes = keys %{$var_hash->{auto_indexes}{$automacro_index}};
			foreach my $condition_index (@cond_indexes) {
				delete $self->{Event_Related_Dynamic_Variables}{$variable_type}{$variable_name}{$complement}{$nest_complement}{$automacro_index}{$condition_index};
			}
			unless (scalar keys %{$self->{Event_Related_Dynamic_Variables}{$variable_type}{$variable_name}{$complement}{$nest_complement}{$automacro_index}}) {
				delete $self->{Event_Related_Dynamic_Variables}{$variable_type}{$variable_name}{$complement}{$nest_complement}{$automacro_index};
			}
		}
		unless (scalar keys %{$self->{Event_Related_Dynamic_Variables}{$variable_type}{$variable_name}{$complement}{$nest_complement}}) {
			delete $self->{Event_Related_Dynamic_Variables}{$variable_type}{$variable_name}{$complement}{$nest_complement};
			unless (scalar keys %{$self->{Event_Related_Dynamic_Variables}{$variable_type}{$variable_name}{$complement}}) {
				delete $self->{Event_Related_Dynamic_Variables}{$variable_type}{$variable_name}{$complement};
				unless (scalar keys %{$self->{Event_Related_Dynamic_Variables}{$variable_type}{$variable_name}}) {
					delete $self->{Event_Related_Dynamic_Variables}{$variable_type}{$variable_name};
					unless (scalar keys %{$self->{Event_Related_Dynamic_Variables}{$variable_type}}) {
						delete $self->{Event_Related_Dynamic_Variables}{$variable_type};
					}
				}
			}
		}
		return;
	}

	foreach my $call (@{$calls}) {
		my $subcall_index = delete $call->{sub_callback_index};

		my $call_complements = $self->{Dynamic_Variable_Complements}{$call->{type}}{$call->{name}}{$call->{complement}};
		delete $call_complements->{complement_defined};

		my $sub_callbacks = $self->{Dynamic_Variable_Sub_Callbacks};

		delete $sub_callbacks->{$call->{type}}{$call->{name}}{$before_value}{$subcall_index};
		unless (scalar keys %{$sub_callbacks->{$call->{type}}{$call->{name}}{$before_value}}) {
			delete $sub_callbacks->{$call->{type}}{$call->{name}}{$before_value};
			unless (scalar keys %{$sub_callbacks->{$call->{type}}{$call->{name}}}) {
				delete $sub_callbacks->{$call->{type}}{$call->{name}};
				unless (scalar keys %{$sub_callbacks->{$call->{type}}}) {
					delete $sub_callbacks->{$call->{type}};
				}
			}
		}

		if ($call_complements->{defined}) {
			$self->deactivated_sub_callback($call->{type}, $call->{name}, $call_complements->{value}, $before_value, $var_hash->{full_nest});
		}
	}
}

sub set_arrays_size_to_zero {
	my ($self) = @_;
	foreach my $array_name (keys %{$self->{Event_Related_Static_Variables}{array}}) {
		$self->array_size_change($array_name);
	}
}

sub set_hashes_size_to_zero {
	my ($self) = @_;
	foreach my $hash_name (keys %{$self->{Event_Related_Static_Variables}{hash}}) {
		$self->hash_size_change($hash_name);
	}
}

sub check_all_conditions {
	my ($self) = @_;
	debug "[eventMacro] Starting to check all state type conditions\n", "eventMacro", 2;
	my @automacros = @{ $self->{Automacro_List}->getItems() };
	foreach my $automacro (@automacros) {
		debug "[eventMacro] Checking all state type conditions in automacro '".$automacro->get_name."'\n", "eventMacro", 2;
		my @conditions = @{ $automacro->{conditionList}->getItems() };
		foreach my $condition (@conditions) {
			next if ($condition->condition_type == EVENT_TYPE);
			debug "[eventMacro] Checking condition of index '".$condition->get_index."' in automacro '".$automacro->get_name."'\n", "eventMacro", 2;
			$automacro->check_state_type_condition($condition->get_index, 'recheck')
		}
		if (exists $self->{Currently_AI_state_Adapted_Automacros}{$automacro->get_index} && $automacro->can_be_added_to_queue) {
			$self->add_to_triggered_prioritized_automacros_index_list($automacro);
		}
	}
}

# Given the results of Utilities::find_variable(), return the variable data.
sub get_split_var {
	my ( $self, $var ) = @_;
	$self->get_var( $var->{type}, $var->{real_name}, $var->{complement} );
}

# Generic variable functions
sub get_var {
	my ($self, $type, $variable_name, $complement) = @_;

	if ($type eq 'scalar') {
		return ($self->get_scalar_var($variable_name));

	} elsif ($type eq 'accessed_array') {
		return ($self->get_array_var($variable_name, $complement));

	} elsif ($type eq 'accessed_hash') {
		return ($self->get_hash_var($variable_name, $complement));

	} else {
		error "[eventMacro] You can't call get_var with a variable type other than 'scalar', 'accessed_array' or 'accessed_hash'.\n";
		return undef;
	}
}

sub set_var {
	my ($self, $type, $variable_name, $variable_value, $check_callbacks, $complement) = @_;

	if ($type eq 'scalar') {
		return ($self->set_scalar_var($variable_name, $variable_value, $check_callbacks));

	} elsif ($type eq 'accessed_array') {
		return ($self->set_array_var($variable_name, $complement, $variable_value, $check_callbacks));

	} elsif ($type eq 'accessed_hash') {
		return ($self->set_hash_var($variable_name, $complement, $variable_value, $check_callbacks));

	} else {
		error "[eventMacro] You can't call set_var with a variable type other than 'scalar', 'accessed_array' or 'accessed_hash'.\n";
		return undef;
	}
}

sub defined_var {
	my ($self, $type, $variable_name, $complement) = @_;

	if ($type eq 'scalar') {
		return ($self->is_scalar_var_defined($variable_name));

	} elsif ($type eq 'accessed_array') {
		return ($self->is_array_var_defined($variable_name, $complement));

	} elsif ($type eq 'accessed_hash') {
		return ($self->is_hash_var_defined($variable_name, $complement));

	} else {
		error "[eventMacro] You can't call defined_var with a variable type other than 'scalar', 'accessed_array' or 'accessed_hash'.\n";
		return undef;
	}
}

# Scalars
sub get_scalar_var {
	my ($self, $variable_name) = @_;

	# Handle special variables.
	if ( substr( $variable_name, 0, 1 ) eq '.' ) {

		# Time-related variables.
		if    ( $variable_name eq '.time' )       { return time; }
		elsif ( $variable_name eq '.datetime' )   { return scalar localtime; }
		elsif ( $variable_name eq '.second' )     { return ( localtime() )[0]; }
		elsif ( $variable_name eq '.minute' )     { return ( localtime() )[1]; }
		elsif ( $variable_name eq '.hour' )       { return ( localtime() )[2]; }
		elsif ( $variable_name eq '.dayofmonth' ) { return ( localtime() )[3]; }
		elsif ( $variable_name eq '.dayofweek' )  {
			my @wday = qw/Monday Tuesday Wednesday Thursday Friday Saturday Sunday+/;
			return $wday[ (localtime())[6] - 1 ];
		}

		# Field-related variables.
		elsif ( $variable_name eq '.map' )      { return $field ? $field->baseName : ''; }
		elsif ( $variable_name eq '.incity' )   { return $field && $field->isCity ? 1 : 0; }
		elsif ( $variable_name eq '.inlockmap') { return $field && $field->baseName eq $config{lockMap} ? 1 : 0; }

		# Character-related variables.
		elsif ( $variable_name eq '.job' )          { return $char && $jobs_lut{ $char->{jobID} } || ''; }
		elsif ( $variable_name eq '.pos' )          { return $char ? sprintf( '%d %d', @{ calcPosition( $char ) }{ 'x', 'y' } ) : ''; }
		elsif ( $variable_name eq '.name' )         { return $char && $char->{name}       || 0; }
		elsif ( $variable_name eq '.hp' )           { return $char && $char->{hp}         || 0; }
		elsif ( $variable_name eq '.sp' )           { return $char && $char->{sp}         || 0; }
		elsif ( $variable_name eq '.lvl' )          { return $char && $char->{lv}         || 0; }
		elsif ( $variable_name eq '.joblvl' )       { return $char && $char->{lv_job}     || 0; }
		elsif ( $variable_name eq '.spirits' )      { return $char && $char->{spirits}    || 0; }
		elsif ( $variable_name eq '.zeny' )         { return $char && $char->{zeny}       || 0; }
		elsif ( $variable_name eq '.weight' )       { return $char && $char->{weight}     || 0; }
		elsif ( $variable_name eq '.weightpercent') {return $char && int $char->{weight} * 100 / int $char->{weight_max} || 0; }
		elsif ( $variable_name eq '.maxweight' )    { return $char && $char->{weight_max} || 0; }
		elsif ( $variable_name eq '.status' ) {
			return '' if !$char;
			return join ',', sort( ( $char->{muted} ? 'muted' : () ), ( $char->{dead} ? 'dead' : () ), map { $statusName{$_} || $_ } keys %{ $char->{statuses} } );
		}
		elsif ( $variable_name eq '.statushandle') {
			return '' if !$char;
			return join ',', keys %{ $char->{statuses} } ;
		}

		# Inventory-related variables.
		elsif( $variable_name eq '.inventoryitems' )      { return $char && $char->inventory->isReady ? $char->inventory->size : 0; }

		# Cart-related variables.
		elsif ( $variable_name eq '.cartweight' )       { return $char && $char->cart->isReady ? $char->cart->{weight}     : 0; }
		elsif ( $variable_name eq '.cartweightpercent') { return $char && $char->cart->isReady ? int $char->cart->{weight} * 100 / int $char->cart->{weight_max} : 0;}
		elsif ( $variable_name eq '.cartmaxweight' )    { return $char && $char->cart->isReady ? $char->cart->{weight_max} : 0; }
		elsif ( $variable_name eq '.cartitems' )        { return $char && $char->cart->isReady ? $char->cart->items        : 0; }
		elsif ( $variable_name eq '.cartmaxitems' )     { return $char && $char->cart->isReady ? $char->cart->items_max    : 0; }
		elsif ( $variable_name eq '.shopopen' )         { return $char && $shopstarted ? 1 : 0}

		# Storage-related variables.
		elsif ( $variable_name eq '.storageopen' )     { return $char && $char->storage->isReady              ? 1                         : 0; }
		elsif ( $variable_name eq '.storageitems' )    { return $char && $char->storage->wasOpenedThisSession ? $char->storage->items     : 0; }
		elsif ( $variable_name eq '.storagemaxitems' ) { return $char && $char->storage->wasOpenedThisSession ? $char->storage->items_max : 0; }
	}

	return $self->{Scalar_Variable_List_Hash}{$variable_name} if (exists $self->{Scalar_Variable_List_Hash}{$variable_name});
	return undef;
}

sub set_scalar_var {
	my ($self, $variable_name, $variable_value, $check_callbacks) = @_;

	my $before_value = $self->get_scalar_var($variable_name);

	if ($variable_value eq 'undef') {
		undef $variable_value;
		delete $self->{Scalar_Variable_List_Hash}{$variable_name};
	} else {
		$self->{Scalar_Variable_List_Hash}{$variable_name} = $variable_value;
	}

	return if (defined $check_callbacks && $check_callbacks == 0);
	$self->manage_variables_callbacks('scalar', $variable_name, $before_value, $variable_value);
}

sub is_scalar_var_defined {
	my ($self, $variable_name) = @_;
	return ((exists $self->{Scalar_Variable_List_Hash}{$variable_name} && defined $self->{Scalar_Variable_List_Hash}{$variable_name}) ? 1 : 0);
}
#########

# Arrays
sub set_full_array {
	my ($self, $variable_name, $list) = @_;

	my @old_array = (exists $self->{Array_Variable_List_Hash}{$variable_name} ? (@{$self->{Array_Variable_List_Hash}{$variable_name}}) : ([]));
	my $old_last_index = $#old_array;
	my $new_last_index = $#{$list};

	debug "[eventMacro] Setting array '@".$variable_name."'\n", "eventMacro";
	foreach my $member_index (0..$new_last_index) {
		my $member_value = $list->[$member_index];
		if ($member_value eq 'undef') {
			undef $member_value;
		}
		$self->{Array_Variable_List_Hash}{$variable_name}[$member_index] = $member_value;
		my $old_member = $old_array[$member_index];
		$self->manage_variables_callbacks('accessed_array', $variable_name, $old_member, $member_value, $member_index);
	}
	if ($new_last_index < $old_last_index) {
		splice(@{$self->{Array_Variable_List_Hash}{$variable_name}}, ($new_last_index+1));
		if ((exists $self->{Event_Related_Static_Variables}{accessed_array} && exists $self->{Event_Related_Static_Variables}{accessed_array}{$variable_name}) || (exists $self->{Event_Related_Dynamic_Variables}{accessed_array} && exists $self->{Event_Related_Dynamic_Variables}{accessed_array}{$variable_name})) {
			foreach my $old_member_index (($new_last_index+1)..$old_last_index) {
				my $old_member = $old_array[$old_member_index];
				$self->manage_variables_callbacks('accessed_array', $variable_name, $old_member, undef, $old_member_index);
			}
		}
	}
	$self->array_size_change($variable_name, $old_last_index) if ($new_last_index != $old_last_index);
}

sub clear_array {
	my ($self, $variable_name) = @_;
	if (exists $self->{Array_Variable_List_Hash}{$variable_name}) {
		debug "[eventMacro] Clearing array '@".$variable_name."'\n", "eventMacro";
		my @old_array = @{$self->{Array_Variable_List_Hash}{$variable_name}};
		delete $self->{Array_Variable_List_Hash}{$variable_name};
		if ((exists $self->{Event_Related_Static_Variables}{accessed_array} && exists $self->{Event_Related_Static_Variables}{accessed_array}{$variable_name}) || (exists $self->{Event_Related_Dynamic_Variables}{accessed_array} && exists $self->{Event_Related_Dynamic_Variables}{accessed_array}{$variable_name})) {
			foreach my $old_member_index (0..$#old_array) {
				my $old_member = $old_array[$old_member_index];
				$self->manage_variables_callbacks('accessed_array', $variable_name, $old_member, undef, $old_member_index);
			}
		}
		$self->array_size_change($variable_name, $#old_array);
	}
}

sub push_array {
	my ($self, $variable_name, $new_member) = @_;

	if ($new_member eq 'undef') {
		undef $new_member;
	}

	push(@{$self->{Array_Variable_List_Hash}{$variable_name}}, $new_member);
	my $index = $#{$self->{Array_Variable_List_Hash}{$variable_name}};

	debug "[eventMacro] 'push' was used in array '@".$variable_name."' to add list member '".$new_member."' into position '".$index."'\n", "eventMacro";

	$self->manage_variables_callbacks('accessed_array', $variable_name, undef, $new_member, $index);
	$self->array_size_change($variable_name, ($index - 1));

	return (scalar @{$self->{Array_Variable_List_Hash}{$variable_name}});
}

sub unshift_array {
	my ($self, $variable_name, $new_member) = @_;

	if ($new_member eq 'undef') {
		undef $new_member;
	}

	my @old_array = @{$self->{Array_Variable_List_Hash}{$variable_name}} if $self->{Array_Variable_List_Hash}{$variable_name};
	unshift(@{$self->{Array_Variable_List_Hash}{$variable_name}}, $new_member);
	my $index = $#{$self->{Array_Variable_List_Hash}{$variable_name}};

	debug "[eventMacro] 'unshift' was used in array '@".$variable_name."' to add list member '".$new_member."' into position '0'\n", "eventMacro";

	foreach my $member_index (0..$index) {
		my $member = ${$self->{Array_Variable_List_Hash}{$variable_name}}[$member_index];
		my $old_member = $old_array[$member_index];
		$self->manage_variables_callbacks('accessed_array', $variable_name, $old_member, $member, $member_index);
	}
	$self->array_size_change($variable_name, ($index - 1));

	return (scalar @{$self->{Array_Variable_List_Hash}{$variable_name}});
}

sub pop_array {
	my ($self, $variable_name) = @_;

	return unless (exists $self->{Array_Variable_List_Hash}{$variable_name});
	return unless (scalar @{$self->{Array_Variable_List_Hash}{$variable_name}} > 0);

	my $index = $#{$self->{Array_Variable_List_Hash}{$variable_name}};
	my $poped = pop(@{$self->{Array_Variable_List_Hash}{$variable_name}});

	debug "[eventMacro] 'pop' was used in array '@".$variable_name."' to remove member '".$poped."' from position '".$index."'\n", "eventMacro";


	$self->manage_variables_callbacks('accessed_array', $variable_name, $poped, undef, $index);
	$self->array_size_change($variable_name, $index);

	return $poped;
}

sub shift_array {
	my ($self, $variable_name) = @_;

	return unless (exists $self->{Array_Variable_List_Hash}{$variable_name});
	return unless (scalar @{$self->{Array_Variable_List_Hash}{$variable_name}} > 0);

	my $index = $#{$self->{Array_Variable_List_Hash}{$variable_name}};
	my @old_array = @{$self->{Array_Variable_List_Hash}{$variable_name}};
	my $shifted = shift(@{$self->{Array_Variable_List_Hash}{$variable_name}});

	debug "[eventMacro] 'shift' was used in array '@".$variable_name."' to remove member '".$shifted."' from position '0'\n", "eventMacro";

	foreach my $member_index (0..$#{$self->{Array_Variable_List_Hash}{$variable_name}}) {
		my $member = ${$self->{Array_Variable_List_Hash}{$variable_name}}[$member_index];
		my $old_member = $old_array[$member_index];
		$self->manage_variables_callbacks('accessed_array', $variable_name, $old_member, $member, $member_index);
	}

	$self->manage_variables_callbacks('accessed_array', $variable_name, $shifted, undef, $index);
	$self->array_size_change($variable_name, $index);

	return $shifted;
}

sub get_array_var {
	my ($self, $variable_name, $index) = @_;
	return ($self->{Array_Variable_List_Hash}{$variable_name}[$index]) if (exists $self->{Array_Variable_List_Hash}{$variable_name} && defined $self->{Array_Variable_List_Hash}{$variable_name}[$index]);
	return undef;
}

sub set_array_var {
	my ($self, $variable_name, $index, $variable_value, $check_callbacks) = @_;

	my $before_value = $self->get_array_var($variable_name, $index);
	my $before_size = $self->get_array_size($variable_name);

	if ($variable_value eq 'undef') {
		undef $variable_value;
		$self->{Array_Variable_List_Hash}{$variable_name}[$index] = undef;
	} else {
		$self->{Array_Variable_List_Hash}{$variable_name}[$index] = $variable_value;
	}
	return if (defined $check_callbacks && $check_callbacks == 0);
	$self->manage_variables_callbacks('accessed_array', $variable_name, $before_value, $variable_value, $index);
	$self->array_size_change($variable_name, $before_size);
}

sub array_size_change {
	my ($self, $variable_name, $before_size) = @_;
	my $size = ((exists $self->{Array_Variable_List_Hash}{$variable_name}) ? (scalar @{$self->{Array_Variable_List_Hash}{$variable_name}}) : 0);
	debug "[eventMacro] Size of array '@".$variable_name."' change from '".$before_size."' to '".$size."'\n", "eventMacro";

	$self->manage_variables_callbacks('array', $variable_name, $before_size, $size);
}

sub get_array_size {
	my ($self, $variable_name) = @_;
	if (exists $self->{Array_Variable_List_Hash}{$variable_name}) {
		return (scalar @{$self->{Array_Variable_List_Hash}{$variable_name}});
	}
	return 0;
}

sub is_array_var_defined {
	my ($self, $variable_name, $index) = @_;
	return ((exists $self->{Array_Variable_List_Hash}{$variable_name} && defined $self->{Array_Variable_List_Hash}{$variable_name}[$index]) ? 1 : 0);
}
#######

# Hahes
sub set_full_hash {
	my ($self, $variable_name, $hash) = @_;

	my %old_hash = (exists $self->{Hash_Variable_List_Hash}{$variable_name} ? (%{$self->{Hash_Variable_List_Hash}{$variable_name}}) : ({}));

	debug "[eventMacro] Setting hash '%".$variable_name."'\n", "eventMacro";
	foreach my $member_key (keys %{$hash}) {
		my $member_value = $hash->{$member_key};
		if ($member_value eq 'undef') {
			undef $member_value;
		}
		$self->{Hash_Variable_List_Hash}{$variable_name}{$member_key} = $member_value;
		my $old_member = $old_hash{$member_key};
		$self->manage_variables_callbacks('accessed_hash', $variable_name, $old_member, $member_value, $member_key);
	}

	if ((exists $self->{Event_Related_Static_Variables}{accessed_hash} && exists $self->{Event_Related_Static_Variables}{accessed_hash}{$variable_name}) || (exists $self->{Event_Related_Dynamic_Variables}{accessed_hash} && exists $self->{Event_Related_Dynamic_Variables}{accessed_hash}{$variable_name})) {
		foreach my $old_member_key (keys %old_hash) {
			if (!exists $self->{Hash_Variable_List_Hash}{$variable_name}{$old_member_key}) {
				my $old_member = $old_hash{$old_member_key};
				$self->manage_variables_callbacks('accessed_hash', $variable_name, $old_member, undef, $old_member_key);
			}
		}
	}
	$self->hash_size_change($variable_name, (scalar keys %old_hash)) if ((scalar keys %old_hash) != (scalar keys %{$self->{Hash_Variable_List_Hash}{$variable_name}}));
}

sub clear_hash {
	my ($self, $variable_name) = @_;
	if (exists $self->{Hash_Variable_List_Hash}{$variable_name}) {
		debug "[eventMacro] Clearing hash '%".$variable_name."'\n", "eventMacro";
		my %old_hash = %{$self->{Hash_Variable_List_Hash}{$variable_name}};
		delete $self->{Hash_Variable_List_Hash}{$variable_name};
		if ((exists $self->{Event_Related_Static_Variables}{accessed_hash} && exists $self->{Event_Related_Static_Variables}{accessed_hash}{$variable_name}) || (exists $self->{Event_Related_Dynamic_Variables}{accessed_hash} && exists $self->{Event_Related_Dynamic_Variables}{accessed_hash}{$variable_name})) {
			foreach my $old_member_key (keys %old_hash) {
				my $old_member = $old_hash{$old_member_key};
				$self->manage_variables_callbacks('accessed_hash', $variable_name, $old_member, undef, $old_member_key);
			}
		}
		$self->hash_size_change($variable_name, (scalar keys %old_hash));
	}
}

sub get_hash_keys {
	my ($self, $variable_name) = @_;
	my @keys = (exists $self->{Hash_Variable_List_Hash}{$variable_name} ? (keys %{$self->{Hash_Variable_List_Hash}{$variable_name}}) : ([]));
	return \@keys;
}

sub get_hash_values {
	my ($self, $variable_name) = @_;
	my @values = (exists $self->{Hash_Variable_List_Hash}{$variable_name} ? (values %{$self->{Hash_Variable_List_Hash}{$variable_name}}) : ([]));
	return \@values;
}

sub exists_hash {
	my ($self, $variable_name, $key) = @_;
	if (exists $self->{Hash_Variable_List_Hash}{$variable_name} && exists $self->{Hash_Variable_List_Hash}{$variable_name}{$key}) {
		return 1;
	}
	return 0;
}

sub delete_key {
	my ($self, $variable_name, $key) = @_;
	if (exists $self->{Hash_Variable_List_Hash}{$variable_name} && exists $self->{Hash_Variable_List_Hash}{$variable_name}{$key}) {
		my $old_size = (scalar keys %{$self->{Hash_Variable_List_Hash}{$variable_name}});
		my $deleted = delete $self->{Hash_Variable_List_Hash}{$variable_name}{$key};
		$self->manage_variables_callbacks('accessed_hash', $variable_name, $deleted, undef, $key);
		$self->hash_size_change($variable_name, $old_size);
		return $deleted;
	}
}

sub get_hash_var {
	my ($self, $variable_name, $key) = @_;
	return $self->{Hash_Variable_List_Hash}{$variable_name}{$key} if (exists $self->{Hash_Variable_List_Hash}{$variable_name} && exists $self->{Hash_Variable_List_Hash}{$variable_name}{$key});
	return undef;
}

sub set_hash_var {
	my ($self, $variable_name, $key, $variable_value, $check_callbacks) = @_;

	my $before_value = $self->get_hash_var($variable_name, $key);
	my $before_size = $self->get_hash_size($variable_name);

	if ($variable_value eq 'undef') {
		undef $variable_value;
	}

	$self->{Hash_Variable_List_Hash}{$variable_name}{$key} = $variable_value;

	return if (defined $check_callbacks && $check_callbacks == 0);
	$self->manage_variables_callbacks('accessed_hash', $variable_name, $before_value, $variable_value, $key);
	$self->hash_size_change($variable_name, $before_size);
}

sub hash_size_change {
	my ($self, $variable_name, $old_size) = @_;
	my $size = ((exists $self->{Hash_Variable_List_Hash}{$variable_name}) ? (scalar keys %{$self->{Hash_Variable_List_Hash}{$variable_name}}) : 0);
	debug "[eventMacro] Size of hash '%".$variable_name."' change from '".$old_size."' to '".$size."'\n", "eventMacro";

	$self->manage_variables_callbacks('hash', $variable_name, $old_size, $size);
}

sub get_hash_size {
	my ($self, $variable_name) = @_;
	if (exists $self->{Hash_Variable_List_Hash}{$variable_name}) {
		return (scalar keys %{$self->{Hash_Variable_List_Hash}{$variable_name}});
	}
	return 0;
}

sub is_hash_var_defined {
	my ($self, $variable_name, $key) = @_;
	return ((exists $self->{Hash_Variable_List_Hash}{$variable_name} && exists $self->{Hash_Variable_List_Hash}{$variable_name}{$key} && defined $self->{Hash_Variable_List_Hash}{$variable_name}{$key}) ? 1 : 0);
}
########

sub manage_variables_callbacks {
	my ($self, $variable_type, $variable_name, $before_value, $value, $complement) = @_;

	$self->sub_callback_variable_event($variable_type, $variable_name, $before_value, $value, $complement);

	if ($variable_type eq 'scalar') {

		if (exists $self->{Event_Related_Static_Variables}{scalar} && exists $self->{Event_Related_Static_Variables}{scalar}{$variable_name}) {
			$self->manage_event_callbacks('variable', $variable_name, $value, $self->{Event_Related_Static_Variables}{scalar}{$variable_name}, $variable_type, $complement);
		}

	} elsif ($variable_type eq 'array') {

		if (exists $self->{Event_Related_Static_Variables}{array} && exists $self->{Event_Related_Static_Variables}{array}{$variable_name}) {
			$self->manage_event_callbacks('variable', $variable_name, $value, $$self->{Event_Related_Static_Variables}{array}{$variable_name}, $variable_type, $complement);
		}

	} elsif ($variable_type eq 'hash') {

		if (exists $self->{Event_Related_Static_Variables}{hash} && exists $self->{Event_Related_Static_Variables}{hash}{$variable_name}) {
			$self->manage_event_callbacks('variable', $variable_name, $value, $self->{Event_Related_Static_Variables}{hash}{$variable_name}, $variable_type, $complement);
		}

	} elsif ($variable_type eq 'accessed_array') {

		if (exists $self->{Event_Related_Static_Variables}{accessed_array} && exists $self->{Event_Related_Static_Variables}{accessed_array}{$variable_name} && exists $self->{Event_Related_Static_Variables}{accessed_array}{$variable_name}{$complement}) {
			$self->manage_event_callbacks('variable', $variable_name, $value, $self->{Event_Related_Static_Variables}{accessed_array}{$variable_name}{$complement}, $variable_type, $complement);
		}
		if (exists $self->{Event_Related_Dynamic_Variables}{accessed_array} && exists $self->{Event_Related_Dynamic_Variables}{accessed_array}{$variable_name} && exists $self->{Event_Related_Dynamic_Variables}{accessed_array}{$variable_name}{$complement}) {
			foreach my $sub_complement (keys %{$self->{Event_Related_Dynamic_Variables}{$variable_type}{$variable_name}{$complement}}) {
				$self->manage_event_callbacks('variable', $variable_name, $value, $self->{Event_Related_Dynamic_Variables}{$variable_type}{$variable_name}{$complement}{$sub_complement}, $variable_type, $sub_complement);
			}
		}

	} elsif ($variable_type eq 'accessed_hash') {

		if (exists $self->{Event_Related_Static_Variables}{accessed_hash} && exists $self->{Event_Related_Static_Variables}{accessed_hash}{$variable_name} && exists $self->{Event_Related_Static_Variables}{accessed_hash}{$variable_name}{$complement}) {
			$self->manage_event_callbacks('variable', $variable_name, $value, $self->{Event_Related_Static_Variables}{accessed_hash}{$variable_name}{$complement}, $variable_type, $complement);
		}
		if (exists $self->{Event_Related_Dynamic_Variables}{accessed_hash} && exists $self->{Event_Related_Dynamic_Variables}{accessed_hash}{$variable_name} && exists $self->{Event_Related_Dynamic_Variables}{accessed_hash}{$variable_name}{$complement}) {
			foreach my $sub_complement (keys %{$self->{Event_Related_Dynamic_Variables}{$variable_type}{$variable_name}{$complement}}) {
				$self->manage_event_callbacks('variable', $variable_name, $value, $self->{Event_Related_Dynamic_Variables}{$variable_type}{$variable_name}{$complement}{$sub_complement}, $variable_type, $sub_complement);
			}
		}
	}
}

sub add_to_triggered_prioritized_automacros_index_list {
	my ($self, $automacro) = @_;
	my $priority = $automacro->get_parameter('priority');
	my $index = $automacro->get_index;

	my $list = $self->{triggered_prioritized_automacros_index_list} ||= [];

	my $index_hash = $self->{automacro_index_to_queue_index};

	# Find where we should insert this item.
	my $new_index;
	for ($new_index = 0 ; $new_index < @$list && @$list[$new_index]->{priority} <= $priority ; $new_index++) {}

	# Insert.
	splice @$list, $new_index, 0, { index => $index, priority => $priority };

	# Update indexes.
	foreach my $auto_index_in_queue ($new_index .. $#{$list}) {
		$index_hash->{$list->[$auto_index_in_queue]->{index}} = $auto_index_in_queue;
	}

	$self->{number_of_triggered_automacros}++;
	$automacro->running_status(1);

	debug "[eventMacro] Automacro '".$automacro->get_name()."' met it's conditions. Adding it to running queue in position '".$new_index."'.\n", "eventMacro";

	# Return the insertion index.
	return $new_index;
}

sub remove_from_triggered_prioritized_automacros_index_list {
	my ($self, $automacro) = @_;
	my $priority = $automacro->get_parameter('priority');
	my $index = $automacro->get_index;

	my $list = $self->{triggered_prioritized_automacros_index_list};

	my $index_hash = $self->{automacro_index_to_queue_index};

	# Find from where we should delete this item.
	my $queue_index = delete $index_hash->{$index};

	# remove.
	splice (@$list, $queue_index, 1);

	# Update indexes.
	foreach my $auto_index_in_queue ($queue_index .. $#{$list}) {
		$index_hash->{$list->[$auto_index_in_queue]->{index}} = $auto_index_in_queue;
	}

	$self->{number_of_triggered_automacros}--;
	$automacro->running_status(0);

	debug "[eventMacro] Automacro '".$automacro->get_name()."' no longer meets it's conditions. Removing it from running queue from position '".$queue_index."'.\n", "eventMacro";

	# Return the removal index.
	return $queue_index;
}

sub manage_event_callbacks {
	my $self = shift;
	my $callback_type = shift;
	my $callback_name = shift;
	my $callback_args = shift;
	my $check_list_hash = shift;

	my $debug_message = "[eventMacro] Callback Happenned, type: '".$callback_type."'";

	$debug_message .= ", name: '".$callback_name."'";

	if ($callback_type eq 'variable') {
		my $sub_type = shift;
		my $complement = shift;
		$debug_message .= ", variable type: '".$sub_type."'";

		if ($sub_type eq 'scalar') {
			$callback_name = '$'.$callback_name;

		} elsif ($sub_type eq 'array') {
			$callback_name = '@'.$callback_name;

		} elsif ($sub_type eq 'accessed_array') {
			$callback_name = '$'.$callback_name.'['.$complement.']';
			$debug_message .= ", array index: '".$complement."'";

		} elsif ($sub_type eq 'hash') {
			$callback_name = '%'.$callback_name;

		} elsif ($sub_type eq 'accessed_hash') {
			$callback_name = '$'.$callback_name.'{'.$complement.'}';
			$debug_message .= ", hash key: '".$complement."'";
		}
		$debug_message .= ", variable value: '".$callback_args."'";
	}

	debug $debug_message."\n", "eventMacro", 2;

	my ($event_type_automacro_call_index, $event_type_automacro_call_priority);

	foreach my $automacro_index (keys %{$check_list_hash}) {
		my ($automacro, $conditions_indexes_hash, $check_event_type) = ($self->{Automacro_List}->get($automacro_index), $check_list_hash->{$automacro_index}, 0);

		debug "[eventMacro] Conditions of state type will be checked in automacro '".$automacro->get_name()."'.\n", "eventMacro", 2;

		my @conditions_indexes_array = keys %{ $conditions_indexes_hash };

		foreach my $condition_index (@conditions_indexes_array) {
			my $condition = $automacro->{conditionList}->get($condition_index);

			if ($condition->condition_type == EVENT_TYPE) {
				debug "[eventMacro] Skipping condition '".$condition->get_name."' of index '".$condition->get_index."' because it is of the event type.\n", "eventMacro", 3;
				$check_event_type = 1;
				next;
			} else {
				debug "[eventMacro] Variable value will be updated in condition of state type in automacro '".$automacro->get_name()."'.\n", "eventMacro", 3 if ($callback_type eq 'variable');

				my $result = $automacro->check_state_type_condition($condition_index, $callback_type, $callback_name, $callback_args);

				#add to running queue
				if (!$result && $automacro->running_status) {
					$self->remove_from_triggered_prioritized_automacros_index_list($automacro);

				#remove from running queue
				} elsif ($result && exists $self->{Currently_AI_state_Adapted_Automacros}{$automacro_index} && $automacro->can_be_added_to_queue) {
					$self->add_to_triggered_prioritized_automacros_index_list($automacro);

				}
			}
		}

		if ($check_event_type) {

			if ($callback_type eq 'variable') {
				debug "[eventMacro] Variable value will be updated in condition of event type in automacro '".$automacro->get_name()."'.\n", "eventMacro", 3;
				$automacro->check_event_type_condition($callback_type, $callback_name, $callback_args);

			} elsif (exists $self->{Currently_AI_state_Adapted_Automacros}{$automacro_index} && ($self->get_automacro_checking_status == CHECKING_AUTOMACROS || $self->get_automacro_checking_status == CHECKING_FORCED_BY_USER) && $automacro->can_be_run_from_event) {
				debug "[eventMacro] Condition of event type will be checked in automacro '".$automacro->get_name()."'.\n", "eventMacro", 3;

				if ($automacro->check_event_type_condition($callback_type, $callback_name, $callback_args)) {
					debug "[eventMacro] Condition of event type was fulfilled.\n", "eventMacro", 3;

					if (!defined $event_type_automacro_call_priority) {
						debug "[eventMacro] Automacro '".$automacro->get_name."' of priority '".$automacro->get_parameter('priority')."' was added to the top of queue.\n", "eventMacro", 3;
						$event_type_automacro_call_index = $automacro_index;
						$event_type_automacro_call_priority = $automacro->get_parameter('priority');

					} elsif ($event_type_automacro_call_priority >= $automacro->get_parameter('priority')) {
						debug "[eventMacro] Automacro '".$automacro->get_name."' of priority '".$automacro->get_parameter('priority')."' was added to the top of queue and took place of automacro '".$self->{Automacro_List}->get($event_type_automacro_call_index)->get_name."' which has priority '".$event_type_automacro_call_priority."'.\n", "eventMacro", 3;
						$event_type_automacro_call_index = $automacro_index;
						$event_type_automacro_call_priority = $automacro->get_parameter('priority');

					} else {
						debug "[eventMacro] Automacro '".$automacro->get_name()."' was not added to running queue because there already is a higher priority event only automacro in it (automacro '".$self->{Automacro_List}->get($event_type_automacro_call_index)->get_name."' which has priority '".$event_type_automacro_call_priority."').\n", "eventMacro", 3;

					}

				} else {
					debug "[eventMacro] Condition of event type was not fulfilled.\n", "eventMacro", 3;

				}

			} else {
				debug "[eventMacro] Condition of event type will not be checked in automacro '".$automacro->get_name()."' because it is not necessary.\n", "eventMacro", 3;

			}
		}
	}

	if (defined $event_type_automacro_call_index) {
		
		my %hookArgs;
		Plugins::callHook("eventMacro_before_call_check", \%hookArgs);
		return if ($hookArgs{return});

		my $automacro = $self->{Automacro_List}->get($event_type_automacro_call_index);

		message "[eventMacro] Event of type '".$callback_type."', and of name '".$callback_name."' activated automacro '".$automacro->get_name()."', calling macro '".$automacro->get_parameter('call')."'\n", "system";

		$self->call_macro($automacro);
	}
}

# For '$add_or_delete' value '0' is for delete and '1' is for add.
sub manage_dynamic_hook_add_and_delete {
	my ($self, $hook_name, $automacro_index, $condition_index, $add_or_delete) = @_;

	my $automacro = $self->{Automacro_List}->get($automacro_index);

	my $condition = $automacro->{conditionList}->get($condition_index);

	if ($add_or_delete == 1) {
		if (exists $self->{Event_Related_Hooks}{$hook_name}{$automacro_index}{$condition_index}) {
			error "[eventMacro] Condition '".$condition->get_name()."', of index '".$condition_index."' on automacro '".$automacro->get_name()."' tried to add hook '".$hook_name."' to callbacks but it already is in it.\n";
			return;
		}

		debug "[eventMacro] Condition '".$condition->get_name()."', of index '".$condition_index."' on automacro '".$automacro->get_name()."' added hook '".$hook_name."' to callbacks.\n", "eventMacro", 3;
		$self->{Event_Related_Hooks}{$hook_name}{$automacro_index}{$condition_index} = undef;

		unless (exists $self->{Hook_Handles}{$hook_name}) {
			my $event_sub = sub {
				my $name = shift;
				my $args = shift;
				my $check_list_hash = $self->{Event_Related_Hooks}{$name};
				$self->manage_event_callbacks('hook', $name, $args, $check_list_hash);
			};
			$self->{Hook_Handles}{$hook_name} = Plugins::addHook( $hook_name, $event_sub, undef );
		}

	} else {
		if (!exists $self->{Event_Related_Hooks}{$hook_name}{$automacro_index}{$condition_index}) {
			error "[eventMacro] Condition '".$condition->get_name()."', of index '".$condition_index."' on automacro '".$automacro->get_name()."' tried to delete hook '".$hook_name."' from callbacks but it isn't in it.\n";
			return;
		}

		debug "[eventMacro] Condition '".$condition->get_name()."', of index '".$condition_index."' on automacro '".$automacro->get_name()."' deleted hook '".$hook_name."' from callbacks.\n", "eventMacro", 3;
		delete $self->{Event_Related_Hooks}{$hook_name}{$automacro_index}{$condition_index};

		unless (scalar keys %{$self->{Event_Related_Hooks}{$hook_name}{$automacro_index}}) {
			delete $self->{Event_Related_Hooks}{$hook_name}{$automacro_index};
			unless (scalar keys %{$self->{Event_Related_Hooks}{$hook_name}}) {
				delete $self->{Event_Related_Hooks}{$hook_name};
				Plugins::delHook($self->{Hook_Handles}{$hook_name});
				delete $self->{Hook_Handles}{$hook_name};
			}
		}
	}
}

sub AI_start_checker {
	my ($self, $state) = @_;

	foreach my $array_member (@{$self->{triggered_prioritized_automacros_index_list}}) {

		my $automacro = $self->{Automacro_List}->get($array_member->{index});

		next unless $automacro->is_timed_out;

		if (!$automacro->get_parameter('self_interruptible') && defined $self->{Macro_Runner} && !$self->{Macro_Runner}->self_interruptible && $self->{Macro_Runner}->get_caller_name eq $automacro->get_name()) {
			next;
		}
		
		my %hookArgs;
		Plugins::callHook("eventMacro_before_call_check", \%hookArgs);
		return if ($hookArgs{return});

		message "[eventMacro] Conditions met for automacro '".$automacro->get_name()."', calling macro '".$automacro->get_parameter('call')."'\n", "system";
	
		$self->call_macro($automacro);

		return;
	}
}

sub disable_all_automacros {
	my ($self) = @_;
	foreach my $automacro (@{$self->{Automacro_List}->getItems()}) {
		$self->disable_automacro($automacro);
	}
}

sub enable_all_automacros {
	my ($self) = @_;
	foreach my $automacro (@{$self->{Automacro_List}->getItems()}) {
		$self->enable_automacro($automacro);
	}
}

sub disable_automacro {
	my ($self, $automacro) = @_;
	$automacro->disable;
	if ($automacro->running_status) {
		$self->remove_from_triggered_prioritized_automacros_index_list($automacro);
	}
}

sub enable_automacro {
	my ($self, $automacro) = @_;
	$automacro->enable;
	if ($automacro->can_be_added_to_queue) {
		$self->add_to_triggered_prioritized_automacros_index_list($automacro);
	}
}

sub call_macro {
	my ($self, $automacro) = @_;
	if (defined $self->{Macro_Runner}) {
		$self->clear_queue();
	}

	if ($automacro->get_parameter('call') =~ /\s+/) {

		#here the macro name and the params are together in get_parameter, time to split
		my ($macro_name, @params) = parseArgs($automacro->get_parameter('call'));

		# Update $.param[0] with the values from the call.
		$eventMacro->set_full_array( ".param", \@params);

		$automacro->set_call('call', $macro_name);
	}

	$automacro->set_timeout_time(time);
	if ($automacro->get_parameter('run-once')) {
		$self->disable_automacro($automacro);
	}

	my $new_variables = $automacro->get_new_macro_variables;

	my @variable_names = keys %{ $new_variables };

	foreach my $variable_name (@variable_names) {
		my $variable_value = $new_variables->{$variable_name};
		$self->set_scalar_var($variable_name, $variable_value, 0);
	}

	$self->{Macro_Runner} = new eventMacro::Runner(
		$automacro->get_parameter('call'),
		$automacro->get_name,
		$automacro->get_parameter('repeat'),
		$automacro->get_parameter('exclusive') ? 0 : 1,
		$automacro->get_parameter('self_interruptible'),
		$automacro->get_parameter('overrideAI'),
		$automacro->get_parameter('orphan'),
		$automacro->get_parameter('delay'),
		$automacro->get_parameter('macro_delay'),
		0
	);

	if (defined $self->{Macro_Runner}) {
		my $iterate_macro_sub = sub { $self->iterate_macro(); };
		$self->{AI_start_Macros_Running_Hook_Handle} = Plugins::addHook( 'AI_start', $iterate_macro_sub, undef );
	} else {
		error "[eventMacro] unable to create macro queue.\n"
	}
}

# Function responsible for actually running the macro script
sub iterate_macro {
	my $self = shift;

	# These two cheks are actually not necessary, but they can prevent future code bugs.
	if ( !defined $self->{Macro_Runner} ) {
		debug "[eventMacro] For some reason the running macro object got undefined, clearing queue to prevent errors.\n", "eventMacro", 2;
		$self->clear_queue();
		return;
	} elsif ($self->{Macro_Runner}->finished) {
		debug "[eventMacro] For some reason macro '".$self->{Macro_Runner}->get_name()."' finished but 'processCmd' did not clear it, clearing queue to prevent errors.\n", "eventMacro", 2;
		$self->clear_queue();
		return;
	}

	return if $self->{Macro_Runner}->is_paused();

	my $macro_timeout = $self->{Macro_Runner}->timeout;

	if (timeOut($macro_timeout) && $self->ai_is_eventMacro) {
		do {
			last unless ( $self->processCmd( $self->{Macro_Runner}->next ) );
		} while ($self->{Macro_Runner} && !$self->{Macro_Runner}->is_paused() && $self->{Macro_Runner}->macro_block);
	}
}

sub ai_is_eventMacro {
	my $self = shift;
	return 1 if $self->{Macro_Runner}->last_subcall_overrideAI;

	# now check for orphaned script object
	# may happen when messing around with "ai clear" and stuff.
	$self->enforce_orphan if (defined $self->{Macro_Runner} && !AI::inQueue('eventMacro'));

	return 1 if (AI::is('eventMacro', 'deal'));
	return 1 if (AI::is('NPC') && $char->args->waitingForSteps);
	return 0;
}

sub enforce_orphan {
	my $self = shift;
	my $method = $self->{Macro_Runner}->last_subcall_orphan;
	message "[eventMacro] Running macro '".$self->{Macro_Runner}->last_subcall_name."' got orphaned, its orphan method is '".$method."'.\n";

	# 'terminate' undefs the whole macro tree and returns "ai is not idle"
	if ($method eq 'terminate') {
		$self->clear_queue();
		return 0;

	# 'terminate_last_call' undefs only the specific macro call that got orphaned, keeping the rest of the macro call tree.
	} elsif ($method eq 'terminate_last_call') {
		my $macro = $self->{Macro_Runner};
		if (defined $macro->{subcall}) {
			while (defined $macro->{subcall}) {
				#cheap way of stopping on the second to last subcall
				last if (!defined $macro->{subcall}->{subcall});
				$macro = $macro->{subcall};
			}
			$macro->clear_subcall;
		} else {
			#since there was no subcall we delete all macro tree
			$self->clear_queue();
		}
		return 0;

	# 'reregister' re-inserts "eventMacro" in ai_queue at the first position
	} elsif ($method eq 'reregister') {
		my $macro = $self->{Macro_Runner};
		while (defined $macro->{subcall}) {
			$macro = $macro->{subcall};
		}
		$macro->register;
		return 1;

	# 'reregister_safe' waits until AI is idle then re-inserts "eventMacro"
	} elsif ($method eq 'reregister_safe') {
		if (AI::isIdle || AI::is('deal')) {
			my $macro = $self->{Macro_Runner};
			while (defined $macro->{subcall}) {
				$macro = $macro->{subcall};
			}
			$macro->register;
			return 1
		}
		return 0;

	} else {
		error "[eventMacro] Unknown orphan method '".$method."'. terminating whole macro tree\n", "eventMacro";
		$self->clear_queue();
		return 0;
	}
}

sub processCmd {
	my ($self, $command) = @_;
	my $macro_name = $self->{Macro_Runner}->last_subcall_name;
	if (defined $command) {
		if ($command ne '') {
			unless (Commands::run($command)) {
				my $error_message = sprintf("[eventMacro] %s failed with %s\n", $macro_name, $command);

				error $error_message, "eventMacro";
				$self->clear_queue();
				return;
			}
		}
		if (defined $self->{Macro_Runner} && $self->{Macro_Runner}->finished) {
			$self->clear_queue();

		} elsif (!defined $self->{Macro_Runner}) {
			debug "[eventMacro] Macro runner object got undefined during a command.\n", "eventMacro", 2;
			return;

		} else {
			$self->{Macro_Runner}->ok;
		}
	} else {
		my $macro = $self->{Macro_Runner};
		while (defined $macro->{subcall}) {
			$macro = $macro->{subcall};
		}
		my $error_message = $macro->error_message;

		error $error_message, "eventMacro";
		$self->clear_queue();
		return;
	}

	return 1;
}

sub clear_queue {
	my ($self) = @_;
	debug "[eventMacro] Clearing queue\n", "eventMacro", 2;
	if ( defined $self->{Macro_Runner} && $self->get_automacro_checking_status() == PAUSED_BY_EXCLUSIVE_MACRO ) {
		debug "[eventMacro] Uninterruptible macro '".$self->{Macro_Runner}->last_subcall_name."' ended. Automacros will return to being checked.\n", "eventMacro", 2;
		$self->set_automacro_checking_status(CHECKING_AUTOMACROS);
	}
	$self->{Macro_Runner} = undef;
	Plugins::delHook($self->{AI_start_Macros_Running_Hook_Handle}) if (defined $self->{AI_start_Macros_Running_Hook_Handle});
	$self->{AI_start_Macros_Running_Hook_Handle} = undef;
}

sub include {
	my ($self, $key, $param) = @_;

	unless ( open( IN, "<:utf8", $self->{file} ) ) {
		error "[eventMacro] Could not open eventMacro file for include operation.\n", "eventMacro";
		return;
	}
	my @lines = <IN>;
	close(IN);

	my $on = "\n------on-------\n";
	my $off = "\n------off------\n";
	my $needrewrite = 0;

	foreach my $line (@lines) {
		if ($line =~ /^\s*(!include\s.+)$/) {
			my $include = $1;
			if ($key eq 'list') {
				$on .= $include."\n";

			} elsif ($key eq 'off') {
				if ($param eq 'all' || $include =~ /.*$param.*/) {
					$line =~ s/!include/#!include/g;
					$needrewrite = 1;
					my ($file) = $include =~ /!include\s+(.+)$/;
					message "[eventMacro] Removed ".$file."\n", 'list';
				}
			}

		} elsif ($line =~ /^\s*(#!include\s.+)$/) {
			my $include = $1;
			if ($key eq 'list') {
				$off .= $include."\n";

			} elsif ($key eq 'on') {
				if ($param eq 'all' || $include =~ /.*$param.*/) {
					$line =~ s/#!include/!include/g;
					$needrewrite = 1;
					my ($file) = $include =~ /#!include\s+(.+)$/;
					message "[eventMacro] Added ".$file."\n", 'list';
				}
			}
		}
	}
	message "$on$off", 'list' if ($key eq 'list');

	if ($needrewrite) {
		open (IN, ">:utf8", $self->{file});
		print IN join ("", @lines);
		close(IN);
	}
}


1;

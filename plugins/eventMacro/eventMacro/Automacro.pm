package eventMacro::Automacro;

use strict;
use Globals qw( %config %timeout );
use Log qw(message error warning debug);
use Utils qw( timeOut );

use eventMacro::Condition;
use eventMacro::Data qw( EVENT_TYPE );

sub new {
	my ($class, $name, $parameters) = @_;
	my $self = bless {}, $class;
	
	$self->{name} = $name;
	
	$self->{conditionList} = new eventMacro::Lists;
	$self->{event_type_condition_index} = undef;
	$self->{hooks} = {};
	$self->{scalar_variables} = {};
	$self->{array_variables} = {};
	$self->{accessed_array_variables} = {};
	$self->{hash_variables} = {};
	$self->{accessed_hash_variables} = {};
	$self->{parameters} = {};
	$self->{running_status} = 0;
	$self->set_parameters( $parameters );
	
	$self->{check_on_ai_state} = {};
	$self->parse_CheckOnAI;
	
	return $self;
}

sub parse_and_create_conditions {
	my ($self, $conditions) = @_;
	$self->create_conditions_list( $conditions );
	$self->{number_of_false_conditions} = $self->{conditionList}->size;
	if (defined $self->{event_type_condition_index}) {
		$self->{number_of_false_conditions}--;
	}
}

sub running_status {
	my ($self, $new_status) = @_;
	if (defined $new_status) {
		$self->{running_status} = $new_status;
	}
	return $self->{running_status};
}

sub get_index {
	my ($self) = @_;
	return $self->{listIndex};
}

sub get_hooks {
	my ($self) = @_;
	return $self->{hooks};
}

sub get_name {
	my ($self) = @_;
	return $self->{name};
}

sub set_timeout_time {
	my ($self, $time) = @_;
	$self->{parameters}{time} = $time;
}

sub disable {
	my ($self) = @_;
	$self->{parameters}{disabled} = 1;
	debug "[eventMacro] Disabling ".$self->get_name()."\n", "eventMacro", 2;
}

sub enable {
	my ($self) = @_;
	$self->{parameters}{disabled} = 0;
	debug "[eventMacro] Enabling ".$self->get_name()."\n", "eventMacro", 2;
}

sub get_parameter {
	my ($self, $parameter) = @_;
	return $self->{parameters}{$parameter};
}

sub set_call {
	my ($self, $parameters, $macro_name) = @_;
	$self->{parameters}{'call'} = $macro_name;
}

sub set_parameters {
	my ($self, $parameters) = @_;
	foreach (keys %{$parameters}) {
		my $key = $_;
		my $value = $parameters->{$_};
		$self->{parameters}{$key} = $value;
	}
	#all parameters must be defined
	if (!defined $self->{parameters}{'timeout'}) {
		$self->{parameters}{'timeout'} = 0;
	}
	if (!defined $self->{parameters}{'delay'}) {
		$self->{parameters}{'delay'} = 0;
	}
	if (!defined $self->{parameters}{'run-once'}) {
		$self->{parameters}{'run-once'} = 0;
	}
	if (!defined $self->{parameters}{'CheckOnAI'}) {
		$self->{parameters}{'CheckOnAI'} = $config{eventMacro_CheckOnAI};
	}
	if (!defined $self->{parameters}{'disabled'}) {
		$self->{parameters}{'disabled'} = 0;
	}
	if (!defined $self->{parameters}{'overrideAI'}) {
		$self->{parameters}{'overrideAI'} = 0;
	}
	if (!defined $self->{parameters}{'orphan'}) {
		$self->{parameters}{'orphan'} = $config{eventMacro_orphans};
	}
	if (!defined $self->{parameters}{'macro_delay'}) {
		$self->{parameters}{'macro_delay'} = $timeout{eventMacro_delay}{timeout};
	}
	if (!defined $self->{parameters}{'priority'}) {
		$self->{parameters}{'priority'} = 0;
	}
	if (!defined $self->{parameters}{'exclusive'}) {
		$self->{parameters}{'exclusive'} = 0;
	}
	if (!defined $self->{parameters}{'self_interruptible'}) {
		$self->{parameters}{'self_interruptible'} = 0;
	}
	if (!defined $self->{parameters}{'repeat'}) {
		$self->{parameters}{'repeat'} = 1;
	}
	$self->{parameters}{time} = 0;
}

sub parse_CheckOnAI {
	my ($self) = @_;
	my @ai_states = split(/\s*,\s*/, $self->{parameters}{'CheckOnAI'});
	
	foreach my $state (@ai_states) {
		if ($state ne 'auto' && $state ne 'manual' && $state ne 'off') {
			error "[eventMacro] Parameter 'CheckOnAI' on automacro '".$self->{name}."' has a non-valid value '".$state."'. Ignoring it.\n";
		} else {
			$self->{check_on_ai_state}{$state} = undef;
		}
	}
}

sub create_conditions_list {
	my ($self, $conditions) = @_;
	foreach (keys %{$conditions}) {
		my $module = $_;
		my $conditionsText = $conditions->{$_};
		eval "use $module";
		foreach my $newConditionText ( @{$conditionsText} ) {
			my $cond = $module->new( $newConditionText, $self->{listIndex} );
			$self->{conditionList}->add( $cond );
			my $cond_index = $cond->get_index;
			foreach my $hook ( @{ $cond->get_hooks() } ) {
				push ( @{ $self->{hooks}{$hook} }, $cond_index );
			}
			foreach my $variable ( @{ $cond->get_variables() } ) {
				$self->define_var_types($variable, $cond_index);
			}
			if ($cond->condition_type == EVENT_TYPE) {
				$self->{event_type_condition_index} = $cond_index;
			}
		}
	}
}

sub define_var_types {
	my ($self, $variable, $cond_index) = @_;
	if ($variable->{type} eq 'scalar') {
		push ( @{ $self->{scalar_variables}{$variable->{real_name}} }, $cond_index );
		
	} elsif ($variable->{type} eq 'array') {
		push ( @{ $self->{array_variables}{$variable->{real_name}}}, $cond_index );
		
	} elsif ($variable->{type} eq 'accessed_array') {
		push ( @{ $self->{accessed_array_variables}{$variable->{real_name}}{$variable->{complement}} }, $cond_index );
		
	} elsif ($variable->{type} eq 'hash') {
		push ( @{ $self->{hash_variables}{$variable->{real_name}}}, $cond_index );
		
	} elsif ($variable->{type} eq 'accessed_hash') {
		push ( @{ $self->{accessed_hash_variables}{$variable->{real_name}}{$variable->{complement}} }, $cond_index );
	}
}

sub get_scalar_variables {
	my ($self) = @_;
	return $self->{scalar_variables};
}

sub get_array_variables {
	my ($self) = @_;
	return $self->{array_variables};
}

sub get_accessed_array_variables {
	my ($self) = @_;
	return $self->{accessed_array_variables};
}

sub get_hash_variables {
	my ($self) = @_;
	return $self->{hash_variables};
}

sub get_accessed_hash_variables {
	my ($self) = @_;
	return $self->{accessed_hash_variables};
}

sub has_event_type_condition {
	my ($self) = @_;
	return defined $self->{event_type_condition_index};
}

sub get_event_type_condition_index {
	my ($self) = @_;
	return $self->{event_type_condition_index};
}

sub check_state_type_condition {
	my ($self, $condition_index, $callback_type, $callback_name, $args) = @_;
	
	my $condition = $self->{conditionList}->get($condition_index);
	
	my $pre_check_status = $condition->is_fulfilled;
	
	my $pos_check_status = $condition->validate_condition($callback_type, $callback_name, $args);
	
	debug "[eventMacro] Checking condition '".$condition->get_name()."' of index '".$condition->get_index."' in automacro '".$self->{name}."', fulfilled value before: '".$pre_check_status."', fulfilled value after: '".$pos_check_status."'.\n", "eventMacro", 3;
	
	if ($pre_check_status == 1 && $condition->is_fulfilled == 0) {
		$self->{number_of_false_conditions}++;
	} elsif ($pre_check_status == 0 && $condition->is_fulfilled == 1) {
		$self->{number_of_false_conditions}--;
	}
	return $pos_check_status;
}

sub check_event_type_condition {
	my ($self, $callback_type, $callback_name, $args) = @_;
	
	my $condition = $self->{conditionList}->get($self->{event_type_condition_index});
	
	my $return = $condition->validate_condition($callback_type, $callback_name, $args);
	
	debug "[eventMacro] Checking event type condition '".$condition->get_name()."' of index '".$condition->get_index."' in automacro '".$self->{name}."', fulfilled value: '".$return."'.\n", "eventMacro", 3;

	return $return;
}

sub are_conditions_fulfilled {
	my ($self) = @_;
	$self->{number_of_false_conditions} == 0;
}

sub is_disabled {
	my ($self) = @_;
	return $self->{parameters}{disabled};
}

sub is_timed_out {
	my ($self) = @_;
	return 1 unless ( $self->{parameters}{'timeout'} );
	return 1 if ( timeOut( { timeout => $self->{parameters}{'timeout'}, time => $self->{parameters}{time} } ) );
	return 0;
}

sub can_be_added_to_queue {
	my ($self) = @_;
	return 1 if ($self->are_conditions_fulfilled && !$self->is_disabled && !$self->running_status && !$self->has_event_type_condition);
	return 0;
}

sub can_be_run_from_event {
	my ($self) = @_;
	return 1 if ($self->are_conditions_fulfilled && !$self->is_disabled && $self->is_timed_out);
	return 0;
}

sub get_new_macro_variables {
	my ($self) = @_;
	my %new_variables;
	foreach my $condition (@{$self->{conditionList}->getItems()}) {
		my $new_variables = $condition->get_new_variable_list;
		my @variable_names = keys %{ $new_variables };
		foreach my $variable_name (@variable_names) {
			my $variable_value = $new_variables->{$variable_name};
			$new_variables{$variable_name} = $variable_value;
		}
	}
	$new_variables{'.caller'} = $self->{name};
	return \%new_variables;
}

1;
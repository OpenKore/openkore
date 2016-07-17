package eventMacro::Automacro;

use strict;
use Globals;
use Log qw(message error warning debug);
use eventMacro::Condition;

sub new {
	my ($class, $name, $conditions, $parameters) = @_;
	my $self = bless {}, $class;
	
	$self->{Name} = $name;
	$self->{is_Fulfilled} = 0;
	
	$self->{conditionList} = new eventMacro::Lists;
	$self->{has_event_only_condition} = 0;
	$self->{event_only_condition_index} = undef;
	$self->{Hooks} = {};
	$self->{Variables} = {};
	$self->create_conditions_list( $conditions );
	
	$self->{Parameters} = {};
	$self->set_parameters( $parameters );
	
	return $self;
}

sub get_hooks {
	my ($self) = @_;
	return $self->{Hooks};
}

sub get_variables {
	my ($self) = @_;
	return $self->{Variables};
}

sub get_name {
	my ($self) = @_;
	return $self->{Name};
}

sub set_timeout_time {
	my ($self, $time) = @_;
	$self->{Parameters}{time} = $time;
}

sub disable {
	my ($self) = @_;
	$self->{Parameters}{disabled} = 1;
	debug "[eventMacro] Disabling ".$self->get_name()."\n", "eventMacro", 2;
	return 1;
}

sub enable {
	my ($self) = @_;
	$self->{Parameters}{disabled} = 0;
	debug "[eventMacro] Enabling ".$self->get_name()."\n", "eventMacro", 2;
	return 1;
}

sub is_disabled {
	my ($self) = @_;
	return $self->{Parameters}{disabled};
}

sub is_timed_out {
	my ($self) = @_;
	return 1 unless ( $self->{Parameters}{'timeout'} );
	return 1 if ( timeOut( timeout => $self->{Parameters}{'timeout'}, time => $self->{Parameters}{time} ) );
	return 0;
}

sub get_parameter {
	my ($self, $parameter) = @_;
	return $self->{Parameters}{$parameter};
}

sub set_parameters {
	my ($self, $parameters) = @_;
	foreach (keys %{$parameters}) {
		my $key = $_;
		my $value = $parameters->{$_};
		$self->{Parameters}{$key} = $value;
	}
	#all parameters must be defined
	if (!defined $self->{Parameters}{'timeout'})  {
		$self->{Parameters}{'timeout'} = 0;
	}
	if (!defined $self->{Parameters}{'delay'})  {
		$self->{Parameters}{'delay'} = 0;
	}
	if (!defined $self->{Parameters}{'run-once'})  {
		$self->{Parameters}{'run-once'} = 0;
	}
	if (!defined $self->{Parameters}{'disabled'})  {
		$self->{Parameters}{'disabled'} = 0;
	}
	if (!defined $self->{Parameters}{'overrideAI'})  {
		$self->{Parameters}{'overrideAI'} = 0;
	}
	if (!defined $self->{Parameters}{'orphan'})  {
		$self->{Parameters}{'orphan'} = $config{eventMacro_orphans};
	}
	if (!defined $self->{Parameters}{'macro_delay'})  {
		$self->{Parameters}{'macro_delay'} = $timeout{eventMacro_delay}{timeout};
	}
	if (!defined $self->{Parameters}{'priority'})  {
		$self->{Parameters}{'priority'} = 0;
	}
	if (!defined $self->{Parameters}{'exclusive'})  {
		$self->{Parameters}{'exclusive'} = 0;
	}
	$self->{Parameters}{time} = 0;
}

sub create_conditions_list {
	my ($self, $conditions) = @_;
	foreach (keys %{$conditions}) {
		my $module = $_;
		my $conditionsText = $conditions->{$_};
		eval "use $module";
		foreach my $newConditionText ( @{$conditionsText} ) {
			my $cond = $module->new( $newConditionText );
			$self->{conditionList}->add( $cond );
			foreach my $hook ( @{ $cond->get_hooks() } ) {
				push ( @{ $self->{Hooks}{$hook} }, $cond->{listIndex} );
			}
			foreach my $variable ( @{ $cond->get_variables() } ) {
				push ( @{ $self->{Variables}{$variable} }, $cond->{listIndex} );
			}
			if ($cond->is_event_only()) {
				$self->{has_event_only_condition} = 1;
				$self->{event_only_condition_index} = $cond->{listIndex};
			}
		}
	}
}

sub validate_automacro_status {
	my ($self) = @_;
	debug "[eventMacro] Validating value of automacro ".$self->get_name()." \n", "eventMacro", 2;
	foreach my $condition ( @{ $self->{conditionList}->getItems() } ) {
		debug "[eventMacro] Checking confition ".$condition->get_name()." index ".$condition->{listIndex}." \n", "eventMacro", 2;
		next if ($condition->is_event_only());
		next if ($condition->is_fulfilled());
		debug "[eventMacro] Not fulfilled \n", "eventMacro", 2;
		$self->{is_Fulfilled} = 0;
		return;
	}
	debug "[eventMacro] Successfully fulfilled \n", "eventMacro", 2;
	$self->{is_Fulfilled} = 1;
}

sub are_conditions_fulfilled {
	my ($self) = @_;
	#debug "[eventMacro] are_conditions_fulfilled called in Automacro ".$self->get_name().", value is ".$self->{is_Fulfilled}." \n", "eventMacro", 2;
	return $self->{is_Fulfilled};
}

sub has_event_only_condition {
	my ($self) = @_;
	return $self->{has_event_only_condition};
}

sub get_event_only_condition_index {
	my ($self) = @_;
	return $self->{event_only_condition_index};
}

1;
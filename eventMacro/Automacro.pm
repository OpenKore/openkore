package eventMacro::Automacro;

use strict;
use Globals;
use Log qw(message error warning);

sub new {
	my ($class, $name, $conditions, $parameters) = @_;
	my $self = bless {}, $class;
	
	$self->{name} = $name;
	$self->{isFulfilled} = 0;
	
	$self->{conditionList} = new eventMacro::Lists;
	$self->{hooks} = {};
	$self->{variables} = {};
	$self->create_conditions_list($conditions);
	
	$self->{parameters} = {};
	$self->set_parameters($parameters);
	
	return $self;
}

sub set_timeout_time {
	my ($self, $time) = @_;
	$self->{parameters}{time} = $time;
}

sub disable {
	my ($self) = @_;
	$self->{parameters}{disabled} = 1;
	message "[eventMacro] Disabling ".$self->{name}."\n","success";
	return 1;
}

sub enable {
	my ($self) = @_;
	$self->{parameters}{disabled} = 0;
	message "[eventMacro] Enabling ".$self->{name}."\n","success";
	return 1;
}

sub is_disabled {
	my ($self) = @_;
	return $self->{parameters}{disabled};
}

sub is_timed_out {
	my ($self) = @_;
	return 1 unless $self->{parameters}{'timeout'};
	return 1 if (timeOut(timeout => $self->{parameters}{'timeout'}, time => $self->{parameters}{time}));
	return 0;
}

sub get_parameter {
	my ($self, $parameter) = @_;
	return $self->{parameters}{$parameter};
}

sub set_parameters {
	my ($self, $parameters) = @_;
	foreach (keys %{$parameters}) {
		my $key = $_;
		my $value = $parameters->{$_};
		$self->{parameters}{$key} = $value;
	}
	#all parameters must be defined
	if (!defined $self->{parameters}{'timeout'})  {
		$self->{parameters}{'timeout'} = 0;
	}
	if (!defined $self->{parameters}{'delay'})  {
		$self->{parameters}{'delay'} = 0;
	}
	if (!defined $self->{parameters}{'run-once'})  {
		$self->{parameters}{'run-once'} = 0;
	}
	if (!defined $self->{parameters}{'disabled'})  {
		$self->{parameters}{'disabled'} = 0;
	}
	if (!defined $self->{parameters}{'overrideAI'})  {
		$self->{parameters}{'overrideAI'} = 0;
	}
	if (!defined $self->{parameters}{'orphan'})  {
		$self->{parameters}{'orphan'} = $config{macro_orphans};
	}
	if (!defined $self->{parameters}{'macro_delay'})  {
		$self->{parameters}{'macro_delay'} = $timeout{eventMacro_delay}{timeout};
	}
	if (!defined $self->{parameters}{'priority'})  {
		$self->{parameters}{'priority'} = 0;
	}
	if (!defined $self->{parameters}{'exclusive'})  {
		$self->{parameters}{'exclusive'} = 0;
	}
	$self->{parameters}{time} = 0;
}

sub create_conditions_list {
	my ($self, $conditions) = @_;
	foreach (keys %{$conditions}) {
		my $module = $_;
		my @conditionsText = @{$conditions->{$_}};
		eval "use $module";
		foreach my $newConditionText (@conditionsText) {
			my $cond = $module->new($newConditionText);
			$self->{conditionList}->add($cond);
			foreach my $hook (@{$cond->{hooks}}) {
				push (@{$self->{hooks}{$hook}}, $cond->{listIndex});
			}
			foreach my $variable (@{$cond->{variables}}) {
				push (@{$self->{variables}{$variable}}, $cond->{listIndex});
			}
		}
	}
}

sub validate_automacro_status {
	my ($self) = @_;
	message "[eventMacro] Validating value of automacro ".$self->{name}." \n","success";
	foreach my $condition (@{$self->{conditionList}->getItems()}) {
		message "[eventMacro] Checking confition ".$condition->{name}." index ".$condition->{listIndex}." \n","success";
		next if ($condition->is_fulfilled());
		message "[eventMacro] Not fulfilled \n","success";
		$self->{isFulfilled} = 0;
		return;
	}
	message "[eventMacro] Successfully fulfilled \n","success";
	$self->{isFulfilled} = 1;
}

use Log qw(message error warning);
sub are_conditions_fulfilled {
	my ($self) = @_;
	#message "[eventMacro] are_conditions_fulfilled called in Automacro ".$self->{name}.", value is ".$self->{isFulfilled}." \n","success";
	return $self->{isFulfilled};
}

1;
package eventMacro::Condition;

use strict;

# Import the validators so our child classes do not have to.
use eventMacro::Validator::NumericComparison;

sub new {
	my ($class, $condition_code) = @_;
	my $self = bless {}, $class;
	
	$self->{Name} = ($class =~ /([^:]+)$/)[0];
	$self->{Variables} = [];

	$self->{Hooks} = [ @{ $self->_hooks } ];

	return if !$self->_parse_syntax( $condition_code );

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

sub is_unique_condition {
	my ($self) = @_;
	return $self->{is_Unique_Condition};
}

sub is_fulfilled {
	my ($self) = @_;
	return $self->{is_Fulfilled};
}

# Default: No hooks.
sub _hooks {
	[];
}

# Default: No syntax parsing, always succeed.
sub _parse_syntax {
	1;
}

# Default: No event_only
sub is_event_only {
	0;
}

1;

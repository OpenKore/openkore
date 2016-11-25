package eventMacro::Condition;

use strict;
use eventMacro::Data;

# Import the validators so our child classes do not have to.
use eventMacro::Validator::NumericComparison;
use eventMacro::Validator::ListMemberCheck;

sub new {
	my ($class, $condition_code) = @_;
	my $self = bless {}, $class;
	
	$self->{name} = ($class =~ /([^:]+)$/)[0];
	$self->{variables} = [];
	$self->{error}  = '';

	$self->{hooks} = [ @{ $self->_hooks } ];

	$self->_parse_syntax( $condition_code );

	return $self;
}

sub validate_condition_status {
	my ( $self, $result ) = @_;
	return $result if ($self->condition_type == EVENT_TYPE);
	$self->{is_Fulfilled} = $result;
}

sub get_hooks {
	my ($self) = @_;
	return $self->{hooks};
}

sub get_variables {
	my ($self) = @_;
	return $self->{variables};
}

sub get_name {
	my ($self) = @_;
	return $self->{name};
}

sub is_unique_condition {
	my ($self) = @_;
	return $self->{is_Unique_Condition};
}

sub is_fulfilled {
	my ($self) = @_;
	
	#Should never happen
	return 0 if ($self->condition_type == EVENT_TYPE);
	
	return $self->{is_Fulfilled};
}

sub error {
	my ( $self ) = @_;
	$self->{error};
}

# Default: No variables.
sub get_new_variable_list {
	{};
}

# Default: No hooks.
sub _hooks {
	[];
}

# Default: No syntax parsing, always succeed.
sub _parse_syntax {
	1;
}

# Default: State type
sub condition_type {
	my ($self) = @_;
	STATE_TYPE;
}

1;

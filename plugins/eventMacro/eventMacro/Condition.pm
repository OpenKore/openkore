package eventMacro::Condition;

use strict;

# Import the validators so our child classes do not have to.
use eventMacro::Validator::NumericComparison;
use eventMacro::Validator::ListMemberCheck;

sub new {
	my ($class, $condition_code) = @_;
	my $self = bless {}, $class;
	
	$self->{name} = ($class =~ /([^:]+)$/)[0];
	$self->{variables} = [];

	$self->{hooks} = [ @{ $self->_hooks } ];

	return if !$self->_parse_syntax( $condition_code );

	return $self;
}

sub validate_condition_status {
	my ( $self, $result ) = @_;
	return $result if ($self->is_event_only);
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

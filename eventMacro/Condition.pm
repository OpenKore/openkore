package eventMacro::Condition;

use strict;

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;
	
	$self->{Variables} = [];
	$self->{is_Fulfilled} = 0;

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

1;
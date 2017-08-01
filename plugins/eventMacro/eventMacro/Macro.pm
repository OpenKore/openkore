package eventMacro::Macro;

use strict;

sub new {
	my ($class, $name, $lines) = @_;
	my $self = bless {}, $class;
	
	$self->{name} = $name;
	$self->{Lines} = $lines;
	
	return $self;
}

sub get_lines {
	my ($self) = @_;
	return $self->{Lines};
}

sub get_name {
	my ($self) = @_;
	return $self->{name};
}

1;
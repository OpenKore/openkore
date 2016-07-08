package eventMacro::Macro;

use strict;

sub new {
	my ($class, $name, $lines) = @_;
	my $self = bless {}, $class;
	
	$self->{name} = $name;
	$self->{lines} = $lines;
	
	return $self;
}

1;
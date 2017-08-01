package eventMacro::Validator;

use strict;

sub new {
	my ( $class, $str ) = @_;
	my $self = bless {}, $class;
	$self->{var}    = [];
	$self->{error}  = undef;
	$self->{parsed} = 1;
	$self->parse( $str ) if (defined $str);
	$self;
}

sub parse {
	1;
}

sub parsed {
	$_[0]->{parsed};
}

sub validate {
	1;
}

sub variables {
	my ( $self ) = @_;
	$self->{var};
}

sub error {
	my ( $self ) = @_;
	$self->{error};
}

1;

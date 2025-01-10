package eventMacro::Condition::InCity;

use strict;

use base 'eventMacro::Condition';

#InCity 1 -> Only triggers in cities
#InCity 0 -> Only triggers outside of cities

use Globals qw( $field );

sub _hooks {
	['Network::Receive::map_changed','in_game','packet_mapChange'];
}


sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{wanted_return_isCity} = undef;
	
	if ($condition_code =~ /^(0|1)$/) {
		$self->{wanted_return_isCity} = $1;
	} else {
		$self->{error} = "Value '".$condition_code."' Should be '0' or '1'";
		return 0;
	}
	
	return 1;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;

	unless ( defined $field ) {
		$self->SUPER::validate_condition( 0 );
	}
	
	$self->{lastMap} = $field->baseName;
	
	return $self->SUPER::validate_condition(  $field->isCity == $self->{wanted_return_isCity} );
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $self->{lastMap};
	
	return $new_variables;
}

1;

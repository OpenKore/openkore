package eventMacro::Condition::MapLoaded;

use strict;

use base 'eventMacro::Conditiontypes::ListConditionEvent';

use Globals qw( $field );

sub _hooks {
	['packet_mapChange'];
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	} elsif ($callback_type eq 'hook') {
		$self->{lastMap} = $field->baseName;
		return $self->SUPER::validate_condition( $self->validator_check($self->{lastMap}) );
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $self->{lastMap};
	
	return $new_variables;
}

1;

package eventMacro::Condition::Zeny;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';

use Globals qw( $char );

sub _hooks {
	['zeny_change','packet/stat_info','packet/stats_info','complete_deal'];
}

sub _get_val {
    $char->{zeny};
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		return $self->SUPER::validate_condition if $callback_name eq 'packet/stat_info' && $args && $args->{type} != 20;
	} elsif ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}
	return $self->SUPER::validate_condition(  $self->validator_check );
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $char->{zeny};
	
	return $new_variables;
}

1;

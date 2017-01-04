package eventMacro::Condition::InStorage;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';

use Globals qw( $char );

sub _hooks {
	['storage_first_session_openning','packet/storage_item_added','storage_item_removed'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{wanted_name} = undef;
	$self->{was_opened} = 0;
	
	if ($condition_code =~ /"(.+)"\s+(\S.*)/) {
		$self->{wanted_name} = $1;
		$condition_code = $2;
	} else {
		$self->{error} = "Item name must be inside quotation marks and a numeric comparison must be given";
		return 0;
	}
	
	$self->{is_on_stand_by} = 1;
	
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub _get_val {
	my ( $self ) = @_;
	$char->storage->sumByName($self->{wanted_name});
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {

		if ($callback_name eq 'storage_first_session_openning') {
			$self->{was_opened} = 1;
		}
		
	} elsif ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
		
	} elsif ($callback_type eq 'recheck') {
		$self->{was_opened} = $char->storage->wasOpenedThisSession;
	}
	
	if ($self->{was_opened} == 0) {
		return $self->SUPER::validate_condition(0);
	} else {
		return $self->SUPER::validate_condition( $self->validator_check );
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $self->{wanted_name};
	$new_variables->{".".$self->{name}."LastAmount"} = $char->storage->sumByName($self->{wanted_name});
	
	return $new_variables;
}

1;

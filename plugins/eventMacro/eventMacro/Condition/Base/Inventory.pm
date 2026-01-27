package eventMacro::Condition::Base::Inventory;

use strict;
use base 'eventMacro::Conditiontypes::NumericConditionState';

sub _parse_syntax {
    my ( $self, $condition_code ) = @_;

    $self->{is_on_stand_by} = 1;
    $self->{member_list} ||= [];
    $self->{last_member} = undef;
}

sub validate_condition {
    my ( $self, $callback_type, $callback_name, $args ) = @_;

    if ($callback_type eq 'variable') {
        $self->update_validator_var($callback_name, $args);
    }

    if ($self->{is_on_stand_by} == 1) {
        return $self->SUPER::validate_condition(0);
    } else {
        return $self->SUPER::validate_condition( $self->validator_check );
    }
}

sub validator_check {
    my ($self) = @_;

    my $last_member;
    foreach my $member (@{ $self->{member_list} }) {
        my $value = $self->_get_val($member->{wanted});
        $last_member = { wanted => $member->{wanted}, amount => $value };
        if ($member->{validator}->validate( $value, $self->_get_ref_val($member->{wanted}) )) {
            $self->{last_member} = $last_member;
            return 1;
        }
    }

    $self->{last_member} = $last_member if defined $last_member;
    return 0;
}

sub update_validator_var {
    my ( $self, $var_name, $var_value ) = @_;

    foreach my $member ( @{ $self->{member_list} } ) {
        $member->{validator}->update_vars( $var_name, $var_value );
    }
}

sub get_new_variable_list {
    my ($self) = @_;
    my $new_variables = {};
    return $new_variables unless (defined $self->{last_member});

    $new_variables->{".".$self->{name}."Last"} = $self->{last_member}{wanted};
    $new_variables->{".".$self->{name}."LastAmount"} = $self->{last_member}{amount};

    return $new_variables;
}

1;

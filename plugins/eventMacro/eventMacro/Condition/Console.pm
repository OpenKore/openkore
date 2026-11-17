package eventMacro::Condition::Console;

use strict;

use base 'eventMacro::Condition::Base::Msg';

sub _hooks {
        ['log'];
}

sub validate_condition {
        my ( $self, $callback_type, $callback_name, $args ) = @_;

        $self->{message} = undef;
        $self->{source} = undef;

        if ($callback_type eq 'hook') {
                $self->{message} = $args->{message};
                $self->{source} = $args->{domain};
        }
        return $self->SUPER::validate_condition( $callback_type, $callback_name, $args );
}

1;
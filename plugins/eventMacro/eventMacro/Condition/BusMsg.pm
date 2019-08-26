package eventMacro::Condition::BusMsg;

use strict;

use base 'eventMacro::Condition::Base::Msg';

sub _hooks {
	my ( $self ) = @_;
	my $hooks = $self->SUPER::_hooks;
	my @other_hooks = ('bus_received');
	push(@{$hooks}, @other_hooks);
	return $hooks;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	if ($callback_type eq 'hook') {
		$self->{message} = $args->{message};
		if (exists $args->{sender}) {
			$self->{source} = $args->{sender};
		} else {
			$self->{source} = undef;
		}
	}
	return $self->SUPER::validate_condition( $callback_type, $callback_name, $args );
}

1;
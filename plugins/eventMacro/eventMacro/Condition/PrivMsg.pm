package eventMacro::Condition::PrivMsg;

use strict;
use Globals;
use Utils;

use base 'eventMacro::Condition::BaseMsg';

sub _hooks {
	my ( $self ) = @_;
	my $hooks = $self->SUPER::_hooks;
	my @other_hooks = ('packet_privMsg');
	push(@{$hooks}, @other_hooks);
	return $hooks;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	$self->{message} = undef;
	$self->{source} = undef;
	
	if ($callback_type eq 'hook') {
		$self->{message} = $args->{Msg};
		$self->{source} = $args->{MsgUser};
	}
	return $self->SUPER::validate_condition( $callback_type, $callback_name, $args );
}

sub usable {
	1;
}

1;
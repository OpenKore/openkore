package eventMacro::Condition::InLockMap;

use strict;

use base 'eventMacro::Condition';

#InLockMap 1 -> Only triggers in the lockMap
#InLockMap 0 -> Only triggers outside of the lockMap

use Globals qw( $field );

sub _hooks {
	[ 'packet_mapChange', 'configModify' ];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;

	if ( $condition_code !~ /^(0|1)$/ ) {
		$self->{error} = "Value '$condition_code' should be '0' or '1'";
		return 0;
	}

	$self->{wanted_return_inLockMap} = $condition_code;

	1;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;

	$self->{lastMap} = $field ? $field->baseName : '';
	$self->{lastLockMap} ||= '';

	if ( $callback_type eq 'hook' && $callback_name eq 'configModify' && $args->{key} eq 'lockMap' ) {
		$self->{lastLockMap} = $args->{val} || '';
	}

	$self->SUPER::validate_condition( ( $self->{lastMap} eq $self->{lastLockMap} ? 1 : 0 ) == $self->{wanted_return_inLockMap} );
}

1;

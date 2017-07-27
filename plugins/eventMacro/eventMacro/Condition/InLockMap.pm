package eventMacro::Condition::InLockMap;

use strict;

use base 'eventMacro::Condition';

#InLockMap 1 -> Only triggers in the lockMap
#InLockMap 0 -> Only triggers outside of the lockMap

use Globals qw( $field %config );

sub _hooks {
	['packet_mapChange','configModify','pos_load_config.txt','in_game'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;

	if ( $condition_code !~ /^(0|1)$/ ) {
		$self->{error} = "Value '$condition_code' should be '0' or '1'";
		return 0;
	}

	$self->{wanted_return_InLockMap} = $condition_code;
	
	$self->{lastMap} = $field ? $field->baseName : '';
	$self->{lastLockMap} = $config{'lockMap'} || '';

	1;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;

	if ($callback_type eq 'hook') {
		
		if ($callback_name eq 'configModify' && $args->{key} eq 'lockMap') {
			$self->{lastLockMap} = $args->{val} || '';
			
		} elsif ($callback_name eq 'pos_load_config.txt' || $callback_name eq 'in_game') {
			$self->{lastLockMap} = $config{'lockMap'} || '';
			
		} elsif ($callback_name eq 'packet_mapChange') {
			$self->{lastMap} = $field ? $field->baseName : '';
		}
	
	} elsif ($callback_type eq 'recheck') {
		$self->{lastLockMap} = $config{'lockMap'} || '';
		$self->{lastMap} = $field ? $field->baseName : '';
	}
	
	if ( $self->{lastLockMap} eq '' || $self->{lastMap} eq '' ) {
		$self->SUPER::validate_condition( 0 );
	} else {
		$self->SUPER::validate_condition( ( $self->{lastMap} eq $self->{lastLockMap} ? 1 : 0 ) == $self->{wanted_return_InLockMap} );
	}
}

1;

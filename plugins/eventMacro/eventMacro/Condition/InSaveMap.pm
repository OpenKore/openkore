package eventMacro::Condition::InSaveMap;

use strict;

use base 'eventMacro::Condition';

#InSaveMap 1 -> Only triggers in the saveMap
#InSaveMap 0 -> Only triggers outside of the saveMap

use Globals qw( $field %config );

sub _hooks {
	['Network::Receive::map_changed','in_game','packet_mapChange','configModify','pos_load_config.txt'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;

	if ( $condition_code !~ /^(0|1)$/ ) {
		$self->{error} = "Value '$condition_code' should be '0' or '1'";
		return 0;
	}

	$self->{wanted_return_InSaveMap} = $condition_code;
	
	$self->{lastMap} = $field ? $field->baseName : '';
	$self->{lastSaveMap} = $config{'saveMap'} || '';

	1;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook' && $callback_name eq 'configModify' && $args->{key} eq 'saveMap') {
		$self->{lastSaveMap} = $args->{val} || '';
	} else {
		$self->{lastSaveMap} = $config{'saveMap'} || '';
	}

	$self->{lastMap} = $field ? $field->baseName : '';

	if ( $self->{lastSaveMap} eq '' || $self->{lastMap} eq '' ) {
		$self->SUPER::validate_condition( 0 );
	} else {
		$self->SUPER::validate_condition( ( $self->{lastMap} eq $self->{lastSaveMap} ? 1 : 0 ) == $self->{wanted_return_InSaveMap} );
	}
}

1;
package eventMacro::Condition::InChatRoom;

use strict;

use base 'eventMacro::Condition';

use Globals qw( $currentChatRoom );

sub _hooks {
	['packet_mapChange','chat_created','chat_leave','chat_joined'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	if ($condition_code !~ /^[01]$/) {
		$self->{error} = "Value '$condition_code' should be '0' or '1'";
		return 0;
	}

	$self->{wanted_state} = $condition_code;

	return 1;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	return $self->SUPER::validate_condition( (($currentChatRoom eq "" ? 0 : 1) == $self->{wanted_state}) ? 1 : 0 );
}

1;

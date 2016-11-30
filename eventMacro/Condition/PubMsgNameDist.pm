package eventMacro::Condition::PubMsgNameDist;

use strict;
use Globals;
use Utils;

use eventMacro::Data;

use base 'eventMacro::Conditiontypes::MultipleValidatorEvent';

sub _hooks {
	['packet_pubMsg'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{validators_index} = {
		0 => 'eventMacro::Validator::RegexCheck',
		1 => 'eventMacro::Validator::RegexCheck',
		2 => 'eventMacro::Validator::NumericComparison'
	};
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		$self->{message} = $args->{Msg};
		$self->{source} = $args->{MsgUser};
		
		foreach my $player (@{$playersList->getItems()}) {
			next unless ($player->{name} eq $self->{source});
			$self->{actor} = $player;
			$self->{dist} = distance($char->{pos_to}, $player->{pos_to});
		}
		$self->SUPER::validate_condition( [$self->{message}, $self->{source}, $self->{dist}] );
		
	} elsif ($callback_type eq 'variable') {
		$self->SUPER::update_validator_var($callback_name, $args);
		return 0;
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".PubMsgNameDistLastName"} = $self->{source};
	$new_variables->{".PubMsgNameDistLastMsg"} = $self->{message};
	$new_variables->{".PubMsgNameDistLastPos"} = sprintf("%d %d %s", $self->{actor}->{pos_to}{x}, $self->{actor}->{pos_to}{y}, $field->baseName);
	$new_variables->{".PubMsgNameDistLastDist"} = $self->{dist};
	$new_variables->{".PubMsgNameDistLastID"} = $self->{actor}->{binID};
	$new_variables->{".PubMsgNameDistLastBinID"} = $self->{actor}->{binType};
	
	return $new_variables;
}

sub condition_type {
	EVENT_TYPE;
}

1;
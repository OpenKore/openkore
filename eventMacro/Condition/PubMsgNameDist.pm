package eventMacro::Condition::PubMsgNameDist;

use strict;
use Globals;
use Utils;

use eventMacro::Data;

use base 'eventMacro::Conditiontypes::MultipleValidatorEvent';

sub _hooks {
	['attack_start'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	my $condition_code_1;
	my $condition_code_2;
	my $condition_code_3;
	
	if ($condition_code =~ /^(\/.*?\/\w?\)s+(\/.*?\/\w?\)s+((?:<|<=|=|==|!=|!|>=|>|)\s*(?:$number_qr%?|\$(?:$variable_qr))(?:\s*\.\.\s*(?:$number_qr%?|\$(?:$variable_qr)))?)\s*$/o) {
		$condition_code_1 = $1;
		$condition_code_2 = $2;
		$condition_code_3 = $3;
	} else {
		$self->{error} = "The list member '".$member."' is not a valid stat";
			return 0;
	}
	
	$self->{validators} = {
		eventMacro::Validator::RegexCheck => 1,
		eventMacro::Validator::RegexCheck => 2,
		eventMacro::Validator::NumericComparison => 3
	};
	
	$self->SUPER::_parse_syntax(1, $condition_code_1);
	$self->SUPER::_parse_syntax(2, $condition_code_2);
	$self->SUPER::_parse_syntax(3, $condition_code_3);
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		$self->{message} = $args->{Msg};
		$self->{source} = $args->{MsgUser};
		$self->SUPER::validate_condition(1,$self->{message});
		$self->SUPER::validate_condition(2,$self->{source});
		
		
	} elsif ($callback_type eq 'variable') {
		$self->SUPER::update_validator_var($callback_name, $args);
		return 0;
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	my $actor = $monsters{$self->{id}};
	
	$new_variables->{".AttackStartRegexLastName"} = $actor->{name};
	$new_variables->{".AttackStartRegexLastPos"} = sprintf("%d %d %s", $actor->{pos_to}{x}, $actor->{pos_to}{y}, $field->baseName);
	$new_variables->{".AttackStartRegexLastDist"} = sprintf("%.1f",distance(calcPosition($actor), calcPosition($char)));
	$new_variables->{".AttackStartRegexLastID"} = $actor->{binID};
	$new_variables->{".AttackStartRegexLastBinID"} = $actor->{binType};
	
	return $new_variables;
}

sub condition_type {
	EVENT_TYPE;
}

1;
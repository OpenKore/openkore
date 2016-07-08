package eventMacro::Condition::Base_level;

use strict;
use Settings;
use Globals;

use Log qw(message error warning);

use eventMacro::Data;
use  eventMacro::Utilities qw(between cmpr match getArgs refreshGlobal
	getPlayerID getSoldOut getInventoryAmount getCartAmount getShopAmount
	getStorageAmount callMacro sameParty);

sub new {
	my ($class, $condition_code) = @_;
	my $self = bless {}, $class;
	
	$self->{name} = 'base_level';
	$self->{variables} = [];
	$self->{code_level} = undef;
	$self->{code_condition} = undef;
	return undef unless ($self->parse_sintax($condition_code));
	
	$self->{isUniqueCondition} = 0;
	$self->{isFulfilled} = 0;
	$self->{hooks} = ['packet/sendMapLoaded', 'packet/stat_info'];

	return $self;
}

sub validate_condition_status {
	my ($self, $event_name, $args) = @_;
	
	return unless (defined $eventMacro);
	return if ($event_name eq 'packet/stat_info' && $args && $args->{type} != 11);
	message "[eventMacro] Base Validate event: '".$event_name."'\n","system";
	
	if ($event_name eq 'variable_event') {
		message "[eventMacro] Variable type event\n","system";
		$self->{isFulfilled} = cmpr($char->{lv}, $self->{code_condition}, $args->{'variable_value'});
		message "[eventMacro] Checking if '".$char->{lv}."' is '".$self->{code_condition}."' than '".$args->{'variable_value'}."'. Answer: '".$self->{isFulfilled}."'\n","system";
	} else {
		message "[eventMacro] Hook type event\n","system";
		if (@{$self->{variables}} > 0) {
			message "[eventMacro] Has variables\n","system";
			my $variable_value = $eventMacro->get_var($self->{code_level});
			if (defined $variable_value) {
				message "[eventMacro] Variable is defined and is '".$variable_value."'\n","system";
				$self->{isFulfilled} = cmpr($char->{lv}, $self->{code_condition}, $variable_value);
				message "[eventMacro] Checking if '".$char->{lv}."' is '".$self->{code_condition}."' than '".$variable_value."'. Answer: '".$self->{isFulfilled}."'\n","system";
			} else {
				message "[eventMacro] Variable is not defined. Answer: '0'\n","system";
				$self->{isFulfilled} = 0;
			}
		} else {
			message "[eventMacro] Does not have variables\n","system";
			$self->{isFulfilled} = cmpr($char->{lv}, $self->{code_condition}, $self->{code_level});
			message "[eventMacro] Checking if '".$char->{lv}."' is '".$self->{code_condition}."' than '".$self->{code_level}."'. Answer: '".$self->{isFulfilled}."'\n","system";
		}
	}
}

sub parse_sintax {
	my ($self, $condition_code) = @_;
	if ($condition_code =~ /([<>=!]+)\s+(\$[a-zA-Z][a-zA-Z\d]*|\d+|\d+\s*\.{2}\s*\d+)\s*$/) {
		$self->{code_condition} = $1;
		my $code_level = $2;
		if ($code_level =~ /^\s*\$/) {
			my ($var) = $code_level =~ /^\$([a-zA-Z][a-zA-Z\d]*)\s*$/;
			return 0 unless defined $var;
			$self->{code_level} = $var;
			push (@{$self->{variables}}, $var);
		} else {
			$self->{code_level} = $code_level;
		}
		return 1;
	}
	return 0;
}

sub is_unique_condition {
	my ($self) = @_;
	return $self->{isUniqueCondition};
}

sub is_fulfilled {
	my ($self) = @_;
	return $self->{isFulfilled};
}

1;
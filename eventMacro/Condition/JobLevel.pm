package eventMacro::Condition::JobLevel;

use strict;
use Settings;
use Globals;

use Log qw(message error warning debug);

use eventMacro::Data;
use eventMacro::Utilities qw(between cmpr match getArgs refreshGlobal
	getPlayerID getSoldOut getInventoryAmount getCartAmount getShopAmount
	getStorageAmount call_macro sameParty);

sub new {
	my ($class, $condition_code) = @_;
	my $self = bless {}, $class;
	
	$self->{Name} = 'JobLevel';
	$self->{Variables} = [];
	$self->{Code_Level} = undef;
	$self->{Code_Condition} = undef;
	return undef unless ($self->parse_syntax($condition_code));
	
	$self->{is_Unique_Condition} = 0;
	$self->{is_Fulfilled} = 0;
	$self->{Hooks} = ['packet/sendMapLoaded', 'packet/stat_info'];

	return $self;
}

sub get_hooks {
	my ($self) = @_;
	return $self->{Hooks};
}

sub get_variables {
	my ($self) = @_;
	return $self->{Variables};
}

sub get_name {
	my ($self) = @_;
	return $self->{Name};
}

sub validate_condition_status {
	my ($self, $event_name, $args) = @_;
	return unless (defined $eventMacro);
	return if ($event_name eq 'packet/stat_info' && $args && $args->{type} != 55);
	
	if ($event_name eq 'variable_event') {
		$self->{is_Fulfilled} = cmpr($char->{lv_job}, $self->{Code_Condition}, $args->{'variable_value'});
	} else {
		if (@{$self->{Variables}} > 0) {
			my $variable_value = $eventMacro->get_var($self->{Code_Level});
			if (defined $variable_value) {
				$self->{is_Fulfilled} = cmpr($char->{lv_job}, $self->{Code_Condition}, $variable_value);
			} else {
				$self->{is_Fulfilled} = 0;
			}
		} else {
			$self->{is_Fulfilled} = cmpr($char->{lv_job}, $self->{Code_Condition}, $self->{Code_Level});
		}
	}
}

sub parse_syntax {
	my ($self, $condition_code) = @_;
	if ($condition_code =~ /([<>=!]+)\s+(\$[a-zA-Z][a-zA-Z\d]*|\d+|\d+\s*\.{2}\s*\d+)\s*$/) {
		$self->{Code_Condition} = $1;
		my $code_level = $2;
		if ($code_level =~ /^\s*\$/) {
			my ($var) = $code_level =~ /^\$([a-zA-Z][a-zA-Z\d]*)\s*$/;
			unless (defined $var) {
				error "[eventMacro] Bad syntax in condition '".$self->get_name()."': '".$condition_code."'\n";
				return 0
			}
			$self->{Code_Level} = $var;
			push (@{$self->{Variables}}, $var);
		} else {
			$self->{Code_Level} = $code_level;
		}
		return 1;
	}
	error "[eventMacro] Bad syntax in condition '".$self->get_name()."': '".$condition_code."'\n";
	return 0;
}

sub is_unique_condition {
	my ($self) = @_;
	return $self->{is_Unique_Condition};
}

sub is_fulfilled {
	my ($self) = @_;
	return $self->{is_Fulfilled};
}

1;
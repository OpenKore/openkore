package eventMacro::Condition::StatAdded;

use strict;
use Globals;

use eventMacro::Data;

use base 'eventMacro::Conditiontypes::ListCondition';

my %stat_type = (
	13 => 'str',
	14 => 'agi',
	15 => 'vit',
	16 => 'int',
	17 => 'dex',
	18 => 'luk'
);

my %possible_values = (
	'str' => 1,
	'agi' => 1,
	'vit' => 1,
	'int' => 1,
	'dex' => 1,
	'luk' => 1
);

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	foreach my $member (split(/\s*,\s*/, $condition_code)) {
		return 0 unless (exists($possible_values{$member}));
	}
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub _hooks {
	['packet_charStats'];
}

sub validate_condition {
	my ( $self, $event_name, $args ) = @_;
	
	$self->{stat} = $stat_type{$args->{type}};
	
	$self->SUPER::validate_condition($self->{stat});
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".StatAddedLast"} = $self->{stat};
	$new_variables->{".StatAddedLastQuantity"} = $char->{$self->{stat}};
	
	return $new_variables;
}

sub condition_type {
	EVENT_TYPE;
}

1;

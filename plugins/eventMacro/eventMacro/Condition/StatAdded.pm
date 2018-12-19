package eventMacro::Condition::StatAdded;

use strict;
use Globals qw( $char );

use base 'eventMacro::Conditiontypes::ListConditionEvent';

my %stat_type = (
	13 => 'str',
	14 => 'agi',
	15 => 'vit',
	16 => 'int',
	17 => 'dex',
	18 => 'luk'
);

my %possible_values = (
	'str' => undef,
	'agi' => undef,
	'vit' => undef,
	'int' => undef,
	'dex' => undef,
	'luk' => undef,
);

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	foreach my $member (split(/\s*,\s*/, $condition_code)) {
		unless (exists($possible_values{$member})) {
			$self->{error} = "The list member '".$member."' is not a valid stat";
			return 0;
		}
	}
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub _hooks {
	['packet_charStats'];
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		$self->{stat} = $stat_type{$args->{type}};
		return $self->SUPER::validate_condition( $self->validator_check($self->{stat}) );
	} elsif ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $self->{stat};
	$new_variables->{".".$self->{name}."Last"."Quantity"} = $char->{$self->{stat}};
	
	return $new_variables;
}

1;

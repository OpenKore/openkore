package eventMacro::Condition::StatAdded;

use strict;

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

use Log qw(message error warning debug);

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

sub validate_condition_status {
	my ( $self, $event_name, $args ) = @_;
	
	$self->SUPER::validate_condition_status($stat_type{$args->{type}});
}

sub is_event_only {
	1;
}

#should never be called
sub is_fulfilled {
	0;
}

1;

package eventMacro::Condition::StatAdded;

use strict;

use base 'eventMacro::Condition';

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{type} = $condition_code =~ /^\s*(str|strength|agi|agility|vit|vitality|int|intelligence|dex|dexterity|luk|luck)\s*$/io;
	return 0 unless $self->{type};
	$self->{type} = $1;

	if ($self->{type} eq 'str' || $self->{type} eq 'strength') {
		$self->{type} = 13;
	} elsif ($self->{type} eq 'agi' || $self->{type} eq 'agility') {
		$self->{type} = 14;
	} elsif ($self->{type} eq 'vit' || $self->{type} eq 'vitality') {
		$self->{type} = 15;
	} elsif ($self->{type} eq 'int' || $self->{type} eq 'intelligence') {
		$self->{type} = 16;
	} elsif ($self->{type} eq 'dex' || $self->{type} eq 'dexterity') {
		$self->{type} = 17;
	} elsif ($self->{type} eq 'luk' || $self->{type} eq 'luck') {
		$self->{type} = 18;
	}
	return 0 unless $self->{type};
	return 1;
}

sub _hooks {
	['packet_charStats'];
}

sub validate_condition_status {
	my ( $self, $event_name, $args ) = @_;
	return 0 if (!$args || $args->{type} != $self->{type});
	return 1;
}

sub is_event_only {
	1;
}

#should never be called
sub is_fulfilled {
	0;
}

1;

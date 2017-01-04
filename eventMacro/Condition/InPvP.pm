package eventMacro::Condition::InPvP;

use strict;

use base 'eventMacro::Conditiontypes::ListConditionState';

my %pvp_type = (
	1 => 'pvp',
	2 => 'gvg',
	3 => 'battleground'
);

my %possible_values = (
	'pvp' => undef,
	'gvg' => undef,
	'battleground' => undef
);

sub _hooks {
	['packet_mapChange','pvp_mode'];
}

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

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
	
		if ($callback_name eq 'pvp_mode') {
			$self->{pvp_type} = $pvp_type{$args->{pvp}};
			return $self->SUPER::validate_condition( $self->validator_check($self->{pvp_type}) );
			
		} elsif ($callback_name eq 'packet_mapChange') {
			return $self->SUPER::validate_condition( 0 );
			
		}
		
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $self->{pvp_type};
	
	return $new_variables;
}

1;

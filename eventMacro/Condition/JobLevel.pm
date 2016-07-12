package eventMacro::Condition::JobLevel;

use strict;

use base 'eventMacro::Condition';

use Globals qw( $char );

sub _hooks {
	[qw( packet/sendMapLoaded packet/stat_info )];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	my $v = $self->{validator} = eventMacro::Validator::NumericComparison->new( $condition_code );
	push @{ $self->{Variables} }, $v->variables;
	$v->parsed;
}

sub validate_condition_status {
	my ( $self, $event_name, $args ) = @_;

	return if $event_name eq 'packet/stat_info' && $args && $args->{type} != 55;

	$self->{is_Fulfilled} = $self->{validator}->validate( $char->{lv_job} );
}

1;

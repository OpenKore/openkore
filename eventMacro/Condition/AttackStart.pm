package eventMacro::Condition::AttackStart;

use strict;
use Globals;

use base 'eventMacro::ListCondition';

sub _hooks {
	['attack_start'];
}

sub validate_condition_status {
	my ( $self, $event_name, $args ) = @_;
	
	$self->SUPER::validate_condition_status(lc($monsters{$args->{ID}}{'name'}));
}

sub is_event_only {
	1;
}

#should never be called
sub is_fulfilled {
	0;
}

1;
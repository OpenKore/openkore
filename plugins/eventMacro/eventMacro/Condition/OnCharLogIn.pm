package eventMacro::Condition::OnCharLogIn;

use strict;

use base 'eventMacro::Conditiontypes::SimpleEvent';

sub _hooks {
	['in_game'];
}

1;

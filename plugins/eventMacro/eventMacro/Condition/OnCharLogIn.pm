package eventMacro::Condition::OnCharLogIn;

use strict;

use base 'eventMacro::Conditiontypes::SimpleEvent';

use eventMacro::Data;

sub _hooks {
	['in_game'];
}

1;

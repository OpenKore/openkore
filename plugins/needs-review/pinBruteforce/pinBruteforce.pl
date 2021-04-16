# pinBruteforce by ya4epT
#
# If you have forgotten your account PIN, this plugin will help you recover it.
# Set this line in control/config.txt as:
# loginPinCode 0000

package pinBruteforce;

use strict;
use Globals qw($messageSender %config);
use Misc qw(configModify);
use Log qw(error message warning);

Plugins::register("pinBruteforce","crack pin code using bruteforce",\&onUnload,\&onUnload);

my $hooks = Plugins::addHooks(["packet_pre/login_pin_code_request",\&check]);

sub onUnload {
	Plugins::delHooks($hooks);
}

sub check {
	my ($self, $args) = @_;
	my $pin = $config{loginPinCode};
	if ( $pin eq '' || $pin !~ /^\d{4}$/ ) {
		error "[pinBruteforce] Invalid PIN: $pin. Please change the value 'loginPinCode' in config.txt\n";
		return;
	}
	message "[pinBruteforce] flag = $args->{flag}, loginPinCode = $pin\n";
	# 0 - correct - RMS
	# 1 - PIN code query request.
	# 4 - PIN code has never been set before, so set it.
	# 7 - correct - RMS
	# 8 - incorrect - RMS
	if ($args->{flag} == 0 || $args->{flag} == 7) {
		$pin--;
		$pin = sprintf("%04d", $pin);
		configModify('loginPinCode', $pin, silent => 1);
		warning ("[pinBruteforce] PIN code is correct: $pin\n"), "success";
	} elsif ($args->{flag} != 1 && $args->{flag} != 4) {
#		sleep (5);
		$messageSender->sendLoginPinCode($args->{seed}, 0);
		$pin++;
		configModify('loginPinCode', $pin, silent => 1);
		$args->{flag} = 10;
	}
}

1;
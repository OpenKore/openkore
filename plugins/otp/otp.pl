#############################################################################
#
# OTP Generator plugin by wizzello, alisonrag and pogramos
#
# Openkore: http://openkore.com/
# Repository: https://github.com/wizzello/openkore-otp
#
# This source code is licensed under the MIT License.
# See https://mit-license.org/
#
#############################################################################

package OpenKore::Plugin::OTP;

use strict;
use Plugins;
use lib $Plugins::current_plugin_folder;
use TOTP;

Plugins::register(
    'otp',
    'Handles OTP requests by generating TOTP',
    \&unload
);

# Add hook to listen for the custom OTP request event
# This event must be triggered by OpenKore PR #4036
my $hooks = Plugins::addHooks(
    ['request_otp_login', \&generate]
);

sub generate {
    my ($plugin, $args) = @_;
    my $otp = $args->{otp};
    my $seed = $args->{seed};
    my $totp = TOTP->new(
        digits   => 6,
        timestep => 30,
    );

    $$otp = $totp->totp($seed);
}



sub unload {
    Plugins::delHooks($hooks);
}

1;
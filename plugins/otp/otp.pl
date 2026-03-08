#############################################################################
#
# OTP Generator plugin by baphomello, alisonrag and pogramos
#
#############################################################################

package OTP;

use strict;
use Plugins;
use lib $Plugins::current_plugin_folder;
use OTP::TOTP;

Plugins::register(
    'OTP',
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
    my $totp = OTP::TOTP->new(
        digits   => 6,
        timestep => 30,
    );

    $$otp = $totp->totp($seed);
}



sub unload {
    Plugins::delHooks($hooks);
}

1;
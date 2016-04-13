# ============================
# cmdOnLogin v.1.0.0
# ============================
# Licensed by hakore (hakore@users.sourceforge.net) under GPL
#
package cmdOnLogin;

use strict;
use Globals;
my $done;
Plugins::register('cmdOnLogin', 'automatically do a command on login', \&onUnload);
my $hooks = Plugins::addHooks(
				['Network::serverConnect/char', \&onConnect],
				['AI_pre', \&onAI]
);
sub onAI {
	if (!$done && $config{cmdOnLogin}) {
		Commands::run($config{cmdOnLogin});
		$done = 1;
	}
}
sub onConnect {
	undef $done;
}
sub onUnload {
	Plugins::delHooks($hooks);
}
return 1;
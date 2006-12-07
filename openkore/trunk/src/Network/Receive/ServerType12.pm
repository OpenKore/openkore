# pRO Thor as of October 22 2006
package Network::Receive::ServerType12;

use strict;
use base qw(Network::Receive);

use Globals;
use Actor;
use Actor::You;
use Time::HiRes qw(time usleep);
use Settings;
use Log qw(message warning error debug);
use FileParsers;
use Interface;
use Network::Send;
use Misc;
use Plugins;
use Utils;
use Skills;


sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	return $self;
}

1;

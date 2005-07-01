package Network::Receive::ServerType2;

use strict;
use base qw(Network::Receive);

use Globals;
use Log qw(message warning error debug);


sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	return $self;
}

1;

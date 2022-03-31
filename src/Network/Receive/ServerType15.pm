# pRO Thor
# Servertype overview: https://openkore.com/wiki/ServerType
package Network::Receive::ServerType15;

use strict;
use Network::Receive::ServerType0 ();
use base qw(Network::Receive::ServerType0);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	return $self;
}

1;

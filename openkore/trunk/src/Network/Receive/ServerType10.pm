# vRO (Vietnam)
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Receive::ServerType10;

use strict;
use base qw(Network::Receive::ServerType0);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	return $self;
}

1;

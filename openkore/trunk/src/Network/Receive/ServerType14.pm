# pRO Thor as of December 1 2006
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Receive::ServerType14;

use strict;
use base qw(Network::Receive::ServerType0);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	return $self;
}

1;

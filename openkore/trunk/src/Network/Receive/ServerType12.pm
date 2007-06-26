# pRO Thor as of October 22 2006
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Receive::ServerType12;

use strict;
use base qw(Network::Receive);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	return $self;
}

1;

# euRO (Europe) as of September 16 2006
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Receive::ServerType11;

use strict;
use base qw(Network::Receive);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	return $self;
}

1;

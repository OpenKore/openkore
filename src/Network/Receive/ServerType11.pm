# euRO (Europe) as of September 16 2006
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Receive::ServerType11;

use strict;
use base qw(Network::Receive::ServerType0);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	return $self;
}

1;

# Korea (kRO)
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Receive::ServerType8;

use strict;
use Network::Receive::ServerType0 ();
use base qw(Network::Receive::ServerType0);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	return $self;
}

# Overrided method.
sub received_characters_blockSize {
	return 108;
}

1;

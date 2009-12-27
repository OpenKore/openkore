# LegacyRO after February 2008
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Receive::ServerType8_3;

use strict;
use Network::Receive::ServerType0 ();
use base qw(Network::Receive::ServerType0);
use Globals qw($masterServer);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	return $self;
}

# Overrided method.
sub received_characters_blockSize {
	if ($masterServer && $masterServer->{charBlockSize}) {
		return $masterServer->{charBlockSize};
	} else {
		return 108;
	}
}

1;

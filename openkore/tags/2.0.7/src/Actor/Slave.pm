package Actor::Slave;

use strict;
use Actor;
use Globals;
use base qw/Actor/;

sub new {
	my ($class, $type) = @_;
	
	my $actorType =
		($type >= 6001 && $type <= 6016) ? 'Homunculus' :
		($type >= 6017 && $type <= 6046) ? 'Mercenary' :
	'Unknown';
	
	return $class->SUPER::new ($actorType);
}

1;
#########################################################################
#  OpenKore - Slave actor object
#  Copyright (c) 2005 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#########################################################################
##
# MODULE DESCRIPTION: Slave actor object
#
# @MODULE(Actor) is the base class for this class.
package Actor::Slave;

use strict;
use Actor;
use Globals;
use base qw/Actor/;

sub new {
	my ($class, $type) = @_;
	
	my $actorType =
		(($type >= 6001 && $type <= 6016) || ($type >= 6048 && $type <= 6052)) ? 'Homunculus' :
		($type >= 6017 && $type <= 6046) ? 'Mercenary' :
	'Unknown';
	
	return $class->SUPER::new ($actorType);
}

##
# float $slave->hp_percent()
#
# Returns slave HP percentage (between 0 and 100).
sub hp_percent {
	my ($self) = @_;

	return main::percent_hp($self);
}

##
# float $slave->sp_percent()
#
# Returns slave SP percentage (between 0 and 100).
sub sp_percent {
	my ($self) = @_;

	return main::percent_sp($self);
}

##
# float $slave->exp_percent()
#
# Returns slave exp percentage (between 0 and 100).
sub exp_percent {
	my ($self) = @_;
	
	if ($self->{exp_max}) {
		return ($self->{exp} / $self->{exp_max} * 100);
	}
		
	return 0;
}

1;
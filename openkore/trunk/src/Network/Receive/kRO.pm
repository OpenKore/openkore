#########################################################################
#  OpenKore - Packet sending
#  This module contains functions for sending packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 6687 $
#  $Id: kRO.pm 6687 2009-04-19 19:04:25Z technologyguild $
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO
package Network::Receive::kRO;

use strict;
use encoding 'utf8';
use Carp::Assert;

use Network::Receive ();
use base qw(Network::Receive);

use Exception::Class ('Network::Receive::kRO::InvalidServerType', 'Network::Receive::kRO::CreationError');

use Misc;
use Log qw(debug);

use Translation;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	return $self;
}

##
# Network::Receive->create(String serverType)
#
# Create a new server message parsing object for the specified server type.
#
# Throws Network::Receive::InvalidServerType if the specified server type does
# not exist.
# Throws Network::Receive::CreationError if some other error occured.
sub create {
	my ($self, $type) = @_;

	my $class = "Network::Receive::kRO::" . $type;

	undef $@;
	eval ("use $class;");
	if ($@ =~ /^Can't locate /s) {
		Network::Receive::kRO::InvalidServerType->throw(
			TF("Cannot load server message parser for server type '%s'.", $type)
		);
	} elsif ($@) {
		Network::Receive::kRO::CreationError->throw(
			TF("An error occured while loading the server message parser for server type '%s':\n%s",
				$type, $@)
		);
	} else {
		return $class->new();
	}
}

1;
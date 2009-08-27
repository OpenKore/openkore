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
package Network::Send::kRO;

use strict;
use encoding 'utf8';
use Carp::Assert;

use Network::Send ();
use base qw(Network::Send);

use Exception::Class ('Network::Send::kRO::ServerTypeNotSupported', 'Network::Send::kRO::CreationException');

use Misc;
use Log qw(debug);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

##
# Network::Send->create(net, serverType)
# net: An object compatible with the '@MODULE(Network)' class.
# serverType: A server type.
#
# Create a new message sender object for the specified server type.
#
# Throws Network::Send::ServerTypeNotSupported if the specified server type
# is not supported.
# Throws Network::Send::CreationException if the server type is supported, but the
# message sender object cannot be created.
sub create {
	my (undef, $serverType) = @_;

	my $class = "Network::Send::kRO::" . $serverType;

	eval("use $class;");
	if ($@ =~ /Can\'t locate/) {
		Network::Send::kRO::ServerTypeNotSupported->throw(error => "Server type '$serverType' not supported.");
	} elsif ($@) {
		die $@;
	}

	my $instance = eval("new $class;");
	if (!$instance) {
		Network::Send::kRO::CreationException->throw(
			error => "Cannot create message sender object for server type '$serverType'.");
	}

	# $instance->{net} = $net;
	# $instance->{serverType} = $serverType;
	# Modules::register($class);

	return $instance;
}

1;
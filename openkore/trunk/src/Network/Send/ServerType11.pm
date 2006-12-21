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
#########################################################################
package Network::Send::ServerType11;

use strict;
use Network::Send::ServerType0;
use base qw(Network::Send::ServerType0);
use AI ();
use Log qw(error);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

sub sendAttack {
	my ($self, $monID, $flag) = @_;

	my %args;
	$args{monID} = $monID;
	$args{flag} = $flag;
	Plugins::callHook('packet_pre/sendAttack', \%args);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}

	error "Your server is not supported because it uses padded packets.\n";
	if (AI::action() eq "NPC") {
		error "Failed to talk to monster NPC.\n";
		AI::dequeue();
	} elsif (AI::action() eq "attack") {
		error "Failed to attack target.\n";
		AI::dequeue();
	}
}

1;

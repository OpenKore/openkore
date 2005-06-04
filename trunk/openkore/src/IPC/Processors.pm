#########################################################################
#  OpenKore - Inter-Process communication framework
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################
##
# MODULE DESCRIPTION: Process messages from the IPC network.

package IPC::Processors;

use strict;
use Globals qw($conState %field $char $charServer %maps_lut);
use IPC;
use Log qw(message debug);
use Utils qw(calcPosition);
use Plugins;


our %handlers;
undef %handlers;


# use SelfLoader; 1;
# __DATA__


sub initHandlers {
	%handlers = (
		'where are you' => \&ipcWhereAreYou,
		'move to',	=> \&ipcMoveTo,
	);
}


sub process {
	my ($ipc, $msg) = @_;

	my %args = (
	    ipc => $ipc,
	    ID => $msg->{ID},
	    args => $msg->{args}
	);
	Plugins::callHook("IPC::Processors::process", \%args);
	if ($args{return}) {
		debug "IPC message '$msg->{ID}' from client $msg->{args}{FROM} handled by plugin\n", "ipc";
		return;
	}

	initHandlers() if (!%handlers);

	if (defined $handlers{$msg->{ID}}) {
		debug "Received message '$msg->{ID}' from client $msg->{args}{FROM}\n", "ipc";
		$handlers{$msg->{ID}}->($ipc, $msg->{ID}, $msg->{args}, $msg->{args}{FROM});
	} else {
		debug "Unhandled IPC message '$msg->{ID}' from client $msg->{args}{FROM}\n", "ipc";
	}
}

# Send a message to the IPC network. This function automatically
# sets the TO field for you if it's given.
sub sendMsg {
	my $ipc = shift;
	my $ID = shift;
	my $to = shift;
	my %hash = @_;

	$hash{TO} = $to if (defined $to);
	$ipc->send($ID, \%hash);
}


##################


sub ipcMoveTo {
	my ($ipc, $ID, $args) = @_;

	if ($conState == 5) {
		my $map = $args->{field};
		message "On route to: " . $maps_lut{"${map}.rsw"} . "($map): $args->{x}, $args->{y}\n";
		main::ai_route($args->{field}, $args->{x}, $args->{y},
			attackOnRoute => 1);
	}
}

sub ipcWhereAreYou {
	my ($ipc, $ID, $args) = @_;

	if ($conState == 5) {
		my $pos = calcPosition($char);
		sendMsg($ipc, "i am here", $args->{REPLY_TO},
			charServer => $charServer,
			name	=> $char->{name},
			field	=> $field{name},
			x	=> $pos->{x},
			y	=> $pos->{y}
		);
	} else {
		sendMsg($ipc, "i am here", $args->{REPLY_TO});
	}
}

1;

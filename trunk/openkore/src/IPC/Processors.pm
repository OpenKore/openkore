package IPC::Processors;

use strict;
use Globals qw($conState %field $char $charServer);
use IPC;
use Log qw(message debug);
use Utils qw(calcPosition);

my %handlers = (
	'where are you' => \&ipcWhereAreYou
);

sub process {
	my $ipc = shift;
	my $msg = shift;

	if (defined $handlers{$msg->{ID}}) {
		$handlers{$msg->{ID}}->($ipc, $msg->{ID}, $msg->{params});
	} else {
		debug "Unhandled IPC message '$msg->{ID}' from client $msg->{clientID}\n", "ipc";
	}
}

sub ipcWhereAreYou {
	my ($ipc, $ID, $params) = @_;
	return unless $conState == 5;

	my $pos = calcPosition($char);
	$ipc->broadcast("i am here", {
		clientID => $ipc->ID,
		charServer => $charServer,
		name	=> $char->{name},
		field	=> $field{name},
		x	=> $pos->{x},
		y	=> $pos->{y}
		});
}

1;

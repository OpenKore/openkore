package IPC::Processors;

use strict;
use Globals qw($conState %field $char $charServer %maps_lut);
use IPC;
use Log qw(message debug);
use Utils qw(calcPosition);


our %handlers = (
	'where are you' => \&ipcWhereAreYou,
	'move to',	=> \&ipcMoveTo,
);


sub process {
	my $ipc = shift;
	my $msg = shift;

	if (defined $handlers{$msg->{ID}}) {
		debug "Received message '$msg->{ID}' from client $msg->{from}\n";
		$handlers{$msg->{ID}}->($ipc, $msg->{ID}, $msg->{params}, $msg->{from});
	} else {
		debug "Unhandled IPC message '$msg->{ID}' from client $msg->{from}\n", "ipc";
	}
}

sub ipcMoveTo {
	my ($ipc, $ID, $params) = @_;

	if ($conState == 5) {
		my $map = $params->{field};
		message "On route to: $maps_lut{$map}($map): $params->{x}, $params->{y}\n";
		main::ai_route($params->{field}, $params->{x}, $params->{y},
			attackOnRoute => 1);
	}
}

sub ipcWhereAreYou {
	my ($ipc, $ID) = @_;
	return unless $conState == 5;

	my $pos = calcPosition($char);
	$ipc->send("i am here",
		charServer => $charServer,
		name	=> $char->{name},
		field	=> $field{name},
		x	=> $pos->{x},
		y	=> $pos->{y}
	);
}

1;

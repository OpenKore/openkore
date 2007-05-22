# tRO (Thai) for 2007-05-22bRagexe by kLabMouse (thanks to abt123 and penz for support)
package Network::Receive::ServerType17;

use strict;
use Network::Receive ();
use base qw(Network::Receive);
use Time::HiRes qw(time usleep);

use AI;
use Globals qw($char %timeout $net %config @chars $conState $conState_tries $messageSender);
use Log qw(message warning error debug);
use Translation;
use Network;
use Utils qw(makeCoords);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	return $self;
}

sub map_loaded {
	my ($self, $args) = @_;
	$net->setState(Network::IN_GAME);
	undef $conState_tries;
	$char = $chars[$config{char}];

	if ($net->version == 1) {
		$net->setState(4);
		message(T("Waiting for map to load...\n"), "connection");
		ai_clientSuspend(0, 10);
		main::initMapChangeVars();
	} else {
		message	T("Requesting guild information...\n"), "info";
		$messageSender->sendGuildInfoRequest($net);

		# Replies 01B6 (Guild Info) and 014C (Guild Ally/Enemy List)
		$messageSender->sendGuildRequest($net, 0);

		# Replies 0166 (Guild Member Titles List) and 0154 (Guild Members List)
		$messageSender->sendGuildRequest($net, 1);
		message(T("You are now in the game\n"), "connection");
		$messageSender->sendMapLoaded();
		$timeout{'ai'}{'time'} = time;
	}

	$char->{pos} = {};
	makeCoords($char->{pos}, $args->{coords});
	$char->{pos_to} = {%{$char->{pos}}};
	message(TF("Your Coordinates: %s, %s\n", $char->{pos}{x}, $char->{pos}{y}), undef, 1);

	$messageSender->sendIgnoreAll("all") if ($config{ignoreAll});
}

sub account_server_info {
	my ($self, $args) = @_;
	my $msg = substr($args->{serverInfo},4);
	my $msg_size = length($msg);

	$net->setState(2);
	undef $conState_tries;
	$sessionID = $args->{sessionID};
	$accountID = $args->{accountID};
	$sessionID2 = $args->{sessionID2};
	$accountSex = $args->{accountSex} % 2;
	$accountSex2 = ($config{'sex'} ne "") ? $config{'sex'} : $accountSex;

	message swrite(
		T("-----------Account Info------------\n" . 
		"Account ID: \@<<<<<<<<< \@<<<<<<<<<<\n" .
		"Sex:        \@<<<<<<<<<<<<<<<<<<<<<\n" .
		"Session ID: \@<<<<<<<<< \@<<<<<<<<<<\n" .
		"            \@<<<<<<<<< \@<<<<<<<<<<\n" .
		"-----------------------------------"), 
		[unpack("V1",$accountID), getHex($accountID), $sex_lut{$accountSex}, unpack("V1",$sessionID), getHex($sessionID),
		unpack("V1",$sessionID2), getHex($sessionID2)]), 'connection';

	my $num = 0;
	undef @servers;
	for (my $i = 0; $i < $msg_size; $i+=32) {
		$servers[$num]{ip} = makeIP(substr($msg, $i, 4));
		$servers[$num]{ip} = $masterServer->{ip} if ($masterServer && $masterServer->{private});
		$servers[$num]{port} = unpack("v1", substr($msg, $i+4, 2));
		($servers[$num]{name}) = bytesToString(unpack("Z*", substr($msg, $i + 6, 20)));
		$servers[$num]{users} = unpack("V",substr($msg, $i + 26, 4));
		$num++;
	}

	message T("--------- Servers ----------\n" .
			"#   Name                  Users  IP              Port\n"), 'connection';
	for (my $num = 0; $num < @servers; $num++) {
		message(swrite(
			"@<< @<<<<<<<<<<<<<<<<<<<< @<<<<< @<<<<<<<<<<<<<< @<<<<<",
			[$num, $servers[$num]{name}, $servers[$num]{users}, $servers[$num]{ip}, $servers[$num]{port}]
		), 'connection');
	}
	message("-------------------------------\n", 'connection');

	if ($net->version != 1) {
		message T("Closing connection to Account Server\n"), 'connection';
		$net->serverDisconnect();
		if (!$masterServer->{charServer_ip} && $config{server} eq "") {
			my @serverList;
			foreach my $server (@servers) {
				push @serverList, $server->{name};
			}
			my $ret = $interface->showMenu(
					T("Please select your login server."),
					\@serverList,
					title => T("Select Login Server"));
			if ($ret == -1) {
				quit();
			} else {
				main::configModify('server', $ret, 1);
			}

		} elsif ($masterServer->{charServer_ip}) {
			message TF("Forcing connect to char server %s: %s\n", $masterServer->{charServer_ip}, $masterServer->{charServer_port}), 'connection';	
			
		} else {
			message TF("Server %s selected\n",$config{server}), 'connection';
		}
	}
}



1;

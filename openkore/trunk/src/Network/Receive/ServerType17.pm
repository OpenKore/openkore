#########################################################################
#  OpenKore - Network subsystem
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# tRO (Thai) for 2007-05-22bRagexe by kLabMouse (thanks to abt123 and penz for support)
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Receive::ServerType17;

use strict;
use Network::Receive::ServerType0 ();
use base qw(Network::Receive::ServerType0);
use Log qw(message warning error debug);
use AI;
use Translation;
use Globals;
use I18N qw(bytesToString);
use Utils qw(getHex swrite makeIP makeCoords);
 
sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	return $self;
}

sub account_server_info {
	my ($self, $args) = @_;
	my $msg = substr($args->{serverInfo},4); # tRO uses some king of offset for the data.
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
		$servers[$num]{name} = bytesToString(unpack("Z*", substr($msg, $i + 6, 20)));
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

#########################################################################
#  OpenKore - Network subsystem
#  This module contains functions for sending messages to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# tRO (Thai) for 2007-05-22bRagexe by kLabMouse (thanks to abt123 and penz for support)
# latest updaes will go here. Please don't use this ServerType for other servers except tRO.
package Network::Send::ServerType17;

use strict;
use Globals;
use Network::Send::ServerType0;
use base qw(Network::Send::ServerType0);
use Log qw(error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

sub sendGameLogin { # 0275
	my ($self, $accountID, $sessionID, $sessionID2, $sex) = @_;
	my ($serv) = $masterServer->{ip} =~ /\d+\.\d+\.\d+\.(\d+)/;
	my $msg = pack("C2", 0x75, 0x02) . $accountID . $sessionID . $sessionID2 . pack("C*", 0, 0, $sex) . pack("x16 C1 x3", $serv);
	$self->sendToServer($msg);
	debug "Sent sendGameLogin\n", "sendPacket", 2;
}

sub sendAttack { # 0193
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

sub sendSit { # 0193
	my $self = shift;

	my %args;
	$args{flag} = 2;
	Plugins::callHook('packet_pre/sendSit', \%args);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}
	
	error "Your server is not supported because it uses padded packets.\n";
	if (AI::action() eq "sitting") {
		error "Failed to sit.\n";
		AI::dequeue();
	}
}

sub sendStand { # 0193
	my $self = shift;

	my %args;
	$args{flag} = 3;
	Plugins::callHook('packet_pre/sendStand', \%args);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}	
	
	error "Your server is not supported because it uses padded packets.\n";
	if (AI::action() eq "standing") {
		error "Failed to stand.\n";
		AI::dequeue();
	}
}

sub sendSkillUse { # 0089
	my $self = shift;
	my $ID = shift;
	my $lv = shift;
	my $targetID = shift;
	
	my %args;
	$args{ID} = $ID;
	$args{lv} = $lv;
	$args{targetID} = $targetID;
	Plugins::callHook('packet_pre/sendSkillUse', \%args);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}

	error "Your server is not supported because it uses padded packets.\n";
	if (AI::action() eq 'teleport') {
		error "Failed to use teleport skill.\n";
		AI::dequeue();
	} elsif (AI::action() ne "skill_use") {
		error "Failed to use skill.\n";
		AI::dequeue();
	}
}

sub sendChat { # 00F3
	my ($self, $message) = @_;
	$message = "|00$message" if ($config{chatLangCode} && $config{chatLangCode} ne "none");

	my ($data, $charName); # Type: Bytes
	$message = stringToBytes($message); # Type: Bytes
	$charName = stringToBytes($char->{name});
	$data = pack("C*", 0xF3, 0x00) .
		pack("v*", length($charName) + length($message) + 8) .
		$charName . " : " . $message . chr(0);
	$self->sendToServer($data);
}

sub sendDrop { # 009B
	my ($self, $index, $amount) = @_;
	my $msg = pack("C2 v1 v1", 0x9B, 0x00, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

sub sendGetPlayerInfo { # 0190
	my ($self, $ID) = @_;
	my $msg = pack("C*", 0x90, 0x01) . $ID. pack("x1") ;

	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendItemUse { # 0113
	my ($self, $ID, $targetID) = @_;
	my $msg = pack("C2", 0x13, 0x01) . $targetID. pack("v1", $ID);
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

sub sendLook { # 0072
	my ($self, $body, $head) = @_;
	my $msg = pack("C3 x1 C1", 0x72, 0x00, $head, $body);

	$self->sendToServer($msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

sub sendMapLogin { # 008C
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	my $msg = pack("C*", 0x8C, 0x00) .
			pack("x3") .
			$accountID .
			$charID .
			pack("x1") .
			$sessionID .
			pack("x4") .
			pack("V", getTickCount()) .
			pack("C*", $sex) .
			pack ("x2");
	$self->sendToServer($msg);
}

sub sendMove { # 00F7
	my $self = shift;
	my $x = int scalar shift;
	my $y = int scalar shift;
	my $msg = pack("C2 x11", 0xF7, 0x00) . getCoordString($x, $y, 1);
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

sub sendSkillUseLoc { # 009F
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg = pack("v1 v1 x3 v1 v1 v1", 0x9F, $y, $lv, $ID, $x);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendStorageAdd { # 00A7
	my $self= shift;
	my $index = shift;
	my $amount = shift;
	my $msg = pack("C2 V1 x1 v1", 0xA7, 0x00, $amount, $index);
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

sub sendStorageGet { # 0094
	my ($self, $index, $amount) = @_;
	my $msg = pack("C2 v1 V1 x6", 0x94, 0x00, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

sub sendStorageClose { # 0085
	my ($self) = @_;
	my $msg = pack("C*", 0x85, 0x00);
	$self->sendToServer($msg);
	debug "Sent Storage Done\n", "sendPacket", 2;
}

sub sendSync { # 007E
	my ($self, $initialSync) = @_;
	my $msg;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	$syncSync = pack("V", getTickCount());
	$msg = pack("C2 x1", 0x7E, 0x00) . $syncSync . pack("x5");

	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

sub sendTake { # 0116
	my $self = shift;
	my $itemID = shift; # $itemID = long
	my $msg = pack("C2", 0x16, 0x01) . $itemID;
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

1;

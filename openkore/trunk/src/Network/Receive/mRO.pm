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
# mRO (Malaysia)
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Receive::mRO;

use strict;
use Globals;
use base qw(Network::Receive::ServerType0);
use Log qw(message warning error debug);
use Network::MessageTokenizer;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'0078' => ['actor_exists', 'C a4 v14 a4 a2 v2 C2 a3 C3 v', [qw(object_type ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords unknown1 unknown2 act lv)]], # 55 # standing
		'007C' => ['actor_connected', 'C a4 v14 C2 a3 C2', [qw(object_type ID walk_speed opt1 opt2 option hair_style weapon lowhead type shield tophead midhead hair_color clothes_color head_dir stance sex coords unknown1 unknown2)]], # 42 # spawning
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
		'022C' => ['actor_moved', 'C a4 v3 V v5 V v5 a4 a2 v V C2 a6 C2 v', [qw(object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords unknown1 unknown2 lv)]], # 65 # walking
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

sub login_pin_code_request {
	my ($self, $args) = @_;
	my $done;

	if ($args->{flag} == 0) {
		# PIN code has never been set before, so set it.
		return if ($config{loginPinCode} eq '' && !($self->queryAndSaveLoginPinCode()));
		my @key = split /[, ]+/, $masterServer->{PINEncryptKey};
		if (!@key) {
			$interface->errorDialog(T("Unable to send PIN code. You must set the 'PINEncryptKey' option in servers.txt."));
			quit();
			return;
		}
		$messageSender->sendLoginPinCode($config{loginPinCode}, $config{loginPinCode}, $args->{key}, 2, \@key);

	} elsif ($args->{flag} == 1) {
		# PIN code query request.
		return if ($config{loginPinCode} eq '' && !($self->queryAndSaveLoginPinCode()));
		my @key = split /[, ]+/, $masterServer->{PINEncryptKey};
		if (!@key) {
			$interface->errorDialog(T("Unable to send PIN code. You must set the 'PINEncryptKey' option in servers.txt."));
			quit();
			return;
		}
		$messageSender->sendLoginPinCode($config{loginPinCode}, 0, $args->{key}, 3, \@key);

	} elsif ($args->{flag} == 2) {
		message T("Login PIN code has been changed successfully.\n");

	} elsif ($args->{flag} == 3) {
		warning TF("Failed to change the login PIN code. Please try again.\n");

		configModify('loginPinCode', '', silent => 1);
		my $oldPin = queryLoginPinCode(T("Please enter your old login PIN code:"));
		if (!defined($oldPin)) {
			return;
		}

		my $newPinCode = queryLoginPinCode(T("Please enter a new login PIN code:"));
		if (!defined($newPinCode)) {
			return;
		}
		configModify('loginPinCode', $newPinCode, silent => 1);

		my @key = split /[, ]+/, $masterServer->{PINEncryptKey};
		if (!@key) {
			$interface->errorDialog(T("Unable to send PIN code. You must set the 'PINEncryptKey' option in servers.txt."));
			quit();
			return;
		}
		$messageSender->sendLoginPinCode($oldPin, $newPinCode, $args->{key},  2, \@key);

	} elsif ($args->{flag} == 4) {
		# PIN code incorrect.
		configModify('loginPinCode', '', 1);
		return if (!($self->queryAndSaveLoginPinCode(T("The login PIN code that you entered is incorrect. Please re-enter your login PIN code."))));

		my @key = split /[, ]+/, $masterServer->{PINEncryptKey};
		if (!@key) {
			$interface->errorDialog(T("Unable to send PIN code. You must set the 'PINEncryptKey' option in servers.txt."));
			quit();
			return;
		}
		$messageSender->sendLoginPinCode($config{loginPinCode}, 0, $args->{key}, 3, \@key);

	} elsif ($args->{flag} == 5) {
		# PIN Entered 3 times Wrong, Disconnect
		warning T("You have entered 3 incorrect login PIN codes in a row. Reconnecting...\n");
		configModify('loginPinCode', '', silent => 1);
		$timeout_ex{master}{time} = time;
		$timeout_ex{master}{timeout} = $timeout{reconnect}{timeout};
		$net->serverDisconnect();

	} else {
		debug("login_pin_code_request: unknown flag $args->{flag}\n");
	}
	$timeout{master}{time} = time;
}

1;
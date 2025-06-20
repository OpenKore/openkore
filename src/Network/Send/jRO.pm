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
# jRO (Japan)
# Servertype overview: https://openkore.com/wiki/ServerType
package Network::Send::jRO;

use strict;
use Network::Send::ServerType0;
use base qw(Network::Send::ServerType0);
use Globals qw(%config);
use Log qw(debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'027C' => ['master_login', 'V Z24 a40 x12 c x a12', [qw(version username_salted password_salted master_version mac)]],# 96
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_look_at 0361
		actor_info_request 0368
		char_create 0A39
		char_delete2_accept 098F
		character_move 035F
		item_drop 0363
		item_take 0362
		master_login 027C
		send_equip 0998
		storage_item_add 0364
		storage_item_remove 0365
		skill_use_location 0366
		sync 0360
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{char_create_version} = 0x0A39;

	$self->{send_sell_buy_complete} = 1;
	$self->{send_buy_bulk_pack} = "v V";

	return $self;
}

sub sendMasterLogin {
	my ($self, $username_salted, $password_salted, $master_version, $version) = @_;
	my $msg;

	die "don't forget to add jRO_auth plugin to sys.txt\n".
		"https://openkore.com/wiki/loadPlugins_list\n" unless ($username_salted and $password_salted);
	my $mac = $config{macAddress} || sprintf("E0311E%02X%02X%02X", (map { int(rand(256)) } 1..3));
	   $mac = uc($mac);
	$msg = $self->reconstruct({
		switch => 'master_login',
		version => $version || $self->version,
		mac => $mac,
		username_salted => $username_salted,
		password_salted => $password_salted,
		master_version => $master_version,
	});

	$self->sendToServer($msg);
	debug "Sent sendMasterLogin\n", "sendPacket", 2;
}

1;

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
# vRO (Vietnam)
# Servertype overview: https://openkore.com/wiki/ServerType
package Network::Send::vRO;

use strict;
use Network::Send::ServerType0;
use base qw(Network::Send::ServerType0);
use Globals qw(%config);
use Log qw(debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0B04' => ['master_login', 'V Z30 Z52 Z100 v', [qw(version username accessToken billingAccessToken master_version)]],# 190
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_look_at 0361
		actor_info_request 0368
		char_create 0A39
		character_move 035F
		item_drop 0363
		item_take 0362
		master_login 0B04
		send_equip 0998
		sync 0360
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{send_buy_bulk_pack} = "v V";
	$self->{char_create_version} = 1;
	$self->{send_sell_buy_complete} = 1;
	return $self;
}

sub sendMasterLogin {
	my ($self, $username, $password, $master_version, $version) = @_;
	my $msg;
	my $accessToken = $config{accessToken};
	my $billingAccessToken = $config{billingAccessToken};

	die "don't forget to add vRO_auth plugin to sys.txt\n".
		"https://openkore.com/wiki/loadPlugins_list\n" unless ($accessToken and $billingAccessToken);

	$msg = $self->reconstruct({
		switch => 'master_login',
		version => $version || $self->version,
		master_version => $master_version,
		username => $username,
		accessToken => $accessToken,
		billingAccessToken => $billingAccessToken,
	});

	$self->sendToServer($msg);
	debug "Sent sendMasterLogin\n", "sendPacket", 2;
}

1;

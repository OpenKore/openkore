# OpenKore - GameFort packet encryption
# Copyright (C) 2009 Technology (credits to Soner Köksal for discovering the algorithm and key)
 
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.

# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.

# You should have received a copy of the GNU General Public License along with
# this program; if not, see <http://www.gnu.org/licenses/>.

package GameFort;

# perl
use strict;

# openkore
use Utils::Rijndael qw(give_hex);
use Globals qw($net %config %masterServers);
use Plugins;
use Network::Send;
use Log qw(message warning error debug);

# globally used vars
my $rijndael = Utils::Rijndael->new();
my $packet_hooks;

Plugins::register("gamefort", "GameFort packet encryption", \&onUnload);

my $kore_hooks = Plugins::addHooks(
	['start3', \&init_encryption_key],
	['Network::serverConnect/mapserver', \&hook_packets],
);

sub hook_packets {
	$packet_hooks = Plugins::addHooks(
		['packet_send/0072', \&encrypt_packet],
		['packet_send/007e', \&encrypt_packet],
		['packet_send/00F5', \&encrypt_packet],
		['packet_send/009B', \&encrypt_packet],
		['packet_send/0436', \&encrypt_packet],
	);
}

sub onUnload {
	Plugins::delHooks($kore_hooks);
	Plugins::delHooks($packet_hooks) if defined @{$packet_hooks}->[0]->[0]; # delete hooks if the first hook didn't had a defined index
}

sub init_encryption_key {
	my $key = pack('H64', $masterServers{$config{'master'}}->{'gamefort_key'});
	my $chain = "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";
	$rijndael->MakeKey($key, $chain, 32, 16);
}

sub encrypt_packet {
	Plugins::delHooks($packet_hooks);
	my ($hook, $args) = @_;
	message "GAMEFORT: ENCRYPTING PACKET $args->{switch}\n", "info";
	$args->{return} = 1;
	$net->serverSend(substr($args->{data}, 0, 2) . $rijndael->Encrypt(substr($args->{data}, 2, 16), undef, 16, 0) . substr($args->{data}, 18));
}

1;

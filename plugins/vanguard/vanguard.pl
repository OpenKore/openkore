# OpenKore - Vanguard packet encryption
# Copyright (C) 2009 Technology (credits to Soner Köksal for discovering the algorithm and key in his antisex project)
 
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
 
# usage: put in servers.txt under your server entry with key being the actual key: vanguard_key key

# the vanguard key consists of a part (len 16) of this entire key:
#	0x98, 0x7F, 0xB6, 0xE0, 0x90, 0x4E, 0x83, 0xC6, 0xF6, 0x29, 0xC2, 0xE0, 0xBD, 0x22, 0x8A, 0xEA,
#	0x67, 0x9C, 0xE0, 0x1E, 0x2D, 0xE0, 0x0E, 0xED, 0x9E, 0xE0, 0xB7, 0xF6, 0xE0, 0xBC, 0x75, 0x30,
#	0xE0, 0xB3, 0x7E, 0xBC, 0x3F, 0x16, 0x00, 0x12, 0x21, 0xA4, 0xE7, 0x28

package Vanguard;

# perl
use strict;

# openkore
use Utils::Rijndael;
use Utils qw(getTickCount);
use Globals qw($net %config %masterServers);
use Plugins;
use Network::Send;
use Log qw(message warning error debug);

# globally used vars
my $hddserial;
for(my $i = 0; $i < 8; $i++) {
	$hddserial .= pack('C', rand() * getTickCount() % 0xFF);
}
my $rijndael = Utils::Rijndael->new();
my $packet_count = 0;
my $encrypt = 0;

Plugins::register("vanguard", "Vanguard packet encryption", \&onUnload);

my $hooks = Plugins::addHooks(
	['start3', \&init_encryption_key],
	['Network::serverConnect/master', \&reset_encryption],
	['Network::serverConnect/char', \&reset_encryption],
	['Network::serverConnect/mapserver', \&start_encryption],
	['Network::serverSend/pre', \&encrypt],
);

sub onUnload {
	Plugins::delHooks($hooks);
}

sub init_encryption_key {
	my $key = pack('H32', $masterServers{$config{'master'}}->{'vanguard_key'});
	#my $key = pack('C16', (0x98, 0x7F, 0xB6, 0xE0, 0x90, 0x4E, 0x83, 0xC6, 0xF6, 0x29, 0xC2, 0xE0, 0xBD, 0x22, 0x8A, 0xEA)); # Elecom Shield: Vanguard v3.8.5.0 # intenseRO:	vanguard_key 987FB6E0904E83C6F629C2E0BD228AEA
	#my $key = pack('C16', (0xB6, 0xE0, 0x90, 0x4E, 0x83, 0xC6, 0xF6, 0x29, 0xC2, 0xE0, 0xBD, 0x22, 0x8A, 0xEA, 0x67, 0x9C)); # Elecom Shield; Vanguard v4.1.0.0 # limitRO:		vanguard_key B6E0904E83C6F629C2E0BD228AEA679C
	#my $key = pack('C16', (0x8A, 0xEA, 0x67, 0x9C, 0xE0, 0x1E, 0x2D, 0xE0, 0x0E, 0xED, 0x9E, 0xE0, 0xB7, 0xF6, 0xE0, 0xBC)); # Elecom Shield: Vanguard v3.8.5.0 # some server: vanguard_key 8AEA679CE01E2DE00EED9EE0B7F6E0BC
	my $chain = "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";
	$rijndael->MakeKey($key, $chain, 16, 16);
}

sub reset_encryption {
	$packet_count = 0;
	$encrypt = 0;
}

sub start_encryption {
	message "STARTING VANGUARD ENCRYPTION\n", "info";
	$encrypt = 1;
}

sub encrypt {
	return unless $encrypt;

	my ($hook, $args) = @_;
	my $new_packet;
	my $old_packet = $args->{msg};
	my $len = length($$old_packet);
	my $olen = $len;
	if($packet_count) {
		$new_packet = pack('V', $packet_count) . $$old_packet;
		$len += 4; # 4 bytes sent packet count
	} else { # initial encrypted packet
		$new_packet = pack('V v', $packet_count, 0xDEAD) . $hddserial . $$old_packet;
		$len += 14; # 4 bytes for sent packet count, 10 for hdd serial
		$olen += 10; # 10 bytes for hdd serial
	}
	$len = (int($len / 16) + 1) * 16; # set length to the multiple of blocksize 16 >= len
	$new_packet = $rijndael->Encrypt($new_packet, undef, $len, 0);
	$len += 6;
	$$old_packet = pack('v3', $len, $olen, 0xFACE) . $new_packet;
	
	$packet_count++;	
}

1;
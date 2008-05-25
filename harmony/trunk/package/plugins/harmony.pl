 # OpenKore - Harmony packet enryption
 # Copyright (C) 2008 darkfate
 
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

package Harmony;

use strict;
use Win32::API;

use lib $Plugins::current_plugin_folder;
use Globals;
use Plugins;
use Network::Send;

my $connecting = 0;

Win32::API->Import('harmony', 'on_connect', '' ,'') ||
	die "Can't import on_connect\n";
Win32::API->Import('harmony', 'create_key', 'P' ,'N') ||
	die "Can't import create_key\n";
Win32::API->Import('harmony', 'create_packet', 'PPN' ,'N') ||
	die "Can't import create_packet\n";
	
Plugins::register("harmony", "Harmony packet encryption", \&onUnload);

my $hooks = Plugins::addHooks(
	['Network::serverSend/pre', \&encrypt],
	['Network::serverConnect/master', \&init],
	['Network::serverConnect/char', \&init],
	['Network::serverConnect/mapserver', \&init],
	['RO_sendMsg_pre', \&init_xkore]
);

sub onUnload {
	Plugins::delHooks($hooks);
}

sub encrypt {
	return if $connecting;

	my ($hook, $args) = @_;
	my $old_packet;
	my $old_len;
	my $new_len;
	my $new_packet = " " x 0x40000;
	
	$old_packet = $args->{msg};
	$old_len = length($$old_packet);
	$new_len = create_packet($new_packet, $$old_packet, $old_len);
	$$old_packet = substr($new_packet, 0, $new_len);
}

sub init {
	on_connect();
	my $key = " " x 13;
	create_key($key);
	$key = substr($key, 0, 13);
	$connecting = 1;
	$net->serverSend($key);
	$connecting = 0;
}

sub init_xkore {
	my ($hook, $args) = @_;
	my $switch = $args->{switch};
	
	if( $switch eq '0064' || $switch eq '0065' || $switch eq '009B' ) {
		init();
	}
}

1;
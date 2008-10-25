package ALERT;
 
use strict;
use Plugins;
use Globals;
use Log qw(message warning error);
my $dataDir = $Plugins::current_plugin_folder;
use FindBin qw($RealBin);
use lib "$RealBin/plugins/mediaClient";
use client; 

my %ALERT;
my $pathTo = 'sounds/ALERT/';

Plugins::register('ALERT', 'plays sounds on events', \&Unload);

my $hooks = Plugins::addHooks(
	['packet/public_chat', \&onPacket, undef],
	['packet/private_message', \&onPacket, undef],
	['packet/system_chat', \&onPacket, undef],
	['packet/guild_chat', \&onPacket, undef],
	['packet/party_chat', \&onPacket, undef],
	['packet/shop_sold', \&onPacket, undef],
);

sub Unload {
	Plugins::delHooks($hooks);
	client->getInstance()->quit;
}

sub onPacket {
	my ($packet, $args) = @_;
	$packet =~ s/packet\///;
	
	my $file = $pathTo . $ALERT{$packet};
	client->getInstance->play($file, 'ALERT', 1);
}

%ALERT = (
	public_chat => 'public_chat.ogg',
	private_message => 'private_message.ogg',
	system_chat => 'system_chat.ogg',
	guild_chat => 'guild_chat.ogg',
	party_chat => 'party_chat.ogg',
	shop_sold => 'shop_sold.ogg',
);

1;

# by ya4epT v1.0 (2021-07-10)
# this plugin allows you to get tokens for authorization on vRO
# https://ro.vtcgame.vn/
# http://apisdk.vtcgame.vn/sdk/login?username=<USERNAME>&password=<MD5-PASSWORD>&client_id=<MD5-CLIENT_ID>&client_secret=<MD5-CLIENT_SECRET>&grant_type=password&authen_type=0&device_type=1

package vRO_auth;

use strict;
#use lib 'C:/strawberry/perl/lib';
#use lib 'C:/strawberry/perl/site/lib';
#use lib 'C:/strawberry/perl/vendor/lib';
use lib $Plugins::current_plugin_folder."//..//!deps";
use Digest::MD5 qw(md5_hex);
use LWP::Simple;

use Globals qw(%config $masterServer);
use Log qw(debug message warning error);
use Misc qw(configModify);
use Plugins;

Plugins::register('vRO_auth', 'Vietnam RO SSO Authenticator', \&unload);

my $hooks = Plugins::addHooks(
	['Network::serverConnect/master',\&getToken]
);

sub unload {
	message "vRO_auth plugin unloading, ", "system";
	Plugins::delHooks($hooks);
}

sub getToken {
	if ($masterServer->{serverType} ne 'vRO') {
		unload ();
		return;
	}
	my ($accessToken, $billingAccessToken, $msg);

	my $USERNAME = $config{username};
	my $MD5_PASSWORD = md5_hex($config{password});
	my $MD5_CLIENT_ID = '2aa32a67b771fcab4fd501273ef8b744';
	my $MD5_CLIENT_SECRET = '9ecf8255d241f5e702714734e3a93afb';

	#die "[vRO_auth] value 'MD5_CLIENT_ID' and 'MD5_CLIENT_SECRET' cannot be empty! See your config.txt\n" unless ($MD5_CLIENT_ID and $MD5_CLIENT_SECRET);

	my $url = 'http://apisdk.vtcgame.vn/sdk/login?username='.$USERNAME.'&password='.$MD5_PASSWORD.'&client_id='.$MD5_CLIENT_ID.'&client_secret='.$MD5_CLIENT_SECRET.'&grant_type=password&authen_type=0&device_type=1';
	debug "[vRO_auth] $url\n\n";

	my $content = get $url;
	die "[vRO_auth] Couldn't get it!" unless defined $content;

	if ($content eq '') {
		die "[vRO_auth] Error: the request returned an empty result\n";
	} else {
		$content =~ m/"error":(-?\d+),/;
		if ($1 eq "-349") {
			die "[vRO_auth] error: $1 (Incorrect account or password)\n";
		} elsif ($1 eq "200") {
			debug "[vRO_auth] Success: $1\n";
			($accessToken, $billingAccessToken) = $content =~ /"accessToken":"([a-z0-9-]*)","billingAccessToken":"([a-z0-9.]*)",/;
			if ($accessToken and $billingAccessToken) {
				debug 	"[vRO_auth] accessToken: $accessToken\n".
						"[vRO_auth] billingAccessToken: $billingAccessToken\n";
				configModify ('accessToken', $accessToken, 1);
				configModify ('billingAccessToken', $billingAccessToken, 1);
			}
		} else {
			die "[vRO_auth] error: $1 (Unknown error)\n";
		}

		debug 	"\n=======\n".
				"[vRO_auth] content: $content\n".
				"\n=======\n\n";
	}
}

1;

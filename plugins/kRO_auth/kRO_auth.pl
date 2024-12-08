# by alisonrag v1.0 (2021-07-12)
# this plugin allows you to get token for authorization on kRO
package kRO_auth;

use strict;
use warnings;

use lib 'C:/Strawberry/perl/lib/';
use lib 'C:/Strawberry/perl/site/lib';
use lib 'C:/Strawberry/perl/vendor/lib';

use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Headers;
use HTML::Form;
use HTTP::Request::Common qw(POST GET);

use Globals qw(%config $masterServer);
use Log qw(debug message);
use Misc qw(configModify);
use Plugins;

Plugins::register('kRO_auth', 'korea RO SSO Authenticator', \&unload);

my $hooks = Plugins::addHooks(
	['initialized',						\&setGlobalVars],
	['Network::serverConnect/master',	\&getToken]
);

my %request;

sub unload {
	message "[kRO_auth] plugin unloading, ", "system";
	undef %request;
	Plugins::delHooks($hooks);
}

sub setGlobalVars {
	$request{'url_host'} = 'login.gnjoy.com';
	$request{'url_login'} = 'https://login.gnjoy.com/proc/loginproc.asp';
	$request{'url_game_start'} = 'https://login.gnjoy.com/webstarter/index.asp?callback=myCallback&gamecode=%s&_=%s';
	$request{'user_agent'} = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.132 Safari/537.36';

	if ( $masterServer->{serverType} eq 'Zero' ) {
		$request{'game_code'} = '0036';
		$request{'url'} = 'http://roz.gnjoy.com';
		$request{'url_index'} = 'http://roz.gnjoy.com/index.asp';
		$request{'url_referer'} = 'https://roz.gnjoy.com/';
	} elsif ( $masterServer->{serverType} eq 'kRO' ) {
		$request{'game_code'} = '0011';
		$request{'url'} = 'http://ro.gnjoy.com';
		$request{'url_index'} = 'http://ro.gnjoy.com/index.asp';
		$request{'url_referer'} = 'https://ro.gnjoy.com/';
	} elsif ( $masterServer->{serverType} eq 'Sakray' ) {
		$request{'game_code'} = '2011';
		$request{'url'} = 'http://ro.gnjoy.com';
		$request{'url_index'} = 'http://ro.gnjoy.com/index.asp';
		$request{'url_referer'} = 'https://ro.gnjoy.com/';
	} else {
		unload();
	}
}

sub getToken {
	# start necessary variables
	my ($ua, $response, @forms, $input, $headers, $url, $req, $cookie_jar);

	message "[kRO_auth] Trying to Authenticate...\n", "system";
	debug "[kRO_auth] Setting Up the LWP AGENT...\n";
	# set lwp and http values
	$cookie_jar = HTTP::Cookies->new(autosave => 1);
	$ua = LWP::UserAgent->new(agent => $request{'user_agent'}, cookie_jar => $cookie_jar);
	$ua->agent($request{'user_agent'});

	# first request to index.php
	debug "[kRO_auth] First Request: ".$request{'url'}."\n";
	$req = GET $request{'url_index'};
	$response = $ua->request($req);

	if (!$response->is_success) {
		die "[kRO_auth] Error in First Request. Status: " . $response->status_line . "\n";
	}

	debug "[kRO_auth] Setting Up the Login Request...\n";
	$cookie_jar->extract_cookies($response);
	@forms = HTML::Form->parse($response, $response->base);
	$input = $forms[1]->find_input('__GnjoyRequestVerificationToken');

	# set LWP User Agent and Header to login
	$ua->cookie_jar($cookie_jar);
	$headers = HTTP::Headers->new(
		'Pragma' => 'no-cache',
		'Origin' => $request{'url'},
		'Accept-Encoding' => 'gzip, deflate, br',
		'Host' => $request{'url_host'},
		'Accept-Language' => 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
		'Upgrade-Insecure-Requests' => '1',
		'Content-Type' => 'application/x-www-form-urlencoded',
		'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
		'Cache-Control' => 'no-cache',
		'Referer' => $request{'url_index'},
		'Connection' => 'keep-alive'
	);
	$ua->default_headers($headers);

	debug "[kRO_auth] Trying to Login: " . $request{'url_login'} . "\n";
	# try to login
	$url = $request{'url_login'};
	$req = POST $url, [
		__GnjoyRequestVerificationToken => $input->{value},
		cpflag => 'G',
		loginsubmit => 'N',
		svc => 'G000',
		uid => $config{username},
		upass => $config{password},
		rtnurl => $request{'url_index'}
	];

	$response = $ua->request($req);
	if (!$response->is_success) {	
		die "[kRO_auth] Error in Login Request. Status: " . $response->status_line . "\n";
	}

	debug "[kRO_auth] Setting Up the Game Start Request...\n";
	$cookie_jar->extract_cookies($response);
	$ua->cookie_jar($cookie_jar);
	# set Header and try to emulate Game Execute
	$headers = HTTP::Headers->new(
		'authority' => $request{'url_host'},
		'user-agent' => $request{'user_agent'},
		'dnt' => '1',
		'accept' => '*/*',
		'sec-fetch-site' => 'same-site',
		'sec-fetch-mode' => 'no-cors',
		'sec-fetch-dest' => 'script',
		'referer' => $request{'url_referer'},
		'accept-language' => 'en-US,en;q=0.9,ar-MA;q=0.8,ar;q=0.7,fr;q=0.6',
		'Pragma' => 'no-cache',
		'Origin' => $request{'url'},
		'Host' => $request{'url_host'},
		'Upgrade-Insecure-Requests' => '1',
		'Cache-Control' => 'no-cache',
		'Connection' => 'keep-alive',
	);
	$ua->default_headers($headers);

	$url = sprintf($request{'url_game_start'}, $request{'game_code'}, time());
	debug "[kRO_auth] Trying to Get the Token: ".$url."\n";
	$req = GET $url;
	$response = $ua->request($req);

	if (!$response->is_success) {
		die "[kRO_auth] Error in Get the Token. Status: " . $response->status_line . "\n";
	}

	if( $response->decoded_content =~/rouri\-kor\:([aA-zZ0-9]+)\&/ || $response->decoded_content =~/rouri\-kor\-zero\:([aA-zZ0-9]+)\&/ || $response->decoded_content =~/rouri\-kor\-sakray\:([aA-zZ0-9]+)\&/ ) {
		debug "[kRO_auth] Token: $1 \n";
		configModify ('accessToken', $1, 1);
		message "[kRO_auth] Successfully Authenticated...\n", "system";
	} else {
		die "[kRO_auth] Error in parse Token. \nContent:\n" . $response->decoded_content . "\n";
	}
}

1;
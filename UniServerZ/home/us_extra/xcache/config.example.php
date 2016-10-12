<?php

// DO NOT rename/delete/modify example file which will be overwritten when upgrade
// How To Custom Config:
// 1. copy config.example.php config.php; edit config.php
// 2. upgrading your config.php when config.example.php were upgraded

// leave this setting unset to auto detect using browser request header
// $config['lang'] = 'en-us';

$config['charset'] = "UTF-8";

// enable this for translators only
$config['show_todo_strings'] = false;

// this ob filter is applied for the cache list, not the whole page
function custom_ob_filter_path_nicer($list_html)
{
	$list_html = ob_filter_path_nicer_default($list_html); // this function is from common.php
	return $list_html;
}
$config['path_nicer'] = 'custom_ob_filter_path_nicer';

// "XCache Cacher" http auth for is enforced for security reason
// if http auth is disabled, any vhost user who can upload *.php will see all variable data cached in XCache

/*// but if you have your own login/permission system, you can integerate it using the following example
// {{{ login example
// this is an example only, it's won't work for you without your implemention.

function check_admin_and_by_pass_xcache_http_auth()
{
	require("/path/to/user-login-and-permission-lib.php");
	session_start();

	if (user_logined()) {
		user_load_permissions();
		if (user_is_admin()) {
			// user is trusted after permission checks above.
			// tell XCache about it (the only secure way to by pass XCache http auth)
			$_SERVER["PHP_AUTH_USER"] = "moo";
			$_SERVER["PHP_AUTH_PW"] = "your-xcache-password-before-md5";
		}
		else {
			die("Permission denied");
		}
	}
	else {
		if (!ask_the_user_to_login()) {
			exit;
		}
	}

	return true;
}

check_admin_and_by_pass_xcache_http_auth();
*/
// }}}

/* by pass XCache http auth
$_SERVER["PHP_AUTH_USER"] = "moo";
$_SERVER["PHP_AUTH_PW"] = "your-xcache-password-before-md5";
*/


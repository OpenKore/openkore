<?php
if ( !defined('IN_PHPBB') )
{
	die('Hacking attempt');
}

/*
CREATE TABLE userlogs(
    id INT UNSIGNED AUTO_INCREMENT,
    ip VARCHAR(255),
    user_id INT UNSIGNED,
    username VARCHAR(255),
    last_time INT UNSIGNED NOT NULL,
    PRIMARY KEY (id)
);
 */

function log_user($user_id, $username, $ip)
{
	global $dbhost;
	global $dbuser;
	global $dbpasswd;
	global $dbname;

	if ($username == "Anonymous" || $user_id == '' || $user_id <= 0 || $username == '')
		return;

	// Connect to database
	if ( !($link = mysql_connect($dbhost, $dbuser, $dbpasswd)) )
		return;
	if (!mysql_select_db($dbname)) {
		mysql_close($link);
		return;
	}


	$user_id = mysql_escape_string($user_id);
	$username = mysql_escape_string($username);
	$ip = mysql_escape_string($ip);
	$user_id = sprintf("%d", $user_id);

	// Has user already used this IP before?
	$sql = "SELECT id FROM userlogs WHERE user_id = $user_id AND ip = '$ip' LIMIT 1;";
	$result = mysql_query($sql);
	if (!$result) {
		mysql_close($link);
		return;
	}

	if ($row = mysql_fetch_assoc($result)) {
		// Yes, update time
		$sql = "UPDATE userlogs SET last_time = UNIX_TIMESTAMP(NOW()) WHERE id = $row[id] AND user_id = $user_id AND ip = '$ip';";
		mysql_query($sql);

	} else {
		$sql = "INSERT INTO userlogs VALUES(NULL, '$ip', $user_id, '$username', UNIX_TIMESTAMP(NOW()));";
		mysql_query($sql);
	}
	mysql_close($link);
}
?>

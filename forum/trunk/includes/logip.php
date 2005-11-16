<?php
if (!defined('IN_PHPBB')) {
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
	global $db;

	if ($username == "Anonymous" || $user_id == '' || $user_id <= 0 || $username == '')
		return;

	$user_id = mysql_escape_string($user_id);
	$username = mysql_escape_string($username);
	$ip = mysql_escape_string($ip);
	$user_id = sprintf("%d", $user_id);

	// Has user already used this IP before?
	$sql = "SELECT id FROM userlogs WHERE user_id = $user_id AND ip = '$ip' LIMIT 1;";
	$result = $db->sql_query($sql);
	if (!$result)
		return;

	if ($row = $db->sql_fetchrow($result)) {
		// Yes, update time
		$sql = "UPDATE userlogs SET last_time = UNIX_TIMESTAMP(NOW()) WHERE id = $row[id] AND user_id = $user_id AND ip = '$ip';";
		$db->sql_query($sql);

	} else {
		$sql = "INSERT INTO userlogs VALUES(NULL, '$ip', $user_id, '$username', UNIX_TIMESTAMP(NOW()));";
		$db->sql_query($sql);
	}
}
?>

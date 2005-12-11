<?php
if ( !defined('IN_PHPBB') ) {
	die("Hacking attempt");
}

define('OPENKORE_FORUM_CONFIG_TABLE', 'openkore_forum_config');

/*
CREATE TABLE openkore_forum_config (
    config_name VARCHAR(255) NOT NULL,
    config_value TEXT NOT NULL
);
 */

// Users who have more than x posts are considered good citizen.
// Users with less than this number of posts will be shown all kinds of warnings.
define('OPENKORE_MIN_USER_POSTS', 40);

function load_openkore_options()
{
	global $db;
	$sql = "SELECT * FROM " . OPENKORE_FORUM_CONFIG_TABLE . " WHERE config_name = 'important_announcement';";
	if (!($result = $db->sql_query($sql))) {
		message_die(GENERAL_ERROR, 'Cannot fetch configuration values.', 'Error', __LINE__, __FILE__, $sql);
	}

	$options = Array();
	while ($row = $db->sql_fetchrow($result)) {
		$options[$row['config_name']] = $row['config_value'];
	}
	return $options;
}
?>
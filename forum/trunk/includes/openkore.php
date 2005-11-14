<?php
if ( !defined('IN_PHPBB') )
{
	die("Hacking attempt");
}

function load_openkore_options()
{
	global $db;
	$sql = "SELECT * FROM " . CONFIG_TABLE . " WHERE config_name = 'important_announcement';";
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
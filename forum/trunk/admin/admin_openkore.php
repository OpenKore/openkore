<?php
/* Special configuration options for the Openkore forum. */
define('IN_PHPBB', 1);

if( !empty($setmodules) )
{
	$file = basename(__FILE__);
	$module['General']['OpenKore'] = "$file";
	return;
}

//
// Basic stuff
//
$phpbb_root_path = './../';
require($phpbb_root_path . 'extension.inc');
require('./pagestart.' . $phpEx);
require_once($phpbb_root_path . 'includes/openkore.' . $phpEx);

$template->set_filenames(array(
	'body' => 'admin/admin_openkore.tpl'
	)
);


//
// Perform actions if needed
//
function set_option($name, $value)
{
	global $db;
	$sql = sprintf("UPDATE %s SET config_value = '%s' " .
		       "WHERE config_name = '%s';",
		       OPENKORE_FORUM_CONFIG_TABLE,
		       $value, $name);
	if (!($result = $db->sql_query($sql)))
		message_die(GENERAL_ERROR, "Could not update config option $name.", 'Error', __LINE, __FILE__, $sql);
}

if ($HTTP_POST_VARS['submit'] == "Submit") {
	set_option('important_announcement', $HTTP_POST_VARS['important_announcement']);
	$template->assign_block_vars('submitted', array());
}


//
// Display the default admin screen
//
$options = load_openkore_options();
while ($row = $db->sql_fetchrow($result)) {
	$options[$row['config_name']] = $row['config_value'];
}


//
// Assign general vars
//
$template->assign_vars(array(
	'V_IMPORTANT_ANNOUNCEMENT' => $options['important_announcement'],
	'S_OPENKORE_ACTION' => append_sid("admin_openkore.$phpEx")
	)
);

$template->pparse('body');

include('./page_footer_admin.'.$phpEx);
?>
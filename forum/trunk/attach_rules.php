<?php
/** 
*
* @package attachment_mod
* @version $Id: attach_rules.php,v 1.2 2005/11/05 12:23:33 acydburn Exp $
* @copyright (c) 2002 Meik Sievertsen
* @license http://opensource.org/licenses/gpl-license.php GNU Public License 
*
*/

/**
*/
if (defined('IN_PHPBB'))
{
	die('Hacking attempt');
	exit;
}

define('IN_PHPBB', TRUE);
$phpbb_root_path = './';
include($phpbb_root_path . 'extension.inc');
include($phpbb_root_path . 'common.'.$phpEx);

$forum_id = get_var('f', 0);
$privmsg = (!$forum_id) ? true : false;

// Start Session Management
$userdata = session_pagestart($user_ip, PAGE_INDEX);
init_userprefs($userdata);

// Display the allowed Extension Groups and Upload Size
if ($privmsg)
{
	$auth['auth_attachments'] = ($userdata['user_level'] != ADMIN) ? intval($attach_config['allow_pm_attach']) : true;
	$auth['auth_view'] = true;
	$_max_filesize = $attach_config['max_filesize_pm'];
}
else
{
	$auth = auth(AUTH_ALL, $forum_id, $userdata);
	$_max_filesize = $attach_config['max_filesize'];
}

if (!($auth['auth_attachments'] && $auth['auth_view']))
{
	message_die(GENERAL_ERROR, 'You are not allowed to call this file (ID:2)');
}

$template->set_filenames(array(
	'body' => 'posting_attach_rules.tpl')
);

$sql = 'SELECT group_id, group_name, max_filesize, forum_permissions
	FROM ' . EXTENSION_GROUPS_TABLE . ' 
	WHERE allow_group = 1 
	ORDER BY group_name ASC';

if (!($result = $db->sql_query($sql)))
{ 
	message_die(GENERAL_ERROR, 'Could not query Extension Groups.', '', __LINE__, __FILE__, $sql); 
} 

$allowed_filesize = array(); 
$rows = $db->sql_fetchrowset($result); 
$num_rows = $db->sql_numrows($result); 
$db->sql_freeresult($result);

// Ok, only process those Groups allowed within this forum
$nothing = true;
for ($i = 0; $i < $num_rows; $i++)
{
	$auth_cache = trim($rows[$i]['forum_permissions']);
	
	$permit = ($privmsg) ? true : ((is_forum_authed($auth_cache, $forum_id)) || trim($rows[$i]['forum_permissions']) == '');

	if ($permit)
	{
		$nothing = false;
		$group_name = $rows[$i]['group_name'];
		$f_size = intval(trim($rows[$i]['max_filesize']));
		$det_filesize = (!$f_size) ? $_max_filesize : $f_size;
		$size_lang = ($det_filesize >= 1048576) ? $lang['MB'] : (($det_filesize >= 1024) ? $lang['KB'] : $lang['Bytes']); 

		if ($det_filesize >= 1048576) 
		{
			$det_filesize = round($det_filesize / 1048576 * 100) / 100; 
		}
		else if ($det_filesize >= 1024) 
		{ 
			$det_filesize = round($det_filesize / 1024 * 100) / 100; 
		} 

		$max_filesize = ($det_filesize == 0) ? $lang['Unlimited'] : $det_filesize . ' ' . $size_lang;

		$template->assign_block_vars('group_row', array(
			'GROUP_RULE_HEADER' => sprintf($lang['Group_rule_header'], $group_name, $max_filesize))
		);
		
		$sql = 'SELECT extension
			FROM ' . EXTENSIONS_TABLE . " 
			WHERE group_id = " . (int) $rows[$i]['group_id'] . " 
			ORDER BY extension ASC";

		if (!($result = $db->sql_query($sql))) 
		{ 
			message_die(GENERAL_ERROR, 'Could not query Extensions.', '', __LINE__, __FILE__, $sql); 
		} 

		$e_rows = $db->sql_fetchrowset($result);
		$e_num_rows = $db->sql_numrows($result);
		$db->sql_freeresult($result);

		for ($j = 0; $j < $e_num_rows; $j++)
		{
			$template->assign_block_vars('group_row.extension_row', array(
				'EXTENSION' => $e_rows[$j]['extension'])
			);
		}
	}
}

$gen_simple_header = TRUE;
$page_title = $lang['Attach_rules_title'];
include($phpbb_root_path . 'includes/page_header.' . $phpEx);

$template->assign_vars(array(
	'L_RULES_TITLE'			=> $lang['Attach_rules_title'],
	'L_CLOSE_WINDOW'		=> $lang['Close_window'],
	'L_EMPTY_GROUP_PERMS'	=> $lang['Note_user_empty_group_permissions'])
);

if ($nothing)
{
	$template->assign_block_vars('switch_nothing', array());
}

$template->pparse('body');

?>
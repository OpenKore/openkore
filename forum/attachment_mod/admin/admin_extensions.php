<?php
/***************************************************************************
 *								admin_extensions.php
 *								-------------------
 *   begin                : Wednesday, Jan 09, 2002
 *   copyright            : (C) 2002 Meik Sievertsen
 *   email                : acyd.burn@gmx.de
 *
 *   $Id: admin_extensions.php,v 1.27 2004/10/31 16:46:58 acydburn Exp $
 *
 ***************************************************************************/

/***************************************************************************
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 ***************************************************************************/

define('IN_PHPBB', true);

if( !empty($setmodules) )
{
	$filename = basename(__FILE__);
	$module['Extensions']['Extension_control'] = $filename . '?mode=extensions';
	$module['Extensions']['Extension_group_manage'] = $filename . '?mode=groups';
	$module['Extensions']['Forbidden_extensions'] = $filename . '?mode=forbidden';
	return;
}

//
// Let's set the root dir for phpBB
//
$phpbb_root_path = '../';
require($phpbb_root_path . 'extension.inc');
require('pagestart.' . $phpEx);

@include_once($phpbb_root_path . 'attach_mod/includes/constants.'.$phpEx);

if (!intval($attach_config['allow_ftp_upload']))
{
	if ( ($attach_config['upload_dir'][0] == '/') || ( ($attach_config['upload_dir'][0] != '/') && ($attach_config['upload_dir'][1] == ':') ) )
	{
		$upload_dir = $attach_config['upload_dir'];
	}
	else
	{
		$upload_dir = '../' . $attach_config['upload_dir'];
	}
}
else
{
	$upload_dir = $attach_config['download_path'];
}

include($phpbb_root_path . 'attach_mod/includes/functions_selects.' . $phpEx);
include($phpbb_root_path . 'attach_mod/includes/functions_admin.' . $phpEx);

//
// Init Vars
//
$types_download = array(INLINE_LINK, PHYSICAL_LINK);
$modes_download = array('inline', 'physical');

$types_category = array(IMAGE_CAT, STREAM_CAT, SWF_CAT);
$modes_category = array($lang['Category_images'], $lang['Category_stream_files'], $lang['Category_swf_files']);

if(isset($HTTP_GET_VARS['size']) || isset($HTTP_POST_VARS['size']))
{
	$size = (isset($HTTP_POST_VARS['size'])) ? $HTTP_POST_VARS['size'] : $HTTP_GET_VARS['size'];
}
else
{
	$size = '';
}

if( isset($HTTP_POST_VARS['mode']) || isset($HTTP_GET_VARS['mode']) )
{
	$mode = ( isset($HTTP_POST_VARS['mode']) ) ? $HTTP_POST_VARS['mode'] : $HTTP_GET_VARS['mode'];
}
else
{
	$mode = '';
}

if( isset($HTTP_POST_VARS['e_mode']) || isset($HTTP_GET_VARS['e_mode']) )
{
	$e_mode = ( isset($HTTP_POST_VARS['e_mode']) ) ? $HTTP_POST_VARS['e_mode'] : $HTTP_GET_VARS['e_mode'];
}
else
{
	$e_mode = '';
}

$submit = (isset($HTTP_POST_VARS['submit'])) ? TRUE : FALSE;

//
// Get Attachment Config
//
$attach_config = array();

$sql = 'SELECT * 
FROM ' . ATTACH_CONFIG_TABLE;
	 
if ( !($result = $db->sql_query($sql)) )
{
	message_die(GENERAL_ERROR, 'Could not query attachment information', '', __LINE__, __FILE__, $sql);
}

while ($row = $db->sql_fetchrow($result))
{
	$attach_config[$row['config_name']] = trim($row['config_value']);
}

//
// Extension Management
//
if ($submit && $mode == 'extensions')
{
	//
	// Change Extensions ?
	//
	$extension_change_list = ( isset($HTTP_POST_VARS['extension_change_list']) ) ? $HTTP_POST_VARS['extension_change_list'] : array();
	$extension_explain_list = ( isset($HTTP_POST_VARS['extension_explain_list']) ) ? $HTTP_POST_VARS['extension_explain_list'] : array();
	$group_select_list = ( isset($HTTP_POST_VARS['group_select']) ) ? $HTTP_POST_VARS['group_select'] : array();

	//
	// Generate correct Change List
	//
	$extensions = array();

	for ($i = 0; $i < count($extension_change_list); $i++)
	{
		$extensions['_' . $extension_change_list[$i]]['comment'] = stripslashes(htmlspecialchars($extension_explain_list[$i]));
		$extensions['_' . $extension_change_list[$i]]['group_id'] = intval($group_select_list[$i]);
	}

	$sql = "SELECT *
	FROM " . EXTENSIONS_TABLE . "
	ORDER BY ext_id";

	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Couldn\'t get Extension Informations.', '', __LINE__, __FILE__, $sql);
	}

	if ( ($db->sql_numrows($result)) > 0 )
	{
		$extension_row = $db->sql_fetchrowset($result);

		for ($i = 0; $i < count($extension_row); $i++)
		{
			if ( ($extension_row[$i]['comment'] != $extensions['_' . $extension_row[$i]['ext_id']]['comment']) || (intval($extension_row[$i]['group_id']) != intval($extensions['_' . $extension_row[$i]['ext_id']]['group_id'])) )
			{
				$sql = "UPDATE " . EXTENSIONS_TABLE . " 
				SET comment = '" . $extensions['_' . $extension_row[$i]['ext_id']]['comment'] . "', group_id = " . $extensions['_' . $extension_row[$i]['ext_id']]['group_id'] . "
				WHERE ext_id = " . $extension_row[$i]['ext_id'];
				
				if (!$db->sql_query($sql))
				{
					message_die(GENERAL_ERROR, 'Couldn\'t update Extension Informations', '', __LINE__, __FILE__, $sql);
				}
			}
		}
	}

	//
	// Delete Extension ?
	//
	$extension_id_list = ( isset($HTTP_POST_VARS['extension_id_list']) ) ?  $HTTP_POST_VARS['extension_id_list'] : array();

	$extension_id_sql = implode(', ', $extension_id_list);

	if ( $extension_id_sql != '' )
	{
		$sql = 'DELETE 
		FROM ' . EXTENSIONS_TABLE . ' 
		WHERE ext_id IN (' . $extension_id_sql . ')';

		if( !$result = $db->sql_query($sql) )
		{
			message_die(GENERAL_ERROR, 'Could not delete Extensions', '', __LINE__, __FILE__, $sql);
		}

	}
		
	//
	// Add Extension ?
	//
	$extension = ( isset($HTTP_POST_VARS['add_extension']) ) ?  trim(strip_tags($HTTP_POST_VARS['add_extension'])) : '';
	$extension_explain = ( isset($HTTP_POST_VARS['add_extension_explain']) ) ?  trim(strip_tags($HTTP_POST_VARS['add_extension_explain'])) : '';
	$extension_group = ( isset($HTTP_POST_VARS['add_group_select']) ) ?  intval($HTTP_POST_VARS['add_group_select']) : '';
	$add = ( isset($HTTP_POST_VARS['add_extension_check']) ) ? TRUE : FALSE;

	if ($extension != '' && $add)
	{
		$template->assign_vars(array(
			'ADD_EXTENSION' => $extension,
			'ADD_EXTENSION_EXPLAIN' => $extension_explain)
		);
	
		if (!$error)
		{
			//
			// check extension
			//
			$sql = "SELECT extension 
			FROM " . EXTENSIONS_TABLE;
	
			if ( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Could not query Extensions', '', __LINE__, __FILE__, $sql);
			}
			
			$row = $db->sql_fetchrowset($result);
			$num_rows = $db->sql_numrows($result);

			if ( $num_rows > 0 )
			{
				for ($i = 0; $i < $num_rows; $i++)
				{
					if (strtolower(trim($row[$i]['extension'])) == strtolower(trim($extension)))
					{
						$error = TRUE;
						if( isset($error_msg) )
						{
							$error_msg .= '<br />';
						}
						$error_msg .= sprintf($lang['Extension_exist'], strtolower(trim($extension)));
					}
				}
			}
			
			//
			// Extension Forbidden ?
			//
			if (!$error)
			{
				$sql = "SELECT extension 
				FROM " . FORBIDDEN_EXTENSIONS_TABLE;
	
				if ( !($result = $db->sql_query($sql)) )
				{
					message_die(GENERAL_ERROR, 'Could not query Extensions', '', __LINE__, __FILE__, $sql);
				}
			
				$row = $db->sql_fetchrowset($result);
				$num_rows = $db->sql_numrows($result);

				if ( $num_rows > 0 )
				{
					for ($i = 0; $i < $num_rows; $i++)
					{
						if (strtolower(trim($row[$i]['extension'])) == strtolower(trim($extension)))
						{
							$error = TRUE;
							if( isset($error_msg) )
							{
								$error_msg .= '<br />';
							}
							$error_msg .= sprintf($lang['Unable_add_forbidden_extension'], strtolower(trim($extension)));
						}
					}
				}
		
			}

			if (!$error)
			{
				$sql = "INSERT INTO " . EXTENSIONS_TABLE . " (group_id, extension, comment) 
				VALUES (" . $extension_group . ", '" . strtolower(trim($extension)) . "', '" . trim($extension_explain) . "')";
	
				if( !$db->sql_query($sql) )
				{
					message_die(GENERAL_ERROR, 'Could not add Extension', '', __LINE__, __FILE__, $sql);
				}

			}
		}
	}

	if (!$error)
	{
		$message = $lang['Attach_config_updated'] . '<br /><br />' . sprintf($lang['Click_return_attach_config'], '<a href="' . append_sid("admin_extensions.$phpEx?mode=extensions") . '">', '</a>') . '<br /><br />' . sprintf($lang['Click_return_admin_index'], '<a href="' . append_sid("index.$phpEx?pane=right") . '">', '</a>');

		message_die(GENERAL_MESSAGE, $message);
	}
}

if ($mode == 'extensions')
{
	//
	// Extensions
	//
	$template->set_filenames(array(
		'body' => 'admin/attach_extensions.tpl')
	);

	$template->assign_vars(array(
		'L_EXTENSIONS_TITLE' => $lang['Manage_extensions'],
		'L_EXTENSIONS_EXPLAIN' => $lang['Manage_extensions_explain'],
		'L_SELECT' => $lang['Select'],
		'L_EXPLANATION' => $lang['Explanation'],
		'L_EXTENSION' => $lang['Extension'],
		'L_EXTENSION_GROUP' => $lang['Extension_group'],
		'L_ADD_NEW' => $lang['Add_new'],
		'L_DELETE' => $lang['Delete'],
		'L_CANCEL' => $lang['Cancel'],
		'L_SUBMIT' => $lang['Submit'],

		'S_CANCEL_ACTION' => append_sid("admin_extensions.$phpEx?mode=extensions"),
		'S_ATTACH_ACTION' => append_sid("admin_extensions.$phpEx?mode=extensions"))
	);

	if ($submit)
	{
		$template->assign_vars(array(
			'S_ADD_GROUP_SELECT' => group_select('add_group_select', $extension_group))
		);
	}
	else
	{
		$template->assign_vars(array(
			'S_ADD_GROUP_SELECT' => group_select('add_group_select'))
		);
	}

	$sql = "SELECT * FROM " . EXTENSIONS_TABLE . " ORDER BY group_id";

	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Couldn\'t get Extension informations', '', __LINE__, __FILE__, $sql);
	}

	$extension_row = $db->sql_fetchrowset($result);
	$num_extension_row = $db->sql_numrows($result);

	if ( $num_extension_row > 0 )
	{
		$extension_row = sort_multi_array ($extension_row, 'group_name', 'ASC');
		
		for ($i = 0; $i < $num_extension_row; $i++)
		{
			if ($submit)
			{
				$template->assign_block_vars('extension_row', array(
					'EXT_ID' => $extension_row[$i]['ext_id'],
					'EXTENSION' => $extension_row[$i]['extension'],
					'EXTENSION_EXPLAIN' => $extension_explain_list[$i], 
					'S_GROUP_SELECT' => group_select('group_select[]', $group_select_list[$i]))
				);
			}
			else
			{
				$template->assign_block_vars('extension_row', array(
					'EXT_ID' => $extension_row[$i]['ext_id'],
					'EXTENSION' => $extension_row[$i]['extension'],
					'EXTENSION_EXPLAIN' => $extension_row[$i]['comment'],
					'S_GROUP_SELECT' => group_select('group_select[]', $extension_row[$i]['group_id']))
				);
			}
		}
	}

}

//
// Extension Groups
//
if ($submit && $mode == 'groups')
{
	//
	// Change Extension Groups ?
	//
	$group_change_list = ( isset($HTTP_POST_VARS['group_change_list']) ) ? $HTTP_POST_VARS['group_change_list'] : array();
	$extension_group_list = ( isset($HTTP_POST_VARS['extension_group_list']) ) ? $HTTP_POST_VARS['extension_group_list'] : array();
	$group_allowed_list = ( isset($HTTP_POST_VARS['allowed_list']) ) ? $HTTP_POST_VARS['allowed_list'] : array();
	$download_mode_list = ( isset($HTTP_POST_VARS['download_mode_list']) ) ? $HTTP_POST_VARS['download_mode_list'] : array();
	$category_list = ( isset($HTTP_POST_VARS['category_list']) ) ? $HTTP_POST_VARS['category_list'] : array();
	$upload_icon_list = ( isset($HTTP_POST_VARS['upload_icon_list']) ) ? $HTTP_POST_VARS['upload_icon_list'] : array();
	$filesize_list = ( isset($HTTP_POST_VARS['max_filesize_list']) ) ? $HTTP_POST_VARS['max_filesize_list'] : array();
	$size_select_list = ( isset($HTTP_POST_VARS['size_select_list']) ) ? $HTTP_POST_VARS['size_select_list'] : array();

	$allowed_list = array();

	for ($i = 0; $i < count($group_allowed_list); $i++)
	{
		for ($j = 0; $j < count($group_change_list); $j++)
		{
			if ($group_allowed_list[$i] == $group_change_list[$j])
			{
				$allowed_list[$j] = '1';
			}
		}
	}

	for ($i = 0; $i < count($group_change_list); $i++)
	{
		$allowed = ( isset($allowed_list[$i]) ) ? '1' : '0';
		
		$filesize_list[$i] = ( $size_select_list[$i] == 'kb' ) ? round($filesize_list[$i] * 1024) : ( ($size_select_list[$i] == 'mb') ? round($filesize_list[$i] * 1048576) : $filesize_list[$i] );

		$sql = "UPDATE " . EXTENSION_GROUPS_TABLE . " 
		SET group_name = '" . $extension_group_list[$i] . "', cat_id = " . $category_list[$i] . ", allow_group = " . $allowed . ", download_mode = " . $download_mode_list[$i] . ", upload_icon = '" . $upload_icon_list[$i] . "', max_filesize = " . $filesize_list[$i] . "
		WHERE group_id = " . $group_change_list[$i];
		
		if ( !($db->sql_query($sql)) )
		{
			message_die(GENERAL_ERROR, 'Couldn\'t update Extension Groups Informations', '', __LINE__, __FILE__, $sql);
		}
	}
	
	//
	// Delete Extension Groups
	//
	$group_id_list = ( isset($HTTP_POST_VARS['group_id_list']) ) ?  $HTTP_POST_VARS['group_id_list'] : array();

	$group_id_sql = implode(', ', $group_id_list);

	if ($group_id_sql != '')
	{
		$sql = 'DELETE 
		FROM ' . EXTENSION_GROUPS_TABLE . ' 
		WHERE group_id IN (' . $group_id_sql . ')';

		if ( !($result = $db->sql_query($sql)) )
		{
			message_die(GENERAL_ERROR, 'Could not delete Extension Groups', '', __LINE__, __FILE__, $sql);
		}

		//
		// Set corresponding Extensions to a pending Group
		//
		$sql = 'UPDATE ' . EXTENSIONS_TABLE . '
		SET group_id = 0
		WHERE group_id IN (' . $group_id_sql . ')';

		if( !$result = $db->sql_query($sql) )
		{
			message_die(GENERAL_ERROR, 'Could not assign Extensions to Pending Group.', '', __LINE__, __FILE__, $sql);
		}

	}
		
	//
	// Add Extensions ?
	//
	$extension_group = ( isset($HTTP_POST_VARS['add_extension_group']) ) ?  trim(strip_tags($HTTP_POST_VARS['add_extension_group'])) : '';
	$download_mode = ( isset($HTTP_POST_VARS['add_download_mode']) ) ?  $HTTP_POST_VARS['add_download_mode'] : '';
	$cat_id = ( isset($HTTP_POST_VARS['add_category']) ) ?  $HTTP_POST_VARS['add_category'] : '';
	$upload_icon = ( isset($HTTP_POST_VARS['add_upload_icon']) ) ?  $HTTP_POST_VARS['add_upload_icon'] : '';
	$filesize = ( isset($HTTP_POST_VARS['add_max_filesize']) ) ?  $HTTP_POST_VARS['add_max_filesize'] : '';
	$size_select = ( isset($HTTP_POST_VARS['add_size_select']) ) ?  $HTTP_POST_VARS['add_size_select'] : '';
	$is_allowed = ( isset($HTTP_POST_VARS['add_allowed']) ) ? '1' : '0';
	$add = ( isset($HTTP_POST_VARS['add_extension_group_check']) ) ? TRUE : FALSE;

	if ($extension_group != '' && $add)
	{
		//
		// check Extension Group
		//
		$sql = 'SELECT group_name 
		FROM ' . EXTENSION_GROUPS_TABLE;
	
		if ( !($result = $db->sql_query($sql)) )
		{
			message_die(GENERAL_ERROR, 'Could not query Extension Groups Table', '', __LINE__, __FILE__, $sql);
		}
			
		$row = $db->sql_fetchrowset($result);
		$num_rows = $db->sql_numrows($result);

		if ( $num_rows > 0 )
		{
			for ($i = 0; $i < $num_rows; $i++)
			{
				if ($row[$i]['group_name'] == $extension_group)
				{
					$error = TRUE;
					if( isset($error_msg) )
					{
						$error_msg .= '<br />';
					}
					$error_msg .= sprintf($lang['Extension_group_exist'], $extension_group);
				}
			}
		}
			
		if (!$error)
		{
			$filesize = ( $size_select == 'kb' ) ? round($filesize * 1024) : ( ($size_select == 'mb') ? round($filesize * 1048576) : $filesize );
		
			$sql = "INSERT INTO " . EXTENSION_GROUPS_TABLE . " (group_name, cat_id, allow_group, download_mode, upload_icon, max_filesize, forum_permissions) 
			VALUES ('" . $extension_group . "', " . $cat_id . ", " . $is_allowed . ", " . $download_mode . ", '" . $upload_icon . "', " . $filesize . ", '')";
	
			if ( !($db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Could not add Extension Group', '', __LINE__, __FILE__, $sql);
			}
		}

	}

	if (!$error)
	{
		$message = $lang['Attach_config_updated'] . '<br /><br />' . sprintf($lang['Click_return_attach_config'], '<a href="' . append_sid("admin_extensions.$phpEx?mode=groups") . '">', '</a>') . '<br /><br />' . sprintf($lang['Click_return_admin_index'], '<a href="' . append_sid("index.$phpEx?pane=right") . '">', '</a>');

		message_die(GENERAL_MESSAGE, $message);
	}
}

if ($mode == 'groups')
{
	//
	// Extension Groups
	//
	$template->set_filenames(array(
		'body' => 'admin/attach_extension_groups.tpl')
	);

	if ((empty($size)) && (!$submit))
	{
		$max_add_filesize = $attach_config['max_filesize'];
		
		$size = ($max_add_filesize >= 1048576) ? 'mb' : ( ($max_add_filesize >= 1024) ? 'kb' : 'b' );
	} 

	if ($max_add_filesize >= 1048576)
	{
		$max_add_filesize = round($max_add_filesize / 1048576 * 100) / 100;
	}
	else if ( $max_add_filesize >= 1024)
	{
		$max_add_filesize = round($max_add_filesize / 1024 * 100) / 100;
	}

	$viewgroup = get_var(POST_GROUPS_URL, 0);

	$template->assign_vars(array(
		'L_EXTENSION_GROUPS_TITLE' => $lang['Manage_extension_groups'],
		'L_EXTENSION_GROUPS_EXPLAIN' => $lang['Manage_extension_groups_explain'],
		'L_EXTENSION_GROUP' => $lang['Extension_group'],
		'L_ADD_NEW' => $lang['Add_new'],
		'L_ALLOWED' => $lang['Allowed'],
		'L_DELETE' => $lang['Delete'],
		'L_CANCEL' => $lang['Cancel'],
		'L_SUBMIT' => $lang['Submit'],
		'L_SPECIAL_CATEGORY' => $lang['Special_category'],	
		'L_DOWNLOAD_MODE' => $lang['Download_mode'],
		'L_UPLOAD_ICON' => $lang['Upload_icon'],
		'L_MAX_FILESIZE' => $lang['Max_groups_filesize'],
		'L_ALLOWED_FORUMS' => $lang['Allowed_forums'],
		'L_FORUM_PERMISSIONS' => $lang['Ext_group_permissions'],

		'ADD_GROUP_NAME' => ( isset($submit) ) ? $extension_group : '',
		'MAX_FILESIZE' => $max_add_filesize,

		'S_FILESIZE' => size_select('add_size_select', $size),
		'S_ADD_DOWNLOAD_MODE' => download_select('add_download_mode'),
		'S_SELECT_CAT' => category_select('add_category'),
		'S_CANCEL_ACTION' => append_sid("admin_extensions.$phpEx?mode=groups"),
		'S_ATTACH_ACTION' => append_sid("admin_extensions.$phpEx?mode=groups"))
	);

	$sql = "SELECT * FROM " . EXTENSION_GROUPS_TABLE;

	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Couldn\'t get Extension Group informations', '', __LINE__, __FILE__, $sql);
	}

	$extension_group = $db->sql_fetchrowset($result);
	$num_extension_group = $db->sql_numrows($result);

	for ($i = 0; $i < $num_extension_group; $i++)
	{
		//
		// Format the filesize
		//
		if ( $extension_group[$i]['max_filesize'] == 0 )
		{
			$extension_group[$i]['max_filesize'] = $attach_config['max_filesize'];
		}

		$size_format = ($extension_group[$i]['max_filesize'] >= 1048576) ? 'mb' : ( ($extension_group[$i]['max_filesize'] >= 1024) ? 'kb' : 'b' );

		if ( $extension_group[$i]['max_filesize'] >= 1048576)
		{
			$extension_group[$i]['max_filesize'] = round($extension_group[$i]['max_filesize'] / 1048576 * 100) / 100;
		}
		else if($extension_group[$i]['max_filesize'] >= 1024)
		{
			$extension_group[$i]['max_filesize'] = round($extension_group[$i]['max_filesize'] / 1024 * 100) / 100;
		}

		$s_allowed = ($extension_group[$i]['allow_group'] == 1) ? 'checked="checked"' : '';
			
		$template->assign_block_vars('grouprow', array(
			'GROUP_ID' => $extension_group[$i]['group_id'],
			'EXTENSION_GROUP' => $extension_group[$i]['group_name'],
			'UPLOAD_ICON' => $extension_group[$i]['upload_icon'],

			'S_ALLOW_SELECTED' => $s_allowed,
			'S_SELECT_CAT' => category_select('category_list[]', $extension_group[$i]['group_id']),
			'S_DOWNLOAD_MODE' => download_select('download_mode_list[]', $extension_group[$i]['group_id']),
			'S_FILESIZE' => size_select('size_select_list[]', $size_format),
				
			'MAX_FILESIZE' => $extension_group[$i]['max_filesize'],
			'CAT_BOX' => ( $viewgroup == $extension_group[$i]['group_id'] ) ? $lang['Decollapse'] : $lang['Collapse'],
			'U_VIEWGROUP' => ( $viewgroup == $extension_group[$i]['group_id'] ) ? append_sid("admin_extensions.$phpEx?mode=groups") : append_sid("admin_extensions.$phpEx?mode=groups&" . POST_GROUPS_URL . "=" . $extension_group[$i]['group_id']),
			'U_FORUM_PERMISSIONS' => append_sid("admin_extensions.$phpEx?mode=$mode&amp;e_mode=perm&amp;e_group=" . $extension_group[$i]['group_id']))
		);

		if ($viewgroup && $viewgroup == $extension_group[$i]['group_id'])
		{
			$sql = "SELECT comment, extension FROM " . EXTENSIONS_TABLE . "
			WHERE group_id = " . $viewgroup;

			if (!$result = $db->sql_query($sql))
			{
				message_die(GENERAL_ERROR, 'Couldn\'t get Extension informations', '', __LINE__, __FILE__, $sql);
			}

			$extension = $db->sql_fetchrowset($result);
			$num_extension = $db->sql_numrows($result);

			for ($j = 0; $j < $num_extension; $j++)
			{
				$template->assign_block_vars('grouprow.extensionrow', array(
					'EXPLANATION' => $extension[$j]['comment'],
					'EXTENSION' => $extension[$j]['extension'])
				);
			}
		}
	}
}

//
// Forbidden Extensions
//
if ($submit && $mode == 'forbidden')
{
	//
	// Store new forbidden extension or delete selected forbidden extensions
	//
	$extension = ( isset($HTTP_POST_VARS['extension_id_list']) ) ? $HTTP_POST_VARS['extension_id_list'] : array();

	$extension_id_sql = implode(', ', $extension);

	if( $extension_id_sql != '' )
	{
		$sql = "DELETE 
		FROM " . FORBIDDEN_EXTENSIONS_TABLE . " 
		WHERE ext_id IN (" . $extension_id_sql . ")";

		if( !$result = $db->sql_query($sql) )
		{
			message_die(GENERAL_ERROR, 'Could not delete forbidden extensions', '', __LINE__, __FILE__, $sql);
		}
	}
		
	$extension = ( isset($HTTP_POST_VARS['add_extension']) ) ? trim(strip_tags($HTTP_POST_VARS['add_extension'])) : '';
	$add = ( isset($HTTP_POST_VARS['add_extension_check']) ) ? TRUE : FALSE;
		
	if ($extension != '' && $add)
	{
		//
		// Check Extension
		//
		$sql = "SELECT extension 
		FROM " . FORBIDDEN_EXTENSIONS_TABLE;

		if ( !($result = $db->sql_query($sql)) )
		{
			message_die(GENERAL_ERROR, 'Could not query forbidden extensions', '', __LINE__, __FILE__, $sql);
		}

		$row = $db->sql_fetchrowset($result);
		$num_rows = $db->sql_numrows($result);	
	
		if( $num_rows > 0 )
		{
			for ($i = 0; $i < $num_rows; $i++)
			{
				if ($row[$i]['extension'] == $extension)
				{
					$error = TRUE;
					if( isset($error_msg) )
					{
						$error_msg .= '<br />';
					}
					$error_msg .= sprintf($lang['Forbidden_extension_exist'], $extension);
				}
			}
		}
			
		// Check, if extension is allowed
		if (!$error)
		{
			$sql = "SELECT extension 
			FROM " . EXTENSIONS_TABLE;

			if ( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Could not query extensions', '', __LINE__, __FILE__, $sql);
			}

			$row = $db->sql_fetchrowset($result);
			$num_rows = $db->sql_numrows($result);	
	
			if( $num_rows > 0 )
			{
				for ($i = 0; $i < $num_rows; $i++)
				{
					if (strtolower(trim($row[$i]['extension'])) == strtolower(trim($extension)))
					{
						$error = TRUE;
						if( isset($error_msg) )
						{
							$error_msg .= '<br />';
						}
						$error_msg .= sprintf($lang['Extension_exist_forbidden'], $extension);
					}
				}
			}
		}

		if (!$error)
		{
			$sql = "INSERT INTO " . FORBIDDEN_EXTENSIONS_TABLE . " (extension)
			VALUES ('" . trim($extension) . "')";

			if ( !($db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Could not add forbidden extension', '', __LINE__, __FILE__, $sql);
			}
		
		}
	}

	if (!$error)
	{
		$message = $lang['Attach_config_updated'] . '<br /><br />' . sprintf($lang['Click_return_attach_config'], '<a href="' . append_sid("admin_extensions.$phpEx?mode=forbidden") . '">', '</a>') . '<br /><br />' . sprintf($lang['Click_return_admin_index'], '<a href="' . append_sid("index.$phpEx?pane=right") . '">', '</a>');

		message_die(GENERAL_MESSAGE, $message);
	}

}

if ($mode == 'forbidden')
{
	$template->set_filenames(array(
		'body' => 'admin/attach_forbidden_extensions.tpl')
	);

	$template->assign_vars(array(
		'S_ATTACH_ACTION' => append_sid('admin_extensions.' . $phpEx . '?mode=forbidden'),

		'L_EXTENSIONS_TITLE' => $lang['Manage_forbidden_extensions'],
		'L_EXTENSIONS_EXPLAIN' => $lang['Manage_forbidden_extensions_explain'],
		'L_EXTENSION' => $lang['Extension'],
		'L_ADD_NEW' => $lang['Add_new'],
		'L_DELETE' => $lang['Delete'])
	);

	$sql = "SELECT *
	FROM " . FORBIDDEN_EXTENSIONS_TABLE . "
	ORDER BY extension";
	
	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Could not get forbidden extension informations', '', __LINE__, __FILE__, $sql);
	}

	$extensionrow = $db->sql_fetchrowset($result);
	$num_extensionrow = $db->sql_numrows($result);

	if ( $num_extensionrow > 0 )
	{
		for ($i = 0; $i < $num_extensionrow; $i++)
		{
			if (!strstr($extensionrow[$i]['extension'], 'php'))
			{
				$template->assign_block_vars('extensionrow', array(
					'EXTENSION_ID' => $extensionrow[$i]['ext_id'],
					'EXTENSION_NAME' => $extensionrow[$i]['extension'])
				);
			}
		}
	}
}

if ($e_mode == 'perm')
{
	$group = get_var('e_group', 0);

	$add_forum = (isset($HTTP_POST_VARS['add_forum'])) ? TRUE : FALSE;
	$delete_forum = (isset($HTTP_POST_VARS['del_forum'])) ? TRUE : FALSE;

	if (isset($HTTP_POST_VARS['close_perm']))
	{
		$e_mode = '';
	}
}

// Add Forums
if ($add_forum && $e_mode == 'perm' && $group)
{
	$add_forums_list = ( isset($HTTP_POST_VARS['entries']) ) ? $HTTP_POST_VARS['entries'] : array();
	$add_all_forums = FALSE;

	for ($i = 0; $i < count($add_forums_list); $i++)
	{
		if ($add_forums_list[$i] == GPERM_ALL)
		{
			$add_all_forums = TRUE;
		}
	}

	// If we add ALL FORUMS, we are able to overwrite the Permissions
	if ($add_all_forums)
	{
		$sql = "UPDATE " . EXTENSION_GROUPS_TABLE . " SET forum_permissions = '' WHERE group_id = " . $group;
		if ( !($result = $db->sql_query($sql)) )
		{
			message_die(GENERAL_ERROR, 'Could not update Permissions', '', __LINE__, __FILE__, $sql);
		}
	}

	// Else we have to add Permissions
	if (!$add_all_forums)
	{
		$sql = "SELECT forum_permissions
		FROM " . EXTENSION_GROUPS_TABLE . "
		WHERE group_id = " . intval($group) . "
		LIMIT 1";
	
		if ( !($result = $db->sql_query($sql)) )
		{
			message_die(GENERAL_ERROR, 'Could not get Group Permissions from ' . EXTENSION_GROUPS_TABLE, '', __LINE__, __FILE__, $sql);
		}

		$row = $db->sql_fetchrow($result);

		if (trim($row['forum_permissions']) == '')
		{
			$auth_p = array();
		}
		else
		{
			$auth_p = auth_unpack($row['forum_permissions']);
		}
		
		// Generate array for Auth_Pack, do not add doubled forums
		for ($i = 0; $i < count($add_forums_list); $i++)
		{
			if (!in_array($add_forums_list[$i], $auth_p))
			{
				$auth_p[] = $add_forums_list[$i];
			}
		}

		$auth_bitstream = auth_pack($auth_p);
		$sql = "UPDATE " . EXTENSION_GROUPS_TABLE . " SET forum_permissions = '" . $auth_bitstream . "' WHERE group_id = " . $group;
		if ( !($result = $db->sql_query($sql)) )
		{
			message_die(GENERAL_ERROR, 'Could not update Permissions', '', __LINE__, __FILE__, $sql);
		}
	}

}

// Delete Forums
if ($delete_forum && $e_mode == 'perm' && $group)
{
	$delete_forums_list = ( isset($HTTP_POST_VARS['entries']) ) ? $HTTP_POST_VARS['entries'] : array();

	// Get the current Forums
	$sql = "SELECT forum_permissions
	FROM " . EXTENSION_GROUPS_TABLE . "
	WHERE group_id = " . intval($group) . "
	LIMIT 1";
	
	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Could not get Group Permissions from ' . EXTENSION_GROUPS_TABLE, '', __LINE__, __FILE__, $sql);
	}

	$row = $db->sql_fetchrow($result);

	$auth_p2 = auth_unpack(trim($row['forum_permissions']));
	$auth_p = array();

	// Generate array for Auth_Pack, delete the chosen ones
	for ($i = 0; $i < count($auth_p2); $i++)
	{
		if (!in_array($auth_p2[$i], $delete_forums_list))
		{
			$auth_p[] = $auth_p2[$i];
		}
	}

	$auth_bitstream = ( count($auth_p) > 0 ) ? auth_pack($auth_p) : '';

	$sql = "UPDATE " . EXTENSION_GROUPS_TABLE . " SET forum_permissions = '" . $auth_bitstream . "' WHERE group_id = " . $group;
	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Could not update Permissions', '', __LINE__, __FILE__, $sql);
	}
}

// Display the Group Permissions Box for configuring it
if ($e_mode == 'perm' && $group)
{
	
	$template->set_filenames(array(
		'perm_box' => 'admin/extension_groups_permissions.tpl')
	);
	
	$sql = "SELECT group_name, forum_permissions
	FROM " . EXTENSION_GROUPS_TABLE . "
	WHERE group_id = " . intval($group) . "
	LIMIT 1";
	
	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Could not get Group Name from ' . EXTENSION_GROUPS_TABLE, '', __LINE__, __FILE__, $sql);
	}

	$row = $db->sql_fetchrow($result);
	$group_name = $row['group_name'];
	$allowed_forums = trim($row['forum_permissions']);

	$forum_perm = array();

	if ($allowed_forums == '')
	{
		$forum_perm[0]['forum_id'] = 0;
		$forum_perm[0]['forum_name'] = $lang['Perm_all_forums'];
	}
	else
	{
		$forum_p = array();
		$act_id = 0;
		$forum_p = auth_unpack($allowed_forums);
		$sql = "SELECT forum_id, forum_name FROM " . FORUMS_TABLE . " WHERE forum_id IN (" . implode(', ', $forum_p) . ")";
		if ( !($result = $db->sql_query($sql)) )
		{
			message_die(GENERAL_ERROR, 'Could not get Forum Names', '', __LINE__, __FILE__, $sql);
		}

		while ($row = $db->sql_fetchrow($result))
		{
			$forum_perm[$act_id]['forum_id'] = $row['forum_id'];
			$forum_perm[$act_id]['forum_name'] = $row['forum_name'];
			$act_id++;
		}
	}

	for ($i = 0; $i < count($forum_perm); $i++)
	{
		$template->assign_block_vars('allow_option_values', array(
			'VALUE' => $forum_perm[$i]['forum_id'],
			'OPTION' => $forum_perm[$i]['forum_name'])
		);
	}

	$template->assign_vars(array(
		'L_GROUP_PERMISSIONS_TITLE' => sprintf($lang['Group_permissions_title'], trim($group_name)),
		'L_GROUP_PERMISSIONS_EXPLAIN' => $lang['Group_permissions_explain'],
		'L_REMOVE_SELECTED' => $lang['Remove_selected'],
		'L_CLOSE_WINDOW' => $lang['Close_window'],
		'L_ADD_FORUMS' => $lang['Add_forums'],
		'L_ADD_SELECTED' => $lang['Add_selected'],
		'L_RESET' => $lang['Reset'],
		'A_PERM_ACTION' => append_sid("admin_extensions.$phpEx?mode=groups&amp;e_mode=perm&amp;e_group=$group"))
	);

	$forum_option_values = array(GPERM_ALL => $lang['Perm_all_forums']);

	$sql = "SELECT forum_id, forum_name FROM " . FORUMS_TABLE;

	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Could not get Forums', '', __LINE__, __FILE__, $sql);
	}

	while ($row = $db->sql_fetchrow($result))
	{
		$forum_option_values[intval($row['forum_id'])] = $row['forum_name'];
	}

	@reset($forum_option_values);
	
	while (list($value, $option) = each($forum_option_values))
	{
		$template->assign_block_vars('forum_option_values', array(
			'VALUE' => $value,
			'OPTION' => $option)
		);
	}

	$template->assign_var_from_handle('GROUP_PERMISSIONS_BOX', 'perm_box');

	$empty_perm_forums = array();


	$sql = "SELECT forum_id, forum_name FROM " . FORUMS_TABLE . " WHERE auth_attachments < " . AUTH_ADMIN;

	if ( !($f_result = $db->sql_query($sql)) ) 
	{ 
		message_die(GENERAL_ERROR, 'Could not get Forums.', '', __LINE__, __FILE__, $sql); 
	} 
	
	while ($row = $db->sql_fetchrow($f_result))
	{
		$forum_id = $row['forum_id'];

		$sql = "SELECT forum_permissions
		FROM " . EXTENSION_GROUPS_TABLE . " 
		WHERE allow_group = 1 
		ORDER BY group_name ASC";

		if ( !($result = $db->sql_query($sql)) ) 
		{ 
			message_die(GENERAL_ERROR, 'Could not query Extension Groups.', '', __LINE__, __FILE__, $sql); 
		} 

		$rows = $db->sql_fetchrowset($result); 
		$num_rows = $db->sql_numrows($result); 

		$found_forum = FALSE;

		for ($i = 0; $i < $num_rows; $i++)
		{
			$allowed_forums = auth_unpack(trim($rows[$i]['forum_permissions']));
			if ( (in_array($forum_id, $allowed_forums)) || (trim($rows[$i]['forum_permissions']) == '') )
			{
				$found_forum = TRUE;
				break;
			}
		}

		if (!$found_forum)
		{
			$empty_perm_forums[$forum_id] = $row['forum_name'];
		}
	}

	@reset($empty_perm_forums);
	$message = '';
	
	while (list($forum_id, $forum_name) = each($empty_perm_forums))
	{
		$message .= ( $message == '' ) ? $forum_name : '<br />' . $forum_name;
	}

	if (count($empty_perm_forums) > 0)
	{
		$template->set_filenames(array(
			'perm_reg_header' => 'error_body.tpl')
		);
	
		$template->assign_vars(array(
			'ERROR_MESSAGE' => $lang['Note_admin_empty_group_permissions'] . $message)
		);
	
		$template->assign_var_from_handle('PERM_ERROR_BOX', 'perm_reg_header');
	}
}

if ($error)
{
	$template->set_filenames(array(
		'reg_header' => 'error_body.tpl')
	);
	
	$template->assign_vars(array(
		'ERROR_MESSAGE' => $error_msg)
	);
	
	$template->assign_var_from_handle('ERROR_BOX', 'reg_header');
}

$template->assign_vars(array(
	'ATTACH_VERSION' => sprintf($lang['Attachment_version'], $attach_config['attach_version']))
);

$template->pparse('body');

include('page_footer_admin.'.$phpEx);

?>
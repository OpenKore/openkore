<?php
/***************************************************************************
 *							admin_attach_cp.php
 *							-------------------
 *	begin				: Saturday, Feb 09, 2002
 *	copyright			: (C) 2002 Meik Sievertsen
 *	email				: acyd.burn@gmx.de
 *
 *	$Id: admin_attach_cp.php,v 1.26 2005/07/16 14:32:20 acydburn Exp $
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
	$module['Attachments']['Control_Panel'] = $filename;
	return;
}

//
// Let's set the root dir for phpBB
//
$phpbb_root_path = './../';
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
// Init Variables
//
$start = get_var('start', 0);

if(isset($HTTP_POST_VARS['order']))
{
	$sort_order = ($HTTP_POST_VARS['order'] == 'ASC') ? 'ASC' : 'DESC';
}
else if(isset($HTTP_GET_VARS['order']))
{
	$sort_order = ($HTTP_GET_VARS['order'] == 'ASC') ? 'ASC' : 'DESC';
}
else
{
	$sort_order = '';
}

$mode = get_var('mode', '');
$view = get_var('view', '');

if(isset($HTTP_GET_VARS['uid']) || isset($HTTP_POST_VARS['u_id']))
{
	$uid = (isset($HTTP_POST_VARS['u_id'])) ? $HTTP_POST_VARS['u_id'] : $HTTP_GET_VARS['uid'];
}
else
{
	$uid = '';
}

$view = ( $HTTP_POST_VARS['search'] ) ? 'attachments' : $view;

//
// process modes based on view
//
if ($view == 'username')
{
	$mode_types_text = array($lang['Sort_Username'], $lang['Sort_Attachments'], $lang['Sort_Size']);
	$mode_types = array('username', 'attachments', 'filesize');

	if (empty($mode))
	{
		$mode = 'attachments';
		$sort_order = 'DESC';
	}
}
else if ($view == 'attachments')
{
	$mode_types_text = array($lang['Sort_Filename'], $lang['Sort_Comment'], $lang['Sort_Extension'], $lang['Sort_Size'], $lang['Sort_Downloads'], $lang['Sort_Posttime'], /*$lang['Sort_Posts']*/);
	$mode_types = array('real_filename', 'comment', 'extension', 'filesize', 'downloads', 'post_time'/*, 'posts'*/);

	if (empty($mode))
	{
		$mode = 'real_filename';
		$sort_order = 'ASC';
	}
}
else if ($view == 'search')
{
	$mode_types_text = array($lang['Sort_Filename'], $lang['Sort_Comment'], $lang['Sort_Extension'], $lang['Sort_Size'], $lang['Sort_Downloads'], $lang['Sort_Posttime'], /*$lang['Sort_Posts']*/);
	$mode_types = array('real_filename', 'comment', 'extension', 'filesize', 'downloads', 'post_time'/*, 'posts'*/);

	$sort_order = 'DESC';
}
else
{
	$view = 'stats';
	$mode_types_text = array();
	$sort_order = '';
}


//
// Pagination ?
//
$do_pagination = ( ($view != 'stats') && ($view != 'search') ) ? TRUE : FALSE;

//
// Set Order
//
$order_by = '';

if ($view == 'username')
{
	switch($mode)
	{
		case 'username':
			$order_by = 'ORDER BY u.username ' . $sort_order . ' LIMIT ' . $start . ', ' . $board_config['topics_per_page'];
			break;
		case 'attachments':
			$order_by = 'ORDER BY total_attachments ' . $sort_order . ' LIMIT ' . $start . ', ' . $board_config['topics_per_page'];
			break;
		case 'filesize':
			$order_by = 'ORDER BY total_size ' . $sort_order . ' LIMIT ' . $start . ', ' . $board_config['topics_per_page'];
			break;
		default:
			$mode = 'attachments';
			$sort_order = 'DESC';
			$order_by = 'ORDER BY total_attachments ' . $sort_order . ' LIMIT ' . $start . ', ' . $board_config['topics_per_page'];
			break;
	}
}
else if ($view == 'attachments')
{
	switch($mode)
	{
		case 'filename':
			$order_by = 'ORDER BY a.real_filename ' . $sort_order . ' LIMIT ' . $start . ', ' . $board_config['topics_per_page'];
			break;
		case 'comment':
			$order_by = 'ORDER BY a.comment ' . $sort_order . ' LIMIT ' . $start . ', ' . $board_config['topics_per_page'];
			break;
		case 'extension':
			$order_by = 'ORDER BY a.extension ' . $sort_order . ' LIMIT ' . $start . ', ' . $board_config['topics_per_page'];
			break;
		case 'filesize':
			$order_by = 'ORDER BY a.filesize ' . $sort_order . ' LIMIT ' . $start . ', ' . $board_config['topics_per_page'];
			break;
		case 'downloads':
			$order_by = 'ORDER BY a.download_count ' . $sort_order . ' LIMIT ' . $start . ', ' . $board_config['topics_per_page'];
			break;
		case 'post_time':
			$order_by = 'ORDER BY a.filetime ' . $sort_order . ' LIMIT ' . $start . ', ' . $board_config['topics_per_page'];
			break;
		default:
			$mode = 'a.real_filename';
			$sort_order = 'ASC';
			$order_by = 'ORDER BY a.real_filename ' . $sort_order . ' LIMIT ' . $start . ', ' . $board_config['topics_per_page'];
			break;
	}
}

//
// Set select fields
//
$view_types_text = array($lang['View_Statistic'], $lang['View_Search'], $lang['View_Username'], $lang['View_Attachments']);
$view_types = array('stats', 'search', 'username', 'attachments');

$select_view = '<select name="view">';

for($i = 0; $i < count($view_types_text); $i++)
{
	$selected = ($view == $view_types[$i]) ? ' selected="selected"' : '';
	$select_view .= '<option value="' . $view_types[$i] . '"' . $selected . '>' . $view_types_text[$i] . '</option>';
}
$select_view .= '</select>';

if (count($mode_types_text) > 0)
{
	$select_sort_mode = '<select name="mode">';

	for($i = 0; $i < count($mode_types_text); $i++)
	{
		$selected = ($mode == $mode_types[$i]) ? ' selected="selected"' : '';
		$select_sort_mode .= '<option value="' . $mode_types[$i] . '"' . $selected . '>' . $mode_types_text[$i] . '</option>';
	}
	$select_sort_mode .= '</select>';
}

if (!empty($sort_order))
{
	$select_sort_order = '<select name="order">';
	if($sort_order == 'ASC')
	{
		$select_sort_order .= '<option value="ASC" selected="selected">' . $lang['Sort_Ascending'] . '</option><option value="DESC">' . $lang['Sort_Descending'] . '</option>';
	}
	else
	{
		$select_sort_order .= '<option value="ASC">' . $lang['Sort_Ascending'] . '</option><option value="DESC" selected="selected">' . $lang['Sort_Descending'] . '</option>';
	}
	$select_sort_order .= '</select>';
}

$submit_change = ( isset($HTTP_POST_VARS['submit_change']) ) ? TRUE : FALSE;
$delete = ( isset($HTTP_POST_VARS['delete']) ) ? TRUE : FALSE;
$delete_id_list = ( isset($HTTP_POST_VARS['delete_id_list']) ) ? array_map('intval', $HTTP_POST_VARS['delete_id_list']) : array();

$confirm = ( $HTTP_POST_VARS['confirm'] ) ? TRUE : FALSE;

if ($confirm && sizeof($delete_id_list) > 0)
{
	$attachments = array();

	delete_attachment(0, $delete_id_list);
}
else if ( ($delete) && (count($delete_id_list)) > 0 )
{
	//
	// Not confirmed, show confirmation message
	//	
	$hidden_fields = '<input type="hidden" name="view" value="' . $view . '" />';
	$hidden_fields .= '<input type="hidden" name="mode" value="' . $mode . '" />';
	$hidden_fields .= '<input type="hidden" name="order" value="' . $sort_order . '" />';
	$hidden_fields .= '<input type="hidden" name="u_id" value="' . $uid . '" />';
	$hidden_fields .= '<input type="hidden" name="start" value="' . $start . '" />';

	for($i = 0; $i < count($delete_id_list); $i++)
	{
		$hidden_fields .= '<input type="hidden" name="delete_id_list[]" value="' . $delete_id_list[$i] . '" />';
	}

	$template->set_filenames(array(
		'confirm' => 'confirm_body.tpl')
	);

	$template->assign_vars(array(
		'MESSAGE_TITLE' => $lang['Confirm'],
		'MESSAGE_TEXT' => $lang['Confirm_delete_attachments'],

		'L_YES' => $lang['Yes'],
		'L_NO' => $lang['No'],

		'S_CONFIRM_ACTION' => append_sid('admin_attach_cp.' . $phpEx),
		'S_HIDDEN_FIELDS' => $hidden_fields)
	);

	$template->pparse('confirm');
	
	include('page_footer_admin.'.$phpEx);

	exit;
}

//
// Assign Default Template Vars
//
$template->assign_vars(array(
	'L_VIEW' => $lang['View'],
	'L_SUBMIT' => $lang['Submit'],
	'L_CONTROL_PANEL_TITLE' => $lang['Control_panel_title'],
	'L_CONTROL_PANEL_EXPLAIN' => $lang['Control_panel_explain'],

	'S_VIEW_SELECT' => $select_view,
	'S_MODE_ACTION' => append_sid('admin_attach_cp.' . $phpEx))
);

if ($submit_change && $view == 'attachments')
{
	$attach_change_list = ( isset($HTTP_POST_VARS['attach_id_list']) ) ? array_map('intval', $HTTP_POST_VARS['attach_id_list']) : array();
	$attach_comment_list = ( isset($HTTP_POST_VARS['attach_comment_list']) ) ? $HTTP_POST_VARS['attach_comment_list'] : array();
	$attach_download_count_list = ( isset($HTTP_POST_VARS['attach_count_list']) ) ? array_map('intval', $HTTP_POST_VARS['attach_count_list']) : array();

	//
	// Generate correct Change List
	//
	$attachments = array();

	for ($i = 0; $i < count($attach_change_list); $i++)
	{
		$attachments['_' . $attach_change_list[$i]]['comment'] = stripslashes(htmlspecialchars($attach_comment_list[$i]));
		$attachments['_' . $attach_change_list[$i]]['download_count'] = intval($attach_download_count_list[$i]);
	}

	$sql = "SELECT *
	FROM " . ATTACHMENTS_DESC_TABLE . "
	ORDER BY attach_id";

	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Couldn\'t get Attachment informations', '', __LINE__, __FILE__, $sql);
	}

	while ( $attachrow = $db->sql_fetchrow($result) )
	{
		if ( isset($attachments['_' . $attachrow['attach_id']]) )
		{
			if ( ($attachrow['comment'] != $attachments['_' . $attachrow['attach_id']]['comment']) || (intval($attachrow['download_count']) != intval($attachments['_' . $attachrow['attach_id']]['download_count'])) )
			{
				$sql = "UPDATE " . ATTACHMENTS_DESC_TABLE . " 
				SET comment = '" . $attachments['_' . $attachrow['attach_id']]['comment'] . "', download_count = " . intval($attachments['_' . $attachrow['attach_id']]['download_count']) . "
				WHERE attach_id = " . $attachrow['attach_id'];
				
				if (!$db->sql_query($sql))
				{
					message_die(GENERAL_ERROR, 'Couldn\'t update Attachments Informations', '', __LINE__, __FILE__, $sql);
				}
			}
		}
	}
}

//
// Statistics
//
if ($view == 'stats')
{

	$template->set_filenames(array(
		'body' => 'admin/attach_cp_body.tpl')
	);

	$upload_dir_size = get_formatted_dirsize();

	if ($attach_config['attachment_quota'] >= 1048576)
	{
		$attachment_quota = round($attach_config['attachment_quota'] / 1048576 * 100) / 100 . ' ' . $lang['MB'];
	}
	else if ($attach_config['attachment_quota'] >= 1024)
	{
		$attachment_quota = round($attach_config['attachment_quota'] / 1024 * 100) / 100 . ' ' . $lang['KB'];
	}
	else
	{
		$attachment_quota = $attach_config['attachment_quota'] . ' ' . $lang['Bytes'];
	}

	$sql = "SELECT count(*) AS total
	FROM " . ATTACHMENTS_DESC_TABLE;

	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Error getting total attachments', '', __LINE__, __FILE__, $sql);
	}

	$total = $db->sql_fetchrow($result);
	$number_of_attachments = $total['total'];

	$sql = "SELECT post_id
	FROM " . ATTACHMENTS_TABLE . "
	WHERE post_id <> 0
	GROUP BY post_id";

	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Error getting total posts', '', __LINE__, __FILE__, $sql);
	}

	$number_of_posts = $db->sql_numrows($result);

	$sql = "SELECT privmsgs_id
	FROM " . ATTACHMENTS_TABLE . "
	WHERE privmsgs_id <> 0
	GROUP BY privmsgs_id";

	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Error getting total private messages', '', __LINE__, __FILE__, $sql);
	}

	$number_of_pms = $db->sql_numrows($result);

	$sql = "SELECT p.topic_id
	FROM " . ATTACHMENTS_TABLE . " a, " . POSTS_TABLE . " p
	WHERE a.post_id = p.post_id
	GROUP BY p.topic_id";

	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Error getting total topics', '', __LINE__, __FILE__, $sql);
	}

	$number_of_topics = $db->sql_numrows($result);

	$sql = "SELECT user_id_1
	FROM " . ATTACHMENTS_TABLE . "
	WHERE (post_id <> 0)
	GROUP BY user_id_1";

	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Error getting total users', '', __LINE__, __FILE__, $sql);
	}

	$number_of_users = $db->sql_numrows($result);

	$template->assign_vars(array(
		'L_STATISTIC' => $lang['Statistic'],
		'L_VALUE' => $lang['Value'],
		'L_NUMBER_OF_ATTACHMENTS' => $lang['Number_of_attachments'],
		'L_TOTAL_FILESIZE' => $lang['Total_filesize'],
		'L_ATTACH_QUOTA' => $lang['Attach_quota'],
		'L_NUMBER_OF_POSTS' => $lang['Number_posts_attach'],
		'L_NUMBER_OF_PMS' => $lang['Number_pms_attach'],
		'L_NUMBER_OF_TOPICS' => $lang['Number_topics_attach'],
		'L_NUMBER_OF_USERS' => $lang['Number_users_attach'],
		
		'TOTAL_FILESIZE' => $upload_dir_size,
		'ATTACH_QUOTA' => $attachment_quota,
		'NUMBER_OF_ATTACHMENTS' => $number_of_attachments,
		'NUMBER_OF_POSTS' => $number_of_posts,
		'NUMBER_OF_PMS' => $number_of_pms,
		'NUMBER_OF_TOPICS' => $number_of_topics,
		'NUMBER_OF_USERS' => $number_of_users)
	);

}

//
// Search
//
if ($view == 'search')
{

	//
	// Get Forums and Categories
	//
	$sql = "SELECT c.cat_title, c.cat_id, f.forum_name, f.forum_id  
	FROM " . CATEGORIES_TABLE . " c, " . FORUMS_TABLE . " f
	WHERE f.cat_id = c.cat_id 
	ORDER BY c.cat_id, f.forum_order";

	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Could not obtain forum_name/forum_id', '', __LINE__, __FILE__, $sql);
	}

	$s_forums = '';
	while ($row = $db->sql_fetchrow($result))
	{
		$s_forums .= '<option value="' . $row['forum_id'] . '">' . $row['forum_name'] . '</option>';

		if( empty($list_cat[$row['cat_id']]) )
		{
			$list_cat[$row['cat_id']] = $row['cat_title'];
		}
	}

	if( $s_forums != '' )
	{
		$s_forums = '<option value="0">' . $lang['All_available'] . '</option>' . $s_forums;

		//
		// Category to search
		//
		$s_categories = '<option value="0">' . $lang['All_available'] . '</option>';
		@reset($list_cat);
		while( list($cat_id, $cat_title) = @each($list_cat))
		{
			$s_categories .= '<option value="' . $cat_id . '">' . $cat_title . '</option>';
		}
	}
	else
	{
		message_die(GENERAL_MESSAGE, $lang['No_searchable_forums']);
	}
	
	$template->set_filenames(array(
		'body' => 'admin/attach_cp_search.tpl')
	);

	$template->assign_vars(array(
		'L_ATTACH_SEARCH_QUERY' => $lang['Attach_search_query'],
		'L_FILENAME' => $lang['File_name'],
		'L_COMMENT' => $lang['File_comment'],
		'L_SEARCH_OPTIONS' => $lang['Search_options'],
		'L_SEARCH_AUTHOR' => $lang['Search_author'],
		'L_WILDCARD_EXPLAIN' => $lang['Search_wildcard_explain'],
		'L_SIZE_SMALLER_THAN' => $lang['Size_smaller_than'],		
		'L_SIZE_GREATER_THAN' => $lang['Size_greater_than'],
		'L_COUNT_SMALLER_THAN' => $lang['Count_smaller_than'],		
		'L_COUNT_GREATER_THAN' => $lang['Count_greater_than'],
		'L_MORE_DAYS_OLD' => $lang['More_days_old'],
		'L_CATEGORY' => $lang['Category'], 
		'L_ORDER' => $lang['Order'],
		'L_SORT_BY' => $lang['Select_sort_method'],
		'L_FORUM' => $lang['Forum'],
		'L_SEARCH' => $lang['Search'],

		'S_FORUM_OPTIONS' => $s_forums, 
		'S_CATEGORY_OPTIONS' => $s_categories,
		'S_SORT_OPTIONS' => $select_sort_mode,
		'S_SORT_ORDER' => $select_sort_order)
	);
}

//
// Username
//
if ($view == 'username')
{

	$template->set_filenames(array(
		'body' => 'admin/attach_cp_user.tpl')
	);

	$template->assign_vars(array(
		'L_SELECT_SORT_METHOD' => $lang['Select_sort_method'],
		'L_ORDER' => $lang['Order'],
		'L_USERNAME' => $lang['Username'],
		'L_TOTAL_SIZE' => $lang['Size_in_kb'],
		'L_ATTACHMENTS' => $lang['Attachments'],

		'S_MODE_SELECT' => $select_sort_mode,
		'S_ORDER_SELECT' => $select_sort_order)
	);


	//
	// Get all Users with their respective total attachments amount
	//
	$sql = "SELECT u.username, a.user_id_1 as user_id, count(*) as total_attachments
	FROM " . ATTACHMENTS_TABLE . " a, " . USERS_TABLE . " u
	WHERE (a.user_id_1 = u.user_id)
	GROUP BY a.user_id_1, u.username"; 

	if ($mode != 'filesize')
	{
		$sql .= ' ' . $order_by;
	}
	
	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Couldn\'t query attachments', '', __LINE__, __FILE__, $sql);
	}

	$members = $db->sql_fetchrowset($result);
	$num_members = $db->sql_numrows($result);

	if ( $num_members > 0 )
	{
		for ($i = 0; $i < $num_members; $i++)
		{
			//
			// Get all attach_id's the specific user posted
			//
			$sql = "SELECT attach_id 
			FROM " . ATTACHMENTS_TABLE . "
			WHERE (user_id_1 = " . intval($members[$i]['user_id']) . ") 
			GROUP BY attach_id";
		
			if ( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Couldn\'t query attachments', '', __LINE__, __FILE__, $sql);
			}
		
			$attach_ids = $db->sql_fetchrowset($result);
			$num_attach_ids = $db->sql_numrows($result);
			$attach_id = array();

			for ($j = 0; $j < $num_attach_ids; $j++)
			{
				$attach_id[] = intval($attach_ids[$j]['attach_id']);
			}
			
			//
			// Now get the total filesize
			//
			$sql = "SELECT sum(filesize) as total_size
			FROM " . ATTACHMENTS_DESC_TABLE . "
			WHERE attach_id IN (" . implode(', ', $attach_id) . ")";

			if ( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Couldn\'t query attachments', '', __LINE__, __FILE__, $sql);
			}

			$row = $db->sql_fetchrow($result);
			$members[$i]['total_size'] = (int) $row['total_size'];
		}
		
		if ($mode == 'filesize')
		{
			$members = sort_multi_array($members, 'total_size', $sort_order, FALSE);
			$members = limit_array($members, $start, $board_config['topics_per_page']);
		}
		
		for ($i = 0; $i < count($members); $i++)
		{
			$username = $members[$i]['username'];
			$total_attachments = $members[$i]['total_attachments'];
			$total_size = $members[$i]['total_size'];

			$row_color = ( !($i % 2) ) ? $theme['td_color1'] : $theme['td_color2'];
			$row_class = ( !($i % 2) ) ? $theme['td_class1'] : $theme['td_class2'];

			$template->assign_block_vars('memberrow', array(
				'ROW_NUMBER' => $i + ( $HTTP_GET_VARS['start'] + 1 ),
				'ROW_COLOR' => '#' . $row_color,
				'ROW_CLASS' => $row_class,
				'USERNAME' => $username,
				'TOTAL_ATTACHMENTS' => $total_attachments,
				'TOTAL_SIZE' => round(($total_size / MEGABYTE), 2),
				'U_VIEW_MEMBER' => append_sid('admin_attach_cp.' . $phpEx . '?view=attachments&amp;uid=' . $members[$i]['user_id']))
			);
		}
	}

	$sql = "SELECT user_id_1
	FROM " . ATTACHMENTS_TABLE . "
	GROUP BY user_id_1";

	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Error getting total users', '', __LINE__, __FILE__, $sql);
	}

	$total_rows = $db->sql_numrows($result);
}

//
// Attachments
//
if ($view == 'attachments')
{
	$user_based = ( !empty($uid) ) ? TRUE : FALSE;
	$search_based = ( $HTTP_POST_VARS['search'] ) ? TRUE : FALSE;
	
	$hidden_fields = '';
	
	$template->set_filenames(array(
		'body' => 'admin/attach_cp_attachments.tpl')
	);

	$template->assign_vars(array(
		'L_SELECT_SORT_METHOD' => $lang['Select_sort_method'],
		'L_ORDER' => $lang['Order'],

		'L_FILENAME' => $lang['File_name'],
		'L_FILECOMMENT' => $lang['File_comment_cp'],
		'L_EXTENSION' => $lang['Extension'],
		'L_SIZE' => $lang['Size_in_kb'],
		'L_DOWNLOADS' => $lang['Downloads'],
		'L_POST_TIME' => $lang['Post_time'],
		'L_POSTED_IN_TOPIC' => $lang['Posted_in_topic'],
		'L_DELETE' => $lang['Delete'],
		'L_DELETE_MARKED' => $lang['Delete_marked'],
		'L_SUBMIT_CHANGES' => $lang['Submit_changes'],
		'L_MARK_ALL' => $lang['Mark_all'],
		'L_UNMARK_ALL' => $lang['Unmark_all'],

		'S_MODE_SELECT' => $select_sort_mode,
		'S_ORDER_SELECT' => $select_sort_order)
	);

	$total_rows = 0;
	
	// 
	// Are we called from Username ?
	//
	if ($user_based)
	{
		$sql = "SELECT username 
		FROM " . USERS_TABLE . " 
		WHERE user_id = " . intval($uid);

		if ( !($result = $db->sql_query($sql)) )
		{
			message_die(GENERAL_ERROR, 'Error getting username', '', __LINE__, __FILE__, $sql);
		}

		$row = $db->sql_fetchrow($result);
		$username = $row['username'];

		$s_hidden = '<input type="hidden" name="u_id" value="' . intval($uid) . '">';
	
		$template->assign_block_vars('switch_user_based', array());

		$template->assign_vars(array(
			'S_USER_HIDDEN' => $s_hidden,
			'L_STATISTICS_FOR_USER' => sprintf($lang['Statistics_for_user'], $username))
		);

		$sql = "SELECT attach_id 
		FROM " . ATTACHMENTS_TABLE . "
		WHERE user_id_1 = " . intval($uid) . "
		GROUP BY attach_id";
		
		if ( !($result = $db->sql_query($sql)) )
		{
			message_die(GENERAL_ERROR, 'Couldn\'t query attachments', '', __LINE__, __FILE__, $sql);
		}
		
		$attach_ids = $db->sql_fetchrowset($result);
		$num_attach_ids = $db->sql_numrows($result);

		if ($num_attach_ids == 0)
		{
			message_die(GENERAL_MESSAGE, 'For some reason no Attachments are assigned to the User "' . $username . '".');
		}
		
		$total_rows = $num_attach_ids;

		$attach_id = array();

		for ($j = 0; $j < $num_attach_ids; $j++)
		{
			$attach_id[] = intval($attach_ids[$j]['attach_id']);
		}
			
		$sql = "SELECT a.*
		FROM " . ATTACHMENTS_DESC_TABLE . " a
		WHERE a.attach_id IN (" . implode(', ', $attach_id) . ") " .
		$order_by;
		
	}
	else if ($search_based)
	{
		//
		// we are called from search
		//
		$attachments = search_attachments($order_by, $total_rows);
	}
	else
	{
		$sql = "SELECT a.*
		FROM " . ATTACHMENTS_DESC_TABLE . " a " .
		$order_by;
	}

	if (!$search_based)
	{
		if ( !($result = $db->sql_query($sql)) )
		{
			message_die(GENERAL_ERROR, 'Couldn\'t query attachments', '', __LINE__, __FILE__, $sql);
		}

		$attachments = $db->sql_fetchrowset($result);
		$num_attach = $db->sql_numrows($result);
	}
	
	if (count($attachments) > 0)
	{
		for ($i = 0; $i < count($attachments); $i++)
		{
			$delete_box = '<input type="checkbox" name="delete_id_list[]" value="' . intval($attachments[$i]['attach_id']) . '" />';

			for ($j = 0; $j < count($delete_id_list); $j++)
			{
				if ($delete_id_list[$j] == $attachments[$i]['attach_id'])
				{
					$delete_box = '<input type="checkbox" name="delete_id_list[]" value="' . intval($attachments[$i]['attach_id']) . '" checked />';
					break;
				}
			}

			$row_color = ( !($i % 2) ) ? $theme['td_color1'] : $theme['td_color2'];
			$row_class = ( !($i % 2) ) ? $theme['td_class1'] : $theme['td_class2'];

			//
			// Is the Attachment assigned to more than one post ?
			// If it's not assigned to any post, it's an private message thingy. ;)
			//
			$post_titles = array();

			$sql = "SELECT *
			FROM " . ATTACHMENTS_TABLE . "
			WHERE attach_id = " . intval($attachments[$i]['attach_id']);

			if ( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Couldn\'t query attachments', '', __LINE__, __FILE__, $sql);
			}

			$ids = $db->sql_fetchrowset($result);
			$num_ids = $db->sql_numrows($result);

			for ($j = 0; $j < $num_ids; $j++)
			{
				if ($ids[$j]['post_id'] != 0)
				{
					$sql = "SELECT t.topic_title
					FROM " . TOPICS_TABLE . " t, " . POSTS_TABLE . " p
					WHERE p.post_id = " . intval($ids[$j]['post_id']) . " AND p.topic_id = t.topic_id
					GROUP BY t.topic_id, t.topic_title";

					if ( !($result = $db->sql_query($sql)) )
					{
						message_die(GENERAL_ERROR, 'Couldn\'t query topic', '', __LINE__, __FILE__, $sql);
					}

					$row = $db->sql_fetchrow($result);
					$post_title = $row['topic_title'];

					if (strlen($post_title) > 32)
					{
						$post_title = substr($post_title, 0, 30) . '...';
					}

					$view_topic = append_sid('../viewtopic.' . $phpEx . '?' . POST_POST_URL . '=' . $ids[$j]['post_id'] . '#' . $ids[$j]['post_id']);

					$post_titles[] = '<a href="' . $view_topic . '" class="gen" target="_blank">' . $post_title . '</a>';
				}
				else
				{
					$post_titles[] = $lang['Private_Message'];
				}
			}

			$post_titles = implode('<br />', $post_titles);

			$hidden_field = '<input type="hidden" name="attach_id_list[]" value="' . intval($attachments[$i]['attach_id']) . '">';

			$template->assign_block_vars('attachrow', array(
				'ROW_NUMBER' => $i + ( $HTTP_GET_VARS['start'] + 1 ),
				'ROW_COLOR' => '#' . $row_color,
				'ROW_CLASS' => $row_class,

				'FILENAME' => htmlspecialchars($attachments[$i]['real_filename']),
				'COMMENT' => htmlspecialchars($attachments[$i]['comment']),
				'EXTENSION' => $attachments[$i]['extension'],
				'SIZE' => round(($attachments[$i]['filesize'] / MEGABYTE), 2),
				'DOWNLOAD_COUNT' => $attachments[$i]['download_count'],
				'POST_TIME' => create_date($board_config['default_dateformat'], $attachments[$i]['filetime'], $board_config['board_timezone']),
				'POST_TITLE' => $post_titles,

				'S_DELETE_BOX' => $delete_box,
				'S_HIDDEN' => $hidden_field,
				'U_VIEW_ATTACHMENT' => append_sid('../download.' . $phpEx . '?id=' . $attachments[$i]['attach_id']))
//				'U_VIEW_POST' => ($attachments[$i]['post_id'] != 0) ? append_sid("../viewtopic." . $phpEx . "?" . POST_POST_URL . "=" . $attachments[$i]['post_id'] . "#" . $attachments[$i]['post_id']) : '')
			);
			
		}
	}

	if ( (!$search_based) && (!$user_based) )
	{
		if ($total_attachments == 0)
		{
			$sql = "SELECT attach_id FROM " . ATTACHMENTS_DESC_TABLE;

			if ( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Could not query Attachment Description Table', '', __LINE__, __FILE__, $sql);
			}

			$total_rows = $db->sql_numrows($result);
		}
	}
}

//
// Generate Pagination
//
if ( ($do_pagination) && ($total_rows > $board_config['topics_per_page']) )
{
	$pagination = generate_pagination('admin_attach_cp.' . $phpEx . '?view=' . $view . '&amp;mode=' . $mode . '&amp;order=' . $sort_order . '&amp;uid=' . $uid, $total_rows, $board_config['topics_per_page'], $start).'&nbsp;';

	$template->assign_vars(array(
		'PAGINATION' => $pagination,
		'PAGE_NUMBER' => sprintf($lang['Page_of'], ( floor( $start / $board_config['topics_per_page'] ) + 1 ), ceil( $total_rows / $board_config['topics_per_page'] )), 

		'L_GOTO_PAGE' => $lang['Goto_page'])
	);
}

$template->assign_vars(array(
	'ATTACH_VERSION' => sprintf($lang['Attachment_version'], $attach_config['attach_version']))
);

$template->pparse('body');

include('page_footer_admin.'.$phpEx);

?>
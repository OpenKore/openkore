<?php
/***************************************************************************
 *                            functions_admin.php
 *                            -------------------
 *   begin                : Sunday, Mar 31, 2002
 *   copyright            : (C) 2002 Meik Sievertsen
 *   email                : acyd.burn@gmx.de
 *
 *   $Id: functions_admin.php,v 1.16 2004/11/30 17:56:11 acydburn Exp $
 *
 *
 ***************************************************************************/

/***************************************************************************
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 *
 ***************************************************************************/

//
// All Attachment Functions only needed in Admin
//

//
// Set/Change Quotas
//
function process_quota_settings($mode, $id, $quota_type, $quota_limit_id = 0)
{
	global $db;

	if ($mode == 'user')
	{
		if (!$quota_limit_id)
		{
			$sql = 'DELETE FROM ' . QUOTA_TABLE . " 
				WHERE user_id = $id 
					AND quota_type = $quota_type";
		}
		else
		{
			// Check if user is already entered
			$sql = 'SELECT user_id 
				FROM ' . QUOTA_TABLE . " 
				WHERE user_id = $id
					AND quota_type = $quota_type";

			if( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Could not get Entry', '', __LINE__, __FILE__, $sql);
			}

			if ($db->sql_numrows($result) == 0)
			{
				$sql = 'INSERT INTO ' . QUOTA_TABLE . " (user_id, group_id, quota_type, quota_limit_id) 
					VALUES ($id, 0, $quota_type, $quota_limit_id)";
			}
			else
			{
				$sql = 'UPDATE ' . QUOTA_TABLE . " 
					SET quota_limit_id = $quota_limit_id 
					WHERE user_id = $id 
						AND quota_type = $quota_type";
			}
		}
	
		if( !($result = $db->sql_query($sql)) )
		{
			message_die(GENERAL_ERROR, 'Unable to update quota Settings', '', __LINE__, __FILE__, $sql);
		}
		
	}
	else if ($mode == 'group')
	{
		if (!$quota_limit_id)
		{
			$sql = 'DELETE FROM ' . QUOTA_TABLE . " 
				WHERE group_id = $id 
					AND quota_type = $quota_type";

			if( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Unable to delete quota Settings', '', __LINE__, __FILE__, $sql);
			}
		}
		else
		{
			// Check if user is already entered
			$sql = 'SELECT group_id 
				FROM ' . QUOTA_TABLE . " 
				WHERE group_id = $id 
					AND quota_type = $quota_type";

			if( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Could not get Entry', '', __LINE__, __FILE__, $sql);
			}

			if ($db->sql_numrows($result) == 0)
			{
				$sql = 'INSERT INTO ' . QUOTA_TABLE . " (user_id, group_id, quota_type, quota_limit_id) 
					VALUES (0, $id, $quota_type, $quota_limit_id)";
			}
			else
			{
				$sql = 'UPDATE ' . QUOTA_TABLE . " SET quota_limit_id = $quota_limit_id 
					WHERE group_id = $id AND quota_type = $quota_type";
			}
	
			if (!$db->sql_query($sql))
			{
				message_die(GENERAL_ERROR, 'Unable to update quota Settings', '', __LINE__, __FILE__, $sql);
			}
		}
	}
}

//
// sort multi-dimensional Array
//
function sort_multi_array ($sort_array, $key, $sort_order, $pre_string_sort = 0) 
{
	$last_element = sizeof($sort_array) - 1;

	if (!$pre_string_sort)
	{
		$string_sort = (is_string($sort_array[$last_element-1][$key]) ) ? true : false;
	}
	else
	{
		$string_sort = $pre_string_sort;
	}

	for ($i = 0; $i < $last_element; $i++) 
	{
		$num_iterations = $last_element - $i;

		for ($j = 0; $j < $num_iterations; $j++) 
		{
			$next = 0;

			//
			// do checks based on key
			//
			$switch = false;
			if (!$string_sort)
			{
				if (($sort_order == 'DESC' && intval($sort_array[$j][$key]) < intval($sort_array[$j + 1][$key])) || ($sort_order == 'ASC' &&    intval($sort_array[$j][$key]) > intval($sort_array[$j + 1][$key])))
				{
					$switch = true;
				}
			}
			else
			{
				if (($sort_order == 'DESC' && strcasecmp($sort_array[$j][$key], $sort_array[$j + 1][$key]) < 0) || ($sort_order == 'ASC' && strcasecmp($sort_array[$j][$key], $sort_array[$j + 1][$key]) > 0))
				{
					$switch = true;
				}
			}

			if ($switch)
			{
				$temp = $sort_array[$j];
				$sort_array[$j] = $sort_array[$j + 1];
				$sort_array[$j + 1] = $temp;
			}
		}
	}

	return $sort_array;
}

//
// See if a post or pm really exist
//
function entry_exists($attach_id)
{
	global $db;

	if (empty($attach_id))
	{
		return false;
	}
	
	$sql = 'SELECT post_id, privmsgs_id
		FROM ' . ATTACHMENTS_TABLE . '
		WHERE attach_id = ' . intval($attach_id);

	if( !$db->sql_query($sql) )
	{
		message_die(GENERAL_ERROR, 'Could not get Entry', '', __LINE__, __FILE__, $sql);
	}

	$ids = $db->sql_fetchrowset($result);
	$num_ids = $db->sql_numrows($result);

	$exists = false;
	
	for ($i = 0; $i < $num_ids; $i++)
	{
		if (intval($ids[$i]['post_id']) != 0)
		{
			$sql = 'SELECT post_id
				FROM ' . POSTS_TABLE . '
				WHERE post_id = ' . intval($ids[$i]['post_id']);
		}
		else if (intval($ids[$i]['privmsgs_id']) != 0)
		{
			$sql = 'SELECT privmsgs_id
				FROM ' . PRIVMSGS_TABLE . '
				WHERE privmsgs_id = ' . intval($ids[$i]['privmsgs_id']);
		}

		if (!$db->sql_query($sql))
		{
			message_die(GENERAL_ERROR, 'Could not get Entry', '', __LINE__, __FILE__, $sql);
		}
	
		if (($db->sql_numrows($result)) > 0)
		{
			$exists = true;
			break;
		}
		$db->sql_freeresult($result);
	}

	return $exists;
}

//
// Collect all Attachments in Filesystem
//
function collect_attachments()
{
	global $upload_dir, $attach_config;

	$file_attachments = array(); 

	if (!intval($attach_config['allow_ftp_upload']))
	{
		if ($dir = @opendir($upload_dir))
		{
			while ($file = @readdir($dir))
			{
				if ($file != 'index.php' && $file != '.htaccess' && !is_dir($upload_dir . '/' . $file) && !is_link($upload_dir . '/' . $file))
				{
					$file_attachments[] = trim($file);
				}
			}
		
			closedir($dir);
		}
		else
		{
			message_die(GENERAL_ERROR, 'Is Safe Mode Restriction in effect? The Attachment Mod seems to be unable to collect the Attachments within the upload Directory. Try to use FTP Upload to circumvent this error.');
		}
	}
	else
	{
		$conn_id = attach_init_ftp();

		$file_listing = array();

		$file_listing = @ftp_rawlist($conn_id, '');

		if (!$file_listing)
		{
			message_die(GENERAL_ERROR, 'Unable to get Raw File Listing. Please be sure the LIST command is enabled at your FTP Server.');
		}

		for ($i = 0; $i < count($file_listing); $i++)
		{
			if (ereg("([-d])[rwxst-]{9}.* ([0-9]*) ([a-zA-Z]+[0-9: ]*[0-9]) ([0-9]{2}:[0-9]{2}) (.+)", $file_listing[$i], $regs))
			{
				if ($regs[1] == 'd') 
				{	
					$dirinfo[0] = 1;	// Directory == 1
				}
				$dirinfo[1] = $regs[2]; // Size
				$dirinfo[2] = $regs[3]; // Date
				$dirinfo[3] = $regs[4]; // Filename
				$dirinfo[4] = $regs[5]; // Time
			}
			
			if ($dirinfo[0] != 1 && $dirinfo[4] != 'index.php' && $dirinfo[4] != '.htaccess')
			{
				$file_attachments[] = trim($dirinfo[4]);
			}
		}

		@ftp_quit($conn_id);
	}

	return $file_attachments;
}

//
// Returns the filesize of the upload directory in human readable format
//
function get_formatted_dirsize()
{
	global $attach_config, $upload_dir, $lang;

	$upload_dir_size = 0;

	if (!intval($attach_config['allow_ftp_upload']))
	{
		if ($dirname = @opendir($upload_dir))
		{
			while ($file = @readdir($dirname))
			{
				if ($file != 'index.php' && $file != '.htaccess' && !is_dir($upload_dir . '/' . $file) && !is_link($upload_dir . '/' . $file))
				{
					$upload_dir_size += @filesize($upload_dir . '/' . $file);
				}
			}
			@closedir($dirname);
		}
		else
		{
			$upload_dir_size = $lang['Not_available'];
			return $upload_dir_size;
		}
	}
	else
	{
		$conn_id = attach_init_ftp();

		$file_listing = array();

		$file_listing = @ftp_rawlist($conn_id, '');

		if (!$file_listing)
		{
			$upload_dir_size = $lang['Not_available'];
			return $upload_dir_size;
		}

		for ($i = 0; $i < count($file_listing); $i++)
		{
			if (ereg("([-d])[rwxst-]{9}.* ([0-9]*) ([a-zA-Z]+[0-9: ]*[0-9]) ([0-9]{2}:[0-9]{2}) (.+)", $file_listing[$i], $regs))
			{
				if ($regs[1] == 'd') 
				{	
					$dirinfo[0] = 1;	// Directory == 1
				}
				$dirinfo[1] = $regs[2]; // Size
				$dirinfo[2] = $regs[3]; // Date
				$dirinfo[3] = $regs[4]; // Filename
				$dirinfo[4] = $regs[5]; // Time
			}
			
			if ($dirinfo[0] != 1 && $dirinfo[4] != 'index.php' && $dirinfo[4] != '.htaccess')
			{
				$upload_dir_size += $dirinfo[1];
			}
		}

		@ftp_quit($conn_id);
	}

	if ($upload_dir_size >= 1048576)
	{
		$upload_dir_size = round($upload_dir_size / 1048576 * 100) / 100 . ' ' . $lang['MB'];
	}
	else if ($upload_dir_size >= 1024)
	{
		$upload_dir_size = round($upload_dir_size / 1024 * 100) / 100 . ' ' . $lang['KB'];
	}
	else
	{
		$upload_dir_size = $upload_dir_size . ' ' . $lang['Bytes'];
	}

	return $upload_dir_size;
}

//
// Build SQL-Statement for the search feature
//
function search_attachments($order_by, &$total_rows)
{
	global $db, $HTTP_POST_VARS, $HTTP_GET_VARS, $lang;
	
	$where_sql = array();

	//
	// Get submitted Vars
	//
	$search_vars = array('search_keyword_fname', 'search_keyword_comment', 'search_author', 'search_size_smaller', 'search_size_greater', 'search_count_smaller', 'search_count_greater', 'search_days_greater', 'search_forum', 'search_cat');
	
	for ($i = 0; $i < sizeof($search_vars); $i++)
	{
		$$search_vars[$i] = get_var($search_vars[$i], '');
	}

	// Author name search 
	if ($search_author != '')
	{
		$search_author = htmlspecialchars(rtrim(trim($search_author), "\\"));
		$search_author = substr(str_replace("\\'", "'", $search_author), 0, 25);
		$search_author = str_replace("'", "\\'", $search_author);

		$search_author = str_replace('*', '%', trim(str_replace("\'", "''", $search_author)));

		//
		// We need the post_id's, because we want to query the Attachment Table
		//
		$sql = 'SELECT user_id
			FROM ' . USERS_TABLE . "
			WHERE username LIKE '$search_author'";

		if ( !($result = $db->sql_query($sql)) )
		{
			message_die(GENERAL_ERROR, 'Couldn\'t obtain list of matching users (searching for: ' . $search_author . ')', '', __LINE__, __FILE__, $sql);
		}

		$matching_userids = '';
		if ( $row = $db->sql_fetchrow($result) )
		{
			do
			{
				$matching_userids .= (($matching_userids != '') ? ', ' : '') . intval($row['user_id']);
			}
			while ($row = $db->sql_fetchrow($result));
		}
		else
		{
			message_die(GENERAL_MESSAGE, $lang['No_attach_search_match']);
		}

		$where_sql[] = ' (t.user_id_1 IN (' . $matching_userids . ')) ';
	}

	//
	// Search Keyword
	//
	if ($search_keyword_fname != '')
	{
		$match_word = str_replace('*', '%', $search_keyword_fname);
		$where_sql[] = " (a.real_filename LIKE '" . str_replace("\'", "''", $match_word) . "') ";
	}

	if ($search_keyword_comment != '')
	{
		$match_word = str_replace('*', '%', $search_keyword_comment);
		$where_sql[] = " (a.comment LIKE '" . str_replace("\'", "''", $match_word) . "') ";
	}

	//
	// Search Download Count
	//
	if ($search_count_smaller != '' || $search_count_greater != '')
	{
		if ($search_count_smaller != '')
		{
			$where_sql[] = ' (a.download_count < ' . (int) $search_count_smaller . ') ';
		}
		else if ($search_count_greater != '')
		{
			$where_sql[] = ' (a.download_count > ' . (int) $search_count_greater . ') ';
		}
	}

	//
	// Search Filesize
	//
	if ($search_size_smaller != '' || $search_size_greater != '')
	{
		if ($search_size_smaller != '')
		{
			$where_sql[] = ' (a.filesize < ' . (int) $search_size_smaller . ') ';
		}
		else if ($search_size_greater != '')
		{
			$where_sql[] = ' (a.filesize > ' . (int) $search_size_greater . ') ';
		}
	}

	//
	// Search Attachment Time
	//
	if ($search_days_greater != '')
	{
		$where_sql[] = ' (a.filetime < ' . ( time() - ((int) $search_days_greater * 86400)) . ') ';
	}

	//
	// Search Forum
	//
	if ($search_forum)
	{
		$where_sql[] = ' (p.forum_id = ' . intval($search_forum) . ') ';
	}
	
	// Search Cat... nope... sorry :(

	$sql = 'SELECT a.*, t.post_id, p.post_time, p.topic_id
		FROM ' . ATTACHMENTS_TABLE . ' t, ' . ATTACHMENTS_DESC_TABLE . ' a, ' . POSTS_TABLE . ' p WHERE ';
	
	if (count($where_sql) > 0)
	{
		$sql .= implode('AND', $where_sql) . ' AND ';
	}

	$sql .= 't.post_id = p.post_id AND a.attach_id = t.attach_id ';
	
	$total_rows_sql = $sql;

	$sql .= $order_by; 

	if (!($result = $db->sql_query($sql)))
	{
		message_die(GENERAL_ERROR, 'Couldn\'t query attachments', '', __LINE__, __FILE__, $sql);
	}

	$attachments = $db->sql_fetchrowset($result);
	$num_attach = $db->sql_numrows($result);

	if ($num_attach == 0)
	{
		message_die(GENERAL_MESSAGE, $lang['No_attach_search_match']);
	}

	if ( !($result = $db->sql_query($total_rows_sql)) )
	{
		message_die(GENERAL_ERROR, 'Could not query attachments', '', __LINE__, __FILE__, $sql);
	}

	$total_rows = $db->sql_numrows($result);
		
	return $attachments;
}

//
// perform LIMIT statement on arrays
//
function limit_array($array, $start, $pagelimit)
{
	//
	// array from start - start+pagelimit
	//
	$limit = ( count($array) < $start + $pagelimit ) ? count($array) : $start + $pagelimit;

	$limit_array = array();

	for ($i = $start; $i < $limit; $i++)
	{
		$limit_array[] = $array[$i];
	}

	return $limit_array;
}

?>
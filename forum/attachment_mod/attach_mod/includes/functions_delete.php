<?php
/** 
*
* @package attachment_mod
* @version $Id: functions_delete.php,v 1.1 2005/11/05 12:23:33 acydburn Exp $
* @copyright (c) 2002 Meik Sievertsen
* @license http://opensource.org/licenses/gpl-license.php GNU Public License 
*
*/

/**
* All Attachment Functions processing the Deletion Process
*/

/**
* Delete Attachment(s) from post(s) (intern)
*/
function delete_attachment($post_id_array = 0, $attach_id_array = 0, $page = 0, $user_id = 0)
{
	global $db;

	// Generate Array, if it's not an array
	if ($post_id_array === 0 && $attach_id_array === 0 && $page === 0)
	{
		return;
	}

	if ($post_id_array === 0 && $attach_id_array !== 0)
	{
		$post_id_array = array();

		if (!is_array($attach_id_array))
		{
			if (strstr($attach_id_array, ', '))
			{
				$attach_id_array = explode(', ', $attach_id_array);
			}
			else if (strstr($attach_id_array, ','))
			{
				$attach_id_array = explode(',', $attach_id_array);
			}
			else
			{
				$attach_id = intval($attach_id_array);
				$attach_id_array = array();
				$attach_id_array[] = $attach_id;
			}
		}
	
		// Get the post_ids to fill the array
		if ($page == PAGE_PRIVMSGS)
		{
			$p_id = 'privmsgs_id';
		}
		else
		{
			$p_id = 'post_id';
		}

		$sql = "SELECT $p_id 
			FROM " . ATTACHMENTS_TABLE . '
				WHERE attach_id IN (' . implode(', ', $attach_id_array) . ")
			GROUP BY $p_id";

		if ( !($result = $db->sql_query($sql)) )
		{
			message_die(GENERAL_ERROR, 'Could not select ids', '', __LINE__, __FILE__, $sql);
		}

		$num_post_list = $db->sql_numrows($result);

		if ($num_post_list == 0)
		{
			$db->sql_freeresult($result);
			return;
		}

		while ($row = $db->sql_fetchrow($result))
		{
			$post_id_array[] = intval($row[$p_id]);
		}
		$db->sql_freeresult($result);
	}
		
	if (!is_array($post_id_array))
	{
		if (trim($post_id_array) == '')
		{
			return;
		}

		if (strstr($post_id_array, ', '))
		{
			$post_id_array = explode(', ', $post_id_array);
		}
		else if (strstr($post_id_array, ','))
		{
			$post_id_array = explode(',', $post_id_array);
		}
		else
		{
			$post_id = intval($post_id_array);

			$post_id_array = array();
			$post_id_array[] = $post_id;
		}
	}
		
	if (!sizeof($post_id_array))
	{
		return;
	}

	// First of all, determine the post id and attach_id
	if ($attach_id_array === 0)
	{
		$attach_id_array = array();

		// Get the attach_ids to fill the array
		if ($page == PAGE_PRIVMSGS)
		{
			$whereclause = 'WHERE privmsgs_id IN (' . implode(', ', $post_id_array) . ')';
		}
		else
		{
			$whereclause = 'WHERE post_id IN (' . implode(', ', $post_id_array) . ')';
		}
			
		$sql = 'SELECT attach_id 
			FROM ' . ATTACHMENTS_TABLE . " $whereclause 
			GROUP BY attach_id";

		if ( !($result = $db->sql_query($sql)) )
		{
			message_die(GENERAL_ERROR, 'Could not select Attachment Ids', '', __LINE__, __FILE__, $sql);
		}

		$num_attach_list = $db->sql_numrows($result);

		if ($num_attach_list == 0)
		{
			$db->sql_freeresult($result);
			return;
		}

		while ($row = $db->sql_fetchrow($result))
		{
			$attach_id_array[] = (int) $row['attach_id'];
		}
		$db->sql_freeresult($result);
	}
	
	if (!is_array($attach_id_array))
	{
		if (strstr($attach_id_array, ', '))
		{
			$attach_id_array = explode(', ', $attach_id_array);
		}
		else if (strstr($attach_id_array, ','))
		{
			$attach_id_array = explode(',', $attach_id_array);
		}
		else
		{
			$attach_id = intval($attach_id_array);

			$attach_id_array = array();
			$attach_id_array[] = $attach_id;
		}
	}

	if (!sizeof($attach_id_array))
	{
		return;
	}

	if ($page == PAGE_PRIVMSGS)
	{
		$sql_id = 'privmsgs_id';
		if ($user_id)
		{
			$post_id_array_2 = array();

			$sql = 'SELECT privmsgs_id, privmsgs_type, privmsgs_to_userid, privmsgs_from_userid
				FROM ' . PRIVMSGS_TABLE . '
				WHERE privmsgs_id IN (' . implode(', ', $post_id_array) . ')';
			if ( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Couldn\'t get Privmsgs Type', '', __LINE__, __FILE__, $sql);
			}

			while ($row = $db->sql_fetchrow($result))
			{
				$privmsgs_type = $row['privmsgs_type'];
								
				if ($privmsgs_type == PRIVMSGS_READ_MAIL || $privmsgs_type == PRIVMSGS_NEW_MAIL || $privmsgs_type == PRIVMSGS_UNREAD_MAIL)
				{
					if ($row['privmsgs_to_userid'] == $user_id)
					{
						$post_id_array_2[] = $row['privmsgs_id'];
					}
				}
				else if ($privmsgs_type == PRIVMSGS_SENT_MAIL)
				{
					if ($row['privmsgs_from_userid'] == $user_id)
					{
						$post_id_array_2[] = $row['privmsgs_id'];
					}
				}
				else if ($privmsgs_type == PRIVMSGS_SAVED_OUT_MAIL)
				{
					if ($row['privmsgs_from_userid'] == $user_id)
					{
						$post_id_array_2[] = $row['privmsgs_id'];
					}
				}
				else if ($privmsgs_type == PRIVMSGS_SAVED_IN_MAIL)
				{
					if ($row['privmsgs_to_userid'] == $user_id)
					{
						$post_id_array_2[] = $row['privmsgs_id'];
					}
				}
			}
			$db->sql_freeresult($result);
			$post_id_array = $post_id_array_2;
		}
	}
	else
	{
		$sql_id = 'post_id';
	}

	if (sizeof($post_id_array) && sizeof($attach_id_array))
	{
		$sql = 'DELETE FROM ' . ATTACHMENTS_TABLE . ' 
			WHERE attach_id IN (' . implode(', ', $attach_id_array) . ") 
				AND $sql_id IN (" . implode(', ', $post_id_array) . ')';

		if ( !($db->sql_query($sql)) )   
		{
			message_die(GENERAL_ERROR, $lang['Error_deleted_attachments'], '', __LINE__, __FILE__, $sql);   
		} 
	
		for ($i = 0; $i < sizeof($attach_id_array); $i++)
		{
			$sql = 'SELECT attach_id 
				FROM ' . ATTACHMENTS_TABLE . ' 
					WHERE attach_id = ' . (int) $attach_id_array[$i];
			
			if ( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Could not select Attachment Ids', '', __LINE__, __FILE__, $sql);
			}
			
			$num_rows = $db->sql_numrows($result);
			$db->sql_freeresult($result);

			if ($num_rows == 0)
			{
				$sql = 'SELECT attach_id, physical_filename, thumbnail
					FROM ' . ATTACHMENTS_DESC_TABLE . '
					WHERE attach_id = ' . (int) $attach_id_array[$i];
	
				if ( !($result = $db->sql_query($sql)) )
				{
					message_die(GENERAL_ERROR, 'Couldn\'t query attach description table', '', __LINE__, __FILE__, $sql);
				}
				
				$num_rows = $db->sql_numrows($result);

				if ($num_rows != 0)
				{
					$num_attach = $num_rows;
					$attachments = $db->sql_fetchrowset($result);
					$db->sql_freeresult($result);

					// delete attachments
					for ($j = 0; $j < $num_attach; $j++)
					{
						unlink_attach($attachments[$j]['physical_filename']);
	
						if (intval($attachments[$j]['thumbnail']) == 1)
						{
							unlink_attach($attachments[$j]['physical_filename'], MODE_THUMBNAIL);
						}
					
						$sql = 'DELETE FROM ' . ATTACHMENTS_DESC_TABLE . '
							WHERE attach_id = ' . (int) $attachments[$j]['attach_id'];

						if ( !($db->sql_query($sql)) )
						{
							message_die(GENERAL_ERROR, $lang['Error_deleted_attachments'], '', __LINE__, __FILE__, $sql);
						}
					}
				}
				else
				{
					$db->sql_freeresult($result);
				}
			}
		}
	}

	// Now Sync the Topic/PM
	if ($page == PAGE_PRIVMSGS)
	{
		for ($i = 0; $i < sizeof($post_id_array); $i++)
		{
			$sql = 'SELECT attach_id 
				FROM ' . ATTACHMENTS_TABLE . ' 
				WHERE privmsgs_id = ' . (int) $post_id_array[$i];

			if ( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Couldn\'t query Attachments Table', '', __LINE__, __FILE__, $sql);
			}
			
			$num_rows = $db->sql_numrows($result);
			$db->sql_freeresult($result);

			if ($num_rows == 0)
			{
				$sql = 'UPDATE ' . PRIVMSGS_TABLE . ' SET privmsgs_attachment = 0 
					WHERE privmsgs_id = ' . $post_id_array[$i];

				if ( !($result = $db->sql_query($sql)) )
				{
					message_die(GENERAL_ERROR, 'Couldn\'t update Private Message Attachment Switch', '', __LINE__, __FILE__, $sql);
				}
			}
		}
	}
	else
	{
		if (sizeof($post_id_array))
		{
			$sql = 'SELECT topic_id 
				FROM ' . POSTS_TABLE . ' 
				WHERE post_id IN (' . implode(', ', $post_id_array) . ') 
				GROUP BY topic_id';
		
			if ( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Couldn\'t select Topic ID', '', __LINE__, __FILE__, $sql);
			}
	
			while ($row = $db->sql_fetchrow($result))
			{
				attachment_sync_topic($row['topic_id']);
			}
			$db->sql_freeresult($result);
		}
	}
}

?>
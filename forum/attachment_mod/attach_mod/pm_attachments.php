<?php
/** 
*
* @package attachment_mod
* @version $Id: pm_attachments.php,v 1.2 2005/11/06 18:35:43 acydburn Exp $
* @copyright (c) 2002 Meik Sievertsen
* @license http://opensource.org/licenses/gpl-license.php GNU Public License 
*
*/

/**
*/
if ( !defined('IN_PHPBB') )
{
	die('Hacking attempt');
	exit;
}

/**
* @package attachment_mod
* Class for Private Messaging
*/
class attach_pm extends attach_parent
{
	var $pm_delete_attachments = false;

	/**
	* Constructor
	*/
	function attach_pm()
	{
		global $HTTP_POST_VARS;

		$this->attach_parent();
		$this->pm_delete_attachments = (isset($HTTP_POST_VARS['pm_delete_attach'])) ? true : false;
		$this->page = PAGE_PRIVMSGS;
	}

	/**
	* Preview Attachments in PM's
	*/
	function preview_attachments()
	{
		global $attach_config, $userdata;

		if (!intval($attach_config['allow_pm_attach']))
		{
			return false;
		}
	
		display_attachments_preview($this->attachment_list, $this->attachment_filesize_list, $this->attachment_filename_list, $this->attachment_comment_list, $this->attachment_extension_list, $this->attachment_thumbnail_list);
	}

	/**
	* Insert an Attachment into a private message
	*/
	function insert_attachment_pm($a_privmsgs_id)
	{
		global $db, $mode, $attach_config, $privmsg_sent_id, $userdata, $to_userdata, $HTTP_POST_VARS;

		$a_privmsgs_id = (int) $a_privmsgs_id;

		// Insert Attachment ?
		if (!$a_privmsgs_id)
		{
			$a_privmsgs_id = (int) $privmsg_sent_id;
		}
		
		if ($a_privmsgs_id && ($mode == 'post' || $mode == 'reply' || $mode == 'edit') && intval($attach_config['allow_pm_attach']))
		{
			$this->do_insert_attachment('attach_list', 'pm', $a_privmsgs_id);
			$this->do_insert_attachment('last_attachment', 'pm', $a_privmsgs_id);

			if ((sizeof($this->attachment_list) > 0 || $this->post_attach) && !isset($HTTP_POST_VARS['update_attachment']))
			{
				$sql = 'UPDATE ' . PRIVMSGS_TABLE . '
					SET privmsgs_attachment = 1
					WHERE privmsgs_id = ' . (int) $a_privmsgs_id;

				if (!$db->sql_query($sql))
				{
					message_die(GENERAL_ERROR, 'Unable to update Private Message Table.', '', __LINE__, __FILE__, $sql);
				}
			}
		}
	}

	/**
	* Duplicate Attachment for sent PM
	*/
	function duplicate_attachment_pm($switch_attachment, $original_privmsg_id, $new_privmsg_id)
	{
		global $db, $privmsg, $folder;

		if (($privmsg['privmsgs_type'] == PRIVMSGS_NEW_MAIL || $privmsg['privmsgs_type'] == PRIVMSGS_UNREAD_MAIL) && $folder == 'inbox' && intval($switch_attachment) == 1)
		{
			$sql = 'SELECT *
				FROM ' . ATTACHMENTS_TABLE . '
				WHERE privmsgs_id = ' . (int) $original_privmsg_id;

			if (!($result = $db->sql_query($sql)))
			{
				message_die(GENERAL_ERROR, 'Couldn\'t query Attachment Table', '', __LINE__, __FILE__, $sql);
			}
			$rows = $db->sql_fetchrowset($result);
			$num_rows = $db->sql_numrows($result);
			$db->sql_freeresult($result);

			if ($num_rows > 0)
			{
				for ($i = 0; $i < $num_rows; $i++)
				{
					$sql_ary = array(
						'attach_id'		=> (int) $rows[$i]['attach_id'],
						'post_id'		=> (int) $rows[$i]['post_id'],
						'privmsgs_id'	=> (int) $new_privmsg_id,
						'user_id_1'		=> (int) $rows[$i]['user_id_1'],
						'user_id_2'		=> (int) $rows[$i]['user_id_2'],
					);

					$sql = 'INSERT INTO ' . ATTACHMENTS_TABLE . ' ' . attach_mod_sql_build_array('INSERT', $sql_ary); 

					if (!($result = $db->sql_query($sql)))
					{
						message_die(GENERAL_ERROR, 'Couldn\'t store Attachment for sent Private Message', '', __LINE__, __FILE__, $sql);
					}
				}

				$sql = 'UPDATE ' . PRIVMSGS_TABLE . '
					SET privmsgs_attachment = 1
					WHERE privmsgs_id = ' . (int) $new_privmsg_id;

				if (!($db->sql_query($sql)))
				{
					message_die(GENERAL_ERROR, 'Unable to update Private Message Table.', '', __LINE__, __FILE__, $sql);
				}
			}
		}
	}

	/**
	* Delete Attachments out of selected Private Message(s)
	*/
	function delete_all_pm_attachments($mark_list)
	{
		global $confirm, $delete_all;

		if (sizeof($mark_list))
		{
			$delete_sql_id = '';
			for ($i = 0; $i < sizeof($mark_list); $i++)
			{
				$delete_sql_id .= (($delete_sql_id != '') ? ', ' : '') . intval($mark_list[$i]);
			}

			if ($delete_all && $confirm)
			{
				delete_attachment($delete_sql_id, 0, PAGE_PRIVMSGS);
			}
		}
	}

	/**
	* Display the Attach Limit Box (move it to displaying.php ?)
	*/ 
	function display_attach_box_limits()
	{
		global $folder, $attach_config, $board_config, $template, $lang, $userdata, $db;

		if (!$attach_config['allow_pm_attach'] && $userdata['user_level'] != ADMIN)
		{
			return;
		}

		$this->get_quota_limits($userdata);

		$pm_filesize_limit = (!$attach_config['pm_filesize_limit']) ? $attach_config['attachment_quota'] : $attach_config['pm_filesize_limit'];

		$pm_filesize_total = get_total_attach_pm_filesize('to_user', (int) $userdata['user_id']);

		$attach_limit_pct = ( $pm_filesize_limit > 0 ) ? round(( $pm_filesize_total / $pm_filesize_limit ) * 100) : 0;
		$attach_limit_img_length = ( $pm_filesize_limit > 0 ) ? round(( $pm_filesize_total / $pm_filesize_limit ) * $board_config['privmsg_graphic_length']) : 0;
		if ($attach_limit_pct > 100)
		{
			$attach_limit_img_length = $board_config['privmsg_graphic_length'];
		}
		$attach_limit_remain = ( $pm_filesize_limit > 0 ) ? $pm_filesize_limit - $pm_filesize_total : 100;

		$l_box_size_status = sprintf($lang['Attachbox_limit'], $attach_limit_pct);

		$template->assign_vars(array(
			'ATTACHBOX_LIMIT_IMG_WIDTH'	=> $attach_limit_img_length, 
			'ATTACHBOX_LIMIT_PERCENT'	=> $attach_limit_pct, 

			'ATTACH_BOX_SIZE_STATUS'	=> $l_box_size_status)
		);
	}
	
	/**
	* For Private Messaging
	*/
	function privmsgs_attachment_mod($mode)
	{
		global $attach_config, $template, $lang, $userdata, $HTTP_POST_VARS, $phpbb_root_path, $phpEx, $db;
		global $confirm, $delete, $delete_all, $post_id, $privmsgs_id, $privmsg_id, $submit, $refresh, $mark_list, $folder;

		if ($folder != 'outbox')
		{
			$this->display_attach_box_limits();
		}

		if (!intval($attach_config['allow_pm_attach']))
		{
			return;
		}

		if (!$refresh)
		{
			$add_attachment_box = (!empty($HTTP_POST_VARS['add_attachment_box'])) ? TRUE : FALSE;
			$posted_attachments_box = (!empty($HTTP_POST_VARS['posted_attachments_box'])) ? TRUE : FALSE;

			$refresh = $add_attachment_box || $posted_attachments_box;
		}

		$post_id = $privmsgs_id;

		$result = $this->handle_attachments($mode, PAGE_PRIVMSGS);

		if ($result === false)
		{
			return;
		}

		$mark_list = get_var('mark', array(0));

		if (($this->pm_delete_attachments || $delete) && sizeof($mark_list))
		{
			if (!$userdata['session_logged_in'])
			{
				$header_location = ( @preg_match('/Microsoft|WebSTAR|Xitami/', getenv('SERVER_SOFTWARE')) ) ? 'Refresh: 0; URL=' : 'Location: ';
				header($header_location . append_sid($phpbb_root_path . "login.$phpEx?redirect=privmsg.$phpEx&folder=inbox", true));
				exit;
			}
			
			if (sizeof($mark_list))
			{
				$delete_sql_id = '';
				for ($i = 0; $i < sizeof($mark_list); $i++)
				{
					$delete_sql_id .= (($delete_sql_id != '') ? ', ' : '') . intval($mark_list[$i]);
				}

				if (($this->pm_delete_attachments || $confirm) && !$delete_all)
				{
					delete_attachment($delete_sql_id, 0, PAGE_PRIVMSGS);
				}
			}
		}

		if ($submit || $refresh || $mode != '')
		{
			$this->display_attachment_bodies();
		}
	}
}

/**
* Entry Point
*/
function execute_privmsgs_attachment_handling($mode)
{
	global $attachment_mod;

	$attachment_mod['pm'] = new attach_pm();
	
	if ($mode != 'read')
	{
		$attachment_mod['pm']->privmsgs_attachment_mod($mode);
	}
}

?>
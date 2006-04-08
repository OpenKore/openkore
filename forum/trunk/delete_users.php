<?php
#########################################################
## Author: Niels Chr. Rød
## Nickname: Niels Chr. Denmark
## Email: ncr@db9.dk
## http://mods.db9.dk
##
## Ver 1.2.11
## Developed as a drop-in to phpBB2 ver 2.0.2
##
## phpBB2 drop-in mod, that checks for unused accounts for X days
## use the script while logged in as ADMIN, add the days=X as a extra parameter
##   e.g. www.yourdomain.com/delete_users.php?mode=not_login&days=10
## will delete all accounts who have never logged in and are older than 10 days 
##
## And zero postes
##   e.g. www.yourdomain.com/delete_users.php?mode=zero_poster&days=10
## will delete all accounts who have never posted and are older than 10 days 
##
## You can also delete specific users
##   e.g. www.yourdomain.com/delete_users.php?mode=user_name&del_user=Niels
##   or www.yourdomain.com/delete_users.php?mode=user_id&del_user=18
## Will delete a specific user either by name or by id, remember that is is NOT case sensetive
## if the user have posted, then his/her posts will be converted to posted by guest, and the users
## name wil still be showen
##
## History:
##	1.0.0. - initial release
##	1.0.3. - history started, added delete not activated
##	1.1.0. - The old version did not delete all entrys, therfore this one works as the original code in ADMIN panel
##	1.2.0. - updated the code to work same as phpBB2 ver 2.0.2. 
##	1.2.1. - fix, "could not update posts table"
##	1.2.2. - fix, there was a error in the sql, regarding the new prune option #4
##	1.2.3. - fix, usernames with ' was giving a erro, when trying to delete, this is now posible
##	1.2.4. - fix, list of usernames was not showen
##	1.2.5. - made MODE, only show if debug is enabled
##	1.2.6. - more debug info, if no group
##	1.2.7. - now support email notification
##	1.2.9. - removed some debug info
##    1.2.10. - changed the php initial tag
##	1.2.11. - extended time execution, if allowed - it may take some time, if email notification is enabled

#########################################################

define('IN_PHPBB', true);
// to enable email notification to the user, after deletion, enable this
define('NOTIFY_USERS', true);
$phpbb_root_path = './';
include($phpbb_root_path . 'extension.inc');
include($phpbb_root_path . 'common.'.$phpEx);
include($phpbb_root_path . 'includes/emailer.'.$phpEx); 
include($phpbb_root_path . 'language/lang_' . $board_config['default_lang'] . '/lang_prune_users.' . $phpEx);

############################################### Do not change anything below this line #######################################

//
// Start session management
//
$userdata = session_pagestart($user_ip, PAGE_INDEX);
init_userprefs($userdata);
//
// End session management
//

if ($userdata['user_level']!=ADMIN)
      message_die(GENERAL_ERROR, $lang['Not_Authorised']);

$del_user = ( isset($HTTP_POST_VARS['del_user']) ) ? intval($HTTP_POST_VARS['del_user']) : (( isset($HTTP_GET_VARS['del_user']) ) ? intval($HTTP_GET_VARS['del_user']):'');
$mode = ( isset($HTTP_POST_VARS['mode']) ) ? $HTTP_POST_VARS['mode'] : ( ( isset($HTTP_GET_VARS['mode']) ) ? $HTTP_GET_VARS['mode']:'');
$days = ( isset($HTTP_POST_VARS['days']) ) ? intval($HTTP_POST_VARS['days']) : (( isset($HTTP_GET_VARS['days']) ) ? intval($HTTP_GET_VARS['days']):'');

// ******************************************************************************************
// Define you own modes here
	
switch ($mode)
{
	case 'user_name' :	$sql=' FROM '. USERS_TABLE .' WHERE username="'.str_replace("'","\'",$del_user).'"';break;

	case 'user_id' :		$sql=' FROM '. USERS_TABLE .' WHERE user_id="'.$del_user.'"';break;

	case 'prune_0' :	$mode ='Zero posters';
	case 'zero_poster' :	$sql=' FROM '. USERS_TABLE .' WHERE user_id<>"'.ANONYMOUS.'" AND user_posts="0" AND user_regdate<"'.(time()-(86400*$days)).'"';break;

	case 'prune_1' :	$mode ='Not logged in';
	case 'not_login': 	$sql=' FROM '. USERS_TABLE .' WHERE user_id<>"'.ANONYMOUS.'" AND user_lastvisit="0" AND user_regdate<"'.(time()-(86400*$days)).'"';break;

	case 'prune_2' :	$mode ='Not activated';
					$sql=' FROM '. USERS_TABLE .' WHERE user_id<>"'.ANONYMOUS.'" AND user_lastvisit="0" AND user_active="0" AND user_actkey<>"" AND user_regdate<"'.(time()-(86400*$days)).'"';break;

	case 'prune_3' :  $mode='Long time visit';
					$sql = 'FROM '.USERS_TABLE .' WHERE user_id<>"'.ANONYMOUS.'" AND user_lastvisit<'.(time()-86400*60).' AND user_regdate<"'.(time()-(86400*$days)).'"';break; 

	case 'prune_4' :  $mode='Avarage posts';
					$sql = 'FROM '.USERS_TABLE .' WHERE user_id<>"'.ANONYMOUS.'" AND user_posts/((user_lastvisit - user_regdate)/86400) < "0.1" AND user_regdate<"'.(time()-(86400*$days)).'"';break; 

	default:		message_die(GENERAL_ERROR, 'No mode specifyed', '', __LINE__, __FILE__);
}

// ******************************************************************************************
// Do not change anything below this line
//

if(!$result = $db->sql_query('SELECT user_id , username, user_email, user_lang ' . $sql . ' ORDER BY username LIMIT 800'))
	message_die(GENERAL_ERROR, 'Error obtaining userdata', '', __LINE__, __FILE__, $sql);
$user_list = $db->sql_fetchrowset($result);

$i=0;
while (isset($user_list[$i]['user_id']))
{
	@set_time_limit(5);
	$user_id=$user_list[$i]['user_id'];
	$username = str_replace("'","\'",$user_list[$i]['username']);
	$user_email = $user_list[$i]['user_email'];
	$user_lang =  $user_list[$i]['user_lang'];
	$sql = "SELECT g.group_id 
		FROM " . USER_GROUP_TABLE . " ug, " . GROUPS_TABLE . " g  
		WHERE ug.user_id = $user_id 
		AND g.group_id = ug.group_id 
		AND g.group_single_user = 1";
	if( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Could not obtain group information for this user', '', __LINE__, __FILE__, $sql);
	}
	$row = $db->sql_fetchrow($result);
	if( empty($row))
	{
		message_die(GENERAL_ERROR, 'Could not find group information for this user: "'.$user_id.'"', '', __LINE__, __FILE__);
	}
	
	$sql = "UPDATE " . POSTS_TABLE . "
		SET poster_id = " . DELETED . ", post_username = '$username' 
		WHERE poster_id = $user_id";
	if( !$db->sql_query($sql) )
	{
		message_die(GENERAL_ERROR, 'Could not update posts for this user', '', __LINE__, __FILE__, $sql);
	}
	$sql = "UPDATE " . TOPICS_TABLE . "
		SET topic_poster = " . DELETED . " 
		WHERE topic_poster = $user_id";
	if( !$db->sql_query($sql) )
	{
		message_die(GENERAL_ERROR, 'Could not update topics for this user', '', __LINE__, __FILE__, $sql);
	}
	
	$sql = "UPDATE " . VOTE_USERS_TABLE . "
		SET vote_user_id = " . DELETED . "
		WHERE vote_user_id = $user_id";
	if( !$db->sql_query($sql) )
	{
		message_die(GENERAL_ERROR, 'Could not update votes for this user', '', __LINE__, __FILE__, $sql);
	}
				
	$sql = "SELECT group_id
		FROM " . GROUPS_TABLE . "
		WHERE group_moderator = $user_id";
	if( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Could not select groups where user was moderator', '', __LINE__, __FILE__, $sql);
	}
		
	while ( $row_group = $db->sql_fetchrow($result) )
	{
		$group_moderator[] = $row_group['group_id'];
	}
		
	if ( count($group_moderator) )
	{
		$update_moderator_id = implode(', ', $group_moderator);
		$sql = "UPDATE " . GROUPS_TABLE . "
			SET group_moderator = " . $userdata['user_id'] . "
			WHERE group_moderator IN ($update_moderator_id)";
		if( !$db->sql_query($sql) )
		{
			message_die(GENERAL_ERROR, 'Could not update group moderators', '', __LINE__, __FILE__, $sql);
		}
	}
	$sql = "DELETE FROM " . USERS_TABLE . "
		WHERE user_id = $user_id";
	if( !$db->sql_query($sql) )
	{
		message_die(GENERAL_ERROR, 'Could not delete user', '', __LINE__, __FILE__, $sql);
	}

	$sql = "DELETE FROM " . USER_GROUP_TABLE . "
		WHERE user_id = $user_id";
	if( !$db->sql_query($sql) )
	{
		message_die(GENERAL_ERROR, 'Could not delete user from user_group table', '', __LINE__, __FILE__, $sql);
	}

	$sql = "DELETE FROM " . GROUPS_TABLE . "
		WHERE group_id = " . $row['group_id'];
		if( !$db->sql_query($sql) )
		{
			message_die(GENERAL_ERROR, 'Could not delete group for this user', '', __LINE__, __FILE__, $sql);
		}

	$sql = "DELETE FROM " . AUTH_ACCESS_TABLE . "
		WHERE group_id = " . $row['group_id'];
	if( !$db->sql_query($sql) )
	{
		message_die(GENERAL_ERROR, 'Could not delete group for this user', '', __LINE__, __FILE__, $sql);
	}

	$sql = "DELETE FROM " . TOPICS_WATCH_TABLE . "
		WHERE user_id = $user_id";
	if ( !$db->sql_query($sql) )
	{
		message_die(GENERAL_ERROR, 'Could not delete user from topic watch table', '', __LINE__, __FILE__, $sql);
	}

	$sql = "SELECT privmsgs_id
		FROM " . PRIVMSGS_TABLE . "
		WHERE ( ( privmsgs_from_userid = $user_id 
		AND privmsgs_type = " . PRIVMSGS_NEW_MAIL . " )
		OR ( privmsgs_from_userid = $user_id
		AND privmsgs_type = " . PRIVMSGS_SENT_MAIL . " )
		OR ( privmsgs_to_userid = $user_id
		AND privmsgs_type = " . PRIVMSGS_READ_MAIL . " )
		OR ( privmsgs_to_userid = $user_id
		AND privmsgs_type = " . PRIVMSGS_SAVED_IN_MAIL . " )
		OR ( privmsgs_from_userid = $user_id
		AND privmsgs_type = " . PRIVMSGS_SAVED_OUT_MAIL . " ) )";
	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Could not select all user\'s private messages', '', __LINE__, __FILE__, $sql);
	}
		
	//
	// This little bit of code directly from the private messaging section.
	// Thanks Paul!
	//
				
	while ( $row_privmsgs = $db->sql_fetchrow($result) )
	{
		$mark_list[] = $row_privmsgs['privmsgs_id'];
	}
			
	if ( count($mark_list) )
	{
		$delete_sql_id = implode(', ', $mark_list);
			
		//
		// We shouldn't need to worry about updating conters here...
		// They are already gone!
		//
						
		$delete_text_sql = "DELETE FROM " . PRIVMSGS_TEXT_TABLE . "
		WHERE privmsgs_text_id IN ($delete_sql_id)";
		$delete_sql = "DELETE FROM " . PRIVMSGS_TABLE . "
		WHERE privmsgs_id IN ($delete_sql_id)";
					
		//
		// Shouldn't need the switch statement here, either, as we just want
		// to take out all of the private messages.  This will not affect
		// the other messages we want to keep; the ids are unique.
		//
					
		if ( !$db->sql_query($delete_sql) )
		{
			message_die(GENERAL_ERROR, 'Could not delete private message info', '', __LINE__, __FILE__, $delete_sql);
		}
					
		if ( !$db->sql_query($delete_text_sql) )
		{
			message_die(GENERAL_ERROR, 'Could not delete private message text', '', __LINE__, __FILE__, $delete_text_sql);
		}
	}
				
	$sql = "UPDATE " . PRIVMSGS_TABLE . "
		SET privmsgs_to_userid = " . DELETED . "
		WHERE privmsgs_to_userid = $user_id";
	if ( !$db->sql_query($sql) )
	{
		message_die(GENERAL_ERROR, 'Could not update private messages saved to the user', '', __LINE__, __FILE__, $sql);
	}
				
	$sql = "UPDATE " . PRIVMSGS_TABLE . "
		SET privmsgs_from_userid = " . DELETED . "
		WHERE privmsgs_from_userid = $user_id";
	if ( !$db->sql_query($sql) )
	{
		message_die(GENERAL_ERROR, 'Could not update private messages saved from the user', '', __LINE__, __FILE__, $sql);
	}

if (NOTIFY_USERS && !empty($user_email))
{

		$script_name = preg_replace('/^\/?(.*?)\/?$/', '\1', trim($board_config['script_path'])). '/profile.'.$phpEx.'?mode=register';
		$server_name = trim($board_config['server_name']);
		$server_protocol = ( $board_config['cookie_secure'] ) ? 'https://' : 'http://';
		$server_port = ( $board_config['server_port'] <> 80 ) ? ':' . trim($board_config['server_port']) . '/' : '/';

            $emailer = new emailer($board_config['smtp_delivery']); 
	      $emailer->email_address($user_email); 
      	$email_headers = "To: \"".$username."\" <".$user_email. ">\r\n"; 
	            $email_headers .= "From: \"".$board_config['sitename']."\" <".$board_config['board_email'].">\r\n"; 
      	      $email_headers .= "Return-Path: " . (($userdata['user_email']&&$userdata['user_viewemail'])? $userdata['user_email']."\r\n":"\r\n"); 
            	$email_headers .= "X-AntiAbuse: Board servername - " . $server_name . "\r\n"; 
	            $email_headers .= "X-AntiAbuse: User_id - " . $userdata['user_id'] . "\r\n"; 
      	      $email_headers .= "X-AntiAbuse: Username - " . $userdata['username'] . "\r\n"; 
            	$email_headers .= "X-AntiAbuse: User IP - " . decode_ip($user_ip) . "\r\n"; 
	            $emailer->use_template("delete_users",(file_exists($phpbb_root_path . "language/lang_" . $user_lang . "/email/delete_users.tpl"))? $user_lang : ""); 
	            $emailer->extra_headers($email_headers); 
      	      $emailer->assign_vars(array( 
			   'U_REGISTER' => $server_protocol . $server_name . $server_port . $script_name,
	               'USER' => $userdata['username'],
			   'USERNAME' =>  $username,
	               'SITENAME' => $board_config['sitename'], 
      	         'BOARD_EMAIL' => $board_config['board_email'])); 
            	$emailer->send(); 
	            $emailer->reset(); 
	}
	$name_list .= (($name_list) ? ' , ':'</br>') .$username;
	$i++;
}
$messages .= ((DEBUG) ? '<b>Mode:['.$mode.']</b> </br>':'').(($i) ? sprintf($lang['Prune_users_number'],$i).$name_list : $lang['Prune_no_users']);
message_die(GENERAL_MESSAGE,$messages.'</br>'.sprintf($lang['Click_return_forum'],'<A HREF="'.append_sid("admin/index.$phpEx").'">','</A>')
); 
?>
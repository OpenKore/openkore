<?php

/***************************************************************************
 *                               archive_topic.php
 *                            -------------------
 *   begin                : Saturday, Feb 13, 2001
 *   copyright            : (C) 2001 The phpBB Group
 *   email                : support@phpbb.com
 *
 *   $Id: viewtopic.php,v 1.186.2.32 2003/06/20 16:34:58 psotfx Exp $
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
 ***************************************************************************/

include($phpbb_root_path . 'includes/bbcode.'.$phpEx);

//
// Start initial var setup
//
$topic_id = $post_id = 0;

$topic_id = intval($_VARS['t']);

$start = ( isset($_VARS['start']) ) ? intval($_VARS['start']) : 0;

if ( !isset($topic_id) && !isset($post_id) )
{
	archive_message_die (GENERAL_MESSAGE, 'Topic_post_not_exist');
}

if ( $_VARS['view'] == 'next' || $_VARS['view'] == 'previous' )
	{
		$sql_condition = ( $_VARS['view'] == 'next' ) ? '>' : '<';
		$sql_ordering = ( $_VARS['view'] == 'next' ) ? 'ASC' : 'DESC';

		$sql = "SELECT t.topic_id
			FROM " . TOPICS_TABLE . " t, " . TOPICS_TABLE . " t2
			WHERE
				t2.topic_id = $topic_id
				AND t.forum_id = t2.forum_id
				AND t.topic_last_post_id $sql_condition t2.topic_last_post_id
			ORDER BY t.topic_id $sql_ordering
			LIMIT 1";
		if ( !($result = $db->sql_query($sql)) )
		{
			archive_message_die(GENERAL_ERROR, "Could not obtain newer/older topic information", '', __LINE__, __FILE__, $sql);
		}

		if ( $row = $db->sql_fetchrow($result) )
		{
			$topic_id = intval($row['topic_id']);
		}
		else
		{
			$message = ( $HTTP_GET_VARS['view'] == 'next' ) ? 'No_newer_topics' : 'No_older_topics';
			archive_message_die(GENERAL_MESSAGE, $message);
		}
	}

//
// This rather complex gaggle of code handles querying for topics but
// also allows for direct linking to a post (and the calculation of which
// page the post is on and the correct display of viewtopic)
//
$join_sql_table = ( empty($post_id) ) ? '' : ", " . POSTS_TABLE . " p, " . POSTS_TABLE . " p2 ";
$join_sql = ( empty($post_id) ) ? "t.topic_id = $topic_id" : "p.post_id = $post_id AND t.topic_id = p.topic_id AND p2.topic_id = p.topic_id AND p2.post_id <= $post_id";
$count_sql = ( empty($post_id) ) ? '' : ", COUNT(p2.post_id) AS prev_posts";

$order_sql = ( empty($post_id) ) ? '' : "GROUP BY p.post_id, t.topic_id, t.topic_title, t.topic_status, t.topic_replies, t.topic_time, t.topic_type, t.topic_vote, t.topic_last_post_id, f.forum_name, f.forum_status, f.forum_id, f.auth_view, f.auth_read, f.auth_post, f.auth_reply, f.auth_edit, f.auth_delete, f.auth_sticky, f.auth_announce, f.auth_pollcreate, f.auth_vote, f.auth_attachments ORDER BY p.post_id ASC";

$sql = "SELECT t.topic_id, t.topic_title, t.topic_status, t.topic_replies, t.topic_time, t.topic_type, t.topic_vote, t.topic_last_post_id, f.forum_name, f.forum_status, f.forum_id, f.auth_view, f.auth_read, f.auth_post, f.auth_reply, f.auth_edit, f.auth_delete, f.auth_sticky, f.auth_announce, f.auth_pollcreate, f.auth_vote, f.auth_attachments" . $count_sql . "
	FROM " . TOPICS_TABLE . " t, " . FORUMS_TABLE . " f" . $join_sql_table . "
	WHERE $join_sql
		AND f.forum_id = t.forum_id
		$order_sql";
if ( !($result = $db->sql_query($sql)) )
{
	archive_message_die(GENERAL_ERROR, "Could not obtain topic information", '', __LINE__, __FILE__, $sql);
}

if ( !($forum_topic_data = $db->sql_fetchrow($result)) )
{
	archive_message_die(GENERAL_MESSAGE, 'Topic_post_not_exist');
}

$forum_id = intval($forum_topic_data['forum_id']);

//
// Start session management
//
$userdata = session_pagestart($user_ip, $forum_id);
init_userprefs($userdata);
//
// End session management
//

$template->root = "./templates/phpBBSEI";

//
// Start auth check
//
$is_auth = array();
$is_auth = auth(AUTH_ALL, $forum_id, $userdata, $forum_topic_data);

if( !$is_auth['auth_view'] || !$is_auth['auth_read'] )
{
	if ( !$userdata['session_logged_in'] )
	{
		$redirect = ( isset($post_id) ) ? POST_POST_URL . "=$post_id" : POST_TOPIC_URL . "=$topic_id";
		$redirect .= ( isset($start) ) ? "&start=$start" : '';
		redirect( append_sid("login.$phpEx?redirect=viewtopic.$phpEx&$redirect", true));
	}

	$message = ( !$is_auth['auth_view'] ) ? $lang['Topic_post_not_exist'] : sprintf($lang['Sorry_auth_read'], $is_auth['auth_read_type']);

	archive_message_die (GENERAL_MESSAGE, $message);
}
//
// End auth check
//

$forum_name = $forum_topic_data['forum_name'];
$topic_title = $forum_topic_data['topic_title'];
$topic_id = intval($forum_topic_data['topic_id']);
$topic_time = $forum_topic_data['topic_time'];

	$total_replies = intval($forum_topic_data['topic_replies']) + 1;

	$limit_posts_time = '';
	$post_days = 0;

	$post_order = 'asc';
	$post_time_order = 'ASC';

//
// Go ahead and pull all data for this topic
//
$sql = "SELECT u.username, u.user_id, u.user_posts, u.user_from, u.user_website, u.user_email, u.user_icq, u.user_aim, u.user_yim, u.user_regdate, u.user_msnm, u.user_viewemail, u.user_rank, u.user_sig, u.user_sig_bbcode_uid, u.user_avatar, u.user_avatar_type, u.user_allowavatar, u.user_allowsmile, p.*,  pt.post_text, pt.post_subject, pt.bbcode_uid
	FROM " . POSTS_TABLE . " p, " . USERS_TABLE . " u, " . POSTS_TEXT_TABLE . " pt
	WHERE p.topic_id = $topic_id
		$limit_posts_time
		AND pt.post_id = p.post_id
		AND u.user_id = p.poster_id
	ORDER BY p.post_id $post_time_order
	LIMIT $start, ".$board_config['posts_per_page'];
if ( !($result = $db->sql_query($sql)) )
{
	archive_message_die(GENERAL_ERROR, "Could not obtain post/user information.", '', __LINE__, __FILE__, $sql);
}

$postrow = array();
if ($row = $db->sql_fetchrow($result))
{
	do
	{
		$postrow[] = $row;
	}
	while ($row = $db->sql_fetchrow($result));
	$db->sql_freeresult($result);

	$total_posts = count($postrow);
}
else
{
   include($phpbb_root_path . 'includes/functions_admin.' . $phpEx);
   sync('topic', $topic_id);

   archive_message_die(GENERAL_MESSAGE, $lang['No_posts_topic']);
}

$resync = FALSE;
if ($forum_topic_data['topic_replies'] + 1 < $start + count($postrow))
{
   $resync = TRUE;
}
elseif ($start + $board_config['posts_per_page'] > $forum_topic_data['topic_replies'])
{
   $row_id = intval($forum_topic_data['topic_replies']) % intval($board_config['posts_per_page']);
   if ($postrow[$row_id]['post_id'] != $forum_topic_data['topic_last_post_id'] || $start + count($postrow) < $forum_topic_data['topic_replies'])
   {
      $resync = TRUE;
   }
}
elseif (count($postrow) < $board_config['posts_per_page'])
{
   $resync = TRUE;
}

if ($resync)
{
   include($phpbb_root_path . 'includes/functions_admin.' . $phpEx);
   sync('topic', $topic_id);

   $result = $db->sql_query('SELECT COUNT(post_id) AS total FROM ' . POSTS_TABLE . ' WHERE topic_id = ' . $topic_id);
   $row = $db->sql_fetchrow($result);
   $total_replies = $row['total'];
}

$sql = "SELECT *
	FROM " . RANKS_TABLE . "
	ORDER BY rank_special, rank_min";
if ( !($result = $db->sql_query($sql)) )
{
	archive_message_die(GENERAL_ERROR, "Could not obtain ranks information.", '', __LINE__, __FILE__, $sql);
}

$ranksrow = array();
while ( $row = $db->sql_fetchrow($result) )
{
	$ranksrow[] = $row;
}
$db->sql_freeresult($result);

//
// Define censored word matches
//
$orig_word = array();
$replacement_word = array();
obtain_word_list ($orig_word, $replacement_word);

//
// Censor topic title
//
if ( count($orig_word) )
{
	$topic_title = preg_replace($orig_word, $replacement_word, $topic_title);
}

//
// Post, reply and other URL generation for
// templating vars
//
$view_forum_url = SITE_URL . "".ARCHIVE."/o_f__" . POST_FORUM_URL . "_".$forum_id."__" . formatName ( $forum_name ) . ".php";
$view_prev_topic_url = SITE_URL . "".ARCHIVE."/o_t__" . POST_TOPIC_URL . "_".$topic_id."__view_previous__index.php";
$view_next_topic_url = SITE_URL . "".ARCHIVE."/o_t__" . POST_TOPIC_URL . "_".$topic_id."__view_next__index.php";

//
// Mozilla navigation bar
//
$nav_links['prev'] = array(
	'url' => $view_prev_topic_url,
	'title' => $lang['View_previous_topic']
);
$nav_links['next'] = array(
	'url' => $view_next_topic_url,
	'title' => $lang['View_next_topic']
);
$nav_links['up'] = array(
	'url' => $view_forum_url,
	'title' => $forum_name
);

//
// Load templates
//
$template->set_filenames(array(
	'body' => 'archive/viewtopic_body.tpl')
);

//
// Output page header
//
$page_title = $lang['View_topic'] .' - ' . $topic_title;
include($phpbb_root_path . 'includes/archive/archive_page_header.'.$phpEx);

$topic_mod = '';


$pagination = archive_generate_pagination ( SITE_URL . "".ARCHIVE."/o_t__" . POST_TOPIC_URL . "_$topic_id", $total_replies, $board_config['posts_per_page'], $start);

//
// Send vars to template
//
$template->assign_vars(array(
	'FORUM_ID' => $forum_id,
    'FORUM_NAME' => $forum_name,
    'TOPIC_ID' => $topic_id,
    'TOPIC_TITLE' => $topic_title,
	'PAGINATION' => $pagination,
	'PAGE_NUMBER' => sprintf($lang['Page_of'], ( floor( $start / intval($board_config['posts_per_page']) ) + 1 ), ceil( $total_replies / intval($board_config['posts_per_page']) )),

	'L_AUTHOR' => $lang['Author'],
	'L_MESSAGE' => $lang['Message'],
	'L_POSTED' => $lang['Posted'],
	'L_POST_SUBJECT' => $lang['Post_subject'],
	'L_VIEW_NEXT_TOPIC' => $lang['View_next_topic'],
	'L_VIEW_PREVIOUS_TOPIC' => $lang['View_previous_topic'],
	'L_BACK_TO_TOP' => $lang['Back_to_top'],
	'L_DISPLAY_POSTS' => $lang['Display_posts'],
	'L_GOTO_PAGE' => $lang['Goto_page'],

	'S_TOPIC_LINK' => POST_TOPIC_URL,
	'S_SELECT_POST_DAYS' => $select_post_days,
	'S_SELECT_POST_ORDER' => $select_post_order,
	'S_AUTH_LIST' => $s_auth_can,
	'S_TOPIC_ADMIN' => $topic_mod,
	'S_WATCH_TOPIC' => $s_watching_topic,
	'S_WATCH_TOPIC_IMG' => $s_watching_topic_img,

	'U_VIEW_TOPIC' => SITE_URL . "".ARCHIVE."/o_t__" . POST_TOPIC_URL . "_".$topic_id."__start_".$start."__index.php",
	'O_VIEW_TOPIC' => "javascript:phpRebelLink ('" . SITE_URL . "viewtopic.$phpEx?" . POST_TOPIC_URL . "=$topic_id&amp;start=$start');",
	'U_VIEW_FORUM' => $view_forum_url,
	'U_VIEW_OLDER_TOPIC' => $view_prev_topic_url,
	'U_VIEW_NEWER_TOPIC' => $view_next_topic_url,
	)
);

//
// Update the topic view counter
//
$sql = "UPDATE " . TOPICS_TABLE . "
	SET topic_views = topic_views + 1
	WHERE topic_id = $topic_id";
if ( !$db->sql_query($sql) )
{
	archive_message_die(GENERAL_ERROR, "Could not update topic views.", '', __LINE__, __FILE__, $sql);
}

//
// Okay, let's do the loop, yeah come on baby let's do the loop
// and it goes like this ...
//
for($i = 0; $i < $total_posts; $i++)
{
	$poster_id = $postrow[$i]['user_id'];
	$poster = ( $poster_id == ANONYMOUS ) ? $lang['Guest'] : $postrow[$i]['username'];

	$post_date = create_date($board_config['default_dateformat'], $postrow[$i]['post_time'], $board_config['board_timezone']);

	$poster_posts = ( $postrow[$i]['user_id'] != ANONYMOUS ) ? $lang['Posts'] . ': ' . $postrow[$i]['user_posts'] : '';

	$poster_from = ( $postrow[$i]['user_from'] && $postrow[$i]['user_id'] != ANONYMOUS ) ? $lang['Location'] . ': ' . $postrow[$i]['user_from'] : '';

	$poster_joined = ( $postrow[$i]['user_id'] != ANONYMOUS ) ? $lang['Joined'] . ': ' . create_date($lang['DATE_FORMAT'], $postrow[$i]['user_regdate'], $board_config['board_timezone']) : '';

	$poster_avatar = '';

	//
	// Handle anon users posting with usernames
	//
	if ( $poster_id == ANONYMOUS && $postrow[$i]['post_username'] != '' )
	{
		$poster = $postrow[$i]['post_username'];
		$poster_rank = $lang['Guest'];
	}

	$temp_url = '';


	$post_subject = ( $postrow[$i]['post_subject'] != '' ) ? $postrow[$i]['post_subject'] : '';

	$message = $postrow[$i]['post_text'];
	$bbcode_uid = $postrow[$i]['bbcode_uid'];

	//
	// Note! The order used for parsing the message _is_ important, moving things around could break any
	// output
	//


	//
	// If the board has HTML off but the post has HTML
	// on then we process it, else leave it alone
	//
	if ( !$board_config['allow_html'] )
	{

		if ( $postrow[$i]['enable_html'] )
		{
			$message = preg_replace('#(<)([\/]?.*?)(>)#is', "&lt;\\2&gt;", $message);
		}
	}

	//
	// Parse message and/or sig for BBCode if reqd
	//
	if ( $board_config['allow_bbcode'] )
	{
		if ( $bbcode_uid != '' )
		{
			$message = ( $board_config['allow_bbcode'] ) ? bbencode_second_pass ($message, $bbcode_uid) : preg_replace('/\:[0-9a-z\:]+\]/si', ']', $message);
		}
	}

	$message = make_clickable ($message);
	
	// strip all html
	$message = strip_tags ( $message );

	//
	// Replace naughty words
	//
	if (count($orig_word))
	{
		$post_subject = preg_replace($orig_word, $replacement_word, $post_subject);

		$message = str_replace('\"', '"', substr(preg_replace('#(\>(((?>([^><]+|(?R)))*)\<))#se', "preg_replace(\$orig_word, \$replacement_word, '\\0')", '>' . $message . '<'), 1, -1));
	}

	$message = str_replace("\n", "\n<br />\n", $message);

	//
	// Again this will be handled by the templating
	// code at some point
	//
	$row_color = ( !($i % 2) ) ? $theme['td_color1'] : $theme['td_color2'];
	$row_class = ( !($i % 2) ) ? $theme['td_class1'] : $theme['td_class2'];

	$template->assign_block_vars('postrow', array(
		'ROW_COLOR' => '#' . $row_color,
		'ROW_CLASS' => $row_class,
		'POSTER_NAME' => $poster,
		'POSTER_RANK' => $poster_rank,
		'RANK_IMAGE' => $rank_image,
		'POSTER_JOINED' => $poster_joined,
		'POSTER_POSTS' => $poster_posts,
		'POSTER_FROM' => $poster_from,
		'POSTER_AVATAR' => $poster_avatar,
		'POST_DATE' => $post_date,
		'POST_SUBJECT' => $post_subject,
		'MESSAGE' => $message,
		'EDITED_MESSAGE' => $l_edited_by,
		'ORIGINAL'  => $t_original,

		'L_MINI_POST_ALT' => $mini_post_alt,

		'U_MINI_POST' => $mini_post_url,
		'U_POST_ID' => $postrow[$i]['post_id'])
	);
}

$template->pparse('body');

include($phpbb_root_path . 'includes/archive/archive_page_tail.'.$phpEx);

?>

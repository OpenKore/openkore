<?php
define('IN_PHPBB', true);
$phpbb_root_path = './';
include($phpbb_root_path . 'extension.inc');
include($phpbb_root_path . 'common.'.$phpEx);
include($phpbb_root_path . 'includes/bbcode.'.$phpEx);
include($phpbb_root_path . 'includes/functions_admin.'.$phpEx);
require_once($phpbb_root_path . 'includes/openkore.'.$phpEx);


// Obtain initial var settings
$forum_id = OUtils::getIntSetting(POST_FORUM_URL);
$post_id  = OUtils::getIntSetting(POST_POST_URL);
$topic_id = OUtils::getIntSetting(POST_TOPIC_URL);

// Start session management
$userdata = session_pagestart($user_ip, $forum_id);
init_userprefs($userdata);

// session id check
if (!empty($HTTP_POST_VARS['sid']) || !empty($HTTP_GET_VARS['sid'])) {
	$sid = (!empty($HTTP_POST_VARS['sid'])) ? $HTTP_POST_VARS['sid'] : $HTTP_GET_VARS['sid'];
} else {
	$sid = '';
}

// session id check
if ($sid == '' || $sid != $userdata['session_id']) {
	message_die(GENERAL_ERROR, 'Invalid_session');
}

// Obtain relevant data
if ( !empty($topic_id) ) {
	$sql = "SELECT f.forum_id, f.forum_name, f.forum_topics
		FROM " . TOPICS_TABLE . " t, " . FORUMS_TABLE . " f
		WHERE t.topic_id = " . $topic_id . "
			AND f.forum_id = t.forum_id";
	if ( !($result = $db->sql_query($sql)) ) {
		message_die(GENERAL_MESSAGE, 'Topic_post_not_exist');
	}
	$topic_row = $db->sql_fetchrow($result);

	if (!$topic_row) {
		message_die(GENERAL_MESSAGE, 'Topic_post_not_exist');
	}

	$forum_topics = ( $topic_row['forum_topics'] == 0 ) ? 1 : $topic_row['forum_topics'];
	$forum_id = $topic_row['forum_id'];
	$forum_name = $topic_row['forum_name'];

} else if ( !empty($forum_id) ) {
	$sql = "SELECT forum_name, forum_topics
		FROM " . FORUMS_TABLE . "
		WHERE forum_id = " . $forum_id;
	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_MESSAGE, 'Forum_not_exist');
	}
	$topic_row = $db->sql_fetchrow($result);

	if (!$topic_row)
	{
		message_die(GENERAL_MESSAGE, 'Forum_not_exist');
	}

	$forum_topics = ( $topic_row['forum_topics'] == 0 ) ? 1 : $topic_row['forum_topics'];
	$forum_name = $topic_row['forum_name'];
}

// Start auth check
$is_auth = auth(AUTH_ALL, $forum_id, $userdata);
if ( !$is_auth['auth_mod'] ) {
	message_die(GENERAL_MESSAGE, $lang['Not_Moderator'], $lang['Not_Authorised']);
}


$trashForumId = findForumId(OConstants::TRASH_FORUM_NAME);
if (is_null($trashForumId)) {
	message_die(GENERAL_MESSAGE, "Cannot find forum ID for the Trash forum.");
} else if ($topic_id == '') {
	message_die(GENERAL_MESSAGE, "No topic ID set.");
} else if ($forum_id == '') {
	message_die(GENERAL_MESSAGE, "No forum ID set.");
}

lockTopic($topic_id, $forum_id);
moveTopic($topic_id, $forum_id, $trashForumId);
header("Location: viewtopic.${phpEx}?t=$topic_id");


/****************************************************/


/**
 * Find a forum ID.
 *
 * @param name  The name of the forum to find the ID for.
 */
function findForumId($name) {
	global $db;
	$sql = "SELECT forum_id,forum_name FROM " . FORUMS_TABLE . "
			WHERE forum_name = '" . addslashes($name) . "'";
	if ( !($result = $db->sql_query($sql)) ) {
		message_die(GENERAL_ERROR, 'Could not select from forums table', '', __LINE__, __FILE__, $sql);
	}

	$forum_info = $db->sql_fetchrow($result);
	$db->sql_freeresult($result);
	if ($forum_info) {
		return $forum_info['forum_id'];
	} else {
		return null;
	}
}

/**
 * Move a topic.
 *
 * @param topic_id        The ID of the topic to move.
 * @param old_forum_id    The forum ID in which the topic lives.
 * @param new_forum_name  The name of the forum to move to.
 */
function moveTopic($topic_id, $old_forum_id, $new_forum_id) {
	global $db;
	$topics = array($topic_id);
	$topic_list = '';
	for($i = 0; $i < count($topics); $i++) {
		$topic_list .= ( ( $topic_list != '' ) ? ', ' : '' ) . intval($topics[$i]);
	}

	$sql = sprintf("SELECT * FROM %s
		WHERE topic_id IN (%s)
			AND forum_id = %d
			AND topic_status <> %d",
		       TOPICS_TABLE, $topic_list, $old_forum_id, TOPIC_MOVED);
	if ( !($result = $db->sql_query($sql, BEGIN_TRANSACTION)) ) {
		message_die(GENERAL_ERROR, 'Could not select from topic table', '', __LINE__, __FILE__, $sql);
	}

	$row = $db->sql_fetchrowset($result);
	$db->sql_freeresult($result);

	for ($i = 0; $i < count($row); $i++) {
		$topic_id = $row[$i]['topic_id'];

		$sql = sprintf("UPDATE %s SET forum_id = %d WHERE topic_id = %d",
			       TOPICS_TABLE, $new_forum_id, $topic_id);
		if ( !$db->sql_query($sql) ) {
			message_die(GENERAL_ERROR, 'Could not update old topic', '', __LINE__, __FILE__, $sql);
		}

		$sql = sprintf("UPDATE %s SET forum_id = %d WHERE topic_id = %d",
			       POSTS_TABLE, $new_forum_id, $topic_id);
		if ( !$db->sql_query($sql) ) {
			message_die(GENERAL_ERROR, 'Could not update post topic ids', '', __LINE__, __FILE__, $sql);
		}
	}

	// Sync the forum indexes
	sync('forum', $new_forum_id);
	sync('forum', $old_forum_id);
}

/**
 * Lock a topic.
 *
 * @param topic_id  The ID of the topic to lock.
 * @param forum_id  The ID of the forum in which the topic exists.
 */
function lockTopic($topic_id, $forum_id) {
	global $db;
	$topics = array($topic_id);
	$topic_id_sql = '';
	for ($i = 0; $i < count($topics); $i++) {
		$topic_id_sql .= ( ( $topic_id_sql != '' ) ? ', ' : '' ) . intval($topics[$i]);
	}

	$sql = sprintf("UPDATE %s SET topic_status = %d
		WHERE topic_id IN (%s)
			AND forum_id = %d
			AND topic_moved_id = 0",
		       TOPICS_TABLE, TOPIC_LOCKED, $topic_id_sql, $forum_id);
	if ( !($result = $db->sql_query($sql)) ) {
		message_die(GENERAL_ERROR, 'Could not update topics table', '', __LINE__, __FILE__, $sql);
	}
}
?>
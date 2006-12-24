<?php
class PhpBB {
	private static $phpBB_args;

	/**
	 * Initialize phpBB.
	 *
	 * @param $args  An associative array, which may contain the following options:
	 *    template: Whether the default header and footer should be printed. Defaults to true.
	 *    admin: Whether the visitor must be an administrator. Defaults to false.
	 *    check_sid: Whether 'sid' parameter should be checked against the visitor's actual SID.
	 *               Defaults to true if 'admin' is set to true, otherwise defaults to false.
	 *    root: Specify the phpbb root path. Defaults to './'.
	 *    page: The page type, as will be shown in the administration panel. Defaults to PAGE_MODERATING
	 *    title: The page title.
	 */
	public static function init($args = array()) {
		global $phpbb_root_path, $phpEx, $user_ip, $userdata, $db, $themes_id, $board_config,
			$template, $theme, $lang, $page_title, $SID, $html_entities_match,
			$html_entities_replace, $user_ip, $attachment_mod, $unhtml_specialchars_match,
			$unhtml_specialchars_replace;

		define('IN_PHPBB', true);

		if (isset($args['root'])) {
			$phpbb_root_path = $args['root'];
		} else {
			$phpbb_root_path = './';
		}
		include($phpbb_root_path . 'extension.inc');
		include($phpbb_root_path . 'common.'.$phpEx);

		// Start session management.
		if (!isset($args['page'])) {
			$args['page'] = PAGE_MODERATING;
		}
		$userdata = session_pagestart($user_ip, $args['page']);
		init_userprefs($userdata);

		// Check whether user is admin.
		if ($args['admin'] && $userdata['user_level'] != ADMIN) {
			message_die(GENERAL_MESSAGE, "You are not an administrator.");
		}

		// Check session ID if necessary.
		if (( !isset($args['check_sid']) && $args['admin'] ) || ($args['check_sid'])) {
			// Session ID check.
			if (!empty($_POST['sid']) || !empty($_GET['sid'])) {
				$sid = (!empty($_POST['sid'])) ? $_POST['sid'] : $_GET['sid'];
			} else {
				$sid = '';
			}
			if ($sid == '' || $sid != $userdata['session_id']) {
				message_die(GENERAL_ERROR, 'Invalid session.');
			}
		}
		$SID = $userdata['session_id'];

		// Print default header and footer.
		if (isset($args['title'])) {
			$page_title = $args['title'];
		}
		if (!isset($args['template']) || $args['template']) {
			include($phpbb_root_path . 'includes/page_header.'.$phpEx);
		}

		

		self::$phpBB_args = $args;
	}

	public static function finalize() {
		global $phpbb_root_path, $phpEx, $user_ip, $userdata, $db, $themes_id, $board_config,
			$template, $theme, $lang, $page_title, $SID, $html_entities_match,
			$html_entities_replace, $user_ip, $attachment_mod, $unhtml_specialchars_match,
			$unhtml_specialchars_replace;

		$args = self::$phpBB_args;
		if (!isset($args['template']) || $args['template']) {
			include($phpbb_root_path . 'includes/page_tail.'.$phpEx);
		}
	}

	/**
	 * Find a forum ID.
	 *
	 * @param name  The name of the forum to find the ID for.
	 */
	public static function findForumId($name) {
		global $db;
		$sql = "SELECT forum_id FROM " . FORUMS_TABLE . "
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
}

// Represents either a post or a topic.
abstract class Item {
	abstract public function getForumId();
	abstract public function getTopicId();
	abstract public function getTopicTitle();

	/**
	 * Move a topic.
	 *
	 * @param new_forum_id    The forum ID of the forum to move to.
	 */
	public function moveTopic($new_forum_id) {
		global $db;
		global $phpbb_root_path;
		global $phpEx;
		require_once($phpbb_root_path . 'includes/functions_admin.'.$phpEx);

		$topic_id = $this->getTopicId();
		$old_forum_id = $this->getForumId();

		$topics = array($topic_id);
		$topic_list = '';
		for ($i = 0; $i < count($topics); $i++) {
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
	 */
	public function lockTopic() {
		global $db;

		$topic_id = $this->getTopicId();
		$forum_id = $this->getForumId();

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

	/**
	 * Add a reply to this topic.
	 *
	 * 
	 */
	public function addReply($message) {
		global $phpbb_root_path, $phpEx, $user_ip, $userdata, $db, $themes_id, $board_config,
			$template, $theme, $lang, $page_title, $SID, $html_entities_match,
			$html_entities_replace, $user_ip, $attachment_mod, $unhtml_specialchars_match,
			$unhtml_specialchars_replace;
		require_once($phpbb_root_path . 'includes/bbcode.'.$phpEx);
		require_once($phpbb_root_path . 'includes/functions_post.'.$phpEx);

		$forum_id = $this->getForumId();
		$topic_id = $this->getTopicId();
		$message = addslashes($message);
		$post_id = null;
		$poll_id = null;
		$attach_sig = 0;

		$mode = 'reply';
		$post_data = array('first_post' => 0, 'last_post' => false, 'has_poll' => false, 'edit_poll' => false);
		$bbcode_on = '1';
		$html_on = '0';
		$smilies_on = '1';
		$error_msg = '';

		$username = '';
		$bbcode_uid = '';
		$subject = '';
		$poll_title = '';
		$poll_options = '';
		$poll_length = '0';
		$poll_length_h = '0';
		$poll_length = $poll_length*24;
		$poll_length = $poll_length_h+$poll_length;
		$poll_length = 0;
		$max_vote = '';
		$hide_vote = '';
		$tothide_vote = '';

		prepare_post($mode, $post_data, $bbcode_on, $html_on, $smilies_on, $error_msg, $username, $bbcode_uid, $subject, $message, $poll_title, $poll_options, $poll_length, $max_vote, $hide_vote, $tothide_vote);

		if ( $error_msg == '' ) {
			$topic_type = 0;

			submit_post($mode, $post_data, $return_message, $return_meta, $forum_id, $topic_id, $post_id, $poll_id, $topic_type,
				$bbcode_on, $html_on, $smilies_on, $attach_sig, $bbcode_uid,
				str_replace("\'", "''", $username), str_replace("\'", "''", $subject), str_replace("\'", "''", $message), str_replace("\'", "''", $poll_title),
				$poll_options, $poll_length, $max_vote, $hide_vote, $tothide_vote);
		}

		if ( $error_msg == '' )
		{
			$user_id = $userdata['user_id'];
			update_post_stats($mode, $post_data, $forum_id, $topic_id, $post_id, $user_id);
			//$attachment_mod['posting']->insert_attachment($post_id);

			if ($error_msg == '')
			{
				$notify_user = true;
				user_notification($mode, $post_data, $this->getTopicTitle(), $forum_id, $topic_id, $post_id, $notify_user);
			}

			$tracking_topics = ( !empty($HTTP_COOKIE_VARS[$board_config['cookie_name'] . '_t']) ) ? unserialize($HTTP_COOKIE_VARS[$board_config['cookie_name'] . '_t']) : array();
			$tracking_forums = ( !empty($HTTP_COOKIE_VARS[$board_config['cookie_name'] . '_f']) ) ? unserialize($HTTP_COOKIE_VARS[$board_config['cookie_name'] . '_f']) : array();
	
			if ( count($tracking_topics) + count($tracking_forums) == 100 && empty($tracking_topics[$topic_id]) )
			{
				asort($tracking_topics);
				unset($tracking_topics[key($tracking_topics)]);
			}

			$tracking_topics[$topic_id] = time();

			setcookie($board_config['cookie_name'] . '_t', serialize($tracking_topics), 0, $board_config['cookie_path'], $board_config['cookie_domain'], $board_config['cookie_secure']);
			return $post_id;
		} else {
			message_die(GENERAL_ERROR, 'An error occured when posting a reply.');
		}
	}
}

class Topic extends Item {
	private $topic_id;
	private $topic_row;

	public function __construct($topic_id) {
		$this->topic_id = $topic_id;
	}

	private function fetch() {
		if (is_null($this->topic_row)) {
			global $db;
			$sql = sprintf("SELECT * FROM %s WHERE topic_id = %d AND topic_status <> %d",
				TOPICS_TABLE, $this->topic_id, TOPIC_MOVED);
			$result = $db->sql_query($sql);
			$this->topic_row = $db->sql_fetchrow($result);
			if (is_null($this->topic_row)) {
				message_die(GENERAL_ERROR, 'Invalid topic ID.');
			}
		}
	}

	public function getForumId() {
		$this->fetch();
		return $this->topic_row['forum_id'];
	}

	public function getTopicId() {
		return $this->topic_id;
	}

	public function getTopicTitle() {
		$this->fetch();
		return $this->topic_row['topic_title'];
	}
}
?>
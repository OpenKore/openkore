<?php
class PhpBB {
	private static $phpBB_args;

	/**
	 * Initialize phpBB.
	 *
	 * @param $args  An associative array, which may contain the following options:
	 *    template: Whether the default header and footer should be printed. Defaults to true.
	 *    moderator: Whether the visitor must be a moderator. Defaults to false.
	 *    admin: Whether the visitor must be an administrator. Defaults to false.
	 *    root: Specify the phpbb root path. Defaults to './'.
	 *    title: The page title.
	 */
	public static function init($args = array()) {
		global $phpbb_root_path;
		global $phpEx;
		global $user_ip;
		global $userdata;
		global $db;
		global $themes_id;
		global $board_config;
		global $template;
		global $theme;
		global $lang;
		global $page_title;

		define('IN_PHPBB', true);

		if (isset($args['root'])) {
			$phpbb_root_path = $args['root'];
		} else {
			$phpbb_root_path = './';
		}
		include($phpbb_root_path . 'extension.inc');
		include($phpbb_root_path . 'common.'.$phpEx);

		// Start session management.
		$userdata = session_pagestart($user_ip, PAGE_FAQ);
		init_userprefs($userdata);

		if ($args['moderator'] || $args['admin']) {
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

		if (isset($args['title'])) {
			$page_title = $args['title'];
		}

		// Print default header and footer.
		if (!isset($args['template']) || $args['template']) {
			include($phpbb_root_path . 'includes/page_header.'.$phpEx);
		}

		if ($args['admin'] && $userdata['user_level'] != ADMIN) {
			message_die(GENERAL_MESSAGE, "You are not an administrator.");
		}

		self::$phpBB_args = $args;
	}

	function finalize() {
		global $phpbb_root_path;
		global $phpEx;
		global $user_ip;
		global $userdata;
		global $db;
		global $themes_id;
		global $board_config;
		global $template;
		global $theme;
		global $lang;

		$args = self::$phpBB_args;
		if ($args['template']) {
			include($phpbb_root_path . 'includes/page_tail.'.$phpEx);
		}
	}
}
?>
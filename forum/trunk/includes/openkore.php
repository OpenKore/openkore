<?php
if (!defined('IN_PHPBB')) {
	die("Hacking attempt");
}
require_once($phpbb_root_path . 'extension.inc');
require_once($phpbb_root_path . 'common.' . $phpEx);
require_once($phpbb_root_path . '/includes/constants.' . $phpEx);

/**
 * SQL utility functions.
 */
class OSQLUtils {
	/** @invariant $db instanceof sql_db */
	private $db;

	/**
	 * Construct a new OSQLUtils object.
	 *
	 * @param db  The sql_db object to use.
	 */
	public function __construct(sql_db $db) {
		$this->db = $db;
	}

	/**
	 * Escape special characters in a string for use in an SQL statement.
	 *
	 * @require !is_null($str)
	 * @ensure  !is_null(result)
	 */
	public function escape($str) {
		global $dbms;
		if ($dbms == "mysql4" || $dbms == "mysql") {
			return mysql_real_escape_string($str, $this->db->db_connect_id);
		} else {
			return addslashes($str);
		}
	}

	/**
	 * Lock $table for writing. Dies on error.
	 *
	 * @require !is_null($table)
	 */
	public function lock($table) {
		$sql = sprintf("LOCK TABLE %s WRITE", $table);
		if (!$this->db->sql_query($sql)) {
			message_die(GENERAL_ERROR, 'A database error occured while locking tables.',
				    'Error', __LINE__, __FILE__, $sql);
		}
	}

	/**
	 * Unlock all locked tables. Dies on error.
	 */
	public function unlock() {
		$sql = "UNLOCK TABLES";
		if (!$this->db->sql_query($sql)) {
			message_die(GENERAL_ERROR, 'A database error occured while unlocking tables.',
				    'Error', __LINE__, __FILE__, $sql);
		}
	}
}


/**
 * A data access object for storing and retrieving key-value options
 * specific to the OpenKore forum.
 */
class OOptions {
	const CONFIG_TABLE = "openkore_forum_config";
	const CONFIG_NAME_COLUMN  = "config_name";
	const CONFIG_VALUE_COLUMN = "config_value";

	private static $instance;

	/** @invariant $db instanceof sql_db */
	private $db;
	/** @invariant $dbu instanceof OSQLUtils */
	private $dbu;

	/**
	 * An associative array for caching options.
	 * @invariant !is_null($options)
	 */
	private $cache;


	/**
	 * Construct a new OpenKoreOptions object.
	 *
	 * @param db  The sql_db object to use.
	 */
	private function __construct(sql_db $db) {
		$this->db = $db;
		$this->dbu = new OSQLUtils($db);
		$this->cache = array();
	}

	/**
	 * Load all options from the database into the internal cache.
	 * Dies on error.
	 */
	public function loadAll() {
		$sql = sprintf("SELECT * FROM %s", self::CONFIG_TABLE);
		$result = $this->db->sql_query($sql);
		if (!$result) {
			message_die(GENERAL_ERROR, 'A database error occured while fetching configuration values.',
				    'Error', __LINE__, __FILE__, $sql);
		}

		while ($row = $db->sql_fetchrow($result)) {
			$name = $row[self::CONFIG_NAME_COLUMN];
			$this->cache[$name] = $row[self::CONFIG_VALUE_COLUMN];
		}
	}

	/**
	 * Returns the value for the configuration option $name.
	 * This method caches results, so it will only fetch from the database once
	 * for every unique $name.
	 * Dies on error.
	 *
	 * @return  The value, of null if the option is not in the database.
	 * @require !is_null($name)
	 */
	public function get($name) {
		if (isset($this->cache[$name])) {
			return $this->cache[$name];
		}

		$sql = sprintf("SELECT * FROM %s WHERE %s = '%s'",
			       self::CONFIG_TABLE,
			       self::CONFIG_NAME_COLUMN,
			       $this->dbu->escape($name));
		$result = $this->db->sql_query($sql);
		if (!$result) {
			message_die(GENERAL_ERROR, 'A database error occured while fetching configuration values.',
				    'Error', __LINE__, __FILE__, $sql);
		}

		$row = $this->db->sql_fetchrow($result);
		$value = $row[self::CONFIG_VALUE_COLUMN];
		$this->cache[$name] = $value;
		return $value;
	}

	/**
	 * @require !is_null($name) && !is_null($value)
	 * @ensure this->get($name) == $value
	 */
	public function set($name, $value) {
		$db = $this->db;
		$dbu = $this->dbu;

		$dbu->lock(self::CONFIG_TABLE);
		if ($this->has($name)) {
			$sql = sprintf("UPDATE %s SET %s = '%s' WHERE %s = '%s'",
				       self::CONFIG_TABLE,
				       self::CONFIG_VALUE_COLUMN,
				       $dbu->escape($value),
				       self::CONFIG_NAME_COLUMN,
				       $dbu->escape($name));
		} else {
			$sql = sprintf("INSERT INTO %s VALUES('%s', '%s')",
				       self::CONFIG_TABLE,
				       $dbu->escape($name),
				       $dbu->escape($value));

		}
		$result = $db->sql_query($sql);
		if (!$result) {
			message_die(GENERAL_ERROR, 'A database error occured while setting configuration values.',
				    'Error', __LINE__, __FILE__, $sql);
		}
		$dbu->unlock();
		$this->cache[$name] = $value;
	}

	/**
	 * Check whether an option exists in the database.
	 * Dies on error.
	 *
	 * @require !is_null($name)
	 */
	public function has($name) {
		$sql = sprintf("SELECT * FROM %s WHERE %s = '%s'",
			       self::CONFIG_TABLE,
			       self::CONFIG_NAME_COLUMN,
			       $this->dbu->escape($name));
		$result = $this->db->sql_query($sql);
		if (!$result) {
			message_die(GENERAL_ERROR, 'A database error occured while fetching configuration values.',
				    'Error', __LINE__, __FILE__, $sql);
		}
		return !is_null($this->db->sql_fetchrow($result));
	}

	/**
	 * Get the global OOptions instance.
	 *
	 * @ensure result instanceof OOptions
	 */
	function getInstance() {
		if (is_null(self::$instance)) {
			global $db;
			self::$instance = new OOptions($db);
		}
		return self::$instance;
	}
}

class OConstants {
	/* Users who have more than x posts are considered good citizen.
	 * Users with less than this number of posts will be shown all kinds of warnings.
	 */
	const MIN_USER_POSTS = 40;
	const SVN_GUIDE_URL = "http://www.openkore.com/wiki/index.php/What_is_SVN%3F";
	const TRASH_FORUM_NAME = "Trashcan";
	const SUPPORT_FORUM_NAME = "Other OpenKore & VisualKore Support";
	/* The 'Forum Contributors' group consists of people who are authorized to help
	 * keeping the forums clean by using the 'forum contributors' control panel,
	 * but have less privileges than sub-moderators.
	 */
	const FORUM_CONTRIBUTORS_GROUP_NAME = "Forum Contributors";

	/**
	 * Get the advertisement content.
	 */
	public static function getAdvertisement() {
		global $phpbb_root_path;
		return file_get_contents($phpbb_root_path . "templates/ad1.txt");
	}
}

/**
 * This class turns words in a message into links.
 * Word matching is case-insensitive.
 */
class OWordLinker {
	private $links;

	public function __construct() {
		$this->links = array();
	}

	/**
	 * Register a new word-to-link substitution.
	 *
	 * @require !is_null($word) && !is_null($link)
	 */
	public function addLink($word, $link) {
		$this->links[$word] = $link;
	}

	private function replaceMyWords($matches) {
		return preg_replace('/<{a .*?}>(.*?)<{\/a}>/', '$1', $matches[0]);
	}

	/**
	 * @require !is_null($message)
	 */
	public function process($message) {
		foreach ($this->links as $word => $link) {
			// Replace words with pseudo-HTML
			$regexp = '/( |\n|^|\.|&quot;)(' . preg_quote($word) . ')([ \?\.,]|&quot;|$)/i';
			$message = preg_replace($regexp,
				'$1<{a href="' . $link . '"}>$2<{/a}>$3',
				$message);

			// Remove nested links
			$message = preg_replace_callback('/<a .*?>(.*?)<\/a>/',
				array($this, 'replaceMyWords'), $message);

			// Turn pseudo-HTML into real HTML
			$message = preg_replace('/<{a (.*?)}>(.*?)<{\/a}>/', '<a $1>$2</a>', $message);
		}
		return $message;
	}
}

/**
 * Various utility functions.
 */
class OUtils {
	/**
	 * Remove one or more keys (and their values) from a query string.
	 *
	 * @param queryString A query string (the part which comes after 'http://foo.com/bar.php?').
	 * @param keys An array of keys you want to remove.
	 * @require !is_null($queryString) && !is_null($keys)
	 */
	public static function removeKeys($queryString, $keys) {
		$result = '';
		$items = explode('&', $queryString);
		foreach ($items as $item) {
			$temp = explode('=', $item);

			$removeThis = false;
			$i = 0;
			$count = count($keys);
			while ($i < $count && !$removeThis) {
				$removeThis = $keys[$i] == $temp[0];
				$i++;
			}

			if (!$removeThis) {
				$result .= '&' . $item;
			}
		}
		if (strlen($result) > 0 && $result{0} == '&') {
			return substr_replace($result, '', 0, 1);
		} else {
			return $result;
		}
	}

	/**
	 * Retrieve an integer value from the GET or POST array,
	 * whichever is first available.
	 *
	 * @param name  The name of the key.
	 * @return An integer value, or an empty string if not found.
	 * @require !is_null($name)
	 * @ensure  !is_null(result)
	 */
	public static function getIntSetting($name) {
		if (isset($_GET[$name]) || isset($_POST[$name])) {
			return (isset($_GET[$name])) ? intval($_GET[$name]) : intval($_POST[$name]);
		} else {
			return '';
		}
	}

	/**
	 * Check whether the current user is a forum contributor.
	 *
	 * @require $userdata and $is_auth must already have been initialized.
	 */
	public static function isForumContributor() {
		global $is_auth;
		if ($is_auth['auth_mod']) {
			return true;
		} else if (!$is_auth['auth_view'] || !$is_auth['auth_read']) {
			return false;
		} else {
			global $userdata;
			global $db;
			$dbu = new OSQLUtils($db);
			$sql = sprintf("SELECT u.user_id FROM " . USERS_TABLE . " u, " . USER_GROUP_TABLE . " ug, " . GROUPS_TABLE . " g " .
				"WHERE u.user_id = ug.user_id AND ug.group_id = g.group_id " .
				"AND u.user_id = %d AND g.group_name = '%s'",
				$dbu->escape($userdata['user_id']),
				$dbu->escape(OConstants::FORUM_CONTRIBUTORS_GROUP_NAME));
			$result = $db->sql_query($sql);
			if (!$result) {
				message_die(GENERAL_ERROR, 'A database error occured.',
					'Error', __LINE__, __FILE__, $sql);
			}

			$row = $db->sql_fetchrow($result);
			return $row != FALSE;
		}
	}
}
?>
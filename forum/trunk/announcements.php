<?php
define('ANNOUNCEMENTS_FORUM_NAME', "Announcements");
define('WEBSITE_BASE_URL', "http://" . $_SERVER['HTTP_HOST'] . dirname($_SERVER['REQUEST_URI']));

require_once('includes/phpbb.php');
PhpBB::init(array('template' => false));

header("Content-Type: text/plain");
printNewsFeed(getNews());

PhpBB::finalize();

function getNews($announcementsForum = ANNOUNCEMENTS_FORUM_NAME, $limit = 8) {
	global $db;
	$sql = sprintf("SELECT topic_id, topic_title, topic_time " .
		"FROM %s WHERE forum_id = " .
			"(SELECT forum_id FROM %s WHERE forum_name = '%s' LIMIT 1) " .
		"ORDER BY topic_time DESC " .
		"LIMIT %d",
		TOPICS_TABLE, FORUMS_TABLE,
		addslashes($announcementsForum), $limit);
	$result = $db->sql_query($sql);
	if (!result) {
		die("Cannot query database.");
	}

	$rows = $db->sql_fetchrowset($result);
	$db->sql_freeresult($result);
	return $rows;
}

function printNewsFeed($news) {
	global $phpEx;
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
	echo "<announcements>\n";
	foreach ($news as $item) {
		$url = WEBSITE_BASE_URL . "viewtopic." . $phpEx . "?t=" . $item['topic_id'];
		echo "	<item>\n";
		echo "		<title>" . htmlentities($item['topic_title']) . "</title>\n";
		echo "		<timestamp>" . $item['topic_time'] . "</timestamp>\n";
		echo "		<id>" . $item['topic_id'] . "</id>\n";
		echo "		<url>" . htmlentities($url) . "</url>\n";
		echo "	</item>\n";
	}
	echo "</announcements>\n";
}
?>
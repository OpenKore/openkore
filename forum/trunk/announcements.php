<?php
define('ANNOUNCEMENTS_FORUM_NAME', "Announcements");
define('WEBSITE_BASE_URL', "http://forums.openkore.com/");
define('FORUM_DATABASE_ENCODING', 'UTF-8');

define('IN_PHPBB', true);
$phpbb_root_path = './';
include($phpbb_root_path . 'extension.inc');
include($phpbb_root_path . 'common.'.$phpEx);

header("Content-Type: application/xml");
printNewsFeed(getNews());

function getNews($limit = 8) {
	global $db;
	$sql = sprintf("SELECT topic_id, topic_title, topic_time " .
		"FROM %s WHERE forum_id = " .
			"(SELECT forum_id FROM %s WHERE forum_name = '%s' LIMIT 1) " .
		"ORDER BY topic_time DESC " .
		"LIMIT %d",
		TOPICS_TABLE, FORUMS_TABLE,
		addslashes(ANNOUNCEMENTS_FORUM_NAME), $limit);
	$result = $db->sql_query($sql);
	if (!result) {
		die("Cannot query database.");
	}

	$rows = $db->sql_fetchrowset($result);
	$db->sql_freeresult($result);
	for ($i = 0; $i < count($rows); $i++) {
		$rows[$i]['topic_title'] = html_entity_decode($rows[$i]['topic_title'],
			ENT_QUOTES, FORUM_DATABASE_ENCODING);
	}
	return $rows;
}

function printNewsFeed($news) {
	global $phpEx;
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
	echo "<announcements>\n";
	foreach ($news as $item) {
		$url = WEBSITE_BASE_URL . "viewtopic." . $phpEx . "?t=" . $item['topic_id'];
		echo "	<item>\n";
		echo "		<title>" . htmlspecialchars($item['topic_title'], ENT_NOQUOTES) . "</title>\n";
		echo "		<timestamp>" . $item['topic_time'] . "</timestamp>\n";
		echo "		<id>" . $item['topic_id'] . "</id>\n";
		echo "		<url>" . $url . "</url>\n";
		echo "	</item>\n";
	}
	echo "</announcements>\n";
}
?>

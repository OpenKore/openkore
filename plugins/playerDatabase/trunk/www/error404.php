<?php
include_once('loginMySQL.php');

if (loginMySQL()) {
	$url = empty($_SERVER['HTTP_REFERER']) ? $_SERVER['REQUEST_URI'] : $_SERVER['HTTP_REFERER'];
	$query = mysql_fetch_object(mysql_query('SELECT * FROM `logs_error404` WHERE `url` = \'' . $url . '\';'));

	if ($query) {
		$query->amount = $query->amount + 1;
		mysql_query('UPDATE `logs_error404` SET amount = ' . $query->amount . ' WHERE url = \'' . $url . '\';');
	} else {
		mysql_query('INSERT INTO `logs_error404`(`url`, `amount`) VALUES(\'' . $url . '\', \'' . 1 . '\');');
	}
}
?>

<html>
<head>
<link rel="shortcut icon" HREF="error404.ico">
</head>
You should want to go to this...<br>
TODO: Include links here to get to other pages
</html>
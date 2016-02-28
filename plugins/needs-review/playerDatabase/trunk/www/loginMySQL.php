<?php
function loginMySQL() {
	$link = mysql_connect('127.0.0.1', 'root', '');
	if (!$link) {
		die ('Error connecting to MySQL: ' . mysql_error());
	} else {
		$db_selected = mysql_select_db('broplayer', $link);

		if (!$db_selected) {
			die ('Error connecting to database: ' . mysql_error());
		} else {
			return(1);
		}
	}
}
?>
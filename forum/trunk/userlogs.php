<?php
require_once('includes/phpbb.php');
PhpBB::init(array('title' => 'User logs', 'admin' => true));

if (!empty($_GET['type']) && $_GET['type'] == 'Username')
	$sql = "SELECT * FROM userlogs WHERE INSTR(username, '" . mysql_escape_string($_GET['search']) . "') ORDER BY last_time DESC LIMIT 20";
else if (!empty($_GET['type']) && $_GET['type'] == 'IP')
	$sql = "SELECT * FROM userlogs WHERE INSTR(ip, '" . mysql_escape_string($_GET['search']) . "') ORDER BY last_time DESC LIMIT 20";
else {
	$sql = "SELECT * FROM userlogs ORDER BY last_time DESC LIMIT 20";
	$normal = 1;
}

$result = $db->sql_query($sql);
if (!$result) {
	message_die(GENERAL_MESSAGE, "Cannot query database.", 'Error', __LINE__, __FILE__, $sql);
}

$num = 0;
while ($row = $db->sql_fetchrow($result)) {
	if ($num % 2 == 0)
		$class = 'row1';
	else
		$class = 'row2';
	$data .= "<tr class=\"$class\">\n";
	$data .= "	<td><a href=\"profile.php?mode=viewprofile&u=$row[user_id]\">$row[username]</a></td>\n";
	$data .= "	<td>$row[ip]</td>\n";
	$data .= "	<td>" . strftime("%B %e, %Y %r", $row[last_time]) . "</td>\n";
	$data .= "</tr>\n";
	$num++;
}

if ($normal) {
	$status = "Last $num visits:";
} else {
	$status = "Search results for '" . htmlentities($_GET['search']) . "'";
}

$template->set_filenames(array('body' => 'userlogs.tpl'));
$template->assign_vars(array(
	'SID' => $userdata['session_id'],
	'STATUS' => $status,
	'DATA' => $data
));
$template->pparse('body');

PhpBB::finalize();
?>

<?php
define('IN_PHPBB', true);
$phpbb_root_path = './';
include($phpbb_root_path . 'extension.inc');
include($phpbb_root_path . 'common.'.$phpEx);

//
// Start session management
//
$userdata = session_pagestart($user_ip, PAGE_FAQ);
init_userprefs($userdata);
//
// End session management
//

include($phpbb_root_path . 'includes/page_header.'.$phpEx);

if ($userdata['user_level'] != ADMIN)
	message_die(GENERAL_MESSAGE, "You are not an administrator.");


if ($HTTP_GET_VARS['type'] == 'Username')
	$sql = "SELECT * FROM userlogs WHERE INSTR(username, '" . mysql_escape_string($HTTP_GET_VARS['search']) . "') ORDER BY last_time DESC LIMIT 20";
else if ($HTTP_GET_VARS['type'] == 'IP')
	$sql = "SELECT * FROM userlogs WHERE INSTR(ip, '" . mysql_escape_string($HTTP_GET_VARS['search']) . "') ORDER BY last_time DESC LIMIT 20";
else {
	$sql = "SELECT * FROM userlogs ORDER BY last_time DESC LIMIT 20";
	$normal = 1;
}

$result = $db->sql_query($sql);
if (!$result)
	message_die(GENERAL_MESSAGE, "Cannot query database.", 'Error', __LINE__, __FILE__, $sql);

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
	$data .= "</tr>";
	$num++;
}

echo "<a href=\"index.php\" class=\"nav\"><b>Forum Index</b></a>

<style class=\"text/css\">
td, .search {
	font-size: small;
}
.row1 {
	background: #eeeeee;
}
</style>

<p><p>
<form class=\"search\" method=\"get\" action=\"userlogs.php\">
<input type=\"text\" name=\"search\">
<select name=\"type\">
	<option>Username</option>
	<option>IP</option>
</select>
<input type=\"submit\" value=\"Search\">
</form>

";

if ($normal)
	echo "<h3>Last $num visits:</h3>\n";
else
	echo "<h3>Search results for '$_GET[search]'</h3>\n";

echo "<table class=\"forumline\" width=\"85%\">
<tr>
	<th>Username</th>
	<th>IP</th>
	<th>Last Visit</th>
</tr>
$data
</table>";


include($phpbb_root_path . 'includes/page_tail.'.$phpEx);
?>

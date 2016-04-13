<?php
/* roshop v.0.9.2
**
** this programm is ...
** ... dont want to write much right now
**
**
**
**
**
**
**
**
** first of all define some things:
*/
$progName="dataminer";
$progVersion="v.0.0.1";
$datum=getdate(time());
$debug="0";
$user="chardb";
$pass="setthis";
$database="chardb";
$server="localhost";
$port="3306";
$image_path="items/";
$ext_info_url="http://www.roempire.com/database/?page=items&act=view&iid=";
$ext_mercdb_url="http://market.leetbox.de/index.php?ROserver=[FULL]%20Chaos&shopcontent=";
if (!isset($p_ROserver)||$p_ROserver == "") $p_ROserver = "[Full] Chaos";
//
import_request_variables('p', 'p_');
import_request_variables('g', 'g_');

$var=array();
if($p_chname<>"")
	array_push($var, "chname=$p_chname");
if($p_giname<>"")
	array_push($var, "giname=$p_giname");
if($p_gpname<>"")
	array_push($var, "gpname=$p_gpname");
if($p_paname<>"")
	array_push($var, "paname=$p_paname");
if($p_acid<>"")
	array_push($var, "acid=$p_acid");
if($p_acserver<>"")
	array_push($var, "acserver=" . urlencode($p_acserver));

if(sizeof($var)){
	$querystr=implode("&", $var);
	$url="index.php?".$querystr;
	header("Refresh: 0;$url"); 
	echo "<html>";
	echo "<head>";
	echo "<title>Redirect</title>";
	echo "<link rel=\"stylesheet\" href=\"/css/style_default.css\" type=\"text/css\" />";
	echo "<META HTTP-EQUIV=\"content-type\" CONTENT=\"text/html; charset=iso-8859-1\">";
	echo "<META HTTP-EQUIV=\"refresh\" CONTENT=\"1; URL=$url\">";
	echo "</head>";
	echo "<body>"; 
	echo "Redirecting to <a href=\"$url\">$url</a>";
	echo "</body></html>";
	exit(0);
}

if($g_chname<>"")
	array_push($var, "chname=$g_chname");
if($g_giname<>"")
	array_push($var, "giname=$g_giname");
if($g_gpname<>"")
	array_push($var, "gpname=$g_gpname");
if($g_paname<>"")
	array_push($var, "paname=$g_paname");
if($g_acid<>"")
	array_push($var, "acid=$g_acid");
if($g_acserver<>"")
	array_push($var, "acserver=" . urlencode($g_acserver));

if(sizeof($var))
	$querystr=implode("&", $var);

/*
** Changelog:
** - way too much right now
** -
** -
** -
**
**
**
*/

if(empty($_POST['username']) && $HTTP_COOKIE_VARS['username'])
{
	$_POST['username'] = $HTTP_COOKIE_VARS['username'];
	$_POST['passwd'] = $HTTP_COOKIE_VARS['passwd'];
}
session_start();

function getmicrotime(){
   list($usec, $sec) = explode(" ", microtime());
   return ((float)$usec + (float)$sec);
}

ob_start();
$microtime1=getmicrotime();
// Use $HTTP_SESSION_VARS with PHP 4.0.6 or less
if ($_POST['username']=="" && !isset($_SESSION['username'])) {
// login-screen:
// -> u need to be logged in, to use the features
//
	echo "<html>\n";
	echo "<head>\n";
	echo "<title>Login</title>\n";
	echo "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />\n";
	echo "<meta http-equiv=\"pragma\" content=\"no-cache\" />\n";
	echo "<link rel=\"stylesheet\" href=\"css/style_default.css\" type=\"text/css\" />\n";
	echo "</head>\n";
	echo "<body>\n";
	echo "<div align=\"center\">\n";
	echo "<table valign=\"middle\" class=\"tablestyleintro\">\n";
	echo "<tr class=\"bghighlight2\">\n";
	echo "<td>\n";
	echo "<div align=\"center\">";
	echo "<H1>Login</H1>\n";
	echo "This is a private site! Please login! (All logins are logged!)<br/>\n";
	echo "You dont have an account ? Bad luck for you! Sorry! /gg<br/>\n";
	echo "</div>\n";
	echo "<form method=\"post\" action=\"". basename(__FILE__) ."\" name=\"loginmenu\">\n";
	echo "<div align=\"center\">\n";
	echo "<table border=\"0\">\n";
	echo "<tr class=\"bghighlight2\">\n";
	echo "<td>Login</td><td>:</td><td><input type=\"text\" name=\"username\"></td>\n";
	echo "</tr><br/>\n";
	echo "<tr class=\"bghighlight2\">\n";
	echo "<td>Password</td><td>:</td><td><input type=\"password\" name=\"passwd\"></td>\n";
	echo "</tr>\n";
	echo "<tr class=\"bghighlight2\">\n";
	echo "<td colspan=\"2\"><input type=\"Checkbox\" name=\"autologin\" value=\"1\"> Auto Login</td>\n";
	echo "<td align=\"center\"><input type=\"submit\" value=\"Login!\"></td>\n";
	echo "</tr>\n";
	echo "<tr><td colspan='3'>&nbsp;</td></tr>";
	echo "<tr class=\"bghighlight2\"><td colspan='3'><center>Best viewed in <a href='http://www.mozilla.com'><u>Firefox</u></a> - Problems with ie, which sucks!</center>";
	echo "<center>Please switch Cookies on for Session Tracking.</center>";
	echo "<center>min 1024x768 recommended!</center></td></tr>";
	echo "</table>\n";
	echo "</div>\n";
	echo "</form>\n";
	echo "</td>\n";
	echo "</tr>\n";
	echo "</table>\n";
	echo "</div>\n";
	echo "</body>\n";
	echo "</html>\n";
	exit;
}

if (!$link = mysql_connect("$server:$port", $user, $pass))
echo mysql_errno().": ".mysql_error()."<br/>";

// db selection:
$query = "use $database";
if (!mysql_query($query, $link)){
	echo("<H1>Database $dbase not found.</H1>\n");
	#include ("../inc/footer.php");
	die();
}
if (!isset($_SESSION['username']) && $_POST['username']!="")
{
	$result=mysql_query("select usname, ususid, usadmin, usshortsearch from users where usname = '" . $_POST['username'] . "' and uspass = '" . $_POST['passwd'] . "'");
	if (!$result)
	{
		$message  = 'Invalid query: ' . mysql_error() . "\n";
		die($message);
	}
	$row=mysql_fetch_row($result);
	if($row[0]!=$_POST['username'])
	{
		echo "<html>\n";
		echo "<head>\n";
		echo "<title>Login</title>\n";
		echo "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />\n";
		echo "<meta http-equiv=\"pragma\" content=\"no-cache\" />\n";
		echo "<link rel=\"stylesheet\" href=\"css/style_default.css\" type=\"text/css\" />\n";
		echo "</head>\n";
		echo "<body>";
		echo "<div align=\"center\">\n";
		echo "<table valign=\"middle\" class=\"tablestyleintro\">\n";
		echo "<tr class=\"bghighlight2\">\n";
		echo "<td>\n";
		echo "<div align=\"center\">";
		echo "<H1>&nbsp;</H1>\n";
		echo "<br/>\n";
		echo "<br/>\n";
		echo "<a href=\"". basename(__FILE__) ."\">Login Incorrect!!!</a>\n";
		echo "<br/><br/><br/><br/><br/><br/><br/>\n";
		echo "</div>\n";
		echo "</td>\n";
		echo "</tr>\n";
		echo "</table>\n";
		echo "</div>\n";
		echo "</body>";
		echo "</html>\n";
		exit;
	}

		if($HTTP_POST_VARS['autologin'] == true)
		{
			setcookie ("username", $_POST['username'],time()+604800);
			setcookie ("passwd", $_POST['passwd'],time()+604800);
		}
	$_SESSION['username']=$_POST['username'];
	$_SESSION['userid']=$row[1];
	$_SESSION['usadmin']=$row[2];
	$_SESSION['usshortsearch']=$row[5];

	$query="insert into logins (lgusid, lgip) values (" . $row[1] . ", '" . @getenv("REMOTE_ADDR") . "')";
	$result=mysql_query($query);
	if (!$result) {
		$message  = 'Invalid query: ' . mysql_error() . "\n";
		$message .= 'Whole query: ' . $query;
		die($message);
	}
}
// main page header starts here
//
//
echo "<html>\n";
echo "<head>\n";
echo "<title>".$progName.": ".$progVersion."</title>\n";
echo "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />\n";
echo "<meta http-equiv=\"pragma\" content=\"no-cache\" />\n";
echo "<meta name=\"description\" content=\"roshop, find items fast\" />\n";
echo "<meta name=\"author\" content=\"none\" />\n";
echo "<meta name=\"publisher\" content=\"none\" />\n";
echo "<meta name=\"distribution\" content=\"global\" />\n";
echo "<meta name=\"expires\" content=\"0\" />\n";
echo "<meta name=\"robots\" content=\"nofollow\" />\n";
echo "<meta name=\"language\" content=\"english, en\" />\n";
echo "<meta name=\"revisit-after\" content=\"999 days\" />\n";
echo "<link rel=\"stylesheet\" href=\"css/style_default.css\" type=\"text/css\" />\n";
echo "<script language=\"JavaScript\" type=\"text/javascript\" src=\"/scripts/default.js\"></script>\n";
echo "</head>\n";
echo "<body>\n";
echo "".$progName." ".$progVersion." | ";
$query_time = "SELECT max( setimestamp ) AS last FROM seen";
$res_time = mysql_query($query_time, $link);
$d_time = mysql_fetch_array($res_time);
echo "Last player seen: " .  strftime("%c", $d_time[last]) . "<br/>";

$query_count = "SELECT count( acacid ) AS p_count FROM account";
$res_count = mysql_query($query_count, $link);
$d_count = mysql_fetch_array($res_count);
echo "Total known accounts: " . $d_count[p_count] . " | ";
$query_count = "select count( chchid ) AS p_count from chars";
$res_count = mysql_query($query_count, $link);
$d_count = mysql_fetch_array($res_count);
echo "Total known chars: " . $d_count[p_count] . "<br/>";
$query_count = "select count( gigiid ) AS p_count from guild";
$res_count = mysql_query($query_count, $link);
$d_count = mysql_fetch_array($res_count);
echo "Total known guilds: " . $d_count[p_count] . " | ";
$query_count = "select count( papaid ) AS p_count from party";
$res_count = mysql_query($query_count, $link);
$d_count = mysql_fetch_array($res_count);
echo "Total known parties: " . $d_count[p_count] . " | ";
$query_count = "SELECT count( seseid ) AS p_count FROM seen";
$res_count = mysql_query($query_count, $link);
$d_count = mysql_fetch_array($res_count);
echo "Total chars seen: " . $d_count[p_count] . "<br/>";

$today = date('Y-m-d');
$query_count = "SELECT count( * ) AS p_count FROM `queryhist`";
$res_count = mysql_query($query_count, $link);
$d_count = mysql_fetch_array($res_count);
echo "Total Number of Queries: " . $d_count[p_count] . " | ";
$query_count = "SELECT count( * ) AS p_count FROM `queryhist` where qhdate > '$today 00:00:00'";
$res_count = mysql_query($query_count, $link);
$d_count = mysql_fetch_array($res_count);
echo "Queries today: " . $d_count[p_count] . " | ";
$query_count = "SELECT count( * ) AS p_count FROM `logins`";
$res_count = mysql_query($query_count, $link);
$d_count = mysql_fetch_array($res_count);
echo "Total Number of Logins: " . $d_count[p_count] . " | ";
$query_count = "SELECT count( * ) AS p_count FROM `logins` where lgdate > '$today 00:00:00'";
$res_count = mysql_query($query_count, $link);
$d_count = mysql_fetch_array($res_count);
echo "Logins today: " . $d_count[p_count] . "<br>";

echo "<div class=\"pagedirection\">\n";
echo "<H1><a href=\"index.php\">Data-Miner</a></H1>\n";

// shoutbox hanling
if (!$_POST['shoutins']==""){
	$query_double = "select sbmessage from shoutbox where sbusid = " . $_SESSION['userid'] . " order by sbdate desc limit 0,2";
	$res_double = mysql_query($query_double);
	$row_double = mysql_fetch_row($res_double);
	if($row_double[0] != $_POST['shoutins']){
		$sinsquery="insert into shoutbox (sbusid, sbmessage) values (" . $_SESSION['userid'] . ", '" . preg_replace ("@</?[^>]*>*@", "", $_POST['shoutins']) . "')";
		mysql_query($sinsquery);
		echo "ShoutBox updated!<br/><br/>";
	}
}

if (!$_GET['delete']=="" && $_SESSION['usadmin']=="Yes"){
	$delquery="delete from shoutbox where sbsbid = " . $_GET['delete'];
	mysql_query($delquery);
	echo "ShoutBoxEntry " . $_GET['delete'] . " deleted, oh master!<br/><br/>";
}

// Query-Fields:
// -> containing input fields for items/card lookups and map-view
// (input fields)
echo "<table class=\"tablestyle\">\n";
echo "<tr class=\"bghighlight0\">\n";
echo "<td class=\"head\" align=\"center\" colspan=\"3\">Interaction</td>\n";
echo "</tr>";
echo "<tr class=\"bghighlight2\">\n";
echo "<td align=\"center\">\n<br/><br/>\n";
echo "<form method='get' ENCTYPE='multipart/form-data' action='" . basename(__FILE__) ."'>\n";
echo "<table>";
echo "<tr><td>Character Name</td><td>:</td><td><input type='text' NAME='chname' SIZE='40' value='$g_chname'/></td></tr>\n";
echo "<tr><td>Guild Name</td><td>:</td><td><input type='text' NAME='giname' SIZE='40' value='$g_giname'/></td></tr>\n";
echo "<tr><td>Guild Position</td><td>:</td><td><input type='text' NAME='gpname' SIZE='40' value='$g_gpname'/></td></tr>\n";
echo "<tr><td>Party Name</td><td>:</td><td><input type='text' NAME='paname' SIZE='40' value='$g_paname'/></td></tr>\n";
echo "<tr><td>Acount ID</td><td>:</td><td><input type='text' NAME='acid' SIZE='40' value='$g_acid'/></td></tr>\n";

// select server
$server_query = "SELECT distinct(acserver) as acserver FROM account ORDER BY 1";
$res_server = mysql_query($server_query, $link);
$rows_server = mysql_num_rows($res_server);
if ((!$res_server) or ($rows_server==0)){
	echo("Abfrage '$query_map' nicht erfolgreich.\n");
	die();
}else {
     echo "<tr><td>Server</td><td>:</td><td><SELECT NAME='acserver'>\n";
     while($d_server = mysql_fetch_array($res_server)){
         echo "<OPTION";
         if (($d_server[acserver] == $p_acserver) or ($d_server[acserver] == $g_acserver)) echo " SELECTED ";
         echo ">$d_server[acserver]</OPTION>\n";
     }
     echo "</SELECT></td></tr>\n";
}


echo "<tr><td colspawn='3'><center><input type='submit' name='Submit' value='Search' /></center></td></tr></table>\n";
echo "</form>\n";
echo "</td>\n";
// -> shoutbox
echo "<td align=\"center\">\n<br/>\n";
echo "Shoutbox Message";
echo "<form method='post' ENCTYPE='multipart/form-data' action='" . basename(__FILE__) ."'>\n";
echo "<textarea name=\"shoutins\" rows=\"3\" cols=\"30\" wrap=\"virtual\" maxlength=\"400\">";
echo "Enter Shout Message here! max. 400 chars!</textarea><br/><br/>\n";
echo "<input type='submit' name='Submit' value='Save' />\n";
echo "</form>\n";
echo "</td></tr></table>\n";

$queryinfo="";

if($g_acserver=="")
	echo "Server not set - rejecting query!<br/><br/>";
else{
	if($g_acacid <> "" && $g_chchid <> ""){
		// this prints the user details

		// account id
		$query="select acroacid, actimestamp from account where acacid = $g_acacid and acserver = '$g_acserver'";
		$res=mysql_query($query);
		$row=mysql_fetch_row($res);
		echo "<b>Charakter Data</b><br/>";
		echo "Account-ID: $row[0]<br/>";
		echo "Account-First Seen: $row[1]<br/>";
		
		$query="select chname, chclass, chsex, chlevel, chtimestamp from chars where chacid = $g_acacid and chchid = $g_chchid";
		$res=mysql_query($query);
		$row=mysql_fetch_row($res);
		echo "Char-Name: $row[0]<br/>";
		echo "Char-Class: $row[1]<br/>";
		echo "Char-Sex: $row[2]<br/>";
		echo "Char-Level: $row[3]<br/>";
		echo "Char-Last Seen: $row[4]<br/><br/>";
				
		echo "<b>Parties he was in [Date]</b><br/>";
		$query="select paname, patimestamp from party where pachid=$g_chchid order by patimestamp desc";
		$res=mysql_query($query);
		while($row=mysql_fetch_row($res)){
			echo "$row[0] [$row[1]]<br/>";
		}
		echo "<br/>";
		
		echo "<b>Guilds he was in [Date]</b><br/>";
		$query="select giname, c2gtimestamp from char2guild left join guild on gigiid = c2ggiid where c2gchid=$g_chchid order by c2gtimestamp desc";
		$res=mysql_query($query);
		while($row=mysql_fetch_row($res)){
			echo "$row[0] [$row[1]]<br/>";
		}
		echo "<br/>";

		echo "<b>Guild-Positions he had [Date]</b><br/>";
		$query="select gpposition, gptimestamp from guildpos where gpchid=$g_chchid order by gptimestamp desc";
		$res=mysql_query($query);
		while($row=mysql_fetch_row($res)){
			echo "$row[0] [$row[1]]<br/>";
		}
		echo "<br/>";

		echo "<b>Seen at map(x/y) -level- [date]</b><br/>";
		$query="select semap, seposx, seposy, selevel, setimestamp, seseenbyacid from seen where sechid=$g_chchid order by setimestamp desc";
		$res=mysql_query($query);
		while($row=mysql_fetch_row($res)){
			echo "$row[0]($row[1]/$row[2]) -$row[3]- [$row[4]] - Seen by: $row[5]<br/>";
		}
		echo "<br/>";

		
	}else{
	
	
	
		// this prints the user overview
		$acacids=array();
		$acroacids=array();
		$searchclause=array();
		// get search paramters
		if($g_chname!=""){
			$query="select acacid, acroacid from chars left join account on chacid = acacid where chname LIKE '%$g_chname%' and acserver = '$g_acserver' order by acroacid desc";
			$res=mysql_query($query);
			while($row=mysql_fetch_row($res))
				if(!in_array($row[0], $acacids)){
					array_push($acacids, $row[0]);
					array_push($acroacids, $row[1]);
				}
			array_push($searchclause, "Character-Name = '$g_chname'");
		}

		if($g_giname!=""){
			$query="select acacid, acroacid from guild left join char2guild on c2ggiid = gigiid left join chars on c2gchid = chchid left join account on chacid = acacid where giname LIKE '%$g_giname%' group by 1,2 order by acroacid desc, chlevel, chname desc";
			$res=mysql_query($query);
			while($row=mysql_fetch_row($res))
				if(!in_array($row[0], $acacids)){
					array_push($acacids, $row[0]);
					array_push($acroacids, $row[1]);
				}
			array_push($searchclause, "Guild-Name = '$g_giname'");			 
		}
		
		if($g_gpname!=""){
			$query="select acacid, acroacid from guildpos left join chars on gpchid = chchid left join account on chacid = acacid where gpposition LIKE '%$g_gpname%'  group by 1,2 order by acroacid desc, chlevel, chname desc";
			$res=mysql_query($query);
			while($row=mysql_fetch_row($res))
				if(!in_array($row[0], $acacids)){
					array_push($acacids, $row[0]);
					array_push($acroacids, $row[1]);
				}
			array_push($searchclause, "Guild-Position = '$g_gpname'");			 			 
		}
		
		if($g_paname!=""){
			$query="select acacid, acroacid from party left join chars on pachid = chchid left join account on chacid = acacid where paname LIKE '%$g_paname%'  group by 1,2 order by acroacid desc, chlevel, chname desc";
			$res=mysql_query($query);
			while($row=mysql_fetch_row($res))
				if(!in_array($row[0], $acacids)){
					array_push($acacids, $row[0]);
					array_push($acroacids, $row[1]);
				}
			array_push($searchclause, "Party-Name = '$g_paname'");						 
		}
		
		if($g_acid!=""){
			$query="select acacid, acroacid from account where acroacid = '$g_acid'";
			$res=mysql_query($query);
			while($row=mysql_fetch_row($res))
				if(!in_array($row[0], $acacids)){
					array_push($acacids, $row[0]);
					array_push($acroacids, $row[1]);
				}
			array_push($searchclause, "Account-ID = '$g_acid'");			 
		}
		
		echo "<br/><b>Searching for:</b><br/>" . implode(" OR ", $searchclause) . "<br/><br/>";
		
		if(sizeof($acacids)){
			// build info page
			echo "<br/><br/><table class=\"tablestyle\"><tr class=\"bghighlight0\">".
				"<td class=\"head\">AccID</td>".
				"<td class=\"head\">Name</td>".
				"<td class=\"head\">Sex</td>".
				"<td class=\"head\">Class</td>".
				"<td class=\"head\">Level</td>".
				"<td class=\"head\">Last Seen</td>".
				"<td class=\"head\">Last Party</td>".
				"<td class=\"head\">Last Guild</td>".
				"<td class=\"head\">Last GuildPos</td>".
				"<td class=\"head\">Last Map</td>".
				"<td class=\"head\">Open Shop</td>".
				"<td class=\"head\">Char Detail</td>".
				"</tr>";
		}

		$rowToggle=1;
				
		while(sizeof($acacids) && $acacid=array_pop($acacids)){
			$acroacid=array_pop($acroacids);
			$rowToggle*=-1;
			$qrChars = "select chchid, chname, chsex, chclass, chlevel, chtimestamp from chars where chacid = $acacid order by chlevel desc";
			$resChars = mysql_query($qrChars);
			
			while($rowChars = mysql_fetch_row($resChars)){
				echo "<tr ";
				if($rowToggle>0)
					echo "class=\"bghighlight2\"";
				else
					echo "class=\"bghighlight1\"";
				echo " onmouseover=\"setPointer(this);\" onmouseout=\"unsetPointer(this);\"><td>$acroacid</td><td>$rowChars[1]</td><td>$rowChars[2]</td><td>$rowChars[3]</td><td>$rowChars[4]</td><td>$rowChars[5]</td>";

				// Last Party
				$qrParty="select paname, date(patimestamp) from party where pachid = $rowChars[0] order by patimestamp desc";
				$resParty=mysql_query($qrParty);
				$rowParty=mysql_fetch_row($resParty);
				echo "<td>[$rowParty[1]] $rowParty[0]</td>";
				
				// Last Guild
				$qrGuild="select giname , date(c2gtimestamp) from guild left join char2guild on c2ggiid = gigiid where c2gchid = $rowChars[0] order by c2gtimestamp desc";
				$resGuild=mysql_query($qrGuild);
				$rowGuild=mysql_fetch_row($resGuild);
				echo "<td>[$rowGuild[1]] $rowGuild[0]</td>";

				// Last GuildPos
				$qrGuildPos="select gpposition, date(gptimestamp) from guildpos where gpchid = $rowChars[0] order by gptimestamp desc";
				$resGuildPos=mysql_query($qrGuildPos);
				$rowGuildPos=mysql_fetch_row($resGuildPos);
				echo "<td>[$rowGuildPos[1]] $rowGuildPos[0]</td>";		

				// Last Map
				$qrSeen="select semap, date(setimestamp), seposx, seposy from seen where sechid = $rowChars[0] order by setimestamp desc";
				$resSeen=mysql_query($qrSeen);
				$rowSeen=mysql_fetch_row($resSeen);
				echo "<td>[$rowSeen[1]] $rowSeen[0] ($rowSeen[2]/$rowSeen[3])</td>";		
				
				echo "<td><a href=$ext_mercdb_url$acroacid>--&gt;X&lt;--</a></td>";
				echo "<td><a href=\"index.php?acacid=$acacid&chchid=$rowChars[0]";
				if($querystr<>"")
					echo "&$querystr";
				echo "&acserver=" . urlencode($g_acserver) .  "\">--&gt;X&lt;--</a></td></tr>";
			}
		}
		echo "</table>";
	}
}


// Query History
// -> shows last 10 entries
//
$stats_query = "Select qhdate, qhquery, qhusid, usname, uscomment from queryhist left join users on ususid=qhusid ";
if($_SESSION['usadmin']=="No")
	$stats_query .= "where length(qhquery) > 2 ";
$stats_query .= "order by qhdate desc limit 0, 10";
$stats_res = mysql_query($stats_query);
echo "<br/><br/><table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" width=\"100%\">\n";
echo "<tr>\n<td valign=\"top\">\n";
echo "<table class=\"tablestyle\">\n";
echo "<tr class=\"bghighlight0\">\n<td class=\"head\" valign=\"top\" colspan=\"5\">Last Queries</td></tr>\n";
echo "<tr class=\"bghighlight0\">\n";
echo "<td class=\"head\">Date</td>\n";
echo "<td class=\"head\">Query</td>\n";
echo "<td class=\"head\">UserID</td>\n";
if($_SESSION['usadmin']=="Yes"){
	echo "<td class=\"head\">Username</td>\n";
	echo "<td class=\"head\">Comment</td>\n";
}

echo "</tr>\n";
for($iTmp2=1;$iTmp2<=10;$iTmp2++){
	$stats_row=mysql_fetch_row($stats_res);
    echo "<tr class=\"bghighlight2\" onmouseover=\"setPointer(this);\" onmouseout=\"unsetPointer(this);\">\n";
	echo "<td>". $stats_row[0] . "</td>\n";
	echo "<td nowrap=\"nowrap\"><a class=\"iconlink\" href=\"" . basename(__FILE__) ."?name=" . $stats_row[1] . "&server=" . $g_ROserver . "\">" . $stats_row[1] . "</a></td>\n";
	echo "<td style=\"text-align: right;\">" . $stats_row[2] . "</td>";
	if($_SESSION['usadmin']=="Yes"){
		echo "<td>".$stats_row[3]."&nbsp;</td>\n";
		echo "<td>".$stats_row[4]."&nbsp;</td>\n";
	}
	echo "</tr>\n";
}
echo "</table>\n";

//table split (search history / comment)
echo "</td>\n<td>&nbsp;&nbsp;&nbsp;&nbsp;</td>\n<td valign=\"top\">\n";

$stats_query = "Select sbdate, sbmessage, sbusid, usname, uscomment, sbsbid from shoutbox left join users on ususid=sbusid order by sbdate desc limit 0, 10";
$stats_res = mysql_query($stats_query);
// Shoutbox
// -> lists last 10 entries of shoutbox message query
//
echo "<table class=\"tablestyle\">\n";
$span=4;
if($_SESSION['usadmin']=="Yes")
	$span=7;
echo "<tr class=\"bghighlight0\">\n<td class=\"head\" valign=\"top\" colspan=\"$span\">Last Shoutbox Messages</td></tr>\n";
echo "<tr class=\"bghighlight0\">\n";
echo "<td class=\"head\">Date</td>\n";
echo "<td class=\"head\">Message</td>\n";
echo "<td class=\"head\">UserID</td>\n";
if($_SESSION['usadmin']=="Yes"){
	echo "<td class=\"head\">Username</td>\n";
	echo "<td class=\"head\">Comment</td>\n";
	echo "<td class=\"head\">Delete</td>\n";
}
echo "</tr>\n";
for($iTmp2=1;$iTmp2<=10;$iTmp2++){
	$stats_row=mysql_fetch_row($stats_res);
    echo "<tr class=\"bghighlight2\" onmouseover=\"setPointer(this);\" onmouseout=\"unsetPointer(this);\"><td>". $stats_row[0] . "&nbsp;</td>\n<td>" . $stats_row[1] . "&nbsp;</td>\n<td style=\"text-align: right;\">" . $stats_row[2] . "&nbsp;</td>\n";
	if($_SESSION['usadmin']=="Yes"){
		echo "<td>".$stats_row[3]."&nbsp;</td>\n";
		echo "<td>".$stats_row[4]."&nbsp;</td>\n";
		echo "<td align=\"center\">\n<a href='" . basename(__FILE__) . "?delete=". $stats_row[5] ."'><img src=\"images/delete.gif\" alt=\"\" border=\"no\" /></a>\n</td>\n";
	}
	echo "</tr>\n";
}
echo "</table>\n";
echo "</td>\n</tr>\n</table>\n";
// last logins
// -> lists last 10 logins plus ip and date
//
if($_SESSION['usadmin']=="Yes"){
	$login_query = "Select lgdate, usname, uscomment, usadmin, lgip from logins left join users on ususid=lgusid order by lgdate desc, usname limit 0, 10";
	$login_res = mysql_query($login_query);
	echo "<br/>";
	echo "<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" width=\"100%\">\n";
	echo "<tr>\n<td valign=\"top\">\n";
	echo "<table class=\"tablestyle\">\n";
	echo "<tr class=\"bghighlight0\">\n<td class=\"head\" valign=\"top\" colspan=\"5\">Last Logins</td></tr>\n";
	echo "<tr class=\"bghighlight0\">\n";
	echo "<td class=\"head\">Date</td>\n";
	echo "<td class=\"head\">User</td>\n";
	echo "<td class=\"head\">Comment</td>\n";
	echo "<td class=\"head\">Admin ?</td>\n";
	echo "<td class=\"head\">IP</td>\n";
	echo "</tr>\n";
	for($iTmp2=1;$iTmp2<=10;$iTmp2++){
		$login_row=mysql_fetch_row($login_res);
	    echo "<tr class=\"bghighlight2\" onmouseover=\"setPointer(this);\" onmouseout=\"unsetPointer(this);\"><td>". $login_row[0] . "&nbsp;</td>\n<td>" . $login_row[1] . "&nbsp;</td>\n<td style=\"text-align: right;\">" . $login_row[2] . "&nbsp;</td>\n<td style=\"text-align: right;\">" . $login_row[3] . "&nbsp;</td>\n<td style=\"text-align: right;\">" . $login_row[4] . "&nbsp;</td>\n";
		echo "</tr>\n";
	}
	echo "</table>\n";
	echo "</td>\n\n";

	echo "\n</tr>\n</table>\n";
}

ob_flush();

echo "</div>\n";
echo "</body>\n";
echo "</html>\n";

?>

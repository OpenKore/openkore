<?php
/* roshop v.0.9.2
** 429
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
$progName="roshop";
$progVersion="v.0.9.2";
$datum=getdate(time());
$debug="0";
$user="mercdb";
$pass="znrCCQqahCuqXYuy";
$database="mercdb";
$server="localhost";
$port="3306";
$image_path="items/";
$ext_info_url="http://www.roempire.com/database/?page=items&act=view&iid=";
if (!isset($p_ROserver)||$p_ROserver == "") $p_ROserver = "[Full] Chaos";
//
import_request_variables('p', 'p_');
import_request_variables('g', 'g_');
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
	$result=mysql_query("select usname, ususid, usadmin, usbotpos, usbotcont, usshortsearch from users where usname = '" . $_POST['username'] . "' and uspass = '" . $_POST['passwd'] . "'");
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
	$_SESSION['usbotpos']=$row[3];
	$_SESSION['usbotcont']=$row[4];
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
$query_time = "SELECT max( time ) AS last FROM `shopvisit` WHERE 1";
$res_time = mysql_query($query_time, $link);
$d_time = mysql_fetch_array($res_time);
echo "Last Tour: " .  strftime("%c", $d_time[last]) . "<br/>";

$query_count = "SELECT count( * ) AS p_count FROM `shopcont`";
$res_count = mysql_query($query_count, $link);
$d_count = mysql_fetch_array($res_count);
echo "Total Items ever seen: " . $d_count[p_count] . " | ";
$query_count = "select count(distinct shopname) AS p_count from shopcont";
$res_count = mysql_query($query_count, $link);
$d_count = mysql_fetch_array($res_count);
echo "Total Shops ever seen: " . $d_count[p_count] . " | ";
$query_count = "SELECT count( id ) AS p_count FROM `shopcont` WHERE isstillin='Yes'";
$res_count = mysql_query($query_count, $link);
$d_count = mysql_fetch_array($res_count);
echo "Current available Items: " . $d_count[p_count] . " | ";
$query_count = "select count(distinct shopownerid) AS p_count	 from shopcont where isstillin = 'Yes'";
$res_count = mysql_query($query_count, $link);
$d_count = mysql_fetch_array($res_count);
echo "Current open Shops: " . $d_count[p_count] . "<br/>";

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
echo "<H1><a href=\"index.php\">Price-Check</a></H1>\n";

// item overview:
//
//
// getting bot pos
$qrActiveBots="select brdate from botruns where brdone = 'No'";
$resActiveBots=mysql_query($qrActiveBots);
$cntActiveBots=mysql_num_rows($resActiveBots);
while($row=mysql_fetch_row($resActiveBots)){
	echo "<a class=\"iconlink\" ";
    echo "onclick=\"openBrWindow('/scripts/botpos.php?','','resizable=no,toolbar=no,width=250,height=280,dependent=yes')\" title=\"map\"><span class=\"warning\">Bot running - not finished yet!<br/>Wait till finished for complete Info!<br/>Click to see bot walking.</span></a></td>\n";
	echo "<br/><br/>";
}
// basic bot control
if($cntActiveBots==0){
	echo "<a class=\"iconlink\" ";
    echo "onclick=\"openBrWindow('/scripts/botcont.php','','resizable=no,toolbar=no,width=250,height=280,dependent=yes')\" title=\"map\"><span class=\"warning\">Bot-Control</span></a></td>\n";
	echo "<br/><br/>";	
}

// Mainpage:
// -> listing of search entry
//
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
echo "<form method='post' ENCTYPE='multipart/form-data' action='" . basename(__FILE__) ."'>\n";
echo "Item-/Cardname: <input type='text' NAME='name' SIZE='40' />\n<br/><br/>\n";

// select map
$city_query = "SELECT map FROM shopcont WHERE -1 GROUP BY map ORDER BY map";
$res_city = mysql_query($city_query, $link);
$rows_city = mysql_num_rows($res_city);
if ((!$res_city) or ($rows_city==0)){
	echo("Abfrage '$query_map' nicht erfolgreich.\n");
	die();
}else{
	echo "Map: <SELECT NAME='map'>\n";
	echo "<OPTION";
		if ($p_map=="" || !isset($p_map) || $p_map=="-")
			echo " SELECTED";
		if ($g_map=="" || !isset($g_map) || $g_map=="-")
			echo " SELECTED";
	echo ">-</OPTION>\n";
	while($d_city = mysql_fetch_array($res_city)){
		echo "<OPTION";
		if (isset($p_map) && $p_map!="-" && $p_map!="" && $p_map==$d_city[map]){
			echo " SELECTED";
		}
		if (isset($g_map) && $g_map!="-" && $g_map!="" && $g_map==$d_city[map]){
			echo " SELECTED";
		}
		echo ">" . $d_city[map] . "</OPTION>\n";
	}
	echo "</SELECT>\n";
}

// select server
$server_query = "SELECT server FROM shopcont WHERE -1 GROUP BY server ORDER BY server";
$res_server = mysql_query($server_query, $link);
$rows_server = mysql_num_rows($res_server);
if ((!$res_server) or ($rows_server==0)){
	echo("Abfrage '$query_map' nicht erfolgreich.\n");
	die();
}else {
     echo "Server: <SELECT NAME='ROserver'>\n";
     while($d_server = mysql_fetch_array($res_server)){
         echo "<OPTION";
         if (($d_server[server] == $p_ROserver) or ($d_server[server] == $g_ROserver)) echo " SELECTED ";
         echo ">$d_server[server]</OPTION>\n";
     }
     echo "</SELECT>\n";
}

echo "<input type='checkbox' name='cards' value='-1' /> Search in slots \n";
echo "<input type='checkbox' name='avail' value='-1' /> Only currently available<br/><br/>\n";
echo "<input type='submit' name='Submit' value='Search' />\n";
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
echo "</td>\n";
// -> map view
echo "<td align=\"center\">\n<br/><br/>\n";
echo "<form method='post' ENCTYPE='multipart/form-data' action='" . basename(__FILE__) ."'>\n";
echo "Map-Position: <input type='text' VALUE='$p_posx' NAME='posx' SIZE='3' MAXLENGTH='3' /> X \n<input type='text'  VALUE='$p_posy' NAME='posy' SIZE='3' MAXLENGTH='3' /> Y \n<br/><br/>\n";
// select map
$city_query = "SELECT map FROM shopcont WHERE -1 GROUP BY map ORDER BY map";
$res_city = mysql_query($city_query, $link);
$rows_city = mysql_num_rows($res_city);
if ((!$res_city) or ($rows_city==0)){
	echo("Abfrage '$query_map' nicht erfolgreich.\n");
	die();
}else{
	echo "Map: <SELECT NAME='map'>\n";
	echo "<OPTION";
		if ($p_map=="" || !isset($p_map) || $p_map=="-"){
			echo " SELECTED";
		}
	echo ">-</OPTION>\n";
	while($d_city = mysql_fetch_array($res_city)){
	echo "<OPTION";
		if (isset($p_map) && $p_map!="-" && $p_map!="" && $p_map==$d_city[map]){
			echo " SELECTED";
		}
		echo ">" . $d_city[map] . "</OPTION>\n";
	}
	echo "</SELECT>\n";
}

// select server
/*
$server_query = "SELECT server FROM shopcont WHERE -1 GROUP BY server ORDER BY server";
$res_server = mysql_query($server_query, $link);
$rows_server = mysql_num_rows($res_server);
if ((!$res_server) or ($rows_server==0)){
	echo("Abfrage '$query_map' nicht erfolgreich.\n");
	die();
}else{
	echo "Server: <SELECT NAME='ROserver'>\n";
    while($d_server = mysql_fetch_array($res_server)){
    	echo "<OPTION";
        if (($d_server[server] == $p_ROserver) or ($d_server[server] == $g_ROserver)) echo " SELECTED ";
        echo ">$d_server[server]</OPTION>\n";
    }
    echo "</SELECT>\n";
}*/
echo "<br/><br/>\n";
echo "<input type='submit' name='Submit' value='Show' />\n";
echo "</form>\n";

// iframe with map, if posx/y available
$cposx=intval($p_posx);
$cposy=intval($p_posy);

if($cposx>=0 && $cposx<=600 && $cposy>=0 && $cposy<=600 && $cposx!='' && $cposy!='' && $p_Submit=="Show"){
	echo "<iframe height=\"400\" width=\"320\" frameborder=\"no\" src=\"maps/";
	if ($p_map=="" || !isset($p_map) || $p_map=="-"){
	   $gmap="prontera";
	}else{
		$gmap=$p_map;
	}
	echo "map.php?show=map&posx=$cposx&posy=$cposy&map=".$gmap."\" scrolling=\"no\"></iframe>\n";
	$stats_query = "SELECT shopname FROM shopcont WHERE posx = '$cposx' AND posy = '$cposy' AND map = '".$gmap."' AND timstamp > (NOW() - 3600)";
	$stats_res = mysql_query($stats_query);
	$stats_row=mysql_fetch_row($stats_res);
	if($stats_row[0]!=''){
		echo "<br/>\n<span class=\"bold\">Shopname:</span> ".$stats_row[0]."\n<br/><br/>\n";
	}
}

echo "</td>\n</tr>\n</table>\n<br/>\n";

if($cntActiveBots>0 && ($p_name=="%%" || $p_name=="%"))
	echo "You cant search for $p_name while bot is running! Crashes bot sometimes!<br/>&nbsp;<br/>";

if ((!($cntActiveBots>0 && ($p_name=="%%" || $p_name=="%"))) && ($p_name<>"" || $g_name<>"")){
	// p_name as standart: either post or get used
	$p_name=($p_name=="")?$g_name:$p_name;
	if ((strlen($p_name)<3 || eregi("%",$p_name)) && $_SESSION['usshortsearch']!="Yes"){
		echo "You are not allowed to search for $p_name!<br/>At least, you are not an \"Short Searcher\" - Ask your admin!<br/>Short searches increase database load!<br/><br/>";
	}else{
		echo "Search for: " . strtoupper($p_name) . " <br/>\n";
		$query_double = "select qhquery from queryhist where qhusid = " . $_SESSION['userid'] . " order by qhdate desc limit 0,2";
		$res_double = mysql_query($query_double);
		$row_double = mysql_fetch_row($res_double);
		if($row_double[0] != $p_name){
			$query_insert = "insert into queryhist (qhusid, qhquery) values ('" . $_SESSION['userid'] . "', '" . $p_name . "')";
			mysql_query($query_insert);
		}
		$query_search = "SELECT name, avg(price), slots, card1, card2, card3, card4, card1ID, card2ID, card3ID, card4ID, itemID, custom, broken, element, star_crumb FROM shopcont WHERE name LIKE '%$p_name%' AND server = '$p_ROserver'";
		if ($p_name == "%%")
			$query_search .= " AND isstillin = 'Yes'";
		if (!($p_map=="" || !isset($p_map) || $p_map=="-")){
//		if ($p_map!=""){
			$query_search .= " AND map = '$p_map'";
		}
		if ($p_cards) $query_search .= " OR card1 LIKE '%$p_name%' OR card2 LIKE '%$p_name%' OR card3 LIKE '%$p_name%' OR card4 LIKE '%$p_name%'";
		$query_search .= " GROUP BY itemID, custom, broken, slots, card1, card2, card3, card4, element, star_crumb order by 2 desc, 1";
		$res_search = mysql_query($query_search, $link);
		$rows_search = mysql_num_rows($res_search);
		if ((!$res_search) or ($rows_search<1)){
			//echo("Abfrage '$query_search' nicht erfolgreich.\n");
			echo "The Search for '$p_name' on '$p_ROserver' found nothing.<br/><br/>\n";
		}else{
			echo "Hits: $rows_search <br/>\n";
			echo "Server: $p_ROserver <br/>\n";
			if($p_map == "-")
				echo "Map: ALL<br/><br/>\n";
			else
				echo "Map: " . strtoupper($p_map) . "<br/><br/>\n";
			echo "<table class=\"tablestyle\">\n";
			echo "<tr class=\"bghighlight0\">\n";
			echo "<td class=\"head\">&nbsp;</td>\n";
			echo "<td class=\"head\">Shops</td>\n";
			echo "<td class=\"head\">Cur Shops</td>\n";
			echo "<td class=\"head\">Name</td>\n";
			echo "<td class=\"head\">Slots</td>\n";
//			echo "<td class=\"head\">custom</td>\n";
//			echo "<td class=\"head\">broken</td>\n";
			echo "<td class=\"head\">cards</td>\n";
/*			echo "<td class=\"head\">card</td>\n";
			echo "<td class=\"head\">card</td>\n";
			echo "<td class=\"head\">card</td>\n"; */
			echo "<td class=\"head\">element</td>\n";
//			echo "<td class=\"head\">creator</td>\n";
			echo "<td class=\"head\">min $</td>\n";
			echo "<td class=\"head\">max $</td>\n";
			echo "<td class=\"head\">avg $</td>\n";
//			echo "<td class=\"head\">Std. Dev.</td>\n";
			echo "<td class=\"head\">Hot-Deal under</td>\n";
			echo "<td class=\"head\">Cheap. Avail</td>\n";
			if($p_name=="%%")
				echo "<td class=\"head\">Diff.</td>\n";
			echo "</tr>\n";
			$hotcount=0;
			while($d_search = mysql_fetch_array($res_search)){
				$query_count = "SELECT count(*), MIN( price ) AS min, MAX( price ) AS max, AVG( price ) AS mid, STD( price ) AS dev FROM shopcont WHERE slots = '" . $d_search[slots] . "' AND card1ID = '" . $d_search[card1ID] . "' AND card2ID = '" . $d_search[card2ID] . "' AND card3ID = '" . $d_search[card3ID] . "' AND card4ID = '" . $d_search[card4ID] . "' AND custom = '" . $d_search[custom] . "' AND element = '" . $d_search[element] . "' AND star_crumb = '" . $d_search[star_crumb] . "' AND itemID = '" . $d_search[itemID] . "' AND server = '$p_ROserver'";
				if (!($p_map=="" || !isset($p_map) || $p_map=="-"))
					$query_count .= " AND map = '" . $p_map . "'";

				//echo $query_count . "<br/>\n";
				$res_count = mysql_query($query_count, $link);
				$row_count = mysql_fetch_row($res_count);
				$rows_count = $row_count[0];
				$min=$row_count[1];
				$max=$row_count[2];
				$avg=$row_count[3];
				$std=$row_count[4];

				// Minimum available price for item
				$qrMinIn="select min(price), count(*) from shopcont WHERE slots = '" . $d_search[slots] .
					"' AND card1ID = '" . $d_search[card1ID] . "' AND card2ID = '" . $d_search[card2ID] .
					"' AND card3ID = '" . $d_search[card3ID] . "' AND card4ID = '" . $d_search[card4ID] .
					"' AND custom = '" . $d_search[custom] . "' AND element = '" . $d_search[element] .
					"' AND star_crumb = '" . $d_search[star_crumb] . "' AND itemID = '" . $d_search[itemID] .
					"' AND server = '$p_ROserver' AND isstillin = 'Yes'";
				if (!($p_map=="" || !isset($p_map) || $p_map=="-"))
					$qrMinIn .= " AND map = '" . $p_map . "'";
				$resMinIn=mysql_query($qrMinIn);
				$rowMinIn=mysql_fetch_row($resMinIn);
				$rows_avail=$rowMinIn[1];
				// hot deal calc
				$hot_deal = $avg - $std;
				$qrIsIn="select id from shopcont WHERE slots = '" . $d_search[slots] .
					"' AND card1ID = '" . $d_search[card1ID] . "' AND card2ID = '" . $d_search[card2ID] .
					"' AND card3ID = '" . $d_search[card3ID] . "' AND card4ID = '" . $d_search[card4ID] .
					"' AND custom = '" . $d_search[custom] . "' AND element = '" . $d_search[element] .
					"' AND star_crumb = '" . $d_search[star_crumb] . "' AND itemID = '" . $d_search[itemID] .
					"' AND server = '$p_ROserver' AND isstillin = 'Yes' AND price < " . $hot_deal;
				if (!($p_map=="" || !isset($p_map) || $p_map=="-"))
					$qrIsIn .= " AND map = '" . $p_map . "'";
				$resIsIn=mysql_query($qrIsIn);
				$rowsIsIn=mysql_num_rows($resIsIn);

				// skip row if only hot price check
				if ($p_name=="%%" && ($hot_deal <= $min || $rowsIsIn == 0))
					continue;

				$hotcount++;

				echo "<tr class=\"bghighlight2\" onmouseover=\"setPointer(this);\" onmouseout=\"unsetPointer(this);\">\n";
				echo "<td>" . $d_search[itemID] . "</td>\n";
				echo "<td>$rows_count</td>\n";
				echo "<td>$rows_avail</td>\n";
				echo "<td><a class=\"iconlink\" href='" . basename(__FILE__) ."?iid=" . $d_search[itemID];
				echo "&custom=" . $d_search[custom];
				echo "&broken=" . $d_search[broken];
				echo "&element=" . $d_search[element];
				echo "&star_crumb=" . $d_search[star_crumb];
				echo "&card1ID=" . $d_search[card1ID];
				echo "&ROserver=$p_ROserver";
				if (!($p_map=="" || !isset($p_map) || $p_map=="-"))
					echo "&map=" . $p_map;
				if ($d_search[card1ID]!='255'){
					echo "&slots=" . $d_search[slots];
					echo "&card3ID=" . $d_search[card3ID] . "&card4ID=" . $d_search[card4ID];
				}
				echo "&card2ID=" . $d_search[card2ID];
				echo "'>$d_search[name]</a>&nbsp;[<a class=\"iconlink\" href='$ext_info_url" . $d_search[itemID] . "' target='_new'>?</a>]</td>\n";
				if ($d_search[card1ID]=="255"){
					$slots = 0;
				}else{
					$slots = $d_search[slots];
				}
				if ($slots>0){
					echo "<td>" . $slots . "&nbsp;</td>\n";
				}else{
					echo "<td>-</td>\n";
				}

				if($d_search[card1]!="") $cardsall[0] = $d_search[card1];
				if($d_search[card2]!="") $cardsall[1] = $d_search[card2];
				if($d_search[card3]!="") $cardsall[2] = $d_search[card3];
				if($d_search[card4]!="") $cardsall[3] = $d_search[card4];
				if($d_search[card1]!=""){
					$cards_separated = implode(" | ", $cardsall);
				}else{
					$cards_separated = "";
				}
				echo "<td>" . $cards_separated . "&nbsp;</td>\n";
				unset($cardsall);

				echo "<td>";
				for ($i=1; $i<= $d_search[star_crumb]; $i++)
					echo "V";
				echo " " . $d_search[element] . "&nbsp;</td>\n";
				echo "<td align='right'>" . number_format($min) . "&nbsp;</td>\n";
				echo "<td align='right'>" . number_format($max) . "&nbsp;</td>\n";
				echo "<td align='right'>" . number_format($avg) . "</td>";

				echo "<td align='right'>";
				echo number_format($hot_deal);
				echo "&nbsp;</td>\n";

				echo "<td align='right'";
				if ($hot_deal > $rowMinIn[0]){
					if($rowsIsIn>0){
						echo "class=\"hotDeal\"";
					}
				}
				echo ">";
				if($rowMinIn[0]!="")
					echo number_format($rowMinIn[0]);
				echo "</td>";
				
				if($p_name=="%%"){
					echo "<td align='right'>";
					echo number_format( $avg-$rowMinIn[0]);
					echo "&nbsp;</td>\n";
				}

				echo "</tr>\n";
			}
			echo "</table>\n";
			// uncool else ended here by mr.incredible
			$microtime2=getmicrotime();
			echo"<table width=\"100%\" style=\"text-align: right;\">\n<tr>\n";
			echo "<td class=\"small\">Execution-Time: ".(round($microtime2-$microtime1,4))." seconds";
			if ($p_name == "%%")
				echo " | " . $hotcount . " Hot Items found!";
			echo "</td>\n";
			echo" </tr>\n</table>\n";
		}
	}
}

if ($g_shopcontent > 0){

	$query_search = "SELECT * FROM shopcont WHERE shopOwnerID='$g_shopcontent' AND server = '$g_ROserver' AND isstillin='Yes' ORDER BY price DESC";
	$res_search = mysql_query($query_search);
	$rows_search = mysql_num_rows($res_search);
	$query_search2 = "SELECT * FROM shopcont WHERE shopOwnerID='$g_shopcontent' AND server = '$g_ROserver' AND isstillin='No' ORDER BY price DESC";
	$res_search2 = mysql_query($query_search2);
	$rows_search2 = mysql_num_rows($res_search2);
	echo "<font class=\"bold\">Shop-Details</font><br/>\n";
	echo "Server: $g_ROserver | \n";
	echo "Shopname: ".stripslashes(urldecode($g_shopName))." <br/><br/>\n";
	if (((!$res_search2) || ($rows_search2==0))&&((!$res_search) || ($rows_search==0))){
		echo "<span class=\"warning\">Shop nicht verf&uuml;gbar!</span><br/>\n";
	}else{
		echo "<table class=\"tablestyle\">\n";
		echo "<tr class=\"bghighlight0\">\n";
		echo "<td class=\"head\">Available Items (". $rows_search .")</td>\n";
		echo "<td class=\"head\">Item/Card</td>\n";
		echo "<td class=\"head\">Amount</td>\n";
		echo "<td class=\"head\">Zenny</td>\n";
		echo "<td class=\"head\">Shop Last Seen</td>\n";
		echo "<td class=\"head\">Shop First Seen</td>\n";
		echo "</tr>\n";
		if((!$res_search) || ($rows_search==0)){
			echo("<tr class=\"bghighlight2\"><td align=\"center\" colspan=\"6\">Shop Closed</td></tr>\n");
		}else{
			while($d_search = mysql_fetch_array($res_search)){
				echo "<tr class=\"bghighlight2\" onmouseover=\"setPointer(this);\" onmouseout=\"unsetPointer(this);\">\n";
				echo "<td>" . $d_search[itemID] . "</td>\n";
				echo "<td>$d_search[name] [<a class=\"iconlink\" href='$ext_info_url" . $d_search[itemID] . "' target='_new'>?</a>]</td>\n";
				echo "<td>" . $d_search[amount] . "&nbsp;</td>\n";
				echo "<td align='right'>" . number_format($d_search[price]) . "&nbsp;</td>\n";
				echo "<td>" . $d_search[timstamp] . "</td>\n";
				echo "<td>" . $d_search[datum] . "</td>\n";
				echo "</tr>\n";
			}
		}
		echo "<tr class=\"bghighlight0\">\n";
		echo "<td class=\"head\">Offered/Sold Items (". $rows_search2 .")</td>\n";
		echo "<td class=\"head\">Item/Card</td>\n";
		echo "<td class=\"head\">Amount</td>\n";
		echo "<td class=\"head\">Zenny</td>\n";
		echo "<td class=\"head\">Shop Last Seen</td>\n";
		echo "<td class=\"head\">Shop First Seen</td>\n";
		echo "</tr>\n";
		while($d_search = mysql_fetch_array($res_search2)){
			echo "<tr class=\"bghighlight2\" onmouseover=\"setPointer(this);\" onmouseout=\"unsetPointer(this);\">\n";
			echo "<td>" . $d_search[itemID] . "</td>\n";
			echo "<td>$d_search[name] [<a class=\"iconlink\" href='$ext_info_url" . $d_search[itemID] . "' target='_new'>?</a>]</td>\n";
			echo "<td>" . $d_search[amount] . "&nbsp;</td>\n";
			echo "<td align='right'>" . number_format($d_search[price]) . "&nbsp;</td>\n";
			echo "<td>" . $d_search[timstamp] . "</td>\n";
			echo "<td>" . $d_search[datum] . "</td>\n";
			echo "</tr>\n";
		}
		echo "</table>\n";
		$microtime2=getmicrotime();
 		echo"<table width=\"100%\" style=\"text-align: right;\">\n";
 		echo "<tr>\n<td class=\"small\">Execution-Time: ".(round($microtime2-$microtime1,4))." seconds</td>\n</tr>\n";
 		echo "</table>\n";
	}
}
// Item-Details Page:
// -> lists item details, with further functions included
// (map-search, shop-view, sorting)
if ($g_iid > 0){
	echo "<font class=\"bold\">Item-Details</font><br/>\n";
	echo "Server: $g_ROserver <br/><br/>\n";
	if ($g_element==""){
		$query_search = "SELECT * FROM shopcont WHERE itemID='$g_iid' AND slots='$g_slots' AND custom='$g_custom' AND card1ID='$g_card1ID' AND card2ID='$g_card2ID' AND card3ID='$g_card3ID' AND card4ID='$g_card4ID' AND server = '$g_ROserver'";
	}else{
		 $query_search = "SELECT * FROM shopcont WHERE itemID='$g_iid' AND custom='$g_custom' AND card2ID='$g_card2ID' AND element='$g_element' AND star_crumb=$g_star_crumb AND server = '$g_ROserver'";
    }
	if (!($g_map=="" || !isset($g_map) || $g_map=="-"))
		$query_search .= " AND map = '$g_map'";
    ($g_sortby=="desc")?($sortby="asc"):($sortby="desc");
	if ($g_sort<>"") $query_search .= " ORDER BY $g_sort $sortby";
	else $query_search .= " ORDER BY timstamp $sortby";
	$res_search = mysql_query($query_search, $link);
	$rows_search = mysql_num_rows($res_search);
	if ((!$res_search) or ($rows_search==0)){
		echo("Abfrage '$query_search' nicht erfolgreich.\n");
		echo("The Search for '$g_iid' found nothing.<br/>\n");
	}else{
		echo "<table class=\"tablestyle\">\n";
		echo "<tr class=\"bghighlight0\">\n";
		echo "<td class=\"head\">&nbsp;</td>\n";
		echo "<td class=\"head\">Name</td>\n";
		echo "<td class=\"head\">slots</td>\n";
//		echo "<td class=\"head\">custom</td>\n";
		echo "<td class=\"head\">Cards</td>\n";
/*		echo "<td class=\"head\">card</td>\n";
		echo "<td class=\"head\">card</td>\n";
		echo "<td class=\"head\">card</td>\n";
*/		echo "<td class=\"head\">element</td>\n";
		#echo "<td class=\"head\">crafted by</td>";
		echo "<td class=\"head\">#</td>\n";
		echo "<td class=\"head\"><a class=\"iconlink\" href='" . basename(__FILE__) ."?sortby=$sortby&sort=price&iid=$g_iid";
		echo "&custom=" . $g_custom;
		echo "&element=" . $g_element;
		echo "&star_crumb=" . $g_star_crumb;
		echo "&card1ID=" . $g_card1ID;
		echo "&slots=" . $g_slots;
		echo "&card3ID=" . $g_card3ID . "&card4ID=" . $g_card4ID;
		echo "&card2ID=" . $g_card2ID;
		echo "&ROserver=$g_ROserver";
		echo "'>Zenny</a></td>";
		echo "<td class=\"head\">Map</td>\n";
		echo "<td class=\"head\">posX</td>\n";
		echo "<td class=\"head\">posY</td>\n";
		#echo "<td class=\"head\">Shopownername</td>\n";
		echo "<td class=\"head\">Shopname</td>\n";
		echo "<td class=\"head\"><a class=\"iconlink\" href='" . basename(__FILE__) ."?sortby=$sortby&sort=timstamp&iid=$g_iid";
		echo "&custom=" . $g_custom;
		echo "&element=" . $g_element;
		echo "&star_crumb=" . $g_star_crumb;
		echo "&card1ID=" . $g_card1ID;
		echo "&slots=" . $g_slots;
		echo "&card3ID=" . $g_card3ID . "&card4ID=" . $g_card4ID;
		echo "&card2ID=" . $g_card2ID;
		echo "&ROserver=$g_ROserver";
		echo "'>Shop Last Seen</a></td>\n";
		echo "<td class=\"head\"><a class=\"iconlink\" href='" . basename(__FILE__) ."?sortby=$sortby&sort=datum&iid=$g_iid";
		echo "&custom=" . $g_custom;
		echo "&element=" . $g_element;
		echo "&star_crumb=" . $g_star_crumb;
		echo "&card1ID=" . $g_card1ID;
		echo "&slots=" . $g_slots;
		echo "&card3ID=" . $g_card3ID . "&card4ID=" . $g_card4ID;
		echo "&card2ID=" . $g_card2ID;
		echo "&ROserver=$g_ROserver";
		echo "'>Shop First Seen</a></td>\n";
		echo "</tr>\n";
		while($d_search = mysql_fetch_array($res_search)){
			// >>>>>>: specify different bg color for better overview
			echo "<tr";
			// select current day date
			ereg("([0-9]{4})-([0-9]{2})-([0-9]{2}).*",$d_search[timstamp],$cDate);
			// toggle when date is different then old date
			if($cDate[3]!=$oldDate){
				if($colorToggle==1){
					$colorToggle=0;
				}else{
					// default:
					$colorToggle=1;
				}
			}
			// save old date
			$oldDate=$cDate[3];
			// select bgcolor depending on colorToggle (starting with value 1)
			if($d_search[isstillin]=="Yes"){
				echo " class=\"isstillin\"";
			}elseif($colorToggle==1){
				echo " class=\"bghighlight2\"";
			}else{
				echo " class=\"bghighlight1\"";
			}
			echo " onmouseover=\"setPointer(this);\" onmouseout=\"unsetPointer(this);\">\n";
			// <<<<<<<<<
			echo "<td>" . $d_search[itemID] . "</td>\n";
			echo "<td>$d_search[name] [<a class=\"iconlink\" href='$ext_info_url" . $d_search[itemID] . "' target='_new'>?</a>]</td>\n";
			if ($d_search[slots]>0){
				echo "<td>" . $d_search[slots] . "&nbsp;</td>\n";
			} else {
				echo "<td>-</td>\n";
			}
/*			if ($d_search[custom]>0){
				echo "<td>+" . $d_search[custom] . "&nbsp;</td>\n";
			}else{
				echo "<td>-</td>\n";
			}
			echo "<td>" . $d_search[card1] . "&nbsp;</td>\n";
			echo "<td>" . $d_search[card2] . "&nbsp;</td>\n";
			echo "<td>" . $d_search[card3] . "&nbsp;</td>\n";
			echo "<td>" . $d_search[card4] . "&nbsp;</td>\n";*/

			if($d_search[card1]!="") $cardsall[0] = $d_search[card1];
			if($d_search[card2]!="") $cardsall[1] = $d_search[card2];
			if($d_search[card3]!="") $cardsall[2] = $d_search[card3];
			if($d_search[card4]!="") $cardsall[3] = $d_search[card4];
			if($d_search[card1]!=""){
				$cards_separated = implode(" | ", $cardsall);
			}else{
				$cards_separated = "";
			}
			echo "<td>" . $cards_separated . " " ."&nbsp;</td>\n";
			unset($cardsall);

			echo "<td>" . $d_search[element] . "&nbsp;</td>\n";
			#echo "<td>" . $d_search[crafted_by] . "&nbsp;</td>\n";
			echo "<td>" . $d_search[amount] . "&nbsp;</td>\n";
			echo "<td align='right'>" . number_format($d_search[price]) . "&nbsp;</td>\n";
			echo "<td>";
      		echo "<a class=\"iconlink\" ";
      		echo " onclick=\"openBrWindow('maps/map.php?map=" . $d_search[map] . "&posx=".$d_search[posx]."&posy=".$d_search[posy]."','','resizable=no,toolbar=no,width=320,height=400,dependent=yes')\" title=\"map\">" . $d_search[map] . "</a></td>\n";
			echo "<td>" . $d_search[posx] . "&nbsp;</td>\n";
			echo "<td>" . $d_search[posy] . "&nbsp;</td>\n";
			#echo "<td>" . $d_search[shopOwner] . "&nbsp;</td>\n";
			echo "<td><a class=\"iconlink\" href='" . basename(__FILE__) ."?shopcontent=" . $d_search[shopOwnerID] ."";
			echo "&ROserver=$g_ROserver";
			echo "&shopName=" . urlencode($d_search[shopName]) ."'>";
			echo "" . $d_search[shopName] . "</a>&nbsp;</td>\n";
			echo "<td>" . $d_search[timstamp] . "</td>\n";
			echo "<td>" . $d_search[datum] . "</td>\n";
			echo "</tr>\n";
		}
		echo "</table>\n";
		$microtime2=getmicrotime();
 		echo"<table width=\"100%\" style=\"text-align: right;\"><tr><td class=\"small\">Execution-Time: ".(round($microtime2-$microtime1,4))." seconds</td></tr></table>\n";
	}
}

#echo "<br/>\n";
// Query History
// -> shows last 10 entries
//
$stats_query = "Select qhdate, qhquery, qhusid, usname, uscomment from queryhist left join users on ususid=qhusid ";
if($_SESSION['usadmin']=="No")
	$stats_query .= "where length(qhquery) > 2 ";
$stats_query .= "order by qhdate desc limit 0, 10";
$stats_res = mysql_query($stats_query);
echo "<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" width=\"100%\">\n";
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
	echo "</td>\n<td>&nbsp;&nbsp;&nbsp;&nbsp;</td>\n<td valign=\"top\">\n";

// last commands
// -> lists last 10 logins plus ip and date
//
	$cont_query = "Select bcdate, bccommand, usname, uscomment from botcont left join users on ususid=bcusid order by bcdate desc, usname limit 0, 10";
	$cont_res = mysql_query($cont_query);
	echo "<table class=\"tablestyle\">\n";
	echo "<tr class=\"bghighlight0\">\n<td class=\"head\" valign=\"top\" colspan=\"4\">Last commands send to bot</td></tr>\n";
	echo "<tr class=\"bghighlight0\">\n";
	echo "<td class=\"head\">Date</td>\n";
	echo "<td class=\"head\">Command</td>\n";
	echo "<td class=\"head\">User</td>\n";
	echo "<td class=\"head\">Comment</td>\n";
	echo "</tr>\n";
	for($iTmp2=1;$iTmp2<=10;$iTmp2++){
		$cont_row=mysql_fetch_row($cont_res);
	    echo "<tr class=\"bghighlight2\" onmouseover=\"setPointer(this);\" onmouseout=\"unsetPointer(this);\"><td>". $cont_row[0] . "&nbsp;</td>\n<td>" . $cont_row[1] . "&nbsp;</td>\n<td style=\"text-align: right;\">" . $cont_row[2] . "&nbsp;</td>\n<td style=\"text-align: right;\">" . $cont_row[3] . "&nbsp;</td>\n";
		echo "</tr>\n";
	}
	echo "</table>\n";
	echo "</td>\n</tr>\n</table>\n";
}

ob_flush();

echo "</div>\n";
echo "</body>\n";
echo "</html>\n";

?>

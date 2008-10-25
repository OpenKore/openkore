<?
session_start();
if($_SESSION['usbotcont']!="Yes"){
	header("Content-type: text/plain");
	echo "You are not allowed to control the Bot!";
	exit;
}
import_request_variables('g', 'g_'); 

$user="mercdb";
$pass="setthis";
$database="mercdb";
$server="localhost";
$port="3306";

if (!$link = mysql_connect("$server:$port", $user, $pass))
echo mysql_errno().": ".mysql_error()."<br/>";

// db selection:
$query = "use $database";
if (!mysql_query($query, $link)){
	echo("<H1>Database $dbase not found.</H1>\n");
	die();
}

echo "<html>";
echo "<head>";
echo "<title>Control the bot!</title>";
echo "<link rel=\"stylesheet\" href=\"/css/style_default.css\" type=\"text/css\" />";
echo "<META HTTP-EQUIV=\"content-type\" CONTENT=\"text/html; charset=iso-8859-1\">";
echo "</head>";
echo "<body>";

$qrActiveBots="select brdate from botruns where brdone = 'No' order by brdate";
$resActiveBots=mysql_query($qrActiveBots);
$rowActiveBots=mysql_num_rows($resActiveBots); 
$cmd="";
$param="";

if($g_act){
	$param=$g_act;
	$cmd="";
	switch($param){
		case "toGspot":
			$cmd="macro gspot";
			break;
		case "startTour":
			$cmd="macro tour";
			break;
	}
	if($cmd==""){
		echo "<span class=\"bold\">Unknown Command</span><br/><br/>";
	}
}

if($rowActiveBots>0){
	echo "<span class=\"bold\">$rowActiveBots Bots running! Can't do anything now!</span><br/><br/><span style=\"cursor: pointer;\" onClick='javascript:window.close();'>Close Window!</span> - <a href=\"botpos.php\">View Bot</a></body></html>";
	exit;
}

if($cmd<>""){
	$qrUpdCmd="UPDATE botcont SET bcdone = 'Yes'";
	mysql_query($qrUpdCmd);
	$qrInsCmd="INSERT INTO botcont (bcusid, bccommand) VALUES (" . $_SESSION['userid'] ." , '$cmd')";
	mysql_query($qrInsCmd);
	echo "<span class=\"bold\">Command '$param' - '$cmd' will be executed now!</span><br/><br/>";
}else
	echo "<span class=\"bold\">No Bots running now<br/>You may enter commands!</span><br/><br/><a href=\"botcont.php?act=startTour\">Start Tour NOW</a> - <a href=\"botcont.php?act=toGspot\">Bot to GSpot</a> - ";

echo "<a href=\"botpos.php\">View Bot</a>";

echo "</body>";
?>

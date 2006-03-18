<?
session_start();
if($_SESSION['usbotpos']!="Yes"){
	header("Content-type: text/plain");
	echo "You are not allowed to see the Bot-Walk!";
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

$qrBotPos="select bpdate, bpposx, bpposy, bpmap from botpos order by bpdate desc limit 0,1";
$resBotPos=mysql_query($qrBotPos);
$rowBotPos=mysql_fetch_row($resBotPos);
$bpdate=$rowBotPos[0]; $bpposx=$rowBotPos[1]; $bpposy=$rowBotPos[2]; $bpmap=$rowBotPos[3];
$qrActiveBots="select brdate from botruns where brdone = 'No' order by brdate";
$resActiveBots=mysql_query($qrActiveBots);
$rowActiveBots=mysql_fetch_row($resActiveBots);
$cntActiveBots=mysql_num_rows($resActiveBots);
$brdate=$rowActiveBots[0];

if($g_pause!="1" || $g_refresh=="-1"){
	$qrRefresh="SELECT usrefresh from users where ususid = " . $_SESSION['userid'];
	$resRefresh=mysql_query($qrRefresh);
	$rowRefresh=mysql_fetch_row($resRefresh);
	if($rowRefresh[0]<5 && ($g_pause=="1" || $rowActiveBots[0]==""))
		$refresh=10;
	else
		$refresh=$rowRefresh[0];
	// update settings
	if($g_refresh!="-1" && $g_refresh!=""){
		$qrUpRefresh="UPDATE users set usrefresh = '$g_refresh' where ususid = ".$_SESSION['userid'];
		mysql_query($qrUpRefresh);
		$refresh=$g_refresh;
	}
	header("Refresh: ".$refresh.";botpos.php");
}else{
	$refresh=-1;
}



echo "<html>";
echo "<head>";
echo "<title>Current Bot-Pos!</title>";
echo "<link rel=\"stylesheet\" href=\"/css/style_default.css\" type=\"text/css\" />";
echo "<META HTTP-EQUIV=\"content-type\" CONTENT=\"text/html; charset=iso-8859-1\">";
if($refresh!="-1")
	echo "<META HTTP-EQUIV=\"refresh\" CONTENT=\"".$refresh."; URL=botpos.php\">";
echo "</head>";
echo "<body>";

if($cntActiveBots==0){
	echo "<span class=\"bold\">No Bots running!</span><br/><br/><span style=\"cursor: pointer;\" onClick='javascript:window.close();'>Close Window!</span><span style=\"cursor: pointer;\">- <a href=\"botcont.php\">Bot Control</a></span><br/><br/>";
}else{
	echo "Starting: $brdate<br/>Last Position Update: $bpdate<br/>Dates are server-dates!<br/>\n";
	echo "<form method=\"get\">Refresh: <input size=\"3\" type=\"text\" name=\"refresh\" value=\"".$refresh."\"> - <a href=\"botpos.php?pause=1\">Pause</a><span style=\"cursor: pointer;\">- <a href=\"botcont.php\">Bot Control</a></span></form>";
	if($bpmap!="Connecting")
		echo "<img src='/maps/map.php?map=$bpmap&posx=$bpposx&posy=$bpposy&showbot=active'>";
	else
		echo "<b>Bot currently connecting!<br/>That may take a while!</b>";
}
echo "</body>";
?>

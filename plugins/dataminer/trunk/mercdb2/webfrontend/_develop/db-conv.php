<html>
<title></title>
<head>
<link rel="SHORTCUT ICON" href="http://www.mrspoocy.com/icon.ico">
<META HTTP-EQUIV="Expires" CONTENT="now">
<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
<!--
Dieser Index darf nicht entfernt werden.
(C) Copyright by Manuel Pogge (MrSpoocy)
E-Mail: info@mrspoocy.com
-->
</head>
<body leftmargin="0" rightmargin="0" topmargin="0" bottommargin="0" marginheight="0" marginwidth="0">
<?php 
$user		= "mercdb";
$pass		= "znrCCQqahCuqXYuy";
$server        = "localhost";
$port        = "3306";

mysql_connect("$server:$port", $user, $pass);
mysql_select_db("mercdb"); 

$get = mysql_query("SELECT datum,id FROM shopcont");
while($row = mysql_fetch_assoc($get))
{
ereg("([0-9]+)\.([0-9]+)\.([0-9]+) ([0-9]+):([0-9]+):([0-9]+)",$row['datum'],$reg);
mysql_query("UPDATE shopcont SET realdate='$reg[3]-$reg[2]-$reg[1] $reg[4]:$reg[5]:$reg[6]' WHERE id='$row[id]'");
unset($reg);
}
?>

</body>
</html>
<?php 

/***************************************************************************
 *
 *   Created by Steffen <steffen@land10web.com> http://www.apachelounge.com
 *   Mofified by kris <kris@xoofoo.org> http://www.xoofoo.org
 *
 *   This program is free software; you can redistribute it and/or modify it.
 *   note: not working with the php mysqli extension
 *
 *    $Id: mysqlinfo.php,v 1.0.0 2006/08/27 steffen Exp $
 *
 ***************************************************************************/

define('ADMIN_USERNAME','root'); 	// Admin Username
define('ADMIN_PASSWORD','root');  	// Admin Password

////////// END OF DEFAULT CONFIG AREA /////////////////////////////////////////////////////////////

///////////////// Password protect ////////////////////////////////////////////////////////////////
if (!isset($_SERVER['PHP_AUTH_USER']) || !isset($_SERVER['PHP_AUTH_PW']) ||
           $_SERVER['PHP_AUTH_USER'] != ADMIN_USERNAME ||$_SERVER['PHP_AUTH_PW'] != ADMIN_PASSWORD) {
			Header("WWW-Authenticate: Basic realm=\"MySQL Infos Login\"");
			Header("HTTP/1.0 401 Unauthorized");

			echo <<<EOB
				<html><body>
				<h1>Rejected!</h1>
				<span style="color: red; font-size: 1.5em; font-weight: bold;">Wrong Username or Password!</span>
				</body></html>
EOB;
			exit;
}

/* Set your host and login parameters */
 
$user=ADMIN_USERNAME;
$password=ADMIN_PASSWORD;
$host="localhost";
?>
<html>
<head>
<title>MySQLinfo and PHPinfo</title>
</head>
<body>
<a name="top">
<br /><br />
<?php
if(!extension_loaded("mysql")){ 
   echo ("<br /><font color=red><b>php MySQL extension not loaded !!</font>
   <br /><br />Check in php.ini if  extension=php_mysql.dll is enabled, and  that the  extension_dir = is pointing to  your php/ext folder. 
   <br /><br />Copy libmySQL.dll from your Mysql/bin folder to c:/windows.</b><br /><br /><br />"); 
    phpinfo();
    die;
} 
$link = mysql_connect($host, $user, $password);
if (!$link) {
   echo ('<br /><font color=red><b>Could not connect to the Mysql server !!</font><br /><br />' . mysql_error() . '<br /><br /><b>Did you set the correct host and login parameters in mysqlinfo.php ? <br /><br /><br />');
   phpinfo();
   die;
}
else
{
if( $user == 'root' ) {
  if( $password == '') {
     echo "<font color=red><b>Your user and password are the install default (user:root and password is blank), change it !!</b></font><br /><br />";
}
}
?>
<a style="text-decoration: underline" href="#var"><b>MySQL Server variables and settings</b></a> &nbsp; &nbsp; 
<a style="text-decoration: underline" href="#phpinf"><b>PHP info</b></a><br /><br />
<?php
printf("<font color=green>User <b>$user</b> connected to the MySQL server at <b>$host</b><br /><br /></b>Mysql version:</b><b> %s\n", mysql_get_server_info());
?>
</b></font><br /><br /><center><font color=green><b>MySQL Runtime Information</b></font><br />
<TABLE border=0  bgcolor="#ffffff" border="0" cellspacing="0" cellpadding="0">
<TD VALIGN=TOP border="0"  bgcolor="#ffffff" border="0" cellspacing="0" cellpadding="0">
<br /><br />
<?php
$result = mysql_query('SHOW GLOBAL STATUS', $link);
$p = 0;
while ($row = mysql_fetch_assoc($result)) {
      $p ++;
      if ($p==123){
          echo '<br /><br /></td><TD VALIGN=TOP><br /><br />';
}
      echo ' &nbsp;  &nbsp;  ' . $row['Variable_name'] . ' = ' . $row['Value'] . " &nbsp; &nbsp; <br />";
}
?>
</td></tr></table><br /><a name="var"><a href="#top"><br /><b>Back to top</b></a><br /><br /><br /><font color=green><b>MySQL Server variables and settings</b></font><br />
<table border=0  bgcolor="#ffffff" border="0" cellspacing="0" cellpadding="0">
<td valign=top>
<br /><br />
<?php
$p = 0;
$result = mysql_query('SHOW VARIABLES', $link);
while ($row = mysql_fetch_assoc($result)) {
      $p ++;
      if ($p==111){
         echo '<br /><br /></td><td valign=top><br /><br />';
}
      echo ' &nbsp;  &nbsp;  ' . $row['Variable_name'] . ' = ' . $row['Value'] . " &nbsp;  &nbsp; <br />";
}
}
echo '</td></tr></table><br /><a name="phpinf"><br /><a href="#top"><b>Back to top</b></a><br /><br /><font color=green><b>Php info()</b><br />';
phpinfo();
?>
</font><a href="#top"><b>Back to top</b></a>
</center>
</body>
</html>

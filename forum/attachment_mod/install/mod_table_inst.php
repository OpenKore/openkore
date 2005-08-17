<?php
/***************************************************************************
 *                            mod_table_inst.php
 *                            -------------------
 *   begin                : Sunday, Jan 13, 2002
 *   copyright            : (C) 2002 Meik Sievertsen
 *   email                : acyd.burn@gmx.de
 *
 *   $Id: mod_table_inst.php,v 1.10 2005/04/16 10:18:07 acydburn Exp $
 *
 ***************************************************************************/

/***************************************************************************
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 ***************************************************************************/

define('IN_PHPBB', true);
define('ATTACH_INSTALL', true);

$phpbb_root_path = './../';
include($phpbb_root_path.'extension.inc');
include($phpbb_root_path.'common.'.$phpEx);	
	
$userdata = session_pagestart($user_ip, PAGE_INDEX);
init_userprefs($userdata);

if ( (!isset($dbms)) || ($dbms == 'oracle') || ($dbms == 'msaccess') )
{
	message_die(GENERAL_ERROR, "This Mod does not support Oracle and MsAccess Databases.");
}

include($phpbb_root_path.'includes/db.'.$phpEx);

//
// Run a complete SQL-Statement, this can be a array
//
function query_($sql_query)
{
	global $table_prefix, $remove_remarks, $delimiter, $db;
	
	$errored = FALSE;
	$sql_query = preg_replace('/phpbb_/', $table_prefix, $sql_query);

	$sql_count = count($sql_query);

	for($i = 0; $i < $sql_count; $i++)
	{
		echo "Running :: " . $sql_query[$i];
		flush();

		if ( !($result = $db->sql_query($sql_query[$i])) )
		{
			$errored = true;
			$error = $db->sql_error();
			echo " -> <b>FAILED</b> ---> <u>" . $error['message'] . "</u><br /><br />\n\n";
		}
		else
		{
			echo " -> <b><span class=\"ok\">COMPLETED</span></b><br /><br />\n\n";
		}
	}

	if ($errored)
	{
		return (FALSE);
	}
	else
	{
		return (TRUE);
	}
}

//
// Here we go
//
include($phpbb_root_path.'includes/sql_parse.'.$phpEx);

$available_dbms = array(
	"mysql" => array(
		"SCHEMA" => "attach_mysql", 
		"DELIM" => ";",
		"DELIM_BASIC" => ";",
		"COMMENTS" => "remove_remarks"
	), 
	"mysql4" => array(
		"SCHEMA" => "attach_mysql", 
		"DELIM" => ";", 
		"DELIM_BASIC" => ";",
		"COMMENTS" => "remove_remarks"
	),
	"mssql" => array(
		"SCHEMA" => "attach_mssql", 
		"DELIM" => "GO", 
		"DELIM_BASIC" => ";",
		"COMMENTS" => "remove_comments"
	),
	"mssql-odbc" =>	array(
		"SCHEMA" => "attach_mssql", 
		"DELIM" => "GO",
		"DELIM_BASIC" => ";",
		"COMMENTS" => "remove_comments"
	),
	"postgres" => array(
		"LABEL" => "PostgreSQL 7.x",
		"SCHEMA" => "attach_postgres", 
		"DELIM" => ";", 
		"DELIM_BASIC" => ";",
		"COMMENTS" => "remove_comments"
	)
);

$dbms_schema = 'schemas/' . $available_dbms[$dbms]['SCHEMA'] . '_schema.sql';
$dbms_basic = 'schemas/' . $available_dbms[$dbms]['SCHEMA'] . '_basic.sql';

$remove_remarks = $available_dbms[$dbms]['COMMENTS'];;
$delimiter = $available_dbms[$dbms]['DELIM']; 
$delimiter_basic = $available_dbms[$dbms]['DELIM_BASIC']; 

if ( !($fp = @fopen($dbms_schema, 'r')) )
{
	message_die(GENERAL_MESSAGE, "Can't open " . $dbms_schema);
}

fclose($fp);

if ( !($fp = @fopen($dbms_basic, 'r')) )
{
	message_die(GENERAL_MESSAGE, "Can't open " . $dbms_basic);
}

fclose($fp);

?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html;">
<meta http-equiv="Content-Style-Type" content="text/css">
<style type="text/css">
<!--

font,th,td,p,body { font-family: "Courier New", courier; font-size: 11pt }

a:link,a:active,a:visited { color : #006699; }
a:hover		{ text-decoration: underline; color : #DD6900;}

hr	{ height: 0px; border: solid #D1D7DC 0px; border-top-width: 1px;}

.maintitle,h1,h2	{font-weight: bold; font-size: 22px; font-family: "Trebuchet MS",Verdana, Arial, Helvetica, sans-serif; text-decoration: none; line-height : 120%; color : #000000;}

.ok {color:green}

/* Import the fancy styles for IE only (NS4.x doesn't use the @import function) */
@import url("./../templates/subSilver/formIE.css"); 
-->
</style>
</head>
<body bgcolor="#FFFFFF" text="#000000" link="#006699" vlink="#5584AA">

<table width="100%" border="0" cellspacing="0" cellpadding="10" align="center"> 
	<tr>
		<td><table width="100%" border="0" cellspacing="0" cellpadding="0">
			<tr>
				<td><img src="./../templates/subSilver/images/logo_phpBB.gif" border="0" alt="Forum Home" vspace="1" /></td>
				<td align="center" width="100%" valign="middle"><span class="maintitle">Installing Attachment Mod</span></td>
			</tr>
		</table></td>
	</tr>
</table>

<br clear="all" />

<?php

//
// process db schema
//
$sql_query = @fread(@fopen($dbms_schema, 'r'), @filesize($dbms_schema));
$sql_query = preg_replace('/phpbb_/', $table_prefix, $sql_query);

if (!strstr($sql_query, 'attach_quota'))
{
	die("<br />PLEASE UPLOAD THE CORRECT DATABASE SCHEMA FILES...<br />If you have done so, run the Installer again.<br />");
}

$sql_query = $remove_remarks($sql_query);
$sql_query = split_sql_file($sql_query, $delimiter);

$sql_count = count($sql_query);

//
// from update_to_rc3.php
//
echo "<html>\n";
echo "<body>\n";
for($i = 0; $i < $sql_count; $i++)
{
	echo "Running :: " . $sql_query[$i];
	flush();

	if ( !($result = $db->sql_query($sql_query[$i])) )
	{
		$errored = true;
		$error = $db->sql_error();
		echo " -> <b>FAILED</b> ---> <u>" . $error['message'] . "</u><br /><br />\n\n";
	}
	else
	{
		echo " -> <b><span class=\"ok\">COMPLETED</span></b><br /><br />\n\n";
	}
}

//
// process basic informations
//
$sql_query = @fread(@fopen($dbms_basic, 'r'), @filesize($dbms_basic));
$sql_query = preg_replace('/phpbb_/', $table_prefix, $sql_query);

if ( (strstr($sql_query, 'attach_config')) && (strstr($sql_query, 'attach_desc')) )
{
	die("<br />PLEASE UPLOAD THE CORRECT DATABASE SCHEMA FILES...<br />If you have done so, run the Installer again.<br />");
}

$sql_query = $remove_remarks($sql_query);
$sql_query = split_sql_file($sql_query, $delimiter_basic);

$sql_count = count($sql_query);

for($i = 0; $i < $sql_count; $i++)
{
	echo "Running :: " . $sql_query[$i];
	flush();

	if ( !($result = $db->sql_query($sql_query[$i])) )
	{
		$errored = true;
		$error = $db->sql_error();
		echo " -> <b>FAILED</b> ---> <u>" . $error['message'] . "</u><br /><br />\n\n";
	}
	else
	{
		echo " -> <b><span class=\"ok\">COMPLETED</span></b><br /><br />\n\n";
	}
}

$message = "";

if ( $errored )
{
	$message .= "<br />Some queries failed.<br />This is sometimes due to tables already there (from a previous installation), therefore please READ the errors and warnings and use common sense in interpreting them. Support is offered at http://www.opentools.de for questions you might have regarding those errors/warnings.";
}
else
{
	$message .= "<br />Attachment Mod Tables generated successfully.";
}

echo "\n<br />\n<b>COMPLETE!</b><br />\n";
echo $message . "<br />";
echo "<br /><b>NOW DELETE THIS FILE</b><br />\n";
echo "</body>";
echo "</html>";

?>
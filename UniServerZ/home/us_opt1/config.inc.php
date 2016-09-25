<?php

// === Get root path ==========================================================
  $path_array = explode("\\us_opt1",dirname(__FILE__)); // Split at folder
  $root       = substr($path_array[0],0,-5);   // Get path e.g C:\..\UniServer

// === Get MySQL Port =========================================================
// Get MySQL Port from environment variable MYSQL_TCP_PORT
  $port_ini = 3306; //Set default
  $port_ini = getenv('MYSQL_TCP_PORT'); //Get port configured

// ===================================================== END Get MySQL Port ===

// === Get MySQL Password ======================================================
  $file="$root\htpasswd\mysql\passwd.txt" ; //Name and path of password file
  $fh = fopen($file, 'r');                  //Open for read
  $password = trim(fgets($fh));             //Get first line removce /n
  fclose($fh);                              //Close
// ================================================= END Get MySQL Password ===

/* Webserver upload/save/import directories */
 
$cfg['UploadDir'] = "$root\\etc\\phpmyadmin";   // Directory for uploaded files 
$cfg['SaveDir']   = "$root\\etc\\phpmyadmin";   // Directory where phpMyAdmin can save exported data
$cfg['docSQLDir'] = "$root\\etc";              // Directory for docSQL imports,
$cfg['TempDir']   = "$root\\tmp";              // Directory where phpMyAdmin can save temporary files.


/* Servers configuration */
$i = 0;

/* Server: localhost [1] */
$i++;

/* Authentication section */
$cfg['Servers'][$i]['auth_type']       = 'config';  // Authentication method (config, http or cookie based)?
$cfg['Servers'][$i]['user']            = 'root';    // MySQL user
$cfg['Servers'][$i]['password']        = $password; // MySQL password (only needed with 'config' auth_type)
$cfg['Servers'][$i]['AllowNoPassword'] = false;     // Must use password

/* Server parameters */
$cfg['Servers'][$i]['verbose']      = 'Uniform Server'; // Verbose name for this host - leave blank to show the hostname
$cfg['Servers'][$i]['host']         = '127.0.0.1';      // MySQL hostname or IP address
$cfg['Servers'][$i]['port']         = $port_ini;        // Port set in ini See above
$cfg['Servers'][$i]['socket']       = '';               // Leave blank for default socket
$cfg['Servers'][$i]['connect_type'] = 'tcp';            // How to connect to MySQL server ('tcp' or 'socket')
$cfg['Servers'][$i]['extension']    = 'mysqli';         // MySQL extension to use ('mysql' or 'mysqli')
$cfg['Servers'][$i]['compress']     = false;            // No compression


/* PMA User advanced features */
$cfg['Servers'][$i]['controluser']    = 'pma';
$cfg['Servers'][$i]['controlpass']    = $password;

/* Advanced features */
$cfg['Servers'][$i]['pmadb']           = 'phpmyadmin';       // Database used for Relation, Bookmark and PDF Features
                  

/* Storage database and tables */
 $cfg['Servers'][$i]['bookmarktable'] = 'pma__bookmark';
 $cfg['Servers'][$i]['relation'] = 'pma__relation';
 $cfg['Servers'][$i]['table_info'] = 'pma__table_info';
 $cfg['Servers'][$i]['table_coords'] = 'pma__table_coords';
 $cfg['Servers'][$i]['pdf_pages'] = 'pma__pdf_pages';
 $cfg['Servers'][$i]['column_info'] = 'pma__column_info';
 $cfg['Servers'][$i]['history'] = 'pma__history';
 $cfg['Servers'][$i]['table_uiprefs'] = 'pma__table_uiprefs';
 $cfg['Servers'][$i]['tracking'] = 'pma__tracking';
 $cfg['Servers'][$i]['userconfig'] = 'pma__userconfig';
 $cfg['Servers'][$i]['recent'] = 'pma__recent';
 $cfg['Servers'][$i]['favorite'] = 'pma__favorite';
 $cfg['Servers'][$i]['users'] = 'pma__users';
 $cfg['Servers'][$i]['usergroups'] = 'pma__usergroups';
 $cfg['Servers'][$i]['navigationhiding'] = 'pma__navigationhiding';
 $cfg['Servers'][$i]['savedsearches'] = 'pma__savedsearches';
 $cfg['Servers'][$i]['central_columns'] = 'pma__central_columns';
 $cfg['Servers'][$i]['designer_settings'] = 'pma__designer_settings';
 $cfg['Servers'][$i]['export_templates'] = 'pma__export_templates';
/* End of servers configuration */




/* Other core phpMyAdmin settings */
$cfg['ServerDefault'] = 1;          // Select default server (0 = no default server)
$cfg['blowfish_secret'] = 'us123';  // Passphrase required for 'cookie' auth_type

$cfg['AllowAnywhereRecoding']       = true;
$cfg['DefaultCharset']              = 'utf-8';
$cfg['DefaultLang']                 = 'en-utf-8';   // Default language to use, if not browser-defined or user-defined
$cfg['DefaultConnectionCollation']  = 'utf8_general_ci';

/* Other core phpMyAdmin settings */

$cfg['ExecTimeLimit']           = 600;  // maximum execution time in seconds (0 for no limit)
$cfg['AllowUserDropDatabase']   = TRUE; // show a 'Drop database' link to normal users
$cfg['LoginCookieValidity']     = 1440; // validity of cookie login (in seconds)
$cfg['LeftFrameDBSeparator']    = '_';  // the separator to sub-tree the select-based light menu tree
$cfg['LeftFrameTableSeparator'] = '_';  // Which string will be used to generate table prefixes
$cfg['ShowTooltipAliasDB']      = TRUE; // if ShowToolTip is enabled, this defines that table/db comments
$cfg['ShowTooltipAliasTB']      = TRUE; // are shown (in the left menu and db_details_structure) instead of

// In the main frame, at startup...
$cfg['ShowPhpInfo']           = TRUE;   // information" and "change password" links for
$cfg['ShowChgPassword']       = TRUE;   // simple users or not
$cfg['ShowAll']               = TRUE;   // allows to display all the rows
$cfg['MaxRows']               = 300;    // maximum number of rows to display

/* Export defaults */

$cfg['Export']['asfile']                    = TRUE;
$cfg['Export']['onserver']                  = TRUE;
$cfg['Export']['file_template_table']       = '__TABLE__-tabel_%Y-%m-%d';
$cfg['Export']['file_template_database']    = '__DB__-db_%Y-%m-%d';
$cfg['Export']['file_template_server']      = '__SERVER__-mysql_%Y-%m-%d';

$cfg['Export']['csv_enclosed']              = '&quot;';

$cfg['Export']['sql_if_not_exists']         = FALSE;
$cfg['Export']['sql_columns']               = FALSE;
$cfg['Export']['sql_extended']              = FALSE;



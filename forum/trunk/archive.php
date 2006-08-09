<?php

// Start Variables

$var_list = get_defined_vars();
$safelist = array('_SERVER', '_GET', '_COOKIE');
foreach($var_list as $name => $value)
{
   if(array_search($name, $safelist) === FALSE)
   {
       unset($$name);
   }
}

unset($var_list, $name, $value, $safelist);

$HTTP_COOKIE_VARS 	= $_COOKIE;
$HTTP_GET_VARS 		= $_GET;

define('IN_PHPBB', true);
$phpbb_root_path = './';
include($phpbb_root_path . 'extension.inc');
include($phpbb_root_path . 'common.'.$phpEx);

// search engine do not index https:// so there's no need to check https://
define ("SITE_URL", "http://".$board_config['server_name'].$board_config['script_path']);
define ("ARCHIVE", "archive.".$phpEx);

include ("includes/archive/archive_functions.".$phpEx);

  $_VARS = array ();
  $url = substr ( strchr ($_SERVER['REQUEST_URI'], 'archive.'.$phpEx.'/'), 12 );
  $urlpieces = explode ("__", $url);
  $urlpiecesold = explode ("/", $url);
  if ( count ($urlpieces) < 2 ) {
  	    $urlpieces = $urlpiecesold;
  }
  foreach ($urlpieces as $val) {
  	if ( trim ( $val ) ) {
  	    $ex = explode ('_', $val);
  	    switch ( $ex[0] ) {
  	    	case "f";
  	    	    $_VARS['o'] = $ex[0];
  	    	    $_VARS['f'] = $ex[1];
  	    	break;
  	    	
  	    	case "c";
  	    	    $_VARS['o'] = $ex[0];
  	    	    $_VARS['c'] = $ex[1];
  	    	break;
  	    	
  	    	case "t";
  	    	    $_VARS['o'] = $ex[0];
  	    	    $_VARS['t'] = $ex[1];
  	    	break;
  	    	
  	    	case "start";
  	    	    $_VARS['start'] = $ex[1];
  	    	break;
  	    	
  	    	case "view";
  	    	    $_VARS['view'] = $ex[1];
  	    	break;
  	    	
  	    }
  	}
  }


//_______________________________________

switch ( $_VARS['o'] ) {
	default;

		include ("includes/archive/archive_index.".$phpEx);

	break;

	case "f";
	
        include ("includes/archive/archive_forum.".$phpEx);
	
	break;
	
	
	case "t";
	
        include ("includes/archive/archive_topic.".$phpEx);
	
	break;

}

?>

<?php
/*************************************************************************** 
*                            admin_prune_users.php 
*             php Admin Script for prune users mod 
*                       ------------------- 
*   begin                : April 30, 2002 
*   email                : ncr@db9.dk HTTP://mods.db9.dk 
*      ver. 1.0.2. 
* 
* 
*   History:
* 	 0.9.0. - initial BETA
*      0.9.1. - added prune inativated option
*	 0.9.2. - added support for the end user easely can customise the
*			 interface with more options    
*	 0.9.3. - changed $lang['prune'] to $lang['Prune__commands']
*	 0.9.4. - added prune "avarage posts prune
*	 0.9.5. - now support own language file, the complete mod, require litle change in existing files
*	 0.9.6. - change the javascript name, in the template file
*      1.0.0. - considered as final, included a limit about how meny users max can be deleted at once
*      1.0.1. - fixed a HTML tag, in the admin URL
*      1.0.2. - moved to users section in ACP
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

define('IN_PHPBB', 1);

if( !empty($setmodules) )
{
	$filename = basename(__FILE__);
	$module['Users'][$lang['Prune_users']] = $filename;
	return;
}
//
// Load default header
//
$no_page_header = TRUE;
$phpbb_root_path = "../";
require($phpbb_root_path . 'extension.inc');
require('pagestart.' . $phpEx);
include($phpbb_root_path . 'language/lang_' . $board_config['default_lang'] . '/lang_prune_users.' . $phpEx);

$sql = array();
$default = array();


// ********************************************************************************
// from here you can define you own delete creterias, if you makes more, then you shall also
// edit the files lang_main.php, and the file delete_users.php, so they hold the same amount
// of options

//
// Initial selection
//

// find zero posters
$sql [0] = ' AND user_posts="0"';
$default [0] = 240;

// find users who have newer logged in
$sql [1] = ' AND user_lastvisit="0"';
$default [1] = 240;

// find not activated users
$sql [2] = ' AND user_lastvisit=0 AND user_active=0';
$default [2] = 240;

// find users not visited since 60 days 
$sql [3] = ' AND user_lastvisit<'.(time()-86400*60); 
$default [3] = 120;
 
// 
// Users with less than 0.1 posts per day avg. 
// 
$sql[4] = ' AND user_posts/((user_lastvisit - user_regdate)/86400) < "0.1"'; 
$default[4] =360;


// ********************************************************************************
// ****************** Do not change any thing below *******************************

$options = '<option value="1">&nbsp;'.$lang['1_Day'].'</option>
	<option value="7">&nbsp;'.$lang['7_Days'].'</option>
	<option value="14">&nbsp;'.$lang['2_Weeks'].'</option>
	<option value="21">&nbsp;'.sprintf($lang['X_Weeks'],3).'</option>
	<option value="30">&nbsp;'.$lang['1_Month'].'</option>
	<option value="60">&nbsp;'.sprintf($lang['X_Months'],2).'</option>
	<option value="90">&nbsp;'.$lang['3_Months'].'</option>
	<option value="180">&nbsp;'.$lang['6_Months'].'</option>
	<option value="365">&nbsp;'.$lang['1_Year'].'</option>
  	</select>';
//
// Generate page
//

include('page_header_admin.'.$phpEx);
$template->set_filenames(array("body" => "admin/prune_users_body.tpl"));
$n=0;
while ( !empty($sql[$n]) )
{
	$vars='days_'.$n;
	
	$default [$n] = ($default [$n])?$default [$n]:10;
	$days [$n] = ( isset($HTTP_GET_VARS[$vars]) ) ? $HTTP_GET_VARS[$vars] : (( isset($HTTP_POST_VARS[$vars]) ) ? intval($HTTP_POST_VARS[$vars]) : $default[$n]);
//		<option value="'.$days[$n].'" SELECTED>&nbsp;'.$days[$n].' '.$lang['Days'].'&nbsp;</option>'.$options;
//	'.str_replace("value=\"".$days[$n]."\"> SELECTED " , "value=\"".$days[$n]."\">" ,$options);

	// make a extra option if the parsed days value does not already exisit
	if (!strpos($options,"value=\"".$days[$n]))
	{
		$options = '<option value="'.$days[$n].'">&nbsp;'.sprintf($lang['X_Days'],$days[$n]).'</option>'.$options;
	}
	$select[$n] = '<select name="days_'.$n.'" size="1" onchange="SetDays();" class="gensmall">
		'.str_replace("value=\"".$days[$n]."\">&nbsp;", "value=\"".$days[$n]."\" SELECTED>&nbsp;*" ,$options);

	if(!($result = $db->sql_query('SELECT user_id , username, user_level FROM '. USERS_TABLE .' WHERE user_id<>"'.ANONYMOUS.'"'.$sql[$n].' AND user_regdate<"'.(time()-(86400*$days [$n])).'" ORDER BY username LIMIT 800')))
		message_die(GENERAL_ERROR, 'Error obtaining userdata'.$sql[$n], '', __LINE__, __FILE__, $sql[$n]);
	$user_list = $db->sql_fetchrowset($result);
	$user_count=count($user_list);
	for($i = 0; $i < $user_count; $i++) 
	{ 
		$style_color = ($user__list[$i]['user_level'] == ADMIN )?'style="color:#' . $theme['fontcolor3'] . '"':(( $user__list[$i]['user_level'] == MOD )?'style="color:#' . $theme['fontcolor2'] . '"':''); 
		$list[$n] .= ' <a href="' . append_sid($phpbb_root_path."profile.$phpEx?mode=viewprofile&amp;" . POST_USERS_URL . "=" . $user_list[$i]['user_id']) . '"' . $style_color .'><b>' . $user_list[$i]['username'] . '</b></a>'; 
	}
	$db->sql_freeresult($result);
$template->assign_block_vars('prune_list', array(
		"LIST" => ($list[$n])?$list[$n]:$lang['None'],
		"USER_COUNT" => $user_count,
		"L_PRUNE" => $lang['Prune_commands'][$n],
		"L_PRUNE_EXPLAIN" => sprintf($lang['Prune_explain'][$n],$days[$n]),
		'S_PRUNE_USERS' => append_sid("admin_prune_users.$phpEx"),
		"S_DAYS" => $select[$n],
		"U_PRUNE" => '<a href="'.append_sid($phpbb_root_path.'delete_users.php?mode=prune_'.$n.'&days='.$days[$n]).'" onClick="return confirm(\''.sprintf($lang['Prune_on_click'],$user_count).'\')">'.$lang['Prune_commands'][$n].'</a>',));
	$n++;
}

$template->assign_vars(array(
	"L_PRUNE_ACTION" => $lang['Prune_Action'],
	"L_PRUNE_LIST" =>	$lang['Prune_user_list'],
	"L_DAYS" => $lang['Days'],
	"L_PRUNE_USERS" => $lang['Prune_users'],
	"L_PRUNE_USERS_EXPLAIN" => $lang['Prune_users_explain'],
));

$template->pparse('body');
include('page_footer_admin.'.$phpEx);

?>

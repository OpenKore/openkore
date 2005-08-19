<?php
/***************************************************************************
 *                             admin_syntax.php
 *                            ------------------
 *   begin                : Tuesday, Nov 2, 2004
 *   copyright            : (C) 2004, 2005 Nigel McNie
 *   email                : nigel@geshi.org
 *
 *   $Id: admin_syntax.php,v 1.2 2005/06/08 04:25:38 oracleshinoda Exp $
 * 
 * Administration for the Syntax Highlighter MOD.
 * 
 * For help with this mod, please use this thread (while this mod is still BETA):
 * 
 *   http://phpbb.com/phpBB/viewtopic.php?t=217723
 * 
 * Please note that this mod is still under development, so bug reports are
 * welcome while support requests may not be honoured.
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
	$file = basename(__FILE__);
	$module['General'][$lang['Syntax_Highlighting']] = "$file";
	return;
}

//
// Basic stuff
//
$phpbb_root_path = './../';
require($phpbb_root_path . 'extension.inc');
require('./pagestart.' . $phpEx);

$template->set_filenames(array(
	'body' => 'admin/admin_syntax_body.tpl'
	)
);

require($phpbb_root_path . 'includes/functions_syntax_cache.'.$phpEx);

//
// Perform actions if needed
//
switch ( $HTTP_POST_VARS['mode'] )
{
	case ( 'clear_cache' ):
		if ( isset($HTTP_POST_VARS['sure']) )
		{
			clear_cache();
			message_die(GENERAL_MESSAGE, $lang['Syntax_cache_cleared_successfully'] . '<br /><br />' . sprintf($lang['Syntax_click_return_syntaxadmin'], '<a href="' . append_sid("admin_syntax.$phpEx") . '">', '</a>'));
		}
		else
		{
			message_die(GENERAL_MESSAGE, $lang['Syntax_cache_not_cleared'] . '<br /><br />' . sprintf($lang['Syntax_click_return_syntaxadmin'], '<a href="' . append_sid("admin_syntax.$phpEx") . '">', '</a>'));
		}
		break;
	case ( 'overall_control' ):
		if ( $board_config['syntax_status'] != $HTTP_POST_VARS['enable_disable_syntax'] && in_array($HTTP_POST_VARS['enable_disable_syntax'], array(0, 1, 2)) )
		{
			clear_cache();

			$sql = "UPDATE " . CONFIG_TABLE . "
				SET config_value = '" . $HTTP_POST_VARS['enable_disable_syntax'] . "'
				WHERE config_name = 'syntax_status'";
			if ( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Could not update Syntax Highlighter status', 'Error', __LINE__, __FILE__, $sql);
			}

			message_die(GENERAL_MESSAGE, $lang['Syntax_status_updated_successfully'] . '<br /><br />' . sprintf($lang['Syntax_click_return_syntaxadmin'], '<a href="' . append_sid("admin_syntax.$phpEx") . '">', '</a>'));
		}
		else
		{
			message_die(GENERAL_MESSAGE, $lang['Syntax_status_not_updated'] . '<br /><br />' . sprintf($lang['Syntax_click_return_syntaxadmin'], '<a href="' . append_sid("admin_syntax.$phpEx") . '">', '</a>'));
		}
		break;
	case ( 'enable_disable_cache' ):
		if ( isset($HTTP_POST_VARS['enable_cache']) && $board_config['syntax_enable_cache'] == 0 )
		{
			//
			// Turn cache on, where previously it was off
			//
			clear_cache();

			$sql = "UPDATE " . CONFIG_TABLE . "
				SET config_value = '1'
				WHERE config_name = 'syntax_enable_cache'";
			if ( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Could not update Syntax Highilghter cache status', 'Error', __LINE__, __FILE__, $sql);
			}
		}
		elseif ( !isset($HTTP_POST_VARS['enable_cache']) && $board_config['syntax_enable_cache'] != 0 )
		{
			//
			// Turn cache off, where previously it was on
			//
			clear_cache();

			$sql = "UPDATE " . CONFIG_TABLE . "
				SET config_value = '0'
				WHERE config_name = 'syntax_enable_cache'";
			if ( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Could not update Syntax Highilghter cache status', 'Error', __LINE__, __FILE__, $sql);
			}
		}

		message_die(GENERAL_MESSAGE, 'Syntax Highlighter cache status updated successfully<br /><br />' . sprintf($lang['Syntax_click_return_syntaxadmin'], '<a href="' . append_sid("admin_syntax.$phpEx") . '">', '</a>'));
		break;
	case ( 'cache_options' ):
		//
		// Updating cache options
		//
		$cache_dir_size = abs(intval($HTTP_POST_VARS['cache_dir_size']));
		$cache_dir_size_units = $HTTP_POST_VARS['cache_dir_size_units'];
		if ( $cache_dir_size_units == 'G' )
		{
			$cache_dir_size = $cache_dir_size * 1024 * 1024 * 1024;
		}
		elseif ( $cache_dir_size_units == 'M' )
		{
			$cache_dir_size = $cache_dir_size * 1024 * 1024;
		}
		elseif ( $cache_dir_size_units == 'K' )
		{
			$cache_dir_size = $cache_dir_size * 1024;
		}
		$cache_dir_size = ( $cache_dir_size > 1023 || $cache_dir_size == 0 ) ? $cache_dir_size : 1024;

		$cache_expiry_time = abs(intval($HTTP_POST_VARS['cache_expiry_time']));
		$cache_expiry_time_units = $HTTP_POST_VARS['cache_expiry_time_units'];
		if ( $cache_expiry_time_units == 'Y' )
		{
			$cache_expiry_time = $cache_expiry_time * 60 * 60 * 24 * 365;
		}
		elseif ( $cache_expiry_time_units == 'M' )
		{
			$cache_expiry_time = $cache_expiry_time * 60 * 60 * 24 * 30;
		}
		elseif ( $cache_expiry_time_units == 'D' )
		{
			$cache_expiry_time = $cache_expiry_time * 60 * 60 * 24;
		}
		elseif ( $cache_expiry_time_units == 'H' )
		{
			$cache_expiry_time = $cache_expiry_time * 60 * 60;
		}
		elseif ( $cache_expiry_time_units == 'M' )
		{
			$cache_expiry_time = $cache_expiry_time * 60;
		}

		if ( $cache_dir_size != $board_config['syntax_cache_dir_size'] )
		{
			$sql = "UPDATE " . CONFIG_TABLE . "
				SET config_value = '$cache_dir_size'
				WHERE config_name = 'syntax_cache_dir_size'";
			if ( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Could not update Syntax Highilghter cache directory size', 'Error', __LINE__, __FILE__, $sql);
			}
			if ( $cache_dir_size != 0 && ($cache_dir_size < $board_config['syntax_cache_dir_size'] || $board_config['syntax_cache_dir_size'] == 0) )
			{
				// New size is smaller - clear the cache
				clear_cache();
			}
		}

		if ( $cache_expiry_time != $board_config['syntax_cache_files_expire'] )
		{
			$sql = "UPDATE " . CONFIG_TABLE . "
				SET config_value = '$cache_expiry_time'
				WHERE config_name = 'syntax_cache_files_expire'";
			if ( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Could not update Syntax Highilghter cache file expiry time', 'Error', __LINE__, __FILE__, $sql);
			}
		}

		message_die(GENERAL_MESSAGE, 'Syntax Highlighter cache configuration updated successfully<br /><br />' . sprintf($lang['Syntax_click_return_syntaxadmin'], '<a href="' . append_sid("admin_syntax.$phpEx") . '">', '</a>'));
		break;
	case ( 'general_options' ):
		//
		// Updating general options
		//
		$enable_line_numbers = ( isset($HTTP_POST_VARS['enable_line_numbers']) ) ? 1 : 0;
		$enable_function_urls = ( isset($HTTP_POST_VARS['enable_function_urls']) ) ? 1 : 0;

		if ( $enable_line_numbers != $board_config['syntax_enable_line_numbers'] )
		{
			$purge_cache = true;
			$sql = "UPDATE " . CONFIG_TABLE . "
				SET config_value = '$enable_line_numbers'
				WHERE config_name = 'syntax_enable_line_numbers'";
			if ( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Could not update Syntax Highilghter general configuration', 'Error', __LINE__, __FILE__, $sql);
			}
		}

		if ( $enable_function_urls != $board_config['syntax_enable_urls'] )
		{
			$purge_cache = true;
			$sql = "UPDATE " . CONFIG_TABLE . "
				SET config_value = '$enable_function_urls'
				WHERE config_name = 'syntax_enable_urls'";
			if ( !($result = $db->sql_query($sql)) )
			{
				message_die(GENERAL_ERROR, 'Could not update Syntax Highilghter general configuration', 'Error', __LINE__, __FILE__, $sql);
			}
		}

		if ( $purge_cache )
		{
			clear_cache();
		}

		message_die(GENERAL_MESSAGE, 'Syntax Highlighter general configuration updated successfully<br /><br />' . sprintf($lang['Syntax_click_return_syntaxadmin'], '<a href="' . append_sid("admin_syntax.$phpEx") . '">', '</a>'));
		break;
	case ( 'update_language_files' ):
		//
		// Updating permissions on language files
		//
		$sql = "SELECT * FROM " . SYNTAX_LANGUAGE_CONFIG_TABLE;
		if ( !($result = $db->sql_query($sql)) )
		{
			message_die(GENERAL_ERROR, 'Could not get Syntax Highlighter config information', 'Error', __LINE__, __FILE__, $sql);
		}

		while ( $row = $db->sql_fetchrow($result) )
		{
			$language = stripslashes($row['language_file_name']);
			$lang_name = substr($language, 0, strpos($language, '.'));

			//
			// Get at vars
			//
			eval('$mode = isset($HTTP_POST_VARS[\'' . $lang_name . '_enabled\']) ? 0644 : 0000;');
			eval('$lang_identifier = addslashes(trim($HTTP_POST_VARS[\'' . $lang_name . '_code\']));');
			eval('$lang_display = addslashes(trim($HTTP_POST_VARS[\'' . $lang_name . '_display\']));');
/*			echo "<pre>lang: $language
mode: " . sprintf("%o", $mode) . "(" . substr(sprintf("%o", fileperms($phpbb_root_path . 'includes/geshi/' . $language)), -3) . "
id: $lang_identifier ({$row['lang_identifier']})
di: $lang_display ({$row['lang_display_name']})</pre>\n";*/

			$change_needed = ( ($lang_identifier != '' && $lang_identifier != $row['lang_identifier']) || ($lang_display != '' && $lang_display != $row['lang_display_name']) || substr(sprintf("%o", fileperms($phpbb_root_path . 'includes/geshi/' . $language)), -3) != sprintf("%o", $mode) );
/*echo $change_needed;
$change_needed = false;*/
			if ( $change_needed )
			{
				eval('@chmod(\'' . $phpbb_root_path . 'includes/geshi/' . $language . '.' . $phpEx . '\', $mode) or message_die(GENERAL_ERROR, \'Could not CHMOD the ' . $language . ' language file <code>' . $phpbb_root_path . 'includes/geshi/' . $language . '.' . $phpEx . '</code>\');');

				$sql = "UPDATE " . SYNTAX_LANGUAGE_CONFIG_TABLE . "
					SET lang_identifier = '$lang_identifier', lang_display_name = '$lang_display'
					WHERE language_file_name = '" . addslashes($language) . "'";
				if ( !($update_result = $db->sql_query($sql)) )
				{
					message_die(GENERAL_ERROR, 'Could not update Syntax Highlighter language config information for ' . $language, 'Error', __LINE__, __FILE__, $sql);
				}
				$purge_cache = true;
			}
		}

		if ( isset($purge_cache) )
		{
			clear_cache();
		}

		message_die(GENERAL_MESSAGE, 'Syntax Highlighter language configuration updated successfully<br /><br />' . sprintf($lang['Syntax_click_return_syntaxadmin'], '<a href="' . append_sid("admin_syntax.$phpEx") . '">', '</a>'));
		break;
	case ( 'update_language_files_simple' ):
		//
		// Updating language file permissions in simple mode
		//
		$dh = @opendir($phpbb_root_path . 'includes/geshi/') or message_die(GENERAL_ERROR, 'Could not open the language file directory');
		$file = readdir($dh);

		while ( $file !== false )
		{
			if ( $file == 'css-gen.cfg' || $file == '.' || $file == '..' )
			{
				$file = readdir($dh);
				continue;
			}
			$lang_name = substr($file, 0, strpos($file, '.'));
			eval('$mode = isset($HTTP_POST_VARS[\'' . $lang_name . '_enabled\']) ? 0644 : 0000;');
			if ( substr(sprintf("%o", fileperms($phpbb_root_path . 'includes/geshi/' . $file)), -3) != sprintf("%o", $mode) )
			{
				@chmod($phpbb_root_path . 'includes/geshi/' . $file, $mode) or message_die(GENERAL_ERROR, 'Could not CHMOD the ' . $language_name . ' language file');
			}

			$file = readdir($dh);
		}

		message_die(GENERAL_MESSAGE, 'Syntax Highlighter language configuration updated successfully<br /><br />' . sprintf($lang['Syntax_click_return_syntaxadmin'], '<a href="' . append_sid("admin_syntax.$phpEx") . '">', '</a>'));
		break;
}


//
// Display the default admin screen
//

// What mode are we in?
if ( !isset($board_config['syntax_status']) )
{
	$l_syntax_mode = $lang['Syntax_highlighting_simple_mode'];

	$template->assign_block_vars('s_advanced_mode_disabled', array(
		'L_MAIN_CONTROL_DISABLED' => $lang['Syntax_main_control_disabled'],
		'L_CACHE_CONTROL_DISABLED' => $lang['Syntax_cache_control_disabled'],
		'L_CACHE_OPTIONS_DISABLED' => $lang['Syntax_cache_options_disabled'],
		'L_LANGUAGE_CONTROL_EXPLAIN' => $lang['Syntax_simple_language_control_explain'],
		'L_LANGUAGE_NAME' => $lang['Syntax_language_name'],
		'L_LANGUAGE_ENABLED' => $lang['Syntax_language_enabled'],
		'L_UPDATE_LANGUAGE_OPTIONS' => $lang['Syntax_update_language_options'],
		'L_RESET_LANGUAGE_FORM' => $lang['Syntax_reset_language_form']
		)
	);

	$dh = @opendir($phpbb_root_path . 'includes/geshi/') or message_die(GENERAL_ERROR, 'Could not open the language file directory');
	$file = readdir($dh);
	$rows = array();

	while ( $file !== false )
	{
		if ( $file == 'css-gen.cfg' || $file == '.' || $file == '..' )
		{
			$file = readdir($dh);
			continue;
		}
		$language_name = substr($file, 0, strpos($file, '.'));
		$language_enabled = ( is_readable($phpbb_root_path . 'includes/geshi/' . $file) ) ? ' checked="checked"' : '';

		$rows[] = array(0 => $language_name, 1 => $language_enabled);
		$file = readdir($dh);
	}
	closedir($dh);

	array_multisort($rows);

	foreach ( $rows as $row )
	{
		$template->assign_block_vars('s_advanced_mode_disabled.language_file', array(
			'LANGUAGE_NAME' => $row[0],
			'LANGUAGE_ENABLED' => $row[1]
			)
		);
	}
	unset($rows);
}
else
{
	$l_syntax_mode = $lang['Syntax_highlighting_advanced_mode'];

	$syntax_enabled_checked = ( $board_config['syntax_status'] == SYNTAX_PARSE_ON ) ? ' checked="checked"' : '';
	$syntax_partial_checked = ( $board_config['syntax_status'] == SYNTAX_PARSE_AS_CODE ) ? ' checked="checked"' : '';
	$syntax_disabled_checked = ( $board_config['syntax_status'] == SYNTAX_NO_PARSE ) ? ' checked="checked"' : '';

	$template->assign_block_vars('s_advanced_mode_enabled', array(
		'L_UPDATE' => $lang['Syntax_update_status'],
        'L_MAIN_CONTROL_EXPLAIN' => $lang['Syntax_main_control_explain'],
		'L_ENABLED' => $lang['Syntax_enabled'],
		'L_PARTIAL' => $lang['Syntax_partial'],
		'L_DISABLED' => $lang['Syntax_disabled'],
		'L_ENABLE_CACHE' => $lang['Syntax_enable_cache'],
		'L_UPDATE_CACHE_ENABLED' => $lang['Syntax_update_cache_enabled'],
		'L_BYTES' => $lang['Syntax_bytes'],
		'L_KILOBYTES' => $lang['Syntax_kilobytes'],
		'L_MEGABYTES' => $lang['Syntax_megabytes'],
		'L_GIGABYTES' => $lang['Syntax_gigabytes'],
		'L_CACHE_DIR_SIZE' => $lang['Syntax_cache_dir_size'],
		'L_SET_CACHE_OPTIONS' => $lang['Syntax_set_cache_options'],
		'L_SECONDS' => $lang['Syntax_seconds'],
		'L_MINUTES' => $lang['Syntax_minutes'],
		'L_HOURS' => $lang['Syntax_hours'],
		'L_DAYS' => $lang['Syntax_days'],
		'L_MONTHS' => $lang['Syntax_months'],
		'L_YEARS' => $lang['Syntax_years'],
		'L_CACHE_EXPIRY_TIME' => $lang['Syntax_cache_expiry_time'],
		'L_LINE_NUMBERS_ENABLED' => $lang['Syntax_line_numbers_enabled'],
		'L_FUNCTION_URLS_ENABLED' => $lang['Syntax_function_urls_enabled'],
		'L_CHANGE_GENERAL_OPTIONS' => $lang['Syntax_change_general_options'],
		'L_LANGUAGE_CONTROL_EXPLAIN' => $lang['Syntax_advanced_language_control_explain'],
		'L_LANGUAGE_NAME' => $lang['Syntax_language_name'],
        'L_LANGUAGE_NAME_EXPLAIN' => $lang['Syntax_language_name_explain'],
		'L_LANGUAGE_ENABLED' => $lang['Syntax_language_enabled'],
        'L_LANGUAGE_ENABLED_EXPLAIN' => $lang['Syntax_language_enabled_explain'],
		'L_LANGUAGE_CODE' => $lang['Syntax_language_code'],
		'L_LANGUAGE_CODE_EXPLAIN' => $lang['Syntax_language_code_explain'],
		'L_LANGUAGE_DISPLAY_NAME' => $lang['Syntax_language_display_name'],
		'L_LANGUAGE_DISPLAY_NAME_EXPLAIN' => $lang['Syntax_language_display_name_explain'],
		'L_UPDATE_LANGUAGE_OPTIONS' => $lang['Syntax_update_language_options'],
		'L_RESET_LANGUAGE_FORM' => $lang['Syntax_reset_language_form'],

		'CACHE_CHECKED_ENABLED' => ( !empty($board_config['syntax_enable_cache']) ) ? ' checked="checked"' : '',
		'CACHE_DIR_SIZE' => $board_config['syntax_cache_dir_size'],
		'CACHE_EXPIRY_TIME' => $board_config['syntax_cache_files_expire'],
		'LINE_NUMBERS_ENABLED' => ( $board_config['syntax_enable_line_numbers'] ) ? ' checked="checked"' : '',
		'FUNCTION_URLS_ENABLED' => ( $board_config['syntax_enable_urls'] ) ? ' checked="checked"' : '',


		'SYNTAX_ENABLED_CHECKED' => $syntax_enabled_checked,
		'SYNTAX_PARTIAL_CHECKED' => $syntax_partial_checked,
		'SYNTAX_DISABLED_CHECKED' => $syntax_disabled_checked,
		)
	);

	//
	// Now, for each language file we need to assign a row
	// about it
	//
	$sql = "SELECT * FROM " . SYNTAX_LANGUAGE_CONFIG_TABLE . "
		ORDER BY language_file_name";
	if ( !($result = $db->sql_query($sql)) )
	{
		message_die(GENERAL_ERROR, 'Could not update Syntax Highilghter cache status', 'Error', __LINE__, __FILE__, $sql);
	}

	while ( $row = $db->sql_fetchrow($result) )
	{
		$language_name = substr(stripslashes($row['language_file_name']), 0, strpos(stripslashes($row['language_file_name']), '.'));
		$language_enabled = ( is_readable($phpbb_root_path . 'includes/geshi/' . $language_name . '.php') ) ? ' checked="checked"' : '';
		$language_code = stripslashes($row['lang_identifier']);
		$language_display_name = stripslashes($row['lang_display_name']);

		$template->assign_block_vars('s_advanced_mode_enabled.language_file', array(
			'LANGUAGE_NAME' => $language_name,
			'LANGUAGE_ENABLED' => $language_enabled,
			'LANGUAGE_CODE' => $language_code,
			'LANGUAGE_DISPLAY_NAME' => $language_display_name
			)
		);
	}
}

//
// Assign general vars
//
$template->assign_vars(array(
	'L_SYNTAX_TITLE' => $lang['Syntax_Highlighting'],
	'L_SYNTAX_EXPLAIN' => $lang['syntax_explain'],
	'L_SYNTAX_MODE' => $l_syntax_mode,
	'L_MAIN_CONTROL' => $lang['Syntax_main_control'],
	'L_CACHE_CONTROL' => $lang['Syntax_cache_control'],
	'L_CLEAR_THE_CACHE' => $lang['Syntax_clear_the_cache'],
	'L_CLEAR_CACHE_YES_NO' => $lang['Syntax_clear_cache_yes_no'],
	'L_CLEAR_CACHE' => $lang['Syntax_clear_cache'],
	'L_CACHE_OPTIONS' => $lang['Syntax_cache_options'],
	'L_GENERAL_OPTIONS' => $lang['Syntax_general_options'],
	'L_LANGUAGE_CONTROL' => $lang['Syntax_language_control'],

	'S_SYNTAX_ACTION' => append_sid("admin_syntax.$phpEx")
	)
);

$template->pparse('body');

include('./page_footer_admin.'.$phpEx);
?>
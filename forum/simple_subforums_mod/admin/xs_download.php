<?php

/***************************************************************************
 *                               xs_import.php
 *                               -------------
 *   copyright            : (C) 2003 - 2005 CyberAlien
 *   support              : http://www.phpbbstyles.com
 *
 *   version              : 2.1.0
 *
 *   file revision        : 55
 *   project revision     : 63
 *   last modified        : 28 Dec 2004  18:32:57
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
$phpbb_root_path = "./../";
$no_page_header = true;
require($phpbb_root_path . 'extension.inc');
require('./pagestart.' . $phpEx);

// check if mod is installed
if(empty($template->xs_version) || $template->xs_version !== 6)
{
	message_die(GENERAL_ERROR, 'eXtreme Styles mod is not installed. You forgot to upload includes/template.php');
}

define('IN_XS', true);
include_once('xs_include.' . $phpEx);

$template->assign_block_vars('nav_left',array('ITEM' => '&raquo; <a href="' . append_sid('xs_import.'.$phpEx) . '">' . $lang['xs_import_styles'] . '</a>'));
$template->assign_block_vars('nav_left',array('ITEM' => '&raquo; <a href="' . append_sid('xs_download.'.$phpEx) . '">' . $lang['xs_download_styles'] . '</a>'));

// submit url
if(isset($HTTP_GET_VARS['url']) && !defined('DEMO_MODE'))
{
	$id = intval($HTTP_GET_VARS['url']);
	$var = 'xs_downloads_' . $id;
	$import_data = array(
		'host'		=> $HTTP_SERVER_VARS['HTTP_HOST'],
		'port'		=> $HTTP_SERVER_VARS['SERVER_PORT'],
		'url'		=> str_replace('xs_download.', 'xs_frameset.', $HTTP_SERVER_VARS['PHP_SELF']),
		'session'	=> $userdata['session_id'],
		'xs'		=> $template->xs_versiontxt,
		'style'		=> STYLE_HEADER_VERSION,
	);
	$str = '<form action="' . $board_config[$var] . '" method="post" style="display: inline;" target="main"><input type="hidden" name="data" value="' . htmlspecialchars(serialize($import_data)) . '" /><input type="submit" value="' . $lang['xs_continue'] . '" class="post" /></form>';
	$message = $lang['xs_import_download_warning'] . '<br /><br />' . $str . '<br /><br />' . str_replace('{URL}', append_sid('xs_download.'.$phpEx), $lang['xs_download_back']);
	xs_message($lang['Information'], $message);
}


if(isset($HTTP_GET_VARS['edit']))
{
	$id = intval($HTTP_GET_VARS['edit']);
	$template->assign_block_vars('edit', array(
		'ID'		=> $id,
		'TITLE'		=> $board_config['xs_downloads_title_'.$id],
		'URL'		=> $board_config['xs_downloads_'.$id]
		));
}

if(isset($HTTP_POST_VARS['edit']) && !defined('DEMO_MODE'))
{
	$id = intval($HTTP_POST_VARS['edit']);
	$update = array();
	if(!empty($HTTP_POST_VARS['edit_delete']))
	{
		// delete link
		$total = $board_config['xs_downloads_count'];
		$update['xs_downloads_count'] = $total - 1;
		for($i=$id; $i<($total-1); $i++)
		{
			$update['xs_downloads_'.$i] = $update['xs_downloads_'.($i+1)];
			$update['xs_downloads_title_'.$i] = $update['xs_downloads_title_'.($i+1)];
		}
		$update['xs_downloads_'.($total-1)] = '';
		$update['xs_downloads_title_'.($total-1)] = '';
	}
	else
	{
		$update['xs_downloads_'.$id] = stripslashes($HTTP_POST_VARS['edit_url']);
		$update['xs_downloads_title_'.$id] = stripslashes($HTTP_POST_VARS['edit_title']);
	}
	foreach($update as $var => $value)
	{
		if(isset($board_config[$var]))
		{
			$sql = "UPDATE " . CONFIG_TABLE . " SET config_value='" . xs_sql($value) . "' WHERE config_name='" . $var . "'";
		}
		else
		{
			$sql = "INSERT INTO " . CONFIG_TABLE . " (config_name, config_value) VALUES ('" . $var . "', '" . xs_sql($value) . "')";
		}
		$db->sql_query($sql);
		$board_config[$var] = $value;
	}
	// update config cache
	if(defined('XS_MODS_CATEGORY_HIERARCHY210'))
	{
		if(!empty($config))
		{
			$config->read(true);
		}
	}
}

if(!empty($HTTP_POST_VARS['add_url']) && !defined('DEMO_MODE'))
{
	$id = $board_config['xs_downloads_count'];
	$update = array();
	$update['xs_downloads_'.$id] = stripslashes($HTTP_POST_VARS['add_url']);
	$update['xs_downloads_title_'.$id] = stripslashes($HTTP_POST_VARS['add_title']);
	$update['xs_downloads_count'] = $board_config['xs_downloads_count'] + 1;
	foreach($update as $var => $value)
	{
		if(isset($board_config[$var]))
		{
			$sql = "UPDATE " . CONFIG_TABLE . " SET config_value='" . xs_sql($value) . "' WHERE config_name='" . $var . "'";
		}
		else
		{
			$sql = "INSERT INTO " . CONFIG_TABLE . " (config_name, config_value) VALUES ('" . $var . "', '" . xs_sql($value) . "')";
		}
		$db->sql_query($sql);
		$board_config[$var] = $value;
	}
	// update config cache
	if( defined('XS_MODS_CATEGORY_HIERARCHY210') && !empty($config) )
	{
		$config->read(true);
	}
}

for($i=0; $i<$board_config['xs_downloads_count']; $i++)
{
	$row_class = $xs_row_class[$i % 2];
	$template->assign_block_vars('url', array(
		'ROW_CLASS'		=> $row_class,
		'NUM'			=> $i,
		'NUM1'			=> $i + 1,
		'URL'			=> htmlspecialchars($board_config['xs_downloads_'.$i]),
		'TITLE'			=> htmlspecialchars($board_config['xs_downloads_title_'.$i]),
		'U_DOWNLOAD'	=> append_sid('xs_download.'.$phpEx.'?url='.$i),
		'U_EDIT'		=> append_sid('xs_download.'.$phpEx.'?edit='.$i),
		));
}

$template->assign_vars(array(
	'U_POST'		=> append_sid('xs_download.'.$phpEx)
	));

$template->set_filenames(array('body' => XS_TPL_PATH . 'downloads.tpl'));
$template->pparse('body');
xs_exit();

?>
<?php

/***************************************************************************
 *                             xs_uninstall.php
 *                             ----------------
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

$template->assign_block_vars('nav_left',array('ITEM' => '&raquo; <a href="' . append_sid('xs_uninstall.'.$phpEx) . '">' . $lang['xs_uninstall_styles'] . '</a>'));

$lang['xs_uninstall_back'] = str_replace('{URL}', append_sid('xs_uninstall.'.$phpEx), $lang['xs_uninstall_back']);
$lang['xs_goto_default'] = str_replace('{URL}', append_sid('xs_styles.'.$phpEx), $lang['xs_goto_default']);

//
// uninstall style
//
if(isset($HTTP_GET_VARS['remove']) && !defined('DEMO_MODE'))
{
	$remove_id = intval($HTTP_GET_VARS['remove']);
	if($board_config['default_style'] == $remove_id)
	{
		xs_error(str_replace('{URL}', append_sid('xs_styles.'.$phpEx), $lang['xs_uninstall_default']) . '<br /><br />' . $lang['xs_uninstall_back']);
	}
	$sql = "SELECT themes_id, template_name, style_name FROM " . THEMES_TABLE . " WHERE themes_id='{$remove_id}'";
	if(!$result = $db->sql_query($sql))
	{
		xs_error($lang['xs_no_style_info'] . '<br /><br />' . $lang['xs_uninstall_back'], __LINE__, __FILE__);
	}
	$row = $db->sql_fetchrow($result);
	if(empty($row['themes_id']))
	{
		xs_error($lang['xs_no_style_info'] . '<br /><br />' . $lang['xs_uninstall_back'], __LINE__, __FILE__);
	}
	$sql = "UPDATE " . USERS_TABLE . " SET user_style=NULL WHERE user_style='{$remove_id}'";
	$db->sql_query($sql);
	$sql = "DELETE FROM " . THEMES_TABLE . " WHERE themes_id='{$remove_id}'";
	$db->sql_query($sql);
	$template->assign_block_vars('removed', array());
	// remove files
	if(!empty($HTTP_GET_VARS['dir']))
	{
		$HTTP_POST_VARS['remove'] = addslashes($row['template_name']);
	}
	// remove config
	if(empty($HTTP_GET_VARS['nocfg']) && isset($board_config['xs_style_'.$row['template_name']]))
	{
		$sql = "DELETE FROM " . CONFIG_TABLE . " WHERE config_name='" . addslashes("xs_style_{$row['template_name']}") . "'";
		$db->sql_query($sql);
		$template->assign_block_vars('left_refresh', array(
				'ACTION'	=> append_sid('index.' . $phpEx . '?pane=left')
			));
		// recache config table for cat_hierarchy 2.1.0
		if(isset($GLOBALS['config']) && is_object($GLOBALS['config']))
		{
			global $config;
			$config->read(true);
		}
	}
	// recache themes table
	if(defined('XS_MODS_CATEGORY_HIERARCHY210'))
	{
		if ( empty($themes) )
		{
			$themes = new themes();
		}
		if ( !empty($themes) )
		{
			$themes->read(true);
		}
	}
}

function remove_all($dir)
{
	$res = opendir($dir);
	if(!$res)
	{
		return false;
	}
	while(($file = readdir($res)) !== false)
	{
		if($file !== '.' && $file !== '..')
		{
			$str = $dir . '/' . $file;
			if(is_dir($str))
			{
				remove_all($str);
				@rmdir($str);
			}
			else
			{
				@unlink($str);
			}
		}
	}
	closedir($res);
}

//
// remove files
//
if(isset($HTTP_POST_VARS['remove']) && !defined('DEMO_MODE'))
{
	$remove = stripslashes($HTTP_POST_VARS['remove']);
	$params = array('remove' => $remove);
	if(!get_ftp_config(append_sid('xs_uninstall.'.$phpEx), $params, true))
	{
		xs_exit();
	}
	xs_ftp_connect(append_sid('xs_uninstall.'.$phpEx), $params, true);
	$write_local = false;
	if($ftp === XS_FTP_LOCAL)
	{
		$write_local = true;
		$write_local_dir = '../templates/';
	}
	if(!$write_local)
	{
		//
		// Generate actions list
		//
		$actions = array();
		// chdir to templates directory
		$actions[] = array(
				'command'	=> 'chdir',
				'dir'		=> 'templates'
			);
		// chdir to template
		$actions[] = array(
				'command'	=> 'chdir',
				'dir'		=> $remove
			);
		// remove all files
		$actions[] = array(
				'command'	=> 'removeall',
				'ignore'	=> true
			);
		$actions[] = array(
				'command'	=> 'cdup'
			);
		$actions[] = array(
				'command'	=> 'rmdir',
				'dir'		=> $remove
			);
		$ftp_log = array();
		$ftp_error = '';
		$res = ftp_myexec($actions);
/*		echo "<!--\n\n";
		echo "\$actions dump:\n\n";
		print_r($actions);
		echo "\n\n\$ftp_log dump:\n\n";
		print_r($ftp_log);
		echo "\n\n -->"; */
	}
	else
	{
		remove_all('../templates/'.$remove);
		@rmdir('../templates/'.$remove);
	}
	$template->assign_block_vars('removed', array());
}



//
// get list of installed styles
//
$sql = 'SELECT themes_id, template_name, style_name FROM ' . THEMES_TABLE . ' ORDER BY template_name, style_name';
if(!$result = $db->sql_query($sql))
{
	xs_error($lang['xs_no_style_info'], __LINE__, __FILE__);
}
$style_rowset = $db->sql_fetchrowset($result);

$tpl = array();
for($i=0; $i<count($style_rowset); $i++)
{
	$item = $style_rowset[$i];
	$tpl[$item['template_name']][] = $item;
}

$j = 0;
foreach($tpl as $tpl => $styles)
{
	$row_class = $xs_row_class[$j % 2];
	$j++;
	$template->assign_block_vars('styles', array(
			'ROW_CLASS'	=> $row_class,
			'TPL'		=> htmlspecialchars($tpl),
			'ROWS'		=> count($styles),
		)
	);
	if(count($styles) > 1)
	{
		for($i=0; $i<count($styles); $i++)
		{
			$template->assign_block_vars('styles.item', array(
					'ID'		=> $styles[$i]['themes_id'],
					'THEME'		=> htmlspecialchars($styles[$i]['style_name']),
					'U_DELETE'	=> append_sid('xs_uninstall.'.$phpEx.'?remove='.$styles[$i]['themes_id'].'&nocfg=1'),
				)
			);
			$template->assign_block_vars('styles.item.nodelete', array());
		}
	}
	else
	{
		$i = 0;
		$template->assign_block_vars('styles.item', array(
				'ID'		=> $styles[$i]['themes_id'],
				'THEME'		=> htmlspecialchars($styles[$i]['style_name']),
				'U_DELETE'	=> append_sid('xs_uninstall.'.$phpEx.'?remove='.$styles[$i]['themes_id']),
			)
		);
		$template->assign_block_vars('styles.item.delete', array(
				'U_DELETE'	=> append_sid('xs_uninstall.'.$phpEx.'?dir=1&remove='.$styles[$i]['themes_id']),
			)
		);
	}
}

$template->set_filenames(array('body' => XS_TPL_PATH . 'uninstall.tpl'));
$template->pparse('body');
xs_exit();

?>
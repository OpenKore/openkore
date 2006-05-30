<?php

/***************************************************************************
 *                            xs_style_config.php
 *                            -------------------
 *   copyright            : (C) 2003 - 2005 CyberAlien
 *   support              : http://www.phpbbstyles.com
 *
 *   version              : 2.1.0
 *
 *   file revision        : 59
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

$tpl = isset($HTTP_POST_VARS['tpl']) ? $HTTP_POST_VARS['tpl'] : (isset($HTTP_GET_VARS['tpl']) ? $HTTP_GET_VARS['tpl'] : '');
$filename = $phpbb_root_path . 'templates/' . $tpl . '/xs_config.cfg';

if(empty($tpl))
{
	xs_error($lang['xs_invalid_style_name']);
}
if(!@file_exists($filename))
{
	// remove from config
	$config_name = 'xs_style_' . $tpl;
	$sql = "DELETE FROM " . CONFIG_TABLE . " WHERE config_name='" . addslashes($config_name) . "'";
	$db->sql_query($sql);
	// recache config table for cat_hierarchy 2.1.0
	if(isset($GLOBALS['config']) && is_object($GLOBALS['config']))
	{
		global $config;
		$config->read(true);
	}
	$template->assign_block_vars('left_refresh', array(
			'ACTION'	=> append_sid('index.' . $phpEx . '?pane=left')
		));
	xs_error($lang['xs_invalid_style_name']);
}

// get configuration
$style_config = array();
include($filename);
$data = $template->get_config($tpl, false);
for($i=0; $i<count($style_config); $i++)
{
	if(!isset($data[$style_config[$i]['var']]))
	{
		$data[$style_config[$i]['var']] = $style_config[$i]['default'];
	}
}


// check submitted form
if(isset($HTTP_POST_VARS['tpl']) && !defined('DEMO_MODE'))
{
	for($i=0; $i<count($style_config); $i++)
	{
		$item = &$style_config[$i];
		$var = $style_config[$i]['var'];
		if($item['type'] === 'list')
		{
			$value = isset($HTTP_POST_VARS['cfg_' . $var]) && is_array($HTTP_POST_VARS['cfg_' . $var]) ? $HTTP_POST_VARS['cfg_' . $var] : array();
			$list = array();
			foreach($value as $var1 => $value1)
			{
				$list[] = $var1;
			}
			$value = implode(',', $list);
		}
		else
		{
			$value = isset($HTTP_POST_VARS['cfg_' . $var]) ? stripslashes($HTTP_POST_VARS['cfg_' . $var]) : 0;
		}
		$data[$var] = $value;
	}
	// update config
	$str = $template->_serialize($data);
	$config_name = 'xs_style_' . $tpl;
	if(isset($board_config[$config_name]))
	{
		$sql = "UPDATE " . CONFIG_TABLE . " SET config_value='" . addslashes($str) . "' WHERE config_name='" . addslashes($config_name) . "'";
	}
	else
	{
		$sql = "INSERT INTO " . CONFIG_TABLE . " (config_name, config_value) VALUES ('" . addslashes($config_name) . "', '" . addslashes($str) . "')";
	}
	$db->sql_query($sql);
	$board_config[$config_name] = $str;
	// recache config table for cat_hierarchy 2.1.0
	if(isset($config) && is_object($config))
	{
		$config->read(true);
	}
}


// show form
$last_cat = '';
for($i=0; $i<count($style_config); $i++)
{
	$item = &$style_config[$i];
	$var = $style_config[$i]['var'];
	$template->assign_block_vars('item', array(
		'VAR'		=> 'cfg_' . $var,
		'VALUE'		=> $data[$var],
		'DEF'		=> $item['default'],
		'TYPE'		=> $item['type'],
		'TEXT'		=> $item['text'],
		'EXPLAIN'	=> isset($item['explain']) ? $item['explain'] : '',
		));
	if($item['type'] === 'select')
	{
		foreach($item['selection'] as $var1 => $value1)
		{
			$template->assign_block_vars('item.select', array(
				'VALUE'		=> $var1,
				'TEXT'		=> $value1,
				'SELECTED'	=> $data[$var] === $var1 ? 1 : 0,
				));
		}
	}
	if($item['type'] === 'list')
	{
		$values = explode(',', $data[$var]);
		foreach($item['selection'] as $var => $value)
		{
			$selected = false;
			for($j=0; $j<count($values); $j++)
			{
				if($values[$j] === $var)
				{
					$selected = true;
				}
			}
			$template->assign_block_vars('item.list', array(
				'VALUE'		=> $var,
				'TEXT'		=> htmlspecialchars($value),
				'SELECTED'	=> $selected,
				));
			$num++;
		}
	}
	if(!empty($item['cat']) && $item['cat'] !== $last_cat)
	{
		$template->assign_block_vars('item.cat', array(
			'TEXT'	=> htmlspecialchars($item['cat'])
			));
		$last_cat = $item['cat'];
	}
}

$template->assign_vars(array(
	'TPL'		=> htmlspecialchars($tpl),
	'U_FORM'	=> 'xs_style_config.'.$phpEx.'?sid='.$userdata['session_id'],
	));

$template->assign_block_vars('nav_left',array('ITEM' => '&raquo; <a href="' . append_sid('xs_style_config.'.$phpEx.'?tpl='.urlencode($tpl)) . '">' . $lang['xs_style_configuration'] . ': ' . $tpl . '</a>'));

$template->set_filenames(array('body' => XS_TPL_PATH . 'style_config.tpl'));
$template->pparse('body');
xs_exit();

?>
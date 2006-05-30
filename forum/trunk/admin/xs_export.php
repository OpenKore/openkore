<?php

/***************************************************************************
 *                               xs_export.php
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

$template->assign_block_vars('nav_left',array('ITEM' => '&raquo; <a href="' . append_sid('xs_export.'.$phpEx) . '">' . $lang['xs_export_styles'] . '</a>'));

$lang['xs_export_back'] = str_replace('{URL}', append_sid('xs_export.'.$phpEx), $lang['xs_export_back']);

//
// Check required functions
//
if(!@function_exists('gzcompress'))
{
	xs_error($lang['xs_import_nogzip']);
}


//
// Export page
//
$export = isset($HTTP_GET_VARS['export']) ? $HTTP_GET_VARS['export'] : '';
$export = xs_tpl_name($export);
if(!empty($export) && @file_exists($phpbb_root_path . $template_dir . $export . '/theme_info.cfg'))
{
	// Get list of styles
	$sql = "SELECT themes_id, style_name FROM " . THEMES_TABLE . " WHERE template_name = '$export' ORDER BY style_name ASC";
	if(!$result = $db->sql_query($sql))
	{
		xs_error($lang['xs_no_theme_data'] . '<br /><br />' . $lang['xs_export_back']);
	}
	$theme_rowset = $db->sql_fetchrowset($result);
	if(count($theme_rowset) == 0)
	{
		xs_error($lang['xs_no_themes'] . '<br /><br />' . $lang['xs_export_back']);
	}
	$template->set_filenames(array('body' => XS_TPL_PATH . 'export2.tpl'));
	$xs_send_method = isset($board_config['xs_export_data']) ? $board_config['xs_export_data'] : '';
	$xs_send = @unserialize($xs_send_method);
	$xs_send_method = $xs_send['method'] == 'ftp' ? 'ftp' : ($xs_send['method'] == 'file' ? 'file' : 'save');
	$template->assign_vars(array(
			'FORM_ACTION'		=> append_sid('xs_export.'.$phpEx),
			'EXPORT_TEMPLATE'	=> htmlspecialchars($export),
			'STYLE_ID'			=> $theme_rowset[0]['themes_id'],
			'STYLE_NAME'		=> htmlspecialchars($theme_rowset[0]['style_name']),
			'TOTAL'				=> count($theme_rowset),
			'SEND_METHOD_'.strtoupper($xs_send_method)	=> ' checked="checked"',
			'SEND_DATA_DIR'		=> isset($xs_send['dir']) ? htmlspecialchars($xs_send['dir']) : '',
			'SEND_DATA_HOST'	=> isset($xs_send['host']) ? htmlspecialchars($xs_send['host']) : '',
			'SEND_DATA_LOGIN'	=> isset($xs_send['login']) ? htmlspecialchars($xs_send['login']) : '',
			'SEND_DATA_FTPDIR'	=> isset($xs_send['ftpdir']) ? htmlspecialchars($xs_send['ftpdir']) : '',
			'L_TITLE'			=> str_replace('{TPL}', $export, $lang['xs_export_style_title']),
			));
	if(count($theme_rowset) == 1)
	{
		$template->assign_block_vars('switch_select_nostyle', array());
	}
	else
	{
		$template->assign_block_vars('switch_select_style', array());
		for($i=0; $i<count($theme_rowset); $i++)
		{
			$template->assign_block_vars('switch_select_style.style', array(
				'NUM'		=> $i,
				'ID'		=> $theme_rowset[$i]['themes_id'],
				'NAME'		=> htmlspecialchars($theme_rowset[$i]['style_name'])
				));
		}
	}
	$template->pparse('body');
	xs_exit();
}

//
// Export style
//
$export = isset($HTTP_POST_VARS['export']) ? $HTTP_POST_VARS['export'] : '';
$export = xs_tpl_name($export);
if(!empty($export) && @file_exists($phpbb_root_path . $template_dir . $export . '/theme_info.cfg') && !defined('DEMO_MODE'))
{
	$total = intval($HTTP_POST_VARS['total']);
	$comment = substr(stripslashes($HTTP_POST_VARS['export_comment']), 0, 255);
	$list = array();
	for($i=0; $i<$total; $i++)
	{
		if(!empty($HTTP_POST_VARS['export_style_'.$i]))
		{
			$list[] = intval($HTTP_POST_VARS['export_style_id_'.$i]);
		}
	}
	if(!count($list))
	{
		xs_error($lang['xs_export_noselect_themes'] . '<br /><br /> ' . $lang['xs_export_back']);
	}
	// Export as...
	$exportas = empty($HTTP_POST_VARS['export_template']) ? $export : $HTTP_POST_VARS['export_template'];
	$exportas = xs_tpl_name($exportas);
	// Generate theme_info.cfg
	$sql = "SELECT * FROM " . THEMES_TABLE . " WHERE template_name = '$export' AND themes_id IN (" . implode(', ', $list) . ")";
	if(!$result = $db->sql_query($sql))
	{
		xs_error($lang['xs_no_theme_data'] . $lang['xs_export_back']);
	}
	$theme_rowset = $db->sql_fetchrowset($result);
	if(count($theme_rowset) == 0)
	{
		xs_error($lang['xs_no_themes']  . '<br /><br />' . $lang['xs_export_back']);
	}
	$theme_data = xs_generate_themeinfo($theme_rowset, $export, $exportas, $total);

	// prepare to pack	
	$pack_error = '';
	$pack_list = array();
	$pack_replace = array('./theme_info.cfg' => $theme_data);

	// pack style
	for($i=0; $i<count($theme_rowset); $i++)
	{
		$id = $theme_rowset[$i]['themes_id'];
		$theme_name = $theme_rowset[$i]['style_name'];
		for($j=0; $j<$total; $j++)
		{
			if(!empty($HTTP_POST_VARS['export_style_name_'.$j]) && $HTTP_POST_VARS['export_style_id_'.$j] == $id)
			{
				$theme_name = stripslashes($HTTP_POST_VARS['export_style_name_'.$j]);
			}
		}
		$theme_rowset[$i]['style_name'] = $theme_name;
	}
	$data = pack_style($export, $exportas, $theme_rowset, $comment);

	// check errors
	if($pack_error)
	{
		xs_error(str_replace('{TPL}', $export, $lang['xs_export_error']) . $pack_error  . '<br /><br />' . $lang['xs_export_back']);
	}
	if(!$data)
	{
		xs_error(str_replace('{TPL}', $export, $lang['xs_export_error2']) . '<br /><br />' . $lang['xs_export_back']);
	}

	//
	// Got file. Sending it.
	//
	$send_method = isset($HTTP_POST_VARS['export_to']) ? $HTTP_POST_VARS['export_to'] : '';
	$export_filename = empty($HTTP_POST_VARS['export_filename']) ? $exportas . STYLE_EXTENSION : $HTTP_POST_VARS['export_filename'];
	if($send_method === 'file')
	{
		// store on local server
		$send_dir = isset($HTTP_POST_VARS['export_to_dir']) ? $HTTP_POST_VARS['export_to_dir'] : '';
		$send_dir = str_replace('\\', '/', stripslashes($send_dir));
		if(empty($send_dir))
		{
			$send_dir = XS_TEMP_DIR;
		}
		if(substr($send_dir, strlen($send_dir) - 1) !== '/')
		{
			$send_dir .= '/';
		}
		$filename = $send_dir . $export_filename;
		$f = @fopen($filename, 'wb');
		if(!$f)
		{
			xs_error(str_replace('{FILE}', $filename, $lang['xs_error_cannot_create_file']) . '<br /><br />' . $lang['xs_export_back']);
		}
		@fwrite($f, $data);
		@fclose($f);
		set_export_method('file', array('dir' => $send_dir));
		xs_message($lang['Information'], str_replace('{FILE}', $filename, $lang['xs_export_saved']) . '<br /><br />' . $lang['xs_export_back']);
	}
	elseif($send_method === 'ftp')
	{
		// upload via ftp
		$ftp_host = $HTTP_POST_VARS['export_to_ftp_host'];
		$ftp_login = $HTTP_POST_VARS['export_to_ftp_login'];
		$ftp_pass = $HTTP_POST_VARS['export_to_ftp_pass'];
		$ftp_dir = str_replace('\\', '/', $HTTP_POST_VARS['export_to_ftp_dir']);
		if($ftp_dir && substr($ftp_dir, strlen($ftp_dir) - 1) !== '/')
		{
			$ftp_dir .= '/';
		}
		// save as temporary file
		$filename = XS_TEMP_DIR.'tmp_' . time() . '.tmp';
		$f = @fopen($filename, 'wb');
		if(!$f)
		{
			xs_error(str_replace('{FILE}', $filename, $lang['xs_error_cannot_create_tmp']) . '<br /><br />' . $lang['xs_export_back']);
		}
		@fwrite($f, $data);
		@fclose($f);
		// connect to ftp
		$ftp = @ftp_connect($ftp_host);
		if(!$ftp)
		{
			@unlink($filename);
			xs_error($lang['xs_ftp_error_noconnect'] . '<br /><br />' . $lang['xs_export_back']);
		}
		$res = @ftp_login($ftp, $ftp_login, $ftp_pass);
		if(!$res)
		{
			@unlink($filename);
			xs_error($lang['xs_ftp_error_login2'] . '<br /><br />' . $lang['xs_export_back']);
		}
		if($ftp_dir)
		{
			@ftp_chdir($ftp, $ftp_dir);
		}
		$res = @ftp_put($ftp, $ftp_dir . $export_filename, $filename, FTP_BINARY);
		@unlink($filename);
		if(!$res)
		{
			xs_error($lang['xs_export_error_uploading'] . '<br /><br />' . $lang['xs_export_back']);
		}
		set_export_method('ftp', array('host' => $ftp_host, 'login' => $ftp_login, 'ftpdir' => $ftp_dir));
		xs_message($lang['Information'], $lang['xs_export_uploaded'] . '<br /><br />' . $lang['xs_export_back']);
	}
	// send file
	xs_download_file($export_filename, $data, 'application/phpbbstyle');
	xs_exit();
}

$template->set_filenames(array('body' => XS_TPL_PATH . 'export.tpl'));

//
// get list of installed styles
//
$sql = 'SELECT themes_id, template_name, style_name FROM ' . THEMES_TABLE . ' ORDER BY template_name';
if(!$result = $db->sql_query($sql))
{
	xs_error($lang['xs_no_style_info'], __LINE__, __FILE__);
}
$style_rowset = $db->sql_fetchrowset($result);

$prev_id = -1;
$prev_tpl = '';
$style_names = array();
$j = 0;
for($i=0; $i<count($style_rowset); $i++)
{
	$item = $style_rowset[$i];
	if($item['template_name'] === $prev_tpl)
	{
		$style_names[] = htmlspecialchars($item['style_name']);
	}
	else
	{
		if($prev_id > 0)
		{
			$str = implode('<br />', $style_names);
			$str2 = urlencode($prev_tpl);
			$row_class = $xs_row_class[$j % 2];
			$j++;
			$template->assign_block_vars('styles', array(
					'ROW_CLASS'	=> $row_class,
					'TPL'		=> $prev_tpl,
					'STYLES'	=> $str,
					'U_EXPORT'	=> "xs_export.{$phpEx}?export={$str2}&sid={$userdata['session_id']}",
				)
			);
		}
		$prev_id = $item['themes_id'];
		$prev_tpl = $item['template_name'];
		$style_names = array(htmlspecialchars($item['style_name']));
	}
}

if($prev_id > 0)
{
	$str = implode('<br />', $style_names);
	$str2 = urlencode($prev_tpl);
	$row_class = $xs_row_class[$j % 2];
	$j++;
	$template->assign_block_vars('styles', array(
			'ROW_CLASS'	=> $row_class,
			'TPL'		=> $prev_tpl,
			'STYLES'	=> $str,
			'U_EXPORT'	=> "xs_export.{$phpEx}?export={$str2}&sid={$userdata['session_id']}",
		)
	);
}

$template->pparse('body');
xs_exit();

?>
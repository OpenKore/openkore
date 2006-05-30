<?php

/***************************************************************************
 *                           xs_include_import.php
 *                           ---------------------
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

if (!defined('IN_PHPBB') || !defined('IN_XS'))
{
	die("Hacking attempt");
}


function generate_actions_files($dir)
{
	global $items;
	// remove trailing /
	$pos = strrpos($dir, '/');
	$dir = $pos === strlen($dir) - 1 ? substr($dir, 0, $pos) : $dir;
	$arr = array('processing: '.$dir);
	for($i=0; $i<count($items); $i++)
	{
		if($items[$i]['dir'] === $dir)
		{
			$arr[] = array(
				'command'	=> 'upload',
				'local'		=> $items[$i]['tmp'],
				'remote'	=> $items[$i]['file']
				);
		}
	}
	return $arr;
}

function generate_actions_dirs($dir = '')
{
	global $dirs;
	$arr = array();
	if($dir && substr($dir, strlen($dir) - 1) !== '/')
	{
		$dir .= '/';
	}
	if($dir)
	{
		// remove trailing /
		$pos = strrpos($dir, '/');
		$str = $pos === strlen($dir) - 1 ? substr($dir, 0, $pos) : $dir;
		// get last directory name
		$pos = strrpos($str, '/');
		$str = $pos ? substr($str, $pos + 1) : $str;
		$arr[] = array(
			'command'	=> 'mkdir',
			'dir'		=> $str,
			'ignore'	=> true
			);
		$arr[] = array(
			'command'	=> 'chdir',
			'dir'		=> $str
			);
	}
	$arr[] = array(
		'command'	=> 'exec',
		'list'		=> generate_actions_files($dir)
		);
	// create subdirectories
	$len = strlen($dir);
	for($i=0; $i<count($dirs); $i++)
	{
		$str = $dirs[$i];
		if(substr($str, 0, $len) === $dir)
		{
			if($len)
			{
				$str = substr($str, $len + 1);
			}
			$pos = strpos($str, '/');
			if($pos == strlen($str) - 1)
			{
				$arr[] = array(
						'command'	=> 'exec',
						'list'		=> generate_actions_dirs($dirs[$i])
					);
			}
		}
	}
	return $arr;
}

function generate_style_name($str)
{
	$str = 'style_' . $str . '_%02d' . STYLE_EXTENSION;
	$num = 0;
	$found = true;
	while($found)
	{
		$filename = sprintf($str, $num);
		$found = @file_exists(XS_TEMP_DIR.$filename);
		$num ++;
	}
	return $filename;
}

?>
<?php

/***************************************************************************
 *                               xs_update.php
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

$template->assign_block_vars('nav_left',array('ITEM' => '&raquo; <a href="' . append_sid('xs_update.'.$phpEx) . '">' . $lang['xs_check_for_updates'] . '</a>'));

$updates = array();

function include_update($filename)
{
	$update = array();
	@include($filename);
	global $updates;
	$updates = array_merge($updates, $update);
}

if($dir = @opendir($phpbb_root_path. 'templates/'))
{
	while($sub_dir = @readdir($dir))
	if(($sub_dir !== '.') && ($sub_dir !== '..') && ($sub_dir !== 'CVS'))
	{
		$file = $phpbb_root_path . 'templates/' . $sub_dir . '/xs.cfg';
		if(@file_exists($file))
		{
			include_update($file);
		}
	}
	closedir($dir);
}

// check for xs files in acp. mask: xs_*.cfg
if($dir = @opendir('.'))
{
	while($file = @readdir($dir))
	if(strlen($file) > 6 && substr($file, 0, 3) === 'xs_' && substr($file, strlen($file) - 4) === '.cfg')
	{
		include_update($file);
	}
	closedir($dir);
}


// nothing to update
if(!count($updates))
{
	xs_error($lang['xs_update_nothing']);
}

// show list of available updates
if(!isset($HTTP_GET_VARS['doupdate']))
{
	$template->set_filenames(array('body' => XS_TPL_PATH . 'update.tpl'));
	$template->assign_vars(array(
		'UPDATE_URL'			=> append_sid('xs_update.'.$phpEx.'?doupdate=1'),
		'L_XS_UPDATE_TOTAL1'	=> str_replace('{NUM}', count($updates), $lang['xs_update_total1']),
		)
	);
	$counter = 0;
	@reset($updates);
	foreach($updates as $var => $item)
	{
		$counter ++;
		$type = isset($lang['xs_update_types'][$item['update_type']]) ? $item['update_type'] : 0;
		$row_class = $xs_row_class[$counter % 2];
		$template->assign_block_vars('row',
				array(
				'ROW_CLASS'	=> $row_class,
				'NUM'		=> $counter,
				'VAR'		=> 'item_'.$counter.'_',
				'ITEM'		=> htmlspecialchars($var),
				'NAME'		=> htmlspecialchars($item['update_name']),
				'TYPE'		=> $lang['xs_update_types'][$type],
				'URL'		=> htmlspecialchars($item['update_url']),
				'VERSION'	=> htmlspecialchars($item['update_version'])
				)
			);
		$template->assign_block_vars('row.'.(empty($item['update_url']) ? 'nourl' : 'url'), array());
	}
	$template->pparse('body');
	xs_exit();
}

// check updates.

// getting list of items to update
@reset($updates);
$urls = array();
$items = array();
$i=0;
foreach($updates as $var1 => $item)
{
	$i++;
	$var = 'item_'.$i.'_';
	if(!empty($HTTP_POST_VARS[$var.'item']) && !empty($HTTP_POST_VARS[$var.'checked']) && $HTTP_POST_VARS[$var.'checked'])
	{
		$item = $HTTP_POST_VARS[$var.'item'];
		if(!empty($updates[$item]['update_url']))
		{
			$items[] = $var1;
			$found = false;
			$url = $updates[$item]['update_url'];
			for($j=0; $j<count($urls) && !$found; $j++)
			{
				if($urls[$j] === $url)
				{
					$found = true;
				}
			}
			if(!$found)
			{
				$urls[] = $url;
			}
		}
	}
	if(isset($updates[$var1]['data']))
	{
		unset($updates[$var1]['data']);
	}
}

// showing error message if there is nothing to update
if(!count($urls))
{
	xs_error($lang['xs_update_nothing']);
}

@set_time_limit(intval($HTTP_POST_VARS['timeout']));

// getting data
for($i=0; $i<count($urls); $i++)
{
	$arr = @file($urls[$i]);
	if(empty($arr))
	{
		// cannot connect. show it as error message
		@reset($items);
		for($j=0; $j<count($items); $j++)
		{
			$item = $updates[$items[$j]];
			if($item['update_url'] === $urls[$i])
			{
				$updates[$items[$j]]['data']['error'] = $lang['xs_update_error_noconnect'];
			}
		}
	}
	else
	{
		for($j=0; $j<count($arr); $j++)
		{	// trim all lines and replace tab with space
			$arr[$j] = trim(str_replace("\t", ' ', $arr[$j]));
		}
		// checking all items to see which ones are for this url
		for($j=0; $j<count($items); $j++)
		{
			$item = $updates[$items[$j]];
			if($item['update_url'] === $urls[$i])
			{
				// searching for data for this item
				$begin_text = '<!-- BEGIN ' . $item['update_item'] . ' -->';
				$end_text = '<!-- END ' . $item['update_item'] . ' -->';
				$begin_pos = -1;
				$end_pos = -1;
				// getting begin and end tags for it
				for($k=0; ($k<count($arr)-1) && ($begin_pos < 0); $k++)
				{
					if($arr[$k] === $begin_text)
					{
						$begin_pos = $k;
						for(; ($k<count($arr)) && ($end_pos < 0); $k++)
						{
							if($arr[$k] === $end_text)
							{
								$end_pos = $k;
							}
						}
						if($end_pos < 0)
						{
							$end_pos = count($arr);
						}
					}
				}
				$data = array();
				// found item position in text
				if($begin_pos >= 0)
				{
					// getting all data for this item in array
					for($k=$begin_pos+1; $k<$end_pos; $k++)
					{
						$arr2 = explode(' ', $arr[$k], 2);
						if(count($arr2) == 2)
						{
							$data[trim($arr2[0])] = trim($arr2[1]);
						}
					}
				}
				else
				{
					$data['error'] = $lang['xs_update_error_noitem'];
				}
				$updates[$items[$j]]['data'] = $data;
			}
		}
	}
}

$template->set_filenames(array('body' => XS_TPL_PATH . 'update2.tpl'));

@reset($updates);
$count_total = 0;
$count_error = 0;
$count_update = 0;
foreach($updates as $var => $item)
{
	if(isset($item['data']) && is_array($item['data']))
	{
		$count_total++;
		$type = isset($lang['xs_update_types'][$item['update_type']]) ? $item['update_type'] : 0;
		$ver1 = htmlspecialchars($item['update_version']);
		$row_class = $xs_row_class[$count_total % 2];
		$template->assign_block_vars('row',
			array(
				'ROW_CLASS'		=> $row_class,
				'ITEM'			=> htmlspecialchars($item['update_name']),
				'TYPE'			=> $lang['xs_update_types'][$type],
				'VERSION'		=> $ver1,
			)
		);
		if(!empty($item['data']['version']))
		{
			$ver2 = htmlspecialchars($item['data']['version']);
			$info = isset($item['data']['info']) ? $item['data']['info'] : '';
			if($ver2 !== $ver1 && (!empty($item['data']['update']) || !empty($item['data']['autoupdate'])))
			{
				$count_update++;
				$u_import = (isset($item['data']['style']) && substr($item['data']['style'], 0, 7) === 'http://') ? append_sid('xs_import.'.$phpEx.'?get_web=' . urlencode($item['data']['style'])) : '';
				$template->assign_block_vars('row.update',
					array(
						'NUM'			=> $count_total,
						'VERSION'		=> $ver2,
						'UPDATE'		=> isset($item['data']['update']) ? htmlspecialchars($item['data']['update']) : '',
						'U_IMPORT'		=> $u_import,
						'INFO'			=> htmlspecialchars($info),
					)
				);
				$template->assign_block_vars('row.update.' . (empty($item['data']['update']) ? 'noupdate' : 'updated'), array());
				$template->assign_block_vars('row.update.' . (empty($item['data']['info']) ? 'noinfo' : 'info'), array());
				$template->assign_block_vars('row.update.' . (empty($u_import) ? 'noimport' : 'import'), array());
			}
			else
			{
				$template->assign_block_vars('row.noupdate', 
					array(
						'VERSION'		=> $ver2,
						'MESSAGE'		=> $lang['xs_update_noupdate'],
						'INFO'			=> empty($info) ? '' : htmlspecialchars($info),
					)
				);
				$template->assign_block_vars('row.noupdate.' . (empty($item['data']['info']) ? 'noinfo' : 'info'), array());
			}
		}
		else
		{
			if(empty($item['data']['error']))
			{
				$item['data']['error'] = $lang['xs_update_error_noitem'];
			}
			$template->assign_block_vars('row.error', array('ERROR' => htmlspecialchars($item['data']['error'])));
			$count_error++;
		}
	}
}

$template->assign_vars(
	array(
		'COUNT_TOTAL'		=> str_replace('{NUM}', $count_total, $lang['xs_update_total1']),
		'COUNT_ERROR'		=> str_replace('{NUM}', $count_error, $lang['xs_update_total2']),
		'COUNT_UPDATE'		=> str_replace('{NUM}', $count_update, $lang['xs_update_total3'])
	)
);

$template->pparse('body');
xs_exit();

?>
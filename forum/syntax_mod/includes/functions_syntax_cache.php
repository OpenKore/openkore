<?php
/***************************************************************************
 *                        functions_syntax_cache.php
 *                       ----------------------------
 *   begin                : Tuesday, Jun 7, 2005
 *   copyright            : (C) 2005 Nigel McNie
 *   email                : nigel@geshi.org
 *
 *   $Id: functions_syntax_cache.php,v 1.2 2005/08/22 22:46:08 oracleshinoda Exp $
 *
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

if (!defined('IN_PHPBB'))
{
	die('Hacking attempt');
}

/**
 * Trashes all files in syntax cache that are too old.
 */
function syntax_cache_maintenance ( $incoming_file_size )
{
    global $phpbb_root_path, $board_config;

    // We only want to do cache maintenance every now and then, because
    // for large caches this will be a costly operation
    if ( do_syntax_cache_maintenance() && $board_config['syntax_cache_files_expire'] != 0 )
    {
        $dh = @opendir($phpbb_root_path . 'cache/syntax') or message_die(GENERAL_ERROR, 'Syntax Highlighting cache maintenance could not be performed: make sure cache/syntax directory exists');
        $file = readdir($dh);

        while ( $file !== false )
        {
            // file names of cache files are an md5 (32 characters) + ".dat" (4 characters)
            if ( strlen($file) == 36 )
            {
                //
                // The function filectime gets the time a file was last *changed*, not
                // the time that it was created. However, because we're only ever reading
                // from cache files we can get away with this :)
                //
                $creation_time = filectime($phpbb_root_path . 'cache/syntax/' . $file);
                if ( ($creation_time + $board_config['syntax_cache_files_expire']) < time() )
                {
                    // Cache file too old - smash it
                    unlink($phpbb_root_path . 'cache/syntax/' . $file);
                }
            }

            $file = readdir($dh);
        }
    }


    $space_left = $board_config['syntax_cache_dir_size'] - get_dir_size($phpbb_root_path . 'cache/syntax/');
    //echo "space left: $space_left  ifs $incoming_file_size";
    if ( $space_left < $incoming_file_size && $board_config['syntax_cache_dir_size'] != 0 )
    {
        // Not enough space! Trash some files...
        // It's hard to pick a strategy for deleting files - lets just delete files
        // until there's enough space
        $dh = @opendir($phpbb_root_path . 'cache/syntax/') or message_die(GENERAL_ERROR, 'Syntax Highlighting cache maintenance could not be performed: make sure cache/syntax directory exists');
        $file = readdir($dh);

        while ( $file !== false )
        {//echo $file . '<br />';
            if ( is_dir($phpbb_root_path . 'cache/syntax/' . $file) || $file == 'index.htm' || $file == 'cache.txt' )
            {
                $file = readdir($dh);
                continue;
            }
            unlink($phpbb_root_path . 'cache/syntax/' . $file);
            //echo "unlinked $file<br />";
            $file = readdir($dh);
        }

        closedir($dh);
    }
}

function get_dir_size ( $dir )
{
    $dir = ( substr($dir, strlen($dir) - 1) != '/' ) ? $dir . '/' : $dir;
    $dh = @opendir($dir) or message_die(GENERAL_ERROR, 'get_dir_size: Syntax Highlighter cache directory size could not be determined: make sure directory cache/syntax exists');

    $file = readdir($dh);
    $size = 0;

    while ( $file !== false )
    {
        if ( is_dir($file) || $file == 'index.htm' || $file == 'cache.txt' )
        {
            $file = readdir($dh);
            continue;
        }
        $size += filesize($dir . $file);
        $file = readdir($dh);
    }

    closedir($dh);
    return $size;
}

/**
 * Checks to see whether we should update the cache
 */
function do_syntax_cache_maintenance ()
{
    global $phpbb_root_path, $board_config;

    $cache_time = (int) implode('', @file($phpbb_root_path . 'cache/syntax/cache.txt'));
    if ( ($cache_time + $board_config['syntax_cache_check_time']) < time() )
    {
        $fh = @fopen($phpbb_root_path . 'cache/syntax/cache.txt', 'w') or message_die(GENERAL_ERROR, 'Syntax Highlighter: could not open cache.txt: please make sure this file is CHMODed to 666');
        @flock($fh, LOCK_EX);
        @fputs($fh, time());
        @flock($fh, LOCK_UN);
        @fclose($fh);
        return true;
    }
    return false;
}

/**
 * Clear the cache
 */
function clear_cache ()
{
    global $phpbb_root_path;
    
    $dh = @opendir($phpbb_root_path . 'cache/syntax') or message_die(GENERAL_ERROR, 'clear_cache: Syntax Highlighter cache could not be cleared: make sure directory cache/syntax exists');

    $file = readdir($dh);

    while ( $file !== false )
    {
        if ( is_dir($file) || $file == 'index.htm' || $file == 'cache.txt' )
        {
            $file = readdir($dh);
            continue;
        }
        @unlink($phpbb_root_path . 'cache/syntax/' . $file);
        $file = readdir($dh);
    }

    closedir($dh);
}
    
?>
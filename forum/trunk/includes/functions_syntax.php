<?php
/***************************************************************************
 *                           functions_syntax.php
 *                          ----------------------
 *   begin                : Tuesday, Jun 7, 2005
 *   copyright            : (C) 2005 Nigel McNie
 *   email                : nigel@geshi.org
 *
 *   $Id: functions_syntax.php,v 1.1 2005/06/08 02:01:25 oracleshinoda Exp $
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

//
// Get language file config information
//
$syntax_config = array();
$sql = "SELECT * FROM " . SYNTAX_LANGUAGE_CONFIG_TABLE;
if ( !($result = $db->sql_query($sql)) )
{
    message_die(GENERAL_ERROR, 'Could not access Syntax Highlighter config information', 'Error', __LINE__, __FILE__, $sql);
}

while ( $row = $db->sql_fetchrow($result) )
{
    $syntax_config[] = $row;
}

/**
 * function: geshi_highlight
 * -------------------------
 * Takes the language to highlight and the sourcecode, and highlights it.
 * Also replaces some things like <br />'s because they're added later
 * by future phpBB code.
 */
function geshi_highlight( $source, $language, $uid )
{
    global $phpbb_root_path, $phpEx, $board_config, $syntax_config;

    include_once($phpbb_root_path . 'includes/geshi.' . $phpEx);

    //
    // Check to see if this language is an alias. Also catches attempts
    // to use the language file name as language name
    //
    $lang_name = '';
    foreach ( $syntax_config as $row )
    {
        if ( stripslashes($row['lang_identifier']) == $language )
        {
            $lang_name = substr(stripslashes($row['language_file_name']), 0, strpos(stripslashes($row['language_file_name']), '.'));
            break;
        }
    }
    $language = strtolower($lang_name);

    // Firstly, we're going to see if this code is cached.
    $cache_file = $phpbb_root_path . 'cache/syntax/' . md5($source . $language) . '.dat';
    if ( $board_config['syntax_enable_cache'] && is_readable($cache_file) )
    {
        // This source must have been cached. Good for us, this will speed things up.
        // We simply get the cached content and return it
        return implode('', file($cache_file));
    }
    else
    {
        // Oh dear, it can't be cached. Never mind, let's compile it and
        // cache it for next time

        $source = str_replace("\\\"", "\"", $source);

        if ( $board_config['syntax_status'] == 2 )
        {
            //
            // We want to look for important lines (signified by >>>line...<<<)
            //
            $array = array();
            $source_lines = explode("\n", str_replace("\r", '', $source));
            $i = 0;
            foreach ( $source_lines as $line )
            {
                $i++;
                if ( substr($line, 0, 12) == '&gt;&gt;&gt;' && substr($line, strlen($line) - 12, 12) == '&lt;&lt;&lt;' )
                {
                    $array[] = $i;
                    $source_lines[$i - 1] = substr($line, 12, strlen($line) - 24);
                }
            }
            $source = implode("\n", $source_lines);
            unset($source_lines);

            // Create the new GeSHi object, passing relevant stuff
            $geshi = &new GeSHi(undo_htmlspecialchars($source), $language, $phpbb_root_path . 'includes/geshi/');
            // Enclose the code in a <div>
            $geshi->set_header_type(GESHI_HEADER_DIV);
            // Turn CSS classes on to reduce output code size
            $geshi->enable_classes();
            // Turn on line numbers if required
            if ( $board_config['syntax_enable_line_numbers'] && !$geshi->error() && $source != '' )
            {
                $geshi->enable_line_numbers(GESHI_NORMAL_LINE_NUMBERS);
            }
            // Turn off URLs if not wanted
            if ( !$board_config['syntax_enable_urls'] )
            {
                for ( $i = 1; $i < 6; $i++ )
                {
                    $geshi->set_url_for_keyword_group($i, '');
                }
            }
            // Assign the important lines we set up earlier
            $geshi->highlight_lines_extra($array);
            // Make links to documentation open in a new window
            $geshi->set_link_target('_blank');
            // Disable important blocks
            $geshi->enable_important_blocks(false);

            // Parse the code
            $source = $geshi->parse_code();
            // Remove <br />'s added by GeSHi - they are added by phpBB later anyway
            $source = str_replace('<br />', '', $source);

            // Add "important" markers if there was an error highlighting
            if ( $geshi->error() )
            {
                $i = 0;
                $source_lines = explode("\n", str_replace("\r", '', $source));
                foreach ( $source_lines as $line )
                {
                    if ( in_array(++$i, $array) )
                    {
                        $line = '<div class="ln-xtra">' . $line . '</div>';
                    }
                    $source_lines[$i - 1] = $line;
                }
                $source = implode("\n", $source_lines);
                unset($source_lines);
            }

            // Remove wierd endline...
            if ( $board_config['syntax_enable_line_numbers'] && !$geshi->error() )
            {
                $source = str_replace("\n", '', $source);
                $source = str_replace('<li><div class="de1">&nbsp;</div></li></ol></div>', '</ol></div>', $source);
            }
            else
            {
                $source = str_replace('&nbsp;</div>', '</div>', $source);
                $source = str_replace("</div>\n", '</div>', $source);
                $source = str_replace('<div class="ln-xtra"></div>', '<div class="ln-xtra">&nbsp;</div>', $source);
            }

            // Remove uids from bbcode...
            $source = str_replace(':' . $uid, '', $source);

            // Make normal endlines
            $source = str_replace("\r", '', $source);
            $source = str_replace("\n", "\r\n", $source);

        }
        else
        {
            // Just perform normal indentation
            $source = str_replace('  ', '&nbsp; ', $source);
            $source = str_replace('  ', ' &nbsp;', $source);
            $source = str_replace("\t", '&nbsp; &nbsp;', $source);
            $source = preg_replace('/^ {1}/m', '&nbsp;', $source);
            // And highlight important lines
            $source = preg_replace("#&gt;&gt;&gt;(.*?)&lt;&lt;&lt;(\r\n)?#si", '<div class="ln-xtra">\\1</div>', $source);
            $source = str_replace('<div class="ln-xtra"></div>', '<div class="ln-xtra">&nbsp;</div>', $source);
        }

        if ( $board_config['syntax_enable_cache'] )
        {
            // Perform cache maintenance
            $source_len = strlen($source);
            syntax_cache_maintenance($source_len);

            if ( get_dir_size($phpbb_root_path . 'cache/syntax/') + $source_len <= $board_config['syntax_cache_dir_size'] || $board_config['syntax_cache_dir_size'] == 0 )
            {
                // Now to put it into cache
                $fh = @fopen($cache_file, 'w') or message_die(GENERAL_ERROR, 'Syntax Highlighter cache file could not be written: CHMOD the cache/syntax directory to 777');
                @flock($fh, LOCK_EX);
                @fputs($fh, $source);
                @flock($fh, LOCK_UN);
                @fclose($fh);
            }
        }

        return $source;
    }
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
        if ( is_dir($file) || $file == 'index.html' || $file == 'cache.txt' )
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

function get_lang_name ( $name )
{
    global $syntax_config;

    foreach ( $syntax_config as $row )
    {
        if ( stripslashes($row['lang_identifier']) == $name )
        {
            return $row['lang_display_name'];
        }
    }
    return $name;
}

?>
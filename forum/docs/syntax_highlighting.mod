##############################################################
## MOD Title: Syntax Highlighting
## MOD Author: 0racle < nigel@geshi.org > (Nigel McNie) http://qbnz.com/highlighter
## MOD Description: Adds [syntax="language"] bbcode to syntax-highlight many languages using GeSHi engine
##                  Better description would be useful. Note on installable by EM. Note on required
##                  BBCode mods.
## MOD Version: 0.4.0
##
## Installation Level: TODO(Easy/Intermediate/Advanced)
## Installation Time: TODOx Minutes
## Files To Edit: includes/bbcode.php,
##      includes/constants.php,
##      language/lang_english/lang_admin.php,
##      templates/subSilver/overall_header.tpl,
##      templates/subSilver/simple_header.tpl,
##      templates/subSilver/bbcode.tpl
## Included Files: (N/A, or list of included files)
##      admin/admin_syntax.php,
##      cache/syntax/index.htm,
##      cache/syntax/cache.txt,
##      includes/geshi.php,
##      includes/geshi/*.php,
##      includes/functions_syntax.php,
##		includes/functions_syntax_cache.php,
##      templates/subSilver/admin/admin_syntax_body.tpl,
##      templates/subSilver/geshi.css,
##      templates/subSilver/geshi-dark.css
## License: http://opensource.org/licenses/gpl-license.php GNU Public License v2
##############################################################
## For security purposes, please check: http://www.phpbb.com/mods/
## for the latest version of this MOD. Although MODs are checked
## before being allowed in the MODs Database there is no guarantee
## that there are no security problems within the MOD. No support
## will be given for MODs not found within the MODs Database which
## can be found at http://www.phpbb.com/mods/
##############################################################
## Author Notes:
##
##   -  This MOD REQUIRES that you have installed the Multi BBCodes MOD, as per phpBB BBCode
##      MOD requirements. You can get this MOD from [here].
##
##   -  I also STRONGLY RECOMMEND you install the BBCode Organizer MOD, available [here]
##
##   -  This MOD *has* been installed by easymod by me successfully. No guarantees for you,
##      this is alpha software. Please tell me about your experiences with easymod!
##
##   -  There is a script - install_syntax.php - that will automatically run the SQL needed
##      to get this MOD going in advanced mode. Run if a) easymod doesn't do the SQL for you,
##      b) you can't do the SQL any other way, and c) if you do run it, run it AFTER ALL
##      FILE MODIFICATIONS. It's mentioned in a DIY instruction below so you won't forget.
##
##   -  HOW TO USE AT YOUR FORUM
##      To highlight code in a certain language, you do this:
##      [syntax="language"]
##      // code...
##      [/syntax]
##      Where language is a language you have a language file for. The quotemarks are
##      optional. For example, this mod comes with language files for php and sql among
##      others, so you could go:
##      [syntax="php"]// a php comment[/syntax]
##      [syntax=sql]-- a sql comment[/syntax]
##
##   -  You can highlight certain lines "extra" if you want to prove a point - start a line
##      in a syntax block with >>> and end it with <<<, and that line will be highlighted
##      to stand out.
##
##   -  This mod comes in two "modes" - simple and advanced. In general, you want the advanced
##      mode. To enable advanced mode, all you have to do is run the SQL that this mod
##      specifies (in the final release there will be a file available that you only have to
##      point your browser at to run the SQL). But if you can't run SQL for some reason,
##      then you can still run this mod fine - just install everything except the SQL. To
##      configure in simple mode, open includes/bbcode.php and change values as needed. Note
##      that if you do change values, you'll need to clear the cache (which you can do in the
##      ACP, even in simple mode).
##
##   -  Language files are in includes/geshi/. To control which languages can be used
##      for highlighting, use the ACP (Syntax Highlighting, under General Admin). If you're
##      in simple mode, you can only control whether a language is highlighted or not,
##      whereas if you're in advanced mode you can control what string the users must use
##      to trigger the highlighting, and what is displayed when viewing syntax-highlighted
##      code.
##
##   -  Unfortunately nested syntax blocks *will* break down. This Is Not My Fault!
##      phpBB does NOT support marking lowest level block for regexp bbcode, so I can't
##      do anything about this. Simple solution: don't do this:
##      [syntax="language"]...[syntax="language2"]...[/syntax]...[/syntax]
##      As it is, destroying smilies and BBCode inside the syntax blocks is somewhat
##      of a hack at the moment...
##
##   -  The default stylesheet (geshi.css) supplied with this mod works well with
##      templates with *light* colours (subSilver, subOracle etc). However, if you're
##      using a dark template, you might want to use geshi-dark.css. Of course, you
##      can play around with the stylesheets to make your own colour scheme...
##      The dark stylesheet is awful, I know. If you fix it up, send it to me and I'll
##      include it with the full version.
##
##   -  Remember to CHMOD the cache/syntax directory to 777, and the cache/syntax/cache.txt
##      file to 666!!!
##
##   -  I suggest you do all your configuration as soon as you install the MOD - that way
##      you won't have to clear the cache when it already has lotsa stuff in it.
##
##   -  And finally, this is ALPHA software. No warranty etc. etc. Please report bugs you
##      find by posting in the phpBB dev thread for this MOD, by email to me or by the sf.net
##      bugtracker for this MOD.
##
##############################################################
## MOD History:
##
##   2004-08-13 - Version 0.1.0
##      - Initial Release
##
##   2004-10-28 - Version 0.2.0
##      - GeSHi upgraded to 1.0.2
##       * Support for nearly 30 languages
##      - geshi-dark.css stylesheet added for dark forums
##      - Cache directory used to speed page rendering
##
##   2004-11-13 - Version 0.3.0
##      - Custom GeSHi 1.0.2 used
##      - Configuration can be done via the ACP
##       * Control of the cache directory
##       * Which languages are supported
##       * What is displayed for various languages
##       * Whether to use line numbering/function to URL conversion
##      - Better handling of bbcode inside [syntax] blocks
##      - Support for >>> ... <<< to extra-highlight a line
##      - Automatic cache control - the cache can be kept to a certain size or have items
##        older than a certain date removed automatically
##      - Support for a "simple mode" which can be used if the user can't run SQL
##
##   2005-08-15 - Version 0.4.0
##      - GeSHi upgraded to 1.0.7.1
##       * Added languages are c_mac, csharp, diff, div, d, eiffel, gml, matlab,
##         mpasm, objc, oracle8, vbnet and vhdl, making a total of 43
##      - Install SQL file added
##       * Can be run after all file alterations to run the SQL needed to install this MOD
##         in advanced mode
##
##############################################################
## Before Adding This MOD To Your Forum, You Should Back Up All Files Related To This MOD
##############################################################

#
#-----[ SQL ]------------------------------------------
#
# [TODO] Don't forget: You *should* do this SQL, but if you can't then
# you can still run this MOD in simple mode, or use the install_syntax.php
# script. See the notes above
#

INSERT INTO phpbb_config (config_name, config_value) VALUES ('syntax_status', '2');
INSERT INTO phpbb_config (config_name, config_value) VALUES ('syntax_enable_cache', '1');
INSERT INTO phpbb_config (config_name, config_value) VALUES ('syntax_cache_check_time', '5000');
INSERT INTO phpbb_config (config_name, config_value) VALUES ('syntax_cache_dir_size', '20971520');
INSERT INTO phpbb_config (config_name, config_value) VALUES ('syntax_cache_files_expire', '2592000');
INSERT INTO phpbb_config (config_name, config_value) VALUES ('syntax_enable_line_numbers', '0');
INSERT INTO phpbb_config (config_name, config_value) VALUES ('syntax_enable_urls', '1');
INSERT INTO phpbb_config (config_name, config_value) VALUES ('syntax_version', '0.4.0');

CREATE TABLE phpbb_syntax_language_config (language_file_name VARCHAR(30), lang_identifier VARCHAR(15), lang_display_name VARCHAR(25));

INSERT INTO phpbb_syntax_language_config VALUES ('actionscript.php', 'actionscript', 'actionscript');
INSERT INTO phpbb_syntax_language_config VALUES ('ada.php', 'ada', 'ada');
INSERT INTO phpbb_syntax_language_config VALUES ('apache.php', 'apache', 'apache');
INSERT INTO phpbb_syntax_language_config VALUES ('asm.php', 'asm', 'asm');
INSERT INTO phpbb_syntax_language_config VALUES ('asp.php', 'asp', 'asp');
INSERT INTO phpbb_syntax_language_config VALUES ('bash.php', 'bash', 'bash');
INSERT INTO phpbb_syntax_language_config VALUES ('caddcl.php', 'caddcl', 'CAD DCL');
INSERT INTO phpbb_syntax_language_config VALUES ('cadlisp.php', 'cadlisp', 'CAD Lisp');
INSERT INTO phpbb_syntax_language_config VALUES ('c_mac.php', 'c_mac', 'C (Mac)');
INSERT INTO phpbb_syntax_language_config VALUES ('c.php', 'c', 'c');
INSERT INTO phpbb_syntax_language_config VALUES ('cpp.php', 'c++', 'c++');
INSERT INTO phpbb_syntax_language_config VALUES ('csharp.php', 'c#', 'C#');
INSERT INTO phpbb_syntax_language_config VALUES ('css.php', 'css', 'css');
INSERT INTO phpbb_syntax_language_config VALUES ('delphi.php', 'delphi', 'delphi');
INSERT INTO phpbb_syntax_language_config VALUES ('diff.php', 'diff', 'Diff Output');
INSERT INTO phpbb_syntax_language_config VALUES ('div.php', 'div', 'DIV');
INSERT INTO phpbb_syntax_language_config VALUES ('d.php', 'd', 'd');
INSERT INTO phpbb_syntax_language_config VALUES ('eiffel.php', 'eiffel', 'Eiffel');
INSERT INTO phpbb_syntax_language_config VALUES ('gml.php', 'gml', 'GML');
INSERT INTO phpbb_syntax_language_config VALUES ('html4strict.php', 'html', 'HTML');
INSERT INTO phpbb_syntax_language_config VALUES ('java.php', 'java', 'Java');
INSERT INTO phpbb_syntax_language_config VALUES ('javascript.php', 'javascript', 'Javascript');
INSERT INTO phpbb_syntax_language_config VALUES ('lisp.php', 'lisp', 'Lisp');
INSERT INTO phpbb_syntax_language_config VALUES ('lua.php', 'lua', 'Lua');
INSERT INTO phpbb_syntax_language_config VALUES ('matlab.php', 'matlab', 'Matlab');
INSERT INTO phpbb_syntax_language_config VALUES ('mpasm.php', 'mpasm', 'Microprocessor ASM');
INSERT INTO phpbb_syntax_language_config VALUES ('nsis.php', 'nsis', 'NullSoft Installer Script');
INSERT INTO phpbb_syntax_language_config VALUES ('objc.php', 'objc', 'Objective C');
INSERT INTO phpbb_syntax_language_config VALUES ('oobas.php', 'oobas', 'Openoffice.org BASIC');
INSERT INTO phpbb_syntax_language_config VALUES ('oracle8.php', 'oracle8', 'Oracle 8');
INSERT INTO phpbb_syntax_language_config VALUES ('pascal.php', 'pascal', 'Pascal');
INSERT INTO phpbb_syntax_language_config VALUES ('perl.php', 'perl', 'Perl');
INSERT INTO phpbb_syntax_language_config VALUES ('php-brief.php', 'php-brief', 'php (brief)');
INSERT INTO phpbb_syntax_language_config VALUES ('php.php', 'php', 'php');
INSERT INTO phpbb_syntax_language_config VALUES ('python.php', 'python', 'Python');
INSERT INTO phpbb_syntax_language_config VALUES ('qbasic.php', 'qbasic', 'QBasic');
INSERT INTO phpbb_syntax_language_config VALUES ('smarty.php', 'smarty', 'Smarty');
INSERT INTO phpbb_syntax_language_config VALUES ('sql.php', 'sql', 'SQL');
INSERT INTO phpbb_syntax_language_config VALUES ('vbnet.php', 'vbnet', 'VB.NET');
INSERT INTO phpbb_syntax_language_config VALUES ('vb.php', 'vb', 'VisualBASIC');
INSERT INTO phpbb_syntax_language_config VALUES ('vhdl.php', 'vhdl', 'VHDL');
INSERT INTO phpbb_syntax_language_config VALUES ('visualfoxpro.php', 'vfp', 'Visual FoxPro');
INSERT INTO phpbb_syntax_language_config VALUES ('xml.php', 'xml', 'XML');

#
#-----[ COPY ]------------------------------------------
#
# [TODO] WARNING: Make sure you CHMOD the cache/syntax directory to 777! This directory
# *must* be writable for the cache files to be written, else you'll get a bunch of
# nasty errors. And make sure you CHOMD the cache.txt file to 666.
# And if you're installing this mod for a dark theme, you might want geshi-dark.css
# instead of geshi.css
#

copy contrib/admin/admin_syntax.php to admin/
copy contrib/cache/syntax/*.* to cache/syntax/
copy contrib/includes/geshi.php to includes/
copy contrib/includes/geshi/*.* to includes/geshi/
copy contrib/includes/functions_syntax.php to includes/
copy contrib/includes/functions_syntax_cache.php to includes/
copy contrib/templates/subSilver/admin/admin_syntax_body.tpl to templates/subSilver/admin/
copy contrib/templates/subSilver/geshi.css to templates/subSilver/
copy contrib/templates/subSilver/geshi-dark.css to templates/subSilver/
copy contrib/install_syntax.php to install_syntax.php

#
#-----[ OPEN ]--------------------------------------------
#
includes/bbcode.php

#
#-----[ FIND ]--------------------------------------------
#
define("BBCODE_UID_LEN", 10);

#
#-----[ AFTER, ADD ]--------------------------------------
#

//
// Begin Syntax Highlighting Mod
//
if ( !isset($board_config['syntax_status']) )
{
	/** TODO: Put this config information into a separate file */
    /*
     * There's no config information from the DB: Better set it
     * 
     * If you're using simple mode, here is where you set the configuration
     * information. If you edit these options after your board has been
     * using syntax highlighting for a while, and you are using the cache
     * (and thus your cache will have some files in it), you need to clear
     * the cache. You can clear the cache by visiting the administration panel.
     *  
     */

    /*
     * Syntax highlighting status
     * --------------------------
     * The allowed values for this option are:
     * 
     *   * SYNTAX_NO_PARSE: [syntax] blocks will not be parsed, and will
     *                      display as normal text @todo Better message here
     *   * SYNTAX_PARSE_AS_CODE: @todo Better comment
     *   * SYNTAX_PARSE_ON: @todo Better comment
     * 
     * Don't forget to clear the cache if you change this value!
     */
    $board_config['syntax_status'] = SYNTAX_PARSE_ON;
    
    /*
     * Cache Usage
     * -----------
     * Whether to enable the cache directory or not (recommended). The
     * directory used can be set below, but the default is generally fine.
     * 
     * Allowed values for this option are true (enable) or false (disable)
     * 
     * *** Make sure you CHMOD the cache directory to 777! ***
     */
    $board_config['syntax_enable_cache'] = true;
    
    /*
     * Cache Directory
     * ---------------
     * What directory should be used for the cache directory. The default is
     * normally just fine, and is where the mod will set the cache directory
     * to be.
     * 
     * If you change this value in here, you will have to remove the old cache
     * directory by hand.
     * 
     * And if you do change this from the default, make sure you put all of
     * the files that were in included in this MOD that were meant for the
     * cache directory indo that directory, else it won't function properly!
     * 
     * The files that should go in this directory are:
     *   @todo put file list here
     * 
     * And lastly:
     *       *** Make sure you CHMOD this directory to 777! ***
     */
    $board_config['syntax_cache_dir'] = $phpbb_root_path . 'cache/syntax/';
    
    /*
     * Cache Directory Maintenance Time
     * --------------------------------
     * How often to check the cache dir (in seconds) - best to leave this
     * quite large.
     * 
     * When the cache directory is checked, it removes files that are older
     * than the expiry time (you can set this below), and if the directory
     * is larger than the maximum size (you can also set this below), it
     * removes files from it to bring it down to size.
     * 
     * You don't have to refresh the cache if you change this value.
     */
    $board_config['syntax_cache_check_time'] = 5000;
    
    /*
     * Cache Directory Max Size
     * ------------------------
     * The maximum size that the cache directory is allowed to be before files
     * are deleted from it. This is measured in bytes.
     * 
     * It's best to leave this reasonably large, otherwise your forum members
     * will complain about slow response times as the same code is highlighted
     * again and again...
     * 
     * The default is 20 megs, but in reality I have little idea on how big it
     * should be for a big board.
     * 
     * You can set this to 0 also - this means unlimited. If you want to disable
     * the cache, use the "Cache Usage" option above instead.
     */
    $board_config['syntax_cache_dir_size'] = 20 * 1024 * 1024;
    
    /*
     * Cache Directory Max File Age
     * ----------------------------
     * The maximum age that files in the cache can be before they expire and are
     * removed. This is measured in seconds.
     * 
     * In combination with the Max Cache Size of the cache directory, this is a
     * good way to ensure the cache never gets too large while keeping your forum
     * resonsive.
     * 
     * The default is 30 days, set this to 0 to turn age checking off.
     */
    $board_config['syntax_cache_files_expire'] = 60 * 60 * 24 * 30;
    
    /*
     * Line Numbers
     * ------------
     * Whether to enable line numbers for [syntax] blocks.
     *
     * Allowed values for this are true (enabled) or false (disabled).
     * 
     * The default is to enable line numbers. 
     * @todo (only works if mod is fully enabled) WHY?
     * @todo Does it give line numbers to stuff parsed as code blocks?
     */
    $board_config['syntax_enable_line_numbers'] = false;
    
    /*
     * Function to URL Conversion
     * --------------------------
     * Whether to enable function to URL conversion for [syntax] blocks.
     * 
     * Allowed values for this are true (enabled) or false (disabled).
     * 
     * The default is to enable function to URL conversion.
     * @todo (only works if mod is fully enabled) WHY?
     */
    $board_config['syntax_enable_urls'] = true;
}

// Get syntax mod functions and information
include($phpbb_root_path . 'includes/functions_syntax.php');

//
// End Syntax Highlighting Mod
//

#
#-----[ FIND ]--------------------------------------------
#
	$bbcode_tpl['code_open'] = str_replace('{L_CODE}', $lang['Code'], $bbcode_tpl['code_open']);

#
#-----[ AFTER, ADD ]--------------------------------------
#

	//
	// Begin Syntax Highlighting mod
	//
	$bbcode_tpl['syntax_open'] = str_replace('{L_LANGUAGE}', '\' . get_lang_name(\'\\1\') . \'', $bbcode_tpl['syntax_open']);
	//
	// End Syntax Highlighting mod
	//

#
#-----[ FIND ]--------------------------------------------
#
function bbencode_second_pass($text, $uid)
{
	global $lang, $bbcode_tpl;

#
#-----[ AFTER, ADD ]--------------------------------------
#

	//
	// Begin Syntax Highlighting Mod
	//
	global $board_config;
	//
	// End Syntax Highlighting Mod
	//

#
#-----[ FIND ]--------------------------------------------
#
	// [CODE] and [/CODE] for posting code (HTML, PHP, C etc etc) in your posts.
	$text = bbencode_second_pass_code($text, $uid, $bbcode_tpl);

#
#-----[ AFTER, ADD ]--------------------------------------
#

    //
    // Begin Syntax Highlighting Mod
    //
    // [SYNTAX="language"] and [/SYNTAX] for posting syntax highlighted code
    // @todo Take into account user preferences
    // @todo Maybe use U modifier to prevent nesting problems?
    // @todo Maybe problem with geshi_highlight function name?
    // @todo Take into account the parse as code possibility?
    if ( $board_config['syntax_status'] != SYNTAX_NO_PARSE )
    {
        $text = preg_replace("/\[syntax:$uid=\"?([a-zA-Z0-9\-_\+\#\$\%]+)\"?\](.*?)\[\/syntax:$uid\]/sie", "'{$bbcode_tpl['syntax_open']}' . geshi_highlight('\\2', '\\1', '$uid') . '{$bbcode_tpl['syntax_close']}'", $text);
    }
    else
    {
        $text = preg_replace("/\[syntax:$uid=(\"?[a-zA-Z0-9\-_\+\#\$\%]+\"?)\](.*?)\[\/syntax:$uid\]/si", "[syntax=\\1]\\2[/syntax]", $text);
    }
    //
    // End Syntax Highlighting Mod
    //

#
#-----[ FIND ]--------------------------------------------
#
	// [CODE] and [/CODE] for posting code (HTML, PHP, C etc etc) in your posts.
	$text = bbencode_first_pass_pda($text, $uid, '[code]', '[/code]', '', true, '');

#
#-----[ AFTER, ADD ]--------------------------------------
#

    //
    // Begin Syntax Highlighting Mod
    //
    // [SYNTAX="language"] and [/SYNTAX] for posting syntax highlighted code
    $text = bbencode_first_pass_pda($text, $uid, '#\[syntax=(\\\"[a-zA-Z0-9\-_]+\\\")\]#is', '[/syntax]', '', false, '', "[syntax:$uid=\\1]");
    //
    // End Syntax Highlighting Mod
    //

#
#-----[ OPEN ]--------------------------------------------
#
includes/constants.php

#
#-----[ FIND ]--------------------------------------------
#
define('SMILIES_TABLE', $table_prefix.'smilies');

#
#-----[ AFTER, ADD ]--------------------------------------
#

// Begin Syntax Highlighter Mod
define('SYNTAX_LANGUAGE_CONFIG_TABLE', $table_prefix.'syntax_language_config');
// End Syntax Highlighter Mod

#
#-----[ FIND ]--------------------------------------------
#
define('VOTE_USERS_TABLE', $table_prefix.'vote_voters');

#
#-----[ AFTER, ADD ]--------------------------------------
#

//
// Begin Syntax Highlighting Mod
//
define('SYNTAX_HIGHLIGHTER_VERSION', '0.4.0');

define('SYNTAX_NO_PARSE', 0);
define('SYNTAX_PARSE_AS_CODE', 1);
define('SYNTAX_PARSE_ON', 2);
//
// End Syntax Highlighting Mod
//

#
#-----[ OPEN ]--------------------------------------------
#
language/lang_english/lang_admin.php

#
#-----[ FIND ]--------------------------------------------
#

//
// That's all Folks!
// -------------------------------------------------

#
#-----[ BEFORE, ADD ]--------------------------------------
#

//
// Begin Syntax Highlighting Mod
//
$lang['Syntax_Highlighting'] = 'Syntax Highlighting';
$lang['syntax_explain'] = 'Here you can control the syntax highlighting of posts, using the [syntax] BBCode. Syntax Highlighting is powered by <a href="http://qbnz.com/highlighter">GeSHi</a>, for which the documentation is <a href="http://qbnz.com/highlighter/documentation.php">here</a> if you\'d like to extend this mod yourself.';
$lang['Syntax_highlighting_advanced_mode'] = 'Syntax Highlighting is in <span style="color: green;">advanced</span> mode. This means that you will have full access to all of the abilities of this mod.';
$lang['Syntax_highlighting_simple_mode'] = 'Syntax Highlighting is in <span style="color: #FF6600;">simple</span> mode. To go to advanced mode, you need to run the script <code>install_syntax.php</code> included with the Syntax Highlighter mod, or the SQL specified in the MOD file.';
$lang['Syntax_main_control'] = 'Main Control';
$lang['Syntax_main_control_explain'] = '<p>Here you can control highlighting on a very basic level. You can choose from one of three options:</p>

<ul class="gen">
    <li><p><strong>Enable Syntax Highlighting</strong>: If you choose this mode, syntax highlighting on your board will be enabled. Users will be able to turn syntax highlighting off for themselves if they wish.</p></li>
    <li><p><strong>Disable Syntax Highlighting, but parse [syntax] blocks as [code]</strong>: Choosing this mode will mean that [syntax] bbcode will be interpreted as if it was a [code] block. Users will not be able to enable syntax highlighting for themselves if you choose this mode.</p></li>
    <li><p><strong>Disable Syntax Highlighting</strong>: The [syntax] bbcode will be disabled, the BBCode help dropdown for [syntax] will disappear and no mention of this MOD will be made in the FAQ. Effectively hides the fact this MOD is installed. Users will not be able to enable syntax highlighting for themselves.</p></li>
</ul>';
$lang['Syntax_cache_control'] = 'Cache Control';
$lang['Syntax_enabled'] = 'Enable syntax highlighting';
$lang['Syntax_partial'] = 'Disable syntax highlighting, but parse [syntax] blocks as [code]';
$lang['Syntax_disabled'] = 'Disable syntax highlighting';
$lang['Syntax_update_status'] = 'Update Status';
$lang['Syntax_main_control_disabled'] = 'Since you are running in simple mode, you cannot change the status of the syntax highlighter from the admin panel. If you wish to enable/disable the syntax highlighter, go into <code>includes/bbcode.php</code>, and edit the relevant fields. In addition, if you are using a cache directory, you should clear the cache (see the cache control below).';
$lang['Syntax_cache_control_disabled'] = 'Since you are running in simple mode, you cannot change whether the cache is to be used or not. If you wish to enable/disable the cache, go into <code>includes/bbcode.php</code>, and edit the relevant fields. In addition, you should clear the cache after any change to this option (see below).';
$lang['Syntax_enable_cache'] = 'Enable cache';
$lang['Syntax_update_cache_enabled'] = 'Update Cache Status';
$lang['Syntax_clear_the_cache'] = 'Clear the Cache';
$lang['Syntax_clear_cache_yes_no'] = 'Clear cache?';
$lang['Syntax_clear_cache'] = 'Clear Cache';
$lang['Syntax_cache_options'] = 'Cache Options';
$lang['Syntax_bytes'] = 'Bytes';
$lang['Syntax_kilobytes'] = 'Kilobytes';
$lang['Syntax_megabytes'] = 'Megabytes';
$lang['Syntax_gigabytes'] = 'Gigabytes';
$lang['Syntax_cache_dir_size'] = 'Maximum size of the cache directory allowed (0 for unlimited, otherwise at least 1K). It is recommended that you leave this at unlimited or a large number, and use time-purging (below) to control cache size.';
$lang['Syntax_set_cache_options'] = 'Set Cache Options';
$lang['Syntax_cache_options_disabled'] = 'Since you are running in simple mode, you cannot change cache options. By default, the cache is 20 megs maximum size, and items older than 30 days will expire. If you wish to change cache options, go into <code>includes/bbcode.php</code>, and edit the relevant fields. In addition, you should clear the cache after any changes to this option (see above).';
$lang['Syntax_seconds'] = 'Seconds';
$lang['Syntax_minutes'] = 'Minutes';
$lang['Syntax_hours'] = 'Hours';
$lang['Syntax_days'] = 'Days';
$lang['Syntax_months'] = 'Months';
$lang['Syntax_years'] = 'Years';
$lang['Syntax_cache_expiry_time'] = 'How long before a syntax file becomes invalid and purged from the cache (0 for unlimited, though this is not recommended).';
$lang['Syntax_line_numbers_enabled'] = 'Whether line numbering is enabled or not (will trigger a purge of the cache if changed)';
$lang['Syntax_function_urls_enabled'] = 'Whether functions are turned into URLs to appropriate documentation (will trigger a purge of the cache if changed, and only applies to some languages that have documentation available).';
$lang['Syntax_general_options'] = 'General Options';
$lang['Syntax_change_general_options'] = 'Change General Options';
$lang['Syntax_language_control'] = 'Language Control';
$lang['Syntax_advanced_language_control_explain'] = 'Use this form to control what languages will be highlighted, what name they are referred to in the [syntax="..."] BBCode, and what name is displayed for them. Changing these options will clear the cache.';
$lang['Syntax_simple_language_control_explain'] = 'Use this form to control what languages will be highlighted. Changing these options will clear the cache';
$lang['Syntax_language_name'] = 'Language Name';
$lang['Syntax_language_name_explain'] = 'This is the name of the GeSHi language file';
$lang['Syntax_language_enabled'] = 'Language Enabled?';
$lang['Syntax_language_enabled_explain'] = 'Check the box to enable the language';
$lang['Syntax_language_code'] = 'Language Code';
$lang['Syntax_language_code_explain'] = 'What needs to be put in [syntax=&quot;...&quot;] to highlight with this language';
$lang['Syntax_language_display_name'] = 'Language Display Name';
$lang['Syntax_language_display_name_explain'] = 'The name the language is displayed as on your forum';
$lang['Syntax_update_language_options'] = 'Update Language Options';
$lang['Syntax_reset_language_form'] = 'Reset Language Form';

$lang['Syntax_click_return_syntaxadmin'] = 'Click %shere%s to return to Syntax Highlighter administration';

$lang['Syntax_cache_cleared_successfully'] = 'Syntax Highlighter cache cleared successfully';
$lang['Syntax_cache_not_cleared'] = 'Syntax Highlighter cache not cleared';
$lang['Syntax_status_updated_successfully'] = 'Syntax Highlighter status updated successfully. As a result, the cache has been cleared.';
$lang['Syntax_status_not_updated'] = 'Syntax Highlighter status not updated, as it was not changed.';

$lang['Syntax_installer_new_install'] = 'Welcome to the Syntax Highlighting MOD SQL installer. This script can be used to automatically run the SQL required to install this MOD.<br /><br />Please be aware that this MOD is <strong>ALPHA software</strong>. You are advised to back up your database before installing this MOD!';
$lang['Syntax_installer_install_mod'] = 'Install MOD';
$lang['Syntax_installer_install_files_first'] = 'You should perform the file modifications and additions for this MOD before you run the DB install SQL.';
$lang['Syntax_installer_sql_failed'] = 'Oops!. For some reason, one of the SQL queries for this MOD failed. The query that failed is below.<br /><br />As this software is alpha, no error-correction is taking place. If you need to run the SQL, either fix the problem or look inside the .mod file for the remaining SQL commands that need to be run and run them some other way.';
$lang['Syntax_installer_mod_installed'] = 'Congratulations! The SQL for this MOD has successfully installed.<br /><br />Please now delete this script, and make sure you have CHMODed the cache/syntax directory to 777 (and the cache/syntax/cache.txt file to 666).';
$lang['Syntax_installer_previous_install'] = 'If you\'re viewing this message, this MOD has been installed OK. Delete this file!';
//
// End Syntax Highlighting Mod
//

#
#-----[ OPEN ]--------------------------------------------
#
templates/subSilver/overall_header.tpl

#
#-----[ FIND ]--------------------------------------------
# Depending on how you've optimised your forum, this may
# or may not have been changed.
<!-- link rel="stylesheet" href="templates/subSilver/{T_HEAD_STYLESHEET}" type="text/css" -->

#
#-----[ AFTER, ADD ]--------------------------------------
# NOTE: geshi.css is a good stylesheet for forums
# with light backgrounds, while geshi-dark.css is good
# for forums with dark backgrounds. Use and modify which
# ever one suits you.

<!-- Begin Syntax Highlighting Mod -->
<link rel="stylesheet" href="templates/subSilver/geshi.css" type="text/css">
<!-- End Syntax Highlighting Mod -->

#
#-----[ OPEN ]--------------------------------------------
#
templates/subSilver/simple_header.tpl

#
#-----[ FIND ]--------------------------------------------
# Depending on how you've optimised your forum, this may
# or may not have been changed.

<!-- link rel="stylesheet" href="templates/subSilver/{T_HEAD_STYLESHEET}" type="text/css" -->

#
#-----[ AFTER, ADD ]--------------------------------------
# The same note applies as above
<!-- Begin Syntax Highlighting Mod -->
<link rel="stylesheet" href="templates/subSilver/geshi.css" type="text/css">
<!-- End Syntax Highlighting Mod -->


#
#-----[ OPEN ]--------------------------------------------
#
templates/subSilver/bbcode.tpl

#
#-----[ FIND ]--------------------------------------------
#

<span class="postbody"><!-- END code_close -->

#
#-----[ AFTER, ADD ]--------------------------------------
#

<!-- BEGIN syntax_open --></span>
<table width="90%" cellspacing="1" cellpadding="3" border="0" align="center">
<tr>
	  <td><span class="genmed"><b><span style="color: #933;">{L_LANGUAGE}:</font></b></span></td>
	</tr>
	<tr>
	  <td class="syntax-code"><!-- END syntax_open -->
<!-- BEGIN syntax_close --></td>
	</tr>
</table>
<span class="postbody"><!-- END syntax_close -->

#
#-----[ DIY INSTRUCTIONS ]------------------------------------------
#
CHMOD the directory cache/syntax 777
CHMOD the file cache/syntax/cache.txt to 666
If you have NOT run the SQL and wish to do it automatically, open in your web browser
and follow the instructions in install_syntax.php

#
#-----[ SAVE/CLOSE ALL FILES ]------------------------------------------
#
# EoM

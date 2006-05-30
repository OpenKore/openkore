<?php
/** 
*
* @package attachment_mod
* @version $Id: attachment_mod.php,v 1.6 2005/11/06 18:35:43 acydburn Exp $
* @copyright (c) 2002 Meik Sievertsen
* @license http://opensource.org/licenses/gpl-license.php GNU Public License 
*
* Minimum Requirement: PHP 4.2.0
*/

/**
*/
if (!defined('IN_PHPBB'))
{
	die('Hacking attempt');
	exit;
}

include($phpbb_root_path . 'attach_mod/includes/constants.' . $phpEx);
include($phpbb_root_path . 'attach_mod/includes/functions_includes.' . $phpEx);
include($phpbb_root_path . 'attach_mod/includes/functions_attach.' . $phpEx);
include($phpbb_root_path . 'attach_mod/includes/functions_delete.' . $phpEx);
include($phpbb_root_path . 'attach_mod/includes/functions_thumbs.' . $phpEx);
include($phpbb_root_path . 'attach_mod/includes/functions_filetypes.' . $phpEx);

if (defined('ATTACH_INSTALL'))
{
	return;
}

/**
* wrapper function for determining the correct language directory
*/
function attach_mod_get_lang($language_file)
{
	global $phpbb_root_path, $phpEx, $attach_config, $board_config;

	$language = $board_config['default_lang'];

	if (!file_exists($phpbb_root_path . 'language/lang_' . $language . '/' . $language_file . '.' . $phpEx))
	{
		$language = $attach_config['board_lang'];
		
		if (!file_exists($phpbb_root_path . 'language/lang_' . $language . '/' . $language_file . '.' . $phpEx))
		{
			message_die(GENERAL_MESSAGE, 'Attachment Mod language file does not exist: language/lang_' . $language . '/' . $language_file . '.' . $phpEx);
		}
		else
		{
			return $language;
		}
	}
	else
	{
		return $language;
	}
}

/**
* Include attachment mod language entries
*/
function include_attach_lang()
{
	global $phpbb_root_path, $phpEx, $lang, $board_config, $attach_config;
	
	// Include Language
	$language = attach_mod_get_lang('lang_main_attach');
	include_once($phpbb_root_path . 'language/lang_' . $language . '/lang_main_attach.' . $phpEx);

	if (defined('IN_ADMIN'))
	{
		$language = attach_mod_get_lang('lang_admin_attach');
		include_once($phpbb_root_path . 'language/lang_' . $language . '/lang_admin_attach.' . $phpEx);
	}
}

/**
* Get attachment mod configuration
*/
function get_config()
{
	global $db, $board_config;

	$attach_config = array();

	$sql = 'SELECT *
		FROM ' . ATTACH_CONFIG_TABLE;
	if (!($result = $db->sql_query($sql)))
	{
		message_die(GENERAL_ERROR, 'Could not query attachment information', '', __LINE__, __FILE__, $sql);
	}

	while ($row = $db->sql_fetchrow($result))
	{
		$attach_config[$row['config_name']] = trim($row['config_value']);
	}

	// We assign the original default board language here, because it gets overwritten later with the users default language
	$attach_config['board_lang'] = trim($board_config['default_lang']);

	return $attach_config;
}

// Get Attachment Config
$cache_dir = $phpbb_root_path . '/cache';
$cache_file = $cache_dir . '/attach_config.php';
$attach_config = array();

if (file_exists($cache_dir) && is_dir($cache_dir) && is_writable($cache_dir))
{
	if (file_exists($cache_file))
	{
		include($cache_file);
	}
	else
	{
		$attach_config = get_config();
		$fp = @fopen($cache_file, 'wt+');
		if ($fp)
		{
			$lines = array();
			foreach ($attach_config as $k => $v)
			{
				if (is_int($v))
				{
					$lines[] = "'$k'=>$v";
				}
				else if (is_bool($v))
				{
					$lines[] = "'$k'=>" . (($v) ? 'TRUE' : 'FALSE');
				}
				else
				{
					$lines[] = "'$k'=>'" . str_replace("'", "\\'", str_replace('\\', '\\\\', $v)) . "'";
				}
			}
			fwrite($fp, '<?php $attach_config = array(' . implode(',', $lines) . '); ?>');
			fclose($fp);

			@chmod($cache_file, 0777);
		}
	}
}
else
{
	$attach_config = get_config();
}

// Please do not change the include-order, it is valuable for proper execution.
// Functions for displaying Attachment Things
include($phpbb_root_path . 'attach_mod/displaying.' . $phpEx);

// Posting Attachments Class (HAVE TO BE BEFORE PM)
include($phpbb_root_path . 'attach_mod/posting_attachments.' . $phpEx);

// PM Attachments Class
include($phpbb_root_path . 'attach_mod/pm_attachments.' . $phpEx);

if (!intval($attach_config['allow_ftp_upload']))
{
	$upload_dir = $attach_config['upload_dir'];
}
else
{
	$upload_dir = $attach_config['download_path'];
}

if (!function_exists('attach_mod_sql_escape'))
{
	message_die(GENERAL_MESSAGE, 'You haven\'t correctly updated/installed the Attachment Mod.<br />You seem to forgot uploading a new file. Please refer to the update instructions for help and make sure you have uploaded every file correctly.');
}


?>
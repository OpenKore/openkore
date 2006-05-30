<?php
/** 
*
* @package attachment_mod
* @version $Id: constants.php,v 1.5 2006/04/22 16:21:09 acydburn Exp $
* @copyright (c) 2002 Meik Sievertsen
* @license http://opensource.org/licenses/gpl-license.php GNU Public License 
*
*/

/**
*/
if (!defined('IN_PHPBB'))
{
	die('Hacking attempt');
	exit;
}

// Attachment Debug Mode
define('ATTACH_DEBUG', 0);		// Attachment Mod Debugging off
//define('ATTACH_DEBUG', 1);	// Attachment Mod Debugging on

//define('ATTACH_QUERY_DEBUG', 1);

// Auth
define('AUTH_DOWNLOAD', 20);

// Download Modes
define('INLINE_LINK', 1);
define('PHYSICAL_LINK', 2);

// Categories
define('NONE_CAT', 0);
define('IMAGE_CAT', 1);
define('STREAM_CAT', 2);
define('SWF_CAT', 3);

// Tables
define('ATTACH_CONFIG_TABLE', $table_prefix . 'attachments_config');
define('EXTENSION_GROUPS_TABLE', $table_prefix . 'extension_groups');
define('EXTENSIONS_TABLE', $table_prefix . 'extensions');
define('FORBIDDEN_EXTENSIONS_TABLE', $table_prefix . 'forbidden_extensions');
define('ATTACHMENTS_DESC_TABLE', $table_prefix . 'attachments_desc');
define('ATTACHMENTS_TABLE', $table_prefix . 'attachments');
define('QUOTA_TABLE', $table_prefix . 'attach_quota');
define('QUOTA_LIMITS_TABLE', $table_prefix . 'quota_limits');

// Pages
define('PAGE_UACP', -1210);
define('PAGE_RULES', -1214);

// Misc
define('MEGABYTE', 1024);
define('ADMIN_MAX_ATTACHMENTS', 50); // Maximum Attachments in Posts or PM's for Admin Users
define('THUMB_DIR', 'thumbs');
define('MODE_THUMBNAIL', 1);

// Forum Extension Group Permissions
define('GPERM_ALL', 0); // ALL FORUMS

// Quota Types
define('QUOTA_UPLOAD_LIMIT', 1);
define('QUOTA_PM_LIMIT', 2);

define('ATTACH_VERSION', '2.4.3');



// Additional Constants


?>
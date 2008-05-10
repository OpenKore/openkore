<?php
/**
*
* @author Tobi Schäfer http://www.tobischaefer.net/
*
* @package phpBB3
* @version $Id: adclick.php, v0.2.0 2008-03-22 17:05:19 tas2580 $
* @copyright (c) 2007 SEO phpBB http://www.seo-phpbb.org
* @license http://opensource.org/licenses/gpl-license.php GNU Public License
*
*/

/**
*/

/**
* @ignore
*/
define('IN_PHPBB', true);
$phpbb_root_path = (defined('PHPBB_ROOT_PATH')) ? PHPBB_ROOT_PATH : './';
$phpEx = substr(strrchr(__FILE__, '.'), 1);
include($phpbb_root_path . 'common.' . $phpEx);


$id	= request_var('id', 0);

$sql = 'SELECT url
	FROM ' . AD_TABLE . ' 
	WHERE ad_id = ' . $id;
$result = $db->sql_query($sql);
$row = $db->sql_fetchrow($result);

$db->sql_query('UPDATE ' . AD_TABLE . ' SET clicks = clicks + 1 WHERE ad_id = ' . $id);

header("Status: 301 Permanently Moved");
header("Location: {$row['url']}"); 



?>
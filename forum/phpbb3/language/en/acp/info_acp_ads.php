<?php
/**
*
* Knowledge Base [Deutsch Du]
* @author Tobi Schaefer http://www.tobischaefer.net/
*
* @package language
* @version $Id: info_acp_ads.php, v0.2.0 2008-03-22 17:05:19 tas2580 $
* @copyright (c) 2007 SEO phpBB http://www.seo-phpbb.org
* @license http://opensource.org/licenses/gpl-license.php GNU Public License
*
*/

/**
* DO NOT CHANGE
*/
if (!defined('IN_PHPBB'))
{
	exit;
}

if (empty($lang) || !is_array($lang))
{
	$lang = array();
}

// DEVELOPERS PLEASE NOTE
//
// All language files should use UTF-8 as their encoding and the files must not contain a BOM.
//
// Placeholders can now contain order information, e.g. instead of
// 'Page %s of %s' you can (and should) write 'Page %1$s of %2$s', this allows
// translators to re-order the output of data while ensuring it remains correct
//
// You do not need this where single placeholders are used, e.g. 'Message %d' is fine
// equally where a string contains only two placeholders which are used to wrap text
// in a url you again do not need to specify an order e.g., 'Click %sHERE%s' is fine

$lang = array_merge($lang, array(
		'ADMANAGEMENT'	=> 'Ad Management',
		'HTML_AD'		=> 'HTML Ads',
		'BANNERS_AD'	=> 'Banner Ads',
));

?>
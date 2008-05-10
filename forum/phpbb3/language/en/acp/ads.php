<?php
/**
*
* @author Tobi Schaefer http://www.tobischaefer.net (MOD author)
* @author Luke Cousins http://www.VioVet.co.uk (translated into English)
* @author Francis Fisher http://radoncube.com (cleanup English tranlsation)
*
* @package language
* @version $Id: acp_ads.php, v0.2.0 2008-03-22 17:05:19 tas2580 $
* @copyright (c) 2007 SEO phpBB http://www.seo-phpbb.org
* @license http://opensource.org/licenses/gpl-license.php GNU Public License
*
*/

/**
* DO NOT CHANGE
*/
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

// Ad management settings
$lang = array_merge($lang, array(
	'ADMANAGEMENT'			=> 'Ad management',
	'NEED_CODE'				=> 'Enter a name and code for the advertisement.',
	'NEED_IMAGE'			=> 'Enter a name, URL and an image of the banner.',
	'ADDED'					=> 'The advertisement was added in the system!',
	'UPDATED'				=> 'The advertisement was updated.',
	'DELETED'				=> 'The advertisement was deleted from the system!',
	'REALY_DELETE'			=> 'Are you sure you want to delete the advertisement?',
	'AD'					=> 'Advertisement',
	'AD_DESC'				=> 'The advertisement can be administered here; you can alternated between several banner ads and enable or disable certain ads.',
	'NEW_AD'				=> 'Add advertisement',
	'EDIT_AD'				=> 'Edit advertisement',
	'NAME'					=> 'Name',
	'NAME_DESC'				=> 'Name of the advertisement.',
	'CODE'					=> 'Adcode',
	'CODE_DESC'				=> 'Code for the advertisement',
	'FORUMS_DESC'			=> 'Give the ID of the forums that can show this advertisment, <br /> several forums must by a comma to be separated.',
	'GROUPS_DESC'			=> 'To witch groups shuld the advertisement be shown? A member must have the group as maingroup thet he see the advertisement.',
	'AD_VIEWS'				=> 'Ad impressions',
	'AD_VIEWS_DESC'			=> 'The number of impressions for the advertisement',
	'AD_MAX_VIEWS'			=> 'Max impressions',
	'AD_MAX_VIEWS_DESC'		=> 'The maximum number of impressions for the advertisement',         
	'POSITION'				=> 'Position',
	'POSITION_DESC'			=> 'At which position is the advertisement to be displayed? ',
	'POSITION1'				=> 'After the first post',
	'POSITION2'				=> 'After each post',
	'POSITION3'				=> 'Above the posts',
	'POSITION4'				=> 'Under the posts',
	'POSITION5'				=> 'In Forumheader',
	'POSITION6'				=> 'In Forumfooter',
	'AD_IN_SYSTEM'			=> 'Ads in the system',
	'AD_IN_SYSTEM_DESC'		=> 'A list of ads stored in the system',
	'SHOW_IN_ALL_FORUMS'	=> 'Show in all Forums',
	'BANNER_AD'				=> 'Banner advertisement',
	'HTML_AD'				=> 'HTML advertisement',
	'IMAGE_DESC'			=> 'Give a image for the banner',
	'URL'					=> 'URL',
	'URL_DESC'				=> 'Give a URL at witch the banner will link too',
	'SIZE'					=> 'Banner size',
	'SIZE_DESC'				=> 'Give the size of the banner',
	'HEIGHT'				=> 'height',
	'WIDTH'					=> 'width',
	'PIXEL'					=> 'pixel',
	'START_DATE'			=> 'Start date',
	'START_DATE_DESC'		=> 'As of this date, the advertising will be shown.',
	'END_DATE'				=> 'End date',
	'END_DATE_DESC'			=> 'Up to this date, the advertising will be displayed.',
	'AD_CLICKS'				=> 'Clicks',
	'AD_CLICKS_DESC'		=> 'How often was the banner clicked?',
	'MAX_AD_CLICKS'			=> 'Max clicks',
	'MAX_AD_CLICKS_DESC'	=> 'Up to how many clicks the advertisement should appear?',
	'SHOW_OPTIONS'			=> 'Display settings',
	'RANKS'					=> 'Ranks',
	'RANKS_DESC'			=> 'For which ranks appear to be advertising? To the advertising of all ranks displayed choose from all ranks.',
	'NO_RANK'				=> 'Users without rank',
));
?>
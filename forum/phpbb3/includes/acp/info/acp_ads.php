<?php
/**
*
* @author Tobi Schäfer http://www.tobischaefer.net/
*
* @package acp
* @version $Id: acp_ads.php, v0.2.0 2008-03-22 17:05:19 tas2580 $
* @copyright (c) 2007 SEO phpBB http://www.seo-phpbb.org
* @license http://opensource.org/licenses/gpl-license.php GNU Public License 
*
*/

/**
* @package module_install
*/
class acp_ads_info
{
	function module()
	{		
		return array(
			'filename'	=> 'acp_ads',
			'title'		=> 'ADMANAGEMENT',
			'version'	=> '0.2.0',
			'modes'		=> array(
				'html'		=> array('title'	=> 'HTML_AD',		'auth'	=> '',	'cat'	=> array('ACP_BOARD_CONFIGURATION'),),
				'banner'	=> array('title'	=> 'BANNERS_AD',	'auth'	=> '',	'cat'	=> array('ACP_BOARD_CONFIGURATION'),),
			),
		);
	}

	function install()
	{
	}

	function uninstall()
	{
	}
	
	function update()
	{
	}
}

?>
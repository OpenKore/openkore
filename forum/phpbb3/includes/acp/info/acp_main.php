<?php
/**
*
* @package acp
* @version $Id: acp_main.php,v 1.4 2007/10/04 15:05:50 acydburn Exp $
* @copyright (c) 2005 phpBB Group
* @license http://opensource.org/licenses/gpl-license.php GNU Public License
*
*/

/**
* @package module_install
*/
class acp_main_info
{
	function module()
	{
		return array(
			'filename'	=> 'acp_main',
			'title'		=> 'ACP_INDEX',
			'version'	=> '1.0.0',
			'modes'		=> array(
				'main'		=> array('title' => 'ACP_INDEX', 'auth' => '', 'cat' => array('ACP_CAT_GENERAL')),
			),
		);
	}

	function install()
	{
	}

	function uninstall()
	{
	}
}

?>
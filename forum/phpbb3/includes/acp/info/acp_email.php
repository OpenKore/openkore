<?php
/**
*
* @package acp
* @version $Id: acp_email.php 9011 2008-10-13 18:45:24Z toonarmy $
* @copyright (c) 2005 phpBB Group
* @license http://opensource.org/licenses/gpl-license.php GNU Public License
*
*/

/**
* @package module_install
*/
class acp_email_info
{
	function module()
	{
		return array(
			'filename'	=> 'acp_email',
			'title'		=> 'ACP_MASS_EMAIL',
			'version'	=> '1.0.0',
			'modes'		=> array(
				'email'		=> array('title' => 'ACP_MASS_EMAIL', 'auth' => 'acl_a_email && cfg_email_enable', 'cat' => array('ACP_GENERAL_TASKS')),
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
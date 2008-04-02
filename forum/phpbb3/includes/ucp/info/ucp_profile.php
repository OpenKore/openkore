<?php
/**
*
* @package ucp
* @version $Id: ucp_profile.php,v 1.4 2007/10/04 15:06:45 acydburn Exp $
* @copyright (c) 2005 phpBB Group
* @license http://opensource.org/licenses/gpl-license.php GNU Public License
*
*/

/**
* @package module_install
*/
class ucp_profile_info
{
	function module()
	{
		return array(
			'filename'	=> 'ucp_profile',
			'title'		=> 'UCP_PROFILE',
			'version'	=> '1.0.0',
			'modes'		=> array(
				'profile_info'	=> array('title' => 'UCP_PROFILE_PROFILE_INFO', 'auth' => '', 'cat' => array('UCP_PROFILE')),
				'signature'		=> array('title' => 'UCP_PROFILE_SIGNATURE', 'auth' => '', 'cat' => array('UCP_PROFILE')),
				'avatar'		=> array('title' => 'UCP_PROFILE_AVATAR', 'auth' => '', 'cat' => array('UCP_PROFILE')),
				'reg_details'	=> array('title' => 'UCP_PROFILE_REG_DETAILS', 'auth' => '', 'cat' => array('UCP_PROFILE')),
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
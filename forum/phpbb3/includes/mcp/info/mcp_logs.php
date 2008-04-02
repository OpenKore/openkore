<?php
/**
*
* @package mcp
* @version $Id: mcp_logs.php,v 1.4 2007/10/04 15:06:01 acydburn Exp $
* @copyright (c) 2005 phpBB Group
* @license http://opensource.org/licenses/gpl-license.php GNU Public License
*
*/

/**
* @package module_install
*/
class mcp_logs_info
{
	function module()
	{
		return array(
			'filename'	=> 'mcp_logs',
			'title'		=> 'MCP_LOGS',
			'version'	=> '1.0.0',
			'modes'		=> array(
				'front'			=> array('title' => 'MCP_LOGS_FRONT', 'auth' => 'acl_m_ || aclf_m_', 'cat' => array('MCP_LOGS')),
				'forum_logs'	=> array('title' => 'MCP_LOGS_FORUM_VIEW', 'auth' => 'acl_m_,$id', 'cat' => array('MCP_LOGS')),
				'topic_logs'	=> array('title' => 'MCP_LOGS_TOPIC_VIEW', 'auth' => 'acl_m_,$id', 'cat' => array('MCP_LOGS')),
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
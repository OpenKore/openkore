<?php

/***************************************************************************
 *                               xs_index.php
 *                               ------------
 *   copyright            : (C) 2003 - 2005 CyberAlien
 *   support              : http://www.phpbbstyles.com
 *
 *   version              : 2.1.0
 *
 *   file revision        : 55
 *   project revision     : 63
 *   last modified        : 28 Dec 2004  18:32:57
 *
 ***************************************************************************/

/***************************************************************************
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 ***************************************************************************/

define('IN_PHPBB', 1);
$phpbb_root_path = "./../";
$no_page_header = true;
require($phpbb_root_path . 'extension.inc');
require('./pagestart.' . $phpEx);

// check if mod is installed
if(empty($template->xs_version) || $template->xs_version !== 6)
{
	message_die(GENERAL_ERROR, 'eXtreme Styles mod is not installed. You forgot to upload includes/template.php');
}

define('IN_XS', true);
include_once('xs_include.' . $phpEx);

if(isset($HTTP_GET_VARS['showwarning']))
{
	$msg = str_replace('{URL}', append_sid('xs_index.'.$phpEx), $lang['xs_main_comment3']);
	xs_message($lang['Information'], $msg);
}

$template->assign_vars(array(
	'U_CONFIG'				=> append_sid('xs_config.'.$phpEx),
	'U_DEFAULT_STYLE'		=> append_sid('xs_styles.'.$phpEx),
	'U_MANAGE_CACHE'		=> append_sid('xs_cache.'.$phpEx),
	'U_IMPORT_STYLES'		=> append_sid('xs_import.'.$phpEx),
	'U_EXPORT_STYLES'		=> append_sid('xs_export.'.$phpEx),
	'U_CLONE_STYLE'			=> append_sid('xs_clone.'.$phpEx),
	'U_DOWNLOAD_STYLES'		=> append_sid('xs_download.'.$phpEx),
	'U_INSTALL_STYLES'		=> append_sid('xs_install.'.$phpEx),
	'U_UNINSTALL_STYLES'	=> append_sid('xs_uninstall.'.$phpEx),
	'U_EDIT_STYLES'			=> append_sid('xs_edit.'.$phpEx),
	'U_EDIT_STYLES_DATA'	=> append_sid('xs_edit_data.'.$phpEx),
	'U_EXPORT_DATA'			=> append_sid('xs_export_data.'.$phpEx),
	'U_UPDATES'				=> append_sid('xs_update.'.$phpEx),
	));

$template->set_filenames(array('body' => XS_TPL_PATH . 'index.tpl'));
$template->pparse('body');
xs_exit();

?>
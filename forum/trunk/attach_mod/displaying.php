<?php
/***************************************************************************
 *								displaying.php
 *                            -------------------
 *   begin                : Monday, Jul 15, 2002
 *   copyright            : (C) 2002 Meik Sievertsen
 *   email                : acyd.burn@gmx.de
 *
 *   $Id: displaying.php,v 1.53 2005/07/16 14:32:21 acydburn Exp $
 *
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

if ( !defined('IN_PHPBB') )
{
	die('Hacking attempt');
	exit;
}

$allowed_extensions = array();
$display_categories = array();
$download_modes = array();
$upload_icons = array();
$attachments = array();

function display_compile_cache_clear($filename, $template_var)
{
	global $template;
	
	if (isset($template->cachedir))
	{
		$filename = str_replace($template->root, '', $filename);
		if (substr($filename, 0, 1) == '/')
		{
			$filename = substr($filename, 1, strlen($filename));
		}

		if (file_exists($template->cachedir . $filename . '.php'))
		{
			@unlink($template->cachedir . $filename . '.php');
		}
	}

	return;
}

// 
// Create needed arrays for Extension Assignments
//
function init_complete_extensions_data()
{
	global $db, $allowed_extensions, $display_categories, $download_modes, $upload_icons;

	$extension_informations = get_extension_informations();
	$allowed_extensions = array();

	for ($i = 0; $i < count($extension_informations); $i++)
	{
		$extension = strtolower(trim($extension_informations[$i]['extension']));
		$allowed_extensions[] = $extension;
		$display_categories[$extension] = intval($extension_informations[$i]['cat_id']);
		$download_modes[$extension] = intval($extension_informations[$i]['download_mode']);
		$upload_icons[$extension] = trim($extension_informations[$i]['upload_icon']);
	}
}

//
// Writing Data into plain Template Vars
//
function init_display_template($template_var, $replacement, $filename = 'viewtopic_attach_body.tpl')
{
	global $template;

	//
	// This function is adapted from the old template class
	// I wish i had the functions from the 2.2 one. :D (This class rocks, can't await to use it in Mods)
	//
	
	//
	// Handle Attachment Informations
	//
	if (!isset($template->uncompiled_code[$template_var]) && empty($template->uncompiled_code[$template_var]))
	{
		// If we don't have a file assigned to this handle, die.
		if (!isset($template->files[$template_var]))
		{
			die("Template->loadfile(): No file specified for handle $template_var");
		}

		$filename_2 = $template->files[$template_var];

		$str = implode("", @file($filename_2));
		if (empty($str))
		{
			die("Template->loadfile(): File $filename_2 for handle $template_var is empty");
		}

		$template->uncompiled_code[$template_var] = $str;
	}

	$complete_filename = $filename;
	if (substr($complete_filename, 0, 1) != '/')
	{
		$complete_filename = $template->root . '/' . $complete_filename;
	}

	if (!file_exists($complete_filename))
	{
		die("Template->make_filename(): Error - file $complete_filename does not exist");
	}

	$content = implode('', file($complete_filename));
	if (empty($content))
	{
		die('Template->loadfile(): File ' . $complete_filename . ' is empty');
	}

	// replace $replacement with uncompiled code in $filename
	$template->uncompiled_code[$template_var] = str_replace($replacement, $content, $template->uncompiled_code[$template_var]);

	//
	// Force Reload on cached version
	//
	display_compile_cache_clear($template->files[$template_var], $template_var);
}

//
// BEGIN ATTACHMENT DISPLAY IN POSTS
//

//
// Returns the image-tag for the topic image icon
//
function topic_attachment_image($switch_attachment)
{
	global $attach_config, $is_auth;

	if (intval($switch_attachment) == 0 || (!($is_auth['auth_download'] && $is_auth['auth_view'])) || intval($attach_config['disable_mod']) || $attach_config['topic_icon'] == '')
	{
		return '';
	}

	$image = '<img src="' . $attach_config['topic_icon'] . '" alt="" border="0" /> ';

	return $image;
}

//
// Display Attachments in Posts
//
function display_post_attachments($post_id, $switch_attachment)
{
	global $attach_config, $is_auth;
		
	if (intval($switch_attachment) == 0 || intval($attach_config['disable_mod']))
	{
		return;
	}

	if ($is_auth['auth_download'] && $is_auth['auth_view'])
	{
		display_attachments($post_id);
	}
	else
	{
		// Display Notice (attachment there but not having permissions to view it)
		// Not included because this would mean template and language file changes (at this stage this is not a wise step. ;))
	}
}

//
// Generate the Display Assign File Link
//
/*
function display_assign_link($post_id)
{
	global $attach_config, $is_auth, $phpEx;

	$image = 'templates/subSilver/images/icon_mini_message.gif';

	if ( (intval($attach_config['disable_mod'])) || (!( ($is_auth['auth_download']) && ($is_auth['auth_view']))) )
	{
		return ('');
	}

	$temp_url = append_sid("assign_file.$phpEx?p=" . $post_id);
	$link = '<a href="' . $temp_url . '" target="_blank"><img src="' . $image . '" alt="Add File" title="Add File" border="0" /></a>';
	
	return ($link);
}
*/

//
// Initializes some templating variables for displaying Attachments in Posts
//
function init_display_post_attachments($switch_attachment)
{
	global $attach_config, $db, $is_auth, $template, $lang, $postrow, $total_posts, $attachments, $forum_row, $forum_topic_data;

	if (empty($forum_topic_data) && !empty($forum_row))
	{
		$switch_attachment = $forum_row['topic_attachment'];
	}

	if (intval($switch_attachment) == 0 || intval($attach_config['disable_mod']) || (!($is_auth['auth_download'] && $is_auth['auth_view'])))
	{
		return;
	}

	$post_id_array = array();
	
	for ($i = 0; $i < $total_posts; $i++)
	{
		if ($postrow[$i]['post_attachment'] == 1)
		{
			$post_id_array[] = $postrow[$i]['post_id'];
		}
	}

	if (count($post_id_array) == 0)
	{
		return;
	}

	$rows = get_attachments_from_post($post_id_array);
	$num_rows = count($rows);

	if ($num_rows == 0)
	{
		return;
	}

	@reset($attachments);

	for ($i = 0; $i < $num_rows; $i++)
	{
		$attachments['_' . $rows[$i]['post_id']][] = $rows[$i];
	}

	init_display_template('body', '{postrow.ATTACHMENTS}');

	init_complete_extensions_data();

	$template->assign_vars(array(
		'L_POSTED_ATTACHMENTS' => $lang['Posted_attachments'],
		'L_KILOBYTE' => $lang['KB'])
	);
}

//
// END ATTACHMENT DISPLAY IN POSTS
//

//
// BEGIN ATTACHMENT DISPLAY IN PM's
//

//
// Returns the image-tag for the PM image icon
//
function privmsgs_attachment_image($privmsg_id)
{
	global $attach_config, $userdata;

	$auth = ($userdata['user_level'] == ADMIN) ? 1 : intval($attach_config['allow_pm_attach']);
	
	if (!attachment_exists_db($privmsg_id, PAGE_PRIVMSGS) || !$auth || intval($attach_config['disable_mod']) || $attach_config['topic_icon'] == '')
	{
		return '';
	}

	$image = '<img src="' . $attach_config['topic_icon'] . '" alt="" border="0" /> ';

	return $image;
}

//
// Display Attachments in PM's
//
function display_pm_attachments($privmsgs_id, $switch_attachment)
{
	global $attach_config, $userdata, $template, $lang;
		
	if ($userdata['user_level'] == ADMIN)
	{
		$auth_download = 1;
	}
	else
	{
		$auth_download = intval($attach_config['allow_pm_attach']);
	}

	if (intval($switch_attachment) == 0 || intval($attach_config['disable_mod']) || !$auth_download)
	{
		return;
	}

	display_attachments($privmsgs_id);
	
	$template->assign_block_vars('switch_attachments', array());
	$template->assign_vars(array(
		'L_DELETE_ATTACHMENTS' => $lang['Delete_attachments'])
	);
}

//
// Initializes some templating variables for displaying Attachments in Private Messages
//
function init_display_pm_attachments($switch_attachment)
{
	global $attach_config, $template, $userdata, $lang, $attachments, $privmsg;

	if ($userdata['user_level'] == ADMIN)
	{
		$auth_download = 1;
	}
	else
	{
		$auth_download = intval($attach_config['allow_pm_attach']);
	}

	if (intval($switch_attachment) == 0 || intval($attach_config['disable_mod']) || !$auth_download)
	{
		return;
	}

	$privmsgs_id = $privmsg['privmsgs_id'];
	
	@reset($attachments);
	$attachments['_' . $privmsgs_id] = get_attachments_from_pm($privmsgs_id);

	if (count($attachments['_' . $privmsgs_id]) == 0)
	{
		return;
	}

	$template->assign_block_vars('postrow', array());
		
	init_display_template('body', '{ATTACHMENTS}');

	init_complete_extensions_data();
	
	$template->assign_vars(array(
		'L_POSTED_ATTACHMENTS' => $lang['Posted_attachments'],
		'L_KILOBYTE' => $lang['KB'])
	);

	display_pm_attachments($privmsgs_id, $switch_attachment);
}

//
// END ATTACHMENT DISPLAY IN PM's
//

//
// BEGIN ATTACHMENT DISPLAY IN TOPIC REVIEW WINDOW
//

//
// Display Attachments in Review Window
//
function display_review_attachments($post_id, $switch_attachment, $is_auth)
{
	global $attach_config, $attachments;
		
	if (intval($switch_attachment) == 0 || intval($attach_config['disable_mod']) || (!($is_auth['auth_download'] && $is_auth['auth_view'])) || intval($attach_config['attachment_topic_review']) == 0)
	{
		return;
	}

	@reset($attachments);
	$attachments['_' . $post_id] = get_attachments_from_post($post_id);

	if (count($attachments['_' . $post_id]) == 0)
	{
		return;
	}

	display_attachments($post_id);
}

//
// Initializes some templating variables for displaying Attachments in Review Topic Window
//
function init_display_review_attachments($is_auth)
{
	global $attach_config;

	if (intval($attach_config['disable_mod']) || (!($is_auth['auth_download'] && $is_auth['auth_view'])) || intval($attach_config['attachment_topic_review']) == 0)
	{
		return;
	}

	init_display_template('reviewbody', '{postrow.ATTACHMENTS}');

	init_complete_extensions_data();
	
}

//
// END ATTACHMENT DISPLAY IN TOPIC REVIEW WINDOW
//

//
// BEGIN DISPLAY ATTACHMENTS -> PREVIEW
//
function display_attachments_preview($attachment_list, $attachment_filesize_list, $attachment_filename_list, $attachment_comment_list, $attachment_extension_list, $attachment_thumbnail_list)
{
	global $attach_config, $is_auth, $allowed_extensions, $lang, $userdata, $display_categories, $upload_dir, $upload_icons, $template, $db, $theme;

	if (count($attachment_list) != 0)
	{
		init_display_template('preview', '{ATTACHMENTS}');
			
		init_complete_extensions_data();

		$template->assign_block_vars('postrow', array());
		$template->assign_block_vars('postrow.attach', array());
	
		$template->assign_vars(array(
			'T_BODY_TEXT' => '#'.$theme['body_text'],
			'T_TR_COLOR3' => '#'.$theme['tr_color3'])
		);

		for ($i = 0; $i < count($attachment_list); $i++)
		{
			$filename = $upload_dir . '/' . $attachment_list[$i];
			$thumb_filename = $upload_dir . '/' . THUMB_DIR . '/t_' . $attachment_list[$i];

			$filesize = $attachment_filesize_list[$i];
			$size_lang = ($filesize >= 1048576) ? $lang['MB'] : ( ($filesize >= 1024) ? $lang['KB'] : $lang['Bytes'] );
			if ($filesize >= 1048576)
			{
				$filesize = (round((round($filesize / 1048576 * 100) / 100), 2));
			}
			else if ($filesize >= 1024)
			{
				$filesize = (round((round($filesize / 1024 * 100) / 100), 2));
			}

			$display_name = htmlspecialchars($attachment_filename_list[$i]);
			$comment = trim(htmlspecialchars(stripslashes($attachment_comment_list[$i])));
			$comment = str_replace("\n", '<br />', $comment);
			
			$extension = strtolower(trim($attachment_extension_list[$i]));

			$denied = false;

			//
			// Admin is allowed to view forbidden Attachments, but the error-message is displayed too to inform the Admin
			//
			if ( (!in_array($extension, $allowed_extensions)) )
			{
				$denied = true;

				$template->assign_block_vars('postrow.attach.denyrow', array(
					'L_DENIED' => sprintf($lang['Extension_disabled_after_posting'], $extension))
				);
			} 

			if (!$denied)
			{
				//
				// Some basic Template Vars
				//
				$template->assign_vars(array(
					'L_DESCRIPTION' => $lang['Description'],
					'L_DOWNLOAD' => $lang['Download'],
					'L_FILENAME' => $lang['File_name'],
					'L_FILESIZE' => $lang['Filesize'])
				);
		
				//
				// define category
				//
				$image = FALSE;
				$stream = FALSE;
				$swf = FALSE;
				$thumbnail = FALSE;
				$link = FALSE;

				if (intval($display_categories[$extension]) == STREAM_CAT)
				{
					$stream = TRUE;
				}
				else if (intval($display_categories[$extension]) == SWF_CAT)
				{
					$swf = TRUE;
				}
				else if ( (intval($display_categories[$extension]) == IMAGE_CAT) && (intval($attach_config['img_display_inlined'])) )
				{
					if ( (intval($attach_config['img_link_width']) != 0) || (intval($attach_config['img_link_height']) != 0) )
					{
						list($width, $height) = image_getdimension($filename);

						if ( ($width == 0) && ($height == 0) )
						{
							$image = TRUE;
						}
						else
						{
							if ( ($width <= intval($attach_config['img_link_width'])) && ($height <= intval($attach_config['img_link_height'])) )
							{
								$image = TRUE;
							}
						}
					}
					else
					{
						$image = TRUE;
					}
				}
			
				if ( (intval($display_categories[$extension]) == IMAGE_CAT) && (intval($attachment_thumbnail_list[$i]) == 1) )
				{
					$thumbnail = TRUE;
					$image = FALSE;
				}

				if ( (!$image) && (!$stream) && (!$swf) && (!$thumbnail) )
				{
					$link = TRUE;
				}

				if ($image)
				{
					//
					// Images
					//
					$template->assign_block_vars('postrow.attach.cat_images', array(
						'DOWNLOAD_NAME' => $display_name,
						'IMG_SRC' => $filename,
						'FILESIZE' => $filesize,
						'SIZE_VAR' => $size_lang,
						'COMMENT' => $comment,
						'L_DOWNLOADED_VIEWED' => $lang['Viewed'])
					);
				}
			
				if ($thumbnail)
				{
					//
					// Images, but display Thumbnail
					//
					$template->assign_block_vars('postrow.attach.cat_thumb_images', array(
						'DOWNLOAD_NAME' => $display_name,
						'IMG_SRC' => $filename,
						'IMG_THUMB_SRC' => $thumb_filename,
						'FILESIZE' => $filesize,
						'SIZE_VAR' => $size_lang,
						'COMMENT' => $comment,
						'L_DOWNLOADED_VIEWED' => $lang['Viewed'])
					);
				}

				if ($stream)
				{
					//
					// Streams
					//
					$template->assign_block_vars('postrow.attach.cat_stream', array(
						'U_DOWNLOAD_LINK' => $filename,
						'DOWNLOAD_NAME' => $display_name,
						'FILESIZE' => $filesize,
						'SIZE_VAR' => $size_lang,
						'COMMENT' => $comment,
						'L_DOWNLOADED_VIEWED' => $lang['Viewed'])
					);
				}
			
				if ($swf)
				{
					//
					// Macromedia Flash Files
					//
					list($width, $height) = swf_getdimension($filename);
					
					$template->assign_block_vars('postrow.attach.cat_swf', array(
						'U_DOWNLOAD_LINK' => $filename,
						'DOWNLOAD_NAME' => $display_name,
						'FILESIZE' => $filesize,
						'SIZE_VAR' => $size_lang,
						'COMMENT' => $comment,
						'L_DOWNLOADED_VIEWED' => $lang['Viewed'],
						'WIDTH' => $width,
						'HEIGHT' => $height)
					);
				}

				if ($link)
				{
					$upload_image = '';

					if ( ($attach_config['upload_img'] != '') && ($upload_icons[$extension] == '') )
					{
						$upload_image = '<img src="' . $attach_config['upload_img'] . '" alt="" border="0" />';
					}
					else if (trim($upload_icons[$extension]) != '')
					{
						$upload_image = '<img src="' . $upload_icons[$extension] . '" alt="" border="0" />';
					}

					$target_blank = 'target="_blank"';
					
					//
					// display attachment
					//
					$template->assign_block_vars('postrow.attach.attachrow', array(
						'U_DOWNLOAD_LINK' => $filename,
						'S_UPLOAD_IMAGE' => $upload_image,
						
						'DOWNLOAD_NAME' => $display_name,
						'FILESIZE' => $filesize,
						'SIZE_VAR' => $size_lang,
						'COMMENT' => $comment,
						'L_DOWNLOADED_VIEWED' => $lang['Downloaded'],
						'TARGET_BLANK' => $target_blank)
					);
				}
			}
		}
	}
}

//
// END DISPLAY ATTACHMENTS -> PREVIEW
//

//
// Assign Variables and Definitions based on the fetched Attachments - internal
// used by all displaying functions, the Data was collected before, it's only dependend on the template used. :)
// before this function is usable, init_display_attachments have to be called for specific pages (pm, posting, review etc...)
//
function display_attachments($post_id)
{
	global $template, $upload_dir, $userdata, $allowed_extensions, $display_categories, $download_modes, $db, $lang, $phpEx, $attachments, $upload_icons, $attach_config;

	$num_attachments = count($attachments['_' . $post_id]);
	
	if ($num_attachments == 0)
	{
		return;
	}

	$template->assign_block_vars('postrow.attach', array());
	
	for ($i = 0; $i < $num_attachments; $i++)
	{
		//
		// Some basic things...
		//
		$filename = $upload_dir . '/' . $attachments['_' . $post_id][$i]['physical_filename'];
		$thumbnail_filename = $upload_dir . '/' . THUMB_DIR . '/t_' . $attachments['_' . $post_id][$i]['physical_filename'];
	
		$upload_image = '';

		if ( ($attach_config['upload_img'] != '') && (trim($upload_icons[$attachments['_' . $post_id][$i]['extension']]) == '') )
		{
			$upload_image = '<img src="' . $attach_config['upload_img'] . '" alt="" border="0" />';
		}
		else if (trim($upload_icons[$attachments['_' . $post_id][$i]['extension']]) != '')
		{
			$upload_image = '<img src="' . $upload_icons[$attachments['_' . $post_id][$i]['extension']] . '" alt="" border="0" />';
		}
		
		$filesize = $attachments['_' . $post_id][$i]['filesize'];
		$size_lang = ($filesize >= 1048576) ? $lang['MB'] : ( ($filesize >= 1024) ? $lang['KB'] : $lang['Bytes'] );
		if ($filesize >= 1048576)
		{
			$filesize = (round((round($filesize / 1048576 * 100) / 100), 2));
		}
		else if ($filesize >= 1024)
		{
			$filesize = (round((round($filesize / 1024 * 100) / 100), 2));
		}

		$display_name = htmlspecialchars($attachments['_' . $post_id][$i]['real_filename']); 
		$comment = trim(htmlspecialchars(stripslashes($attachments['_' . $post_id][$i]['comment'])));
		$comment = str_replace("\n", '<br />', $comment);

		$attachments['_' . $post_id][$i]['extension'] = strtolower(trim($attachments['_' . $post_id][$i]['extension']));

		$denied = false;

		//
		// Admin is allowed to view forbidden Attachments, but the error-message is displayed too to inform the Admin
		//
		if ( (!in_array($attachments['_' . $post_id][$i]['extension'], $allowed_extensions)) )
		{
			$denied = true;

			$template->assign_block_vars('postrow.attach.denyrow', array(
				'L_DENIED' => sprintf($lang['Extension_disabled_after_posting'], $attachments['_' . $post_id][$i]['extension']))
			);
		} 

		if (!$denied)
		{
			//
			// Some basic Template Vars
			//
			$template->assign_vars(array(
				'L_DESCRIPTION' => $lang['Description'],
				'L_DOWNLOAD' => $lang['Download'],
				'L_FILENAME' => $lang['File_name'],
				'L_FILESIZE' => $lang['Filesize'])
			);
			
			//
			// define category
			//
			$image = FALSE;
			$stream = FALSE;
			$swf = FALSE;
			$thumbnail = FALSE;
			$link = FALSE;

			if (intval($display_categories[$attachments['_' . $post_id][$i]['extension']]) == STREAM_CAT)
			{
				$stream = TRUE;
			}
			else if (intval($display_categories[$attachments['_' . $post_id][$i]['extension']]) == SWF_CAT)
			{
				$swf = TRUE;
			}
			else if ( (intval($display_categories[$attachments['_' . $post_id][$i]['extension']]) == IMAGE_CAT) && (intval($attach_config['img_display_inlined'])) )
			{
				if ( (intval($attach_config['img_link_width']) != 0) || (intval($attach_config['img_link_height']) != 0) )
				{
					list($width, $height) = image_getdimension($filename);

					if ( ($width == 0) && ($height == 0) )
					{
						$image = TRUE;
					}
					else
					{
						if ( ($width <= intval($attach_config['img_link_width'])) && ($height <= intval($attach_config['img_link_height'])) )
						{
							$image = TRUE;
						}
					}
				}
				else
				{
					$image = TRUE;
				}
			}
			
			if ( (intval($display_categories[$attachments['_' . $post_id][$i]['extension']]) == IMAGE_CAT) && ($attachments['_' . $post_id][$i]['thumbnail'] == 1) )
			{
				$thumbnail = TRUE;
				$image = FALSE;
			}

			if ( (!$image) && (!$stream) && (!$swf) && (!$thumbnail) )
			{
				$link = TRUE;
			}

			if ($image)
			{
				//
				// Images
				// NOTE: If you want to use the download.php everytime an image is displayed inlined, replace the
				// Section between BEGIN and END with (Without the // of course):
				//	$img_source = append_sid('download.' . $phpEx . '?id=' . $attachments['_' . $post_id][$i]['attach_id']);
				//	$download_link = TRUE;
				// 
				//
				if ((intval($attach_config['allow_ftp_upload'])) && (trim($attach_config['download_path']) == ''))
				{
					$img_source = append_sid('download.' . $phpEx . '?id=' . $attachments['_' . $post_id][$i]['attach_id']);
					$download_link = TRUE;
				}
				else
				{
					// Check if we can reach the file or if it is stored outside of the webroot
					if ($attach_config['upload_dir'][0] == '/' || ( $attach_config['upload_dir'][0] != '/' && $attach_config['upload_dir'][1] == ':'))
					{
						$img_source = append_sid('download.' . $phpEx . '?id=' . $attachments['_' . $post_id][$i]['attach_id']);
						$download_link = TRUE;
					}
					else
					{
						$img_source = $filename;
						$download_link = FALSE;
					}
				}

				$template->assign_block_vars('postrow.attach.cat_images', array(
					'DOWNLOAD_NAME' => $display_name,
					'S_UPLOAD_IMAGE' => $upload_image,

					'IMG_SRC' => $img_source,
					'FILESIZE' => $filesize,
					'SIZE_VAR' => $size_lang,
					'COMMENT' => $comment,
					'L_DOWNLOADED_VIEWED' => $lang['Viewed'],
					'L_DOWNLOAD_COUNT' => sprintf($lang['Download_number'], $attachments['_' . $post_id][$i]['download_count']))
				);

				//
				// Directly Viewed Image ... update the download count
				//
				if (!$download_link)
				{
					$sql = 'UPDATE ' . ATTACHMENTS_DESC_TABLE . ' 
					SET download_count = download_count + 1 
					WHERE attach_id = ' . $attachments['_' . $post_id][$i]['attach_id'];
	
					if ( !($db->sql_query($sql)) )
					{
						message_die(GENERAL_ERROR, 'Couldn\'t update attachment download count.', '', __LINE__, __FILE__, $sql);
					}
				}
			}
			
			if ($thumbnail)
			{
				//
				// Images, but display Thumbnail
				// NOTE: If you want to use the download.php everytime an thumnmail is displayed inlined, replace the
				// Section between BEGIN and END with (Without the // of course):
				//	$thumb_source = append_sid('download.' . $phpEx . '?id=' . $attachments['_' . $post_id][$i]['attach_id'] . '&thumb=1');
				//
				if ( (intval($attach_config['allow_ftp_upload'])) && (trim($attach_config['download_path']) == '') )
				{
					$thumb_source = append_sid('download.' . $phpEx . '?id=' . $attachments['_' . $post_id][$i]['attach_id'] . '&thumb=1');
				}
				else
				{
					// Check if we can reach the file or if it is stored outside of the webroot
					if ($attach_config['upload_dir'][0] == '/' || ( $attach_config['upload_dir'][0] != '/' && $attach_config['upload_dir'][1] == ':'))
					{
						$thumb_source = append_sid('download.' . $phpEx . '?id=' . $attachments['_' . $post_id][$i]['attach_id'] . '&thumb=1');
					}
					else
					{
						$thumb_source = $thumbnail_filename;
					}
				}
				
				$template->assign_block_vars('postrow.attach.cat_thumb_images', array(
					'DOWNLOAD_NAME' => $display_name,
					'S_UPLOAD_IMAGE' => $upload_image,

					'IMG_SRC' => append_sid('download.' . $phpEx . '?id=' . $attachments['_' . $post_id][$i]['attach_id']),
					'IMG_THUMB_SRC' => $thumb_source,
					'FILESIZE' => $filesize,
					'SIZE_VAR' => $size_lang,
					'COMMENT' => $comment,
					'L_DOWNLOADED_VIEWED' => $lang['Viewed'],
					'L_DOWNLOAD_COUNT' => sprintf($lang['Download_number'], $attachments['_' . $post_id][$i]['download_count']))
				);
			}

			if ($stream)
			{
				//
				// Streams
				//
				$template->assign_block_vars('postrow.attach.cat_stream', array(
					'U_DOWNLOAD_LINK' => $filename,
					'S_UPLOAD_IMAGE' => $upload_image,

//					'U_DOWNLOAD_LINK' => append_sid('download.' . $phpEx . '?id=' . $attachments['_' . $post_id][$i]['attach_id']),
					'DOWNLOAD_NAME' => $display_name,
					'FILESIZE' => $filesize,
					'SIZE_VAR' => $size_lang,
					'COMMENT' => $comment,
					'L_DOWNLOADED_VIEWED' => $lang['Viewed'],
					'L_DOWNLOAD_COUNT' => sprintf($lang['Download_number'], $attachments['_' . $post_id][$i]['download_count']))
				);

				//
				// Viewed/Heared File ... update the download count (download.php is not called here)
				//
				$sql = 'UPDATE ' . ATTACHMENTS_DESC_TABLE . ' 
				SET download_count = download_count + 1 
				WHERE attach_id = ' . $attachments['_' . $post_id][$i]['attach_id'];
	
				if ( !($db->sql_query($sql)) )
				{
					message_die(GENERAL_ERROR, 'Couldn\'t update attachment download count', '', __LINE__, __FILE__, $sql);
				}
			}
			
			if ($swf)
			{
				//
				// Macromedia Flash Files
				//
				list($width, $height) = swf_getdimension($filename);
						
				$template->assign_block_vars('postrow.attach.cat_swf', array(
					'U_DOWNLOAD_LINK' => $filename,
					'S_UPLOAD_IMAGE' => $upload_image,

					'DOWNLOAD_NAME' => $display_name,
					'FILESIZE' => $filesize,
					'SIZE_VAR' => $size_lang,
					'COMMENT' => $comment,
					'L_DOWNLOADED_VIEWED' => $lang['Viewed'],
					'L_DOWNLOAD_COUNT' => sprintf($lang['Download_number'], $attachments['_' . $post_id][$i]['download_count']),
					'WIDTH' => $width,
					'HEIGHT' => $height)
				);

				//
				// Viewed/Heared File ... update the download count (download.php is not called here)
				//
				$sql = 'UPDATE ' . ATTACHMENTS_DESC_TABLE . ' 
				SET download_count = download_count + 1 
				WHERE attach_id = ' . $attachments['_' . $post_id][$i]['attach_id'];
	
				if ( !($db->sql_query($sql)) )
				{
					message_die(GENERAL_ERROR, 'Couldn\'t update attachment download count', '', __LINE__, __FILE__, $sql);
				}
			}

			if ($link)
			{
				$target_blank = 'target="_blank"'; //( (intval($display_categories[$attachments['_' . $post_id][$i]['extension']]) == IMAGE_CAT) ) ? 'target="_blank"' : '';

				//
				// display attachment
				//
				$template->assign_block_vars('postrow.attach.attachrow', array(
					'U_DOWNLOAD_LINK' => append_sid('download.' . $phpEx . '?id=' . $attachments['_' . $post_id][$i]['attach_id']),
					'S_UPLOAD_IMAGE' => $upload_image,
						
					'DOWNLOAD_NAME' => $display_name,
					'FILESIZE' => $filesize,
					'SIZE_VAR' => $size_lang,
					'COMMENT' => $comment,
					'TARGET_BLANK' => $target_blank,

					'L_DOWNLOADED_VIEWED' => $lang['Downloaded'],
					'L_DOWNLOAD_COUNT' => sprintf($lang['Download_number'], $attachments['_' . $post_id][$i]['download_count']))
				);
						
			}
		}
	}
}

?>
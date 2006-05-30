<?php
/** 
*
* @package attachment_mod
* @version $Id: functions_thumbs.php,v 1.3 2005/11/15 21:26:47 acydburn Exp $
* @copyright (c) 2002 Meik Sievertsen
* @license http://opensource.org/licenses/gpl-license.php GNU Public License 
*
*/

/**
* All Attachment Functions needed to create Thumbnails
*/

/**
*/
if ( !defined('IN_PHPBB') )
{
	die('Hacking attempt');
	exit;
}

$imagick = '';

/**
* Calculate the needed size for Thumbnail
*/
function get_img_size_format($width, $height)
{
	// Maximum Width the Image can take
	$max_width = 400;

	if ($width > $height)
	{
		return array(
			round($width * ($max_width / $width)),
			round($height * ($max_width / $width))
		);
	} 
	else 
	{
		return array(
			round($width * ($max_width / $height)),
			round($height * ($max_width / $height))
		);
	}
}

/**
* Check if imagick is present
*/
function is_imagick() 
{
	global $imagick, $attach_config;

	if ($attach_config['img_imagick'] != '')
	{
		$imagick = $attach_config['img_imagick'];
		return true;
	}
	else
	{
		return false;
	}
}

/**
* Get supported image types
*/
function get_supported_image_types($type)
{
	if (@extension_loaded('gd'))
	{
		$format = imagetypes();
		$new_type = 0;

		switch ($type)
		{
			case 1:
				$new_type = ($format & IMG_GIF) ? IMG_GIF : 0;
				break;
			case 2:
			case 9:
			case 10:
			case 11:
			case 12:
				$new_type = ($format & IMG_JPG) ? IMG_JPG : 0;
				break;
			case 3:
				$new_type = ($format & IMG_PNG) ? IMG_PNG : 0;
				break;
			case 6:
			case 15:
				$new_type = ($format & IMG_WBMP) ? IMG_WBMP : 0;
				break;
		}
		
		return array(
			'gd'		=> ($new_type) ? true : false,
			'format'	=> $new_type,
			'version'	=> (function_exists('imagecreatetruecolor')) ? 2 : 1
		);
	}

	return array('gd' => false);
}

/**
* Create thumbnail
*/
function create_thumbnail($source, $new_file, $mimetype) 
{
	global $attach_config, $imagick;

	$source = amod_realpath($source);
	$min_filesize = (int) $attach_config['img_min_thumb_filesize'];
	$img_filesize = (@file_exists($source)) ? @filesize($source) : false;

	if (!$img_filesize || $img_filesize <= $min_filesize)
	{
		return false;
	}

	list($width, $height, $type, ) = getimagesize($source);

	if (!$width || !$height)
	{
		return false;
	}

	list($new_width, $new_height) = get_img_size_format($width, $height);

	$tmp_path = $old_file = '';

	if (intval($attach_config['allow_ftp_upload']))
	{
		$old_file = $new_file;

		$tmp_path = explode('/', $source);
		$tmp_path[count($tmp_path)-1] = '';
		$tmp_path = implode('/', $tmp_path);

		if ($tmp_path == '')
		{
			$tmp_path = '/tmp';
		}

		$value = trim($tmp_path);

		if ($value[strlen($value)-1] == '/')
		{
			$value[strlen($value)-1] = ' ';
		}

		// 
		$new_file = tempnam(trim($value), 't00000');

		// We remove it now because it gets created again later
		@unlink($new_file);
	}

	$used_imagick = false;

	if (is_imagick()) 
	{
		passthru($imagick . ' -quality 85 -antialias -sample ' . $new_width . 'x' . $new_height . ' "' . str_replace('\\', '/', $source) . '" +profile "*" "' . str_replace('\\', '/', $new_file) . '"');
		if (@file_exists($new_file))
		{
			$used_imagick = true;
		}
	} 

	if (!$used_imagick) 
	{
		$type = get_supported_image_types($type);
		
		if ($type['gd'])
		{
			switch ($type['format']) 
			{
				case IMG_GIF:
					$image = imagecreatefromgif($source);
					break;
				case IMG_JPG:
					$image = imagecreatefromjpeg($source);
					break;
				case IMG_PNG:
					$image = imagecreatefrompng($source);
					break;
				case IMG_WBMP:
					$image = imagecreatefromwbmp($source);
					break;
			}

			if ($type['version'] == 1 || !$attach_config['use_gd2'])
			{
				$new_image = imagecreate($new_width, $new_height);
				imagecopyresized($new_image, $image, 0, 0, 0, 0, $new_width, $new_height, $width, $height);
			}
			else
			{
				$new_image = imagecreatetruecolor($new_width, $new_height);
				imagecopyresampled($new_image, $image, 0, 0, 0, 0, $new_width, $new_height, $width, $height);
			}
			
			switch ($type['format'])
			{
				case IMG_GIF:
					imagegif($new_image, $new_file);
					break;
				case IMG_JPG:
					imagejpeg($new_image, $new_file, 90);
					break;
				case IMG_PNG:
					imagepng($new_image, $new_file);
					break;
				case IMG_WBMP:
					imagewbmp($new_image, $new_file);
					break;
			}

			imagedestroy($new_image);
		}
	}

	if (!@file_exists($new_file))
	{
		return false;
	}

	if (intval($attach_config['allow_ftp_upload']))
	{
		$result = ftp_file($new_file, $old_file, $mimetype, true); // True for disable error-mode
		@unlink($new_file);

		if (!$result)
		{
			return false;
		}
	}
	else
	{
		@chmod($new_file, 0664);
	}
	
	return true;
}

?>
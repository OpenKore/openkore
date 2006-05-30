<?php
/** 
*
* @package attachment_mod
* @version $Id: functions_filetypes.php,v 1.1 2005/11/05 12:30:57 acydburn Exp $
* @copyright (c) 2002 Meik Sievertsen
* @license http://opensource.org/licenses/gpl-license.php GNU Public License 
*
*/

/**
* All Attachment Functions needed to determine Special Files/Dimensions
*/

/**
* Read Long Int (4 Bytes) from File
*/
function read_longint($fp)
{
	$data = fread($fp, 4);

	$value = ord($data[0]) + (ord($data[1])<<8)+(ord($data[2])<<16)+(ord($data[3])<<24);
	if ($value >= 4294967294)
	{
		$value -= 4294967296;
	}

	return $value;
}

/**
* Read Word (2 Bytes) from File - Note: It's an Intel Word
*/
function read_word($fp)
{
	$data = fread($fp, 2);

	$value = ord($data[1]) * 256 + ord($data[0]);
	
	return $value;
}

/**
* Read Byte
*/
function read_byte($fp)
{
	$data = fread($fp, 1);

	$value = ord($data);
	
	return $value;
}

/**
* Get Image Dimensions
*/
function image_getdimension($file)
{
	$size = @getimagesize($file);

	if ($size[0] != 0 || $size[1] != 0)
	{
		return $size;
	}

	// Try to get the Dimension manually, depending on the mimetype
	$fp = @fopen($file, 'rb');
	if (!$fp)
	{
		return $size;
	}
	
	$error = faöse;

	// BMP - IMAGE

	$tmp_str = fread($fp, 2);
	if ($tmp_str == 'BM')
	{
		$length = read_longint($fp);

		if ($length <= 6)
		{
			$error = true;
		}

		if (!$error)
		{
			$i = read_longint($fp); 
			if ( $i != 0)
			{
				$error = true;
			}
		}

		if (!$error)
		{
			$i = read_longint($fp);

			if ($i != 0x3E && $i != 0x76 && $i != 0x436 && $i != 0x36)
			{
				$error = true;
			}
		}

		if (!$error)
		{
			$tmp_str = fread($fp, 4); 
			$width = read_longint($fp); 
			$height = read_longint($fp);

			if ($width > 3000 || $height > 3000)
			{
				$error = true;
			}
		}
	}
	else
	{
		$error = true;
	}

	if (!$error)
	{
		fclose($fp);
		return array(
			$width,
			$height,
			6
		);
	}
	
	$error = false;
	fclose($fp);

	// GIF - IMAGE

	$fp = @fopen($file, 'rb');

	$tmp_str = fread($fp, 3);
	
	if ($tmp_str == 'GIF')
	{
		$tmp_str = fread($fp, 3);
		$width = read_word($fp);
		$height = read_word($fp);

		$info_byte = fread($fp, 1);
		$info_byte = ord($info_byte);
		if (($info_byte & 0x80) != 0x80 && ($info_byte & 0x80) != 0)
		{
			$error = true;
		}
		
		if (!$error)
		{
			if (($info_byte & 8) != 0)
			{
				$error = true;
			}

		}
	}
	else
	{
		$error = true;
	}

	if (!$error)
	{
		fclose($fp);
		return array(
			$width,
			$height,
			1
		);
	}
	
	$error = false;
	fclose($fp);

	// JPG - IMAGE
	$fp = @fopen($file, 'rb');

	$tmp_str = fread($fp, 4);
	$w1 = read_word($fp);

	if (intval($w1) < 16)
	{
		$error = true;
	}
	
	if (!$error)
	{
		$tmp_str = fread($fp, 4);
		if ($tmp_str == 'JFIF')
		{
			$o_byte = fread($fp, 1);
			if (intval($o_byte) != 0)
			{
				$error = true;
			}

			if (!$error)
			{
				$str = fread($fp, 2);
				$b = read_byte($fp);

				if ($b != 0 && $b != 1 && $b != 2)
				{
					$error = true;
				}
			}

			if (!$error)
			{
				$width = read_word($fp);
				$height = read_word($fp);

				if ($width <= 0 || $height <= 0)
				{
					$error = true;
				}
			}
		}
	}
	else
	{
		$error = true;
	}

	if (!$error)
	{
		fclose($fp);
		return array(
			$width,
			$height,
			2
		);
	}
	
	$error = false;
	fclose($fp);

	// PCX - IMAGE

	$fp = @fopen($file, 'rb');

	$tmp_str = fread($fp, 3);
	
	if ((ord($tmp_str[0]) == 10) && (ord($tmp_str[1]) == 0 || ord($tmp_str[1]) == 2 || ord($tmp_str[1]) == 3 || ord($tmp_str[1]) == 4 || ord($tmp_str[1]) == 5) && (ord($tmp_str[2]) == 1))
	{
		$b = fread($fp, 1);

		if (ord($b) != 1 && ord($b) != 2 && ord($b) != 4 && ord($b) != 8 && ord($b) != 24)
		{
			$error = true;
		}

		if (!$error)
		{
			$xmin = read_word($fp);
			$ymin = read_word($fp);
			$xmax = read_word($fp);
			$ymax = read_word($fp);
			$tmp_str = fread($fp, 52);
	  
			$b = fread($fp, 1);
			if ($b != 0)
			{
				$error = true;
			}
		}

		if (!$error)
		{
			$width = $xmax - $xmin + 1;
			$height = $ymax - $ymin + 1;
		}
	}
	else
	{
		$error = true;
	}

	if (!$error)
	{
		fclose($fp);
		return array(
			$width,
			$height,
			7
		);
	}
	
	fclose($fp);

	return $size;
}

/**
* Flash MX Support
* Routines and Methods are from PhpAdsNew (www.sourceforge.net/projects/phpadsnew)
*/

/**
*/
define('swf_tag_compressed', chr(0x43).chr(0x57).chr(0x53));
define('swf_tag_identify', chr(0x46).chr(0x57).chr(0x53));

/**
* Get flash bits
*/
function swf_bits($buffer, $pos, $count)
{
	$result = 0;
	
	for ($loop = $pos; $loop < $pos + $count; $loop++)
	{
		$result = $result + ((((ord($buffer[(int)($loop / 8)])) >> (7 - ($loop % 8))) & 0x01) << ($count - ($loop - $pos) - 1));
	}

	return $result;
}

/**
* decompress flash contents
*/
function swf_decompress($buffer)
{
	if ((function_exists('gzuncompress')) && (substr($buffer, 0, 3) == swf_tag_compressed) && (ord(substr($buffer, 3, 1)) >= 6) )
	{
		// Only decompress relevant Informations
		$output  = 'F';
		$output .= substr ($buffer, 1, 7);
		$output .= gzuncompress (substr ($buffer, 8));
		
		return $output;
	}
	else
	{
		return $buffer;
	}
}

/**
* Get flash dimension
*/
function swf_getdimension($file)
{
	$size = @getimagesize($file);

	if ($size[0] != 0 || $size[1] != 0)
	{
		return $size;
	}

	// Try to get the Dimension manually
	$fp = @fopen($file, 'rb');
	if (!$fp)
	{
		return $size;
	}
	
	$error = false;

	// SWF - FLASH FILE
	$fp = @fopen($file, 'rb');

	// Decompress if file is a Flash MX compressed file
	$buffer = fread($fp, 1024);
	
	if (substr($buffer, 0, 3) == swf_tag_identify || substr($buffer, 0, 3) == swf_tag_compressed)
	{
		if (substr($buffer, 0, 3) == swf_tag_compressed)
		{
			fclose($fp);
			$fp = @fopen($file, 'rb');
			$buffer = fread($fp, filesize($file));
			$buffer = swf_decompress($buffer);
		}
	
		// Get size of rect structure
		$bits = swf_bits ($buffer, 64, 5);

		// Get rect
		$width  = (int)(swf_bits ($buffer, 69 + $bits, $bits) - swf_bits ($buffer, 69, $bits)) / 20;
		$height = (int)(swf_bits ($buffer, 69 + (3 * $bits), $bits) - swf_bits ($buffer, 69 + (2 * $bits), $bits)) / 20;
	}
	else
	{
		$error = true;
	}

	if (!$error)
	{
		fclose($fp);
		return array(
			$width,
			$height,
			2
		);
	}
	
	fclose($fp);

	return $size;
}

?>
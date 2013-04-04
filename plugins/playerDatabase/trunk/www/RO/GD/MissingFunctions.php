<?php

define('IMAGE_FLIP_VERTICAL', 1);
define('IMAGE_FLIP_HORIZONTAL', 2);
define('IMAGE_FLIP_BOTH', 3);

/**
 * Funчуo nуo implementada da GD
 * @param $img Image resource
 * @param $mode Flip mode
 * @return bool
 */
function imageflip($img, $mode) {
	$width  = imagesx($img);
	$height = imagesy($img);
	$tmp    = imagecreatetruecolor($width, $height);
	imagecopy($tmp, $img, 0, 0, 0, 0, $width, $height);
	
	if($mode & IMAGE_FLIP_VERTICAL)
		for($i = 0; $i < $height; $i++)
			imagecopy($img, $tmp, 0, $i, 0, $height - $i - 1, $width, 1);
	
	if($mode & IMAGE_FLIP_HORIZONTAL)
		for($i = 0; $i < $width; $i++)
			imagecopy($img, $tmp, $i, 0, $width - $i - 1, 0, 1, $height);

	return true;
}
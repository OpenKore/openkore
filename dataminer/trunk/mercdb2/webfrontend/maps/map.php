<?

if($_GET['posx']=="" or $_GET['posy']=="")
  exit;

if($_GET['map']=="aldebaran"){
	$posx=(($_GET['posx']))*1.08;
	$posy=((280-($_GET['posy'])))*1.08;
}elseif($_GET['map']=="payon"){
	$posx=($_GET['posx']);
	$posy=(360-($_GET['posy']));
}else{
	# $_GET['map']=="prontera"
	$posx=($_GET['posx']);
	$posy=(385-($_GET['posy']));
}

$filename=$_GET['map'].".jpg";
$im = @imagecreatefromjpeg($filename); /* Attempt to open */

if (!$im) { /* See if it failed */
   	$im  = imagecreatetruecolor(150, 30); /* Create a black image */
   	$bgc = imagecolorallocate($im, 255, 255, 255);
   	imagefilledrectangle($im, 0, 0, 150, 30, $bgc);
   	$tc  = imagecolorallocate($im, 0, 0, 0);
   	imagestring($im, 1, 5, 5, "Error loading $imgname", $tc);
   	exit;
}

if($_GET['showbot']=="active"){
	#position point
	$col = ImageColorAllocate($im,0,0,0);
	imagefilledrectangle($im, $posx-9, $posy-9, $posx+9, $posy+9, $col);
	$col = ImageColorAllocate($im,255,0,255);
	imagefilledrectangle($im, $posx-5, $posy-5, $posx+5, $posy+5, $col);
	$percent = 0.5;
	list($width, $height) = getimagesize($filename);
	$new_width = $width * $percent;
	$new_height = $height * $percent;
	$image_p = imagecreatetruecolor($new_width, $new_height);
	imagecopyresampled($image_p, $im, 0, 0, 0, 0, $new_width, $new_height, $width, $height);
	$im=$image_p;
	#black field
	$bgc = imagecolorallocate($im, 0, 0, 0);
   	imagefilledrectangle($im, 0, 0, 70, 18, $bgc);
   	#pic-type name
	$tc  = imagecolorallocate($im, 255, 255, 255);
	imagestring($im, 1, 5, 5, "Bot-Position", $tc);
	#black field
	$bgc = imagecolorallocate($im, 0, 0, 0);
   	imagefilledrectangle($im, $new_width-55, $new_height-18, $new_width, $new_height, $bgc);
   	#coordinates
	$tc  = imagecolorallocate($im, 255, 255, 255);
	imagestring($im, 1, $new_width-50, $new_height-13, "".str_pad ($_GET['posx'], 3, " ", STR_PAD_LEFT)." x ".str_pad ($_GET['posy'], 3, " ", STR_PAD_LEFT)."", $tc);
}else{
	if(isset($_GET['show']) && $_GET['show']=="map"){
		#black field
		$bgc = imagecolorallocate($im, 0, 0, 0);
   		imagefilledrectangle($im, 0, 0, 70, 18, $bgc);
   		#pic-type name
   		$tc  = imagecolorallocate($im, 255, 255, 255);
		imagestring($im, 1, 5, 5, "Map-Position", $tc);
	}else{
		#black field
		$bgc = imagecolorallocate($im, 0, 0, 0);
   		imagefilledrectangle($im, 0, 0, 74, 18, $bgc);
   		#pic-type name
   		$tc  = imagecolorallocate($im, 255, 255, 255);
		imagestring($im, 1, 5, 5, "Shop-Position", $tc);
	}
	#black field
	list($width, $height) = getimagesize($filename);
	$bgc = imagecolorallocate($im, 0, 0, 0);
   	imagefilledrectangle($im, $width-55, $height-18, $width, $height, $bgc);
   	#coordinates
	$tc  = imagecolorallocate($im, 255, 255, 255);
	imagestring($im, 1, $width-50, $height-13, "".str_pad ($_GET['posx'], 3, " ", STR_PAD_LEFT)." x ".str_pad ($_GET['posy'], 3, " ", STR_PAD_LEFT)."", $tc);
	#position point
	$col = ImageColorAllocate($im,255,0,0);
	imagefilledrectangle($im, $posx-5, $posy-5, $posx+5, $posy+5, $col);
	$col = ImageColorAllocate($im,255,255,0);
	imagefilledrectangle($im, $posx-3, $posy-3, $posx+3, $posy+3, $col);
}

// output the picture
header("Content-type: image/jpeg");
imagepng($im);

?>

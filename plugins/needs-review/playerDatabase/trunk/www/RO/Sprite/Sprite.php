<?php
/**
 * Representa um Sprite
 *
 * Representa um sprite contido na Lista de sprites (*.spr)
 *
 * @package    Sprite
 * @author     HwapX(aka Hacker_wap)
 * @copyright  2012-2013 HwapX
 * @license    http://www.php.net/license/3_01.txt  PHP License 3.01
 * @version    Release: @1.0.0@
 * @see        SpriteList
 */

namespace RO\Sprite;

class Sprite {
	private $palette = [];//TODO: armazenar uma referencia
	private $width;
	private $height;
	private $data;

	/**
	 * Cria um sprite 
	 */
	public function __construct($w, $h, $d) {
		$this->width  = $w;
		$this->height = $h;
		$this->data   = $d;
	}
	
	/**
	 * Seta a paleta de cores.
	 * @param $pal referencia a um array com as cores.
	 */
	public function setPalette(&$pal) {
		$this->palette = $pal;
	}
	
	/**
	 * Carrega a paleta de cores apatir de outro arquivo.
	 * @param $fileName nome do arquivo
	 */
	function loadPalette($fileName) {
		$f = fopen($fileName, "rb");
		for($i = 0; $i < 256; ++$i) {
			$this->palette[$i] = unpack('Cred/Cgreen/Cblue/Calpha', fread($f, 4));
		}
		fclose($f);
	}
	
	/**
	 * Retorna a largura
	 * @return int
	 */
	public function getWidth() {
		return($this->width);
	}
	
	/**
	 * Retorna a altura
	 * @return int
	 */
	public function getHeight() {
		return($this->height);
	}
	
	/**
	 * Cria a imagem apartir dos dados do Sprite.
	 */
	public function createImage() {
		$img = imagecreatetruecolor($this->width, $this->height);//http://in.php.net/manual/en/function.imagecreatetruecolor.php
		imagecolortransparent($img, imagecolorallocatealpha($img, $this->palette[0]['red'],
													   $this->palette[0]['green'],
													   $this->palette[0]['blue'],
													   $this->palette[0]['alpha']));
		$i = 0;
		$p = 0;
		while($i < strlen($this->data)) {
			$b = ord($this->data[$i]);//http://in.php.net/manual/en/function.ord.php
			if($b == 0) {
				$i++;
				$dest = $p + ord($this->data[$i]);
				$color = imagecolorallocatealpha($img, $this->palette[0]['red'],
													   $this->palette[0]['green'],
													   $this->palette[0]['blue'],
													   $this->palette[0]['alpha']);//http://in.php.net/manual/en/function.imagecolorallocatealpha.php
				for($p; $p < $dest; $p++) {
					imagesetpixel($img, $p % $this->width, $p / $this->width, $color);
				}
			} else {
				$color = imagecolorallocatealpha($img, $this->palette[$b]['red'],
													   $this->palette[$b]['green'],
													   $this->palette[$b]['blue'],
													   $this->palette[$b]['alpha']);
				imagesetpixel($img, $p % $this->width, $p / $this->width, $color);//http://in.php.net/manual/en/function.imagesetpixel.php
				$p++;
			}
			$i++;
		}
		
		return $img;
	}
	
	/**
	 * Imprime a imagem no buffer padrão setando também o header
	 */
	public function show() {
		$img = $this->createImage();
		header('content-type: ', 'image/gif');//http://in.php.net/manual/en/function.header.php
		imagegif($img);//http://in.php.net/manual/en/function.imagegif.php
		imagedestroy($img);//http://in.php.net/manual/en/function.imagedestroy.php
	}
}
?>
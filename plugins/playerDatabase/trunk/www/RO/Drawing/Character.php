<?php

namespace RO\Drawing;

use RO\Sprite\Sprite;

require("/RO/GD/MissingFunctions.php");
/**
 * Representa um personagem
 */
class Character {
	protected $body;
	protected $parts  = [];
	protected $width  = 200;
	protected $height = 200;

	/**
	 * Cria o personagem
	 * @param 
	 */
	public function __construct($body, $head) {
		$this->body = $body;
		$this->parts['head'] = $head;
	}

	/**
	 * Imprime um frame da animação do personagem
	 * @param $action_index animação desejada
	 * @param $frame_index frame da animação
	 */
	public function output($action_index, $frame_index, $filename = "") {
		$center_x = $this->width / 2;
		$center_y = $this->height / 4 * 3;
		$img = imagecreatetruecolor($this->width, $this->height);
		// Cor que vai ser usada para a transparencia
		$pink = imagecolorallocate($img, 255, 255, 255);
		
		// Deixa toda a imagem transparente
		imagefill($img, 0, 0, $pink);
		imagecolortransparent($img, $pink);
		
		//Pega o frame do corpo
		$body = $this->body->getActionList()->getAction($action_index)->getFrame($frame_index);
		
		//e os sprites que compõem ele
		$sprites = $body->getSprites();
		
		// desenha o corpo
		foreach($sprites as $s) {
			// caso o sprite seja invalido pula ele
			if($s->getIndex() < 0)
				continue;
			
			//cria a imagem
			$tmp_img = $this->body->getSpriteList()->getSprite($s->getIndex())->createImage();
			
			//espelha a imagem se necessario
			if($s->getMirror())
				imageflip($tmp_img, IMAGE_FLIP_HORIZONTAL);
			
			imagerotate($tmp_img, $s->getRotation(), $pink);
			
			// calcula a largura e altura
			$width  = $s->getWidth() ? $s->getWidth() : imagesx($tmp_img);
			$height = $s->getHeight() ? $s->getHeight() : imagesy($tmp_img);
			
			$width  *= $s->getScaleX();
			$height *= $s->getScaleY();
			
			//desenha o sprite
			imagecopyresized($img, $tmp_img, $center_x - $width / 2 + $s->getX(), $center_y - $height / 2 + $s->getY(), 0, 0, $width, $height, imagesx($tmp_img), imagesy($tmp_img));
			imagedestroy($tmp_img);
		}
		
		//desenha todas as outras partes que compõem o personagem
		foreach($this->parts as $part) {
			$frame  = $part->getActionList()->getAction($action_index)->getFrame($frame_index);
			$sprites = $frame->getSprites();
			
			foreach($sprites as $s) {
				if($s->getIndex() < 0)
					continue;
				
				$tmp_img = $part->getSpriteList()->getSprite($s->getIndex())->createImage();

				if($s->getMirror())
					imageflip($tmp_img, IMAGE_FLIP_HORIZONTAL);
				
				imagerotate($tmp_img, $s->getRotation(), $pink);
				//imagefilter($tmp_img, IMG_FILTER_COLORIZE, 255, 0, 0, 255);
				
				$width  = $s->getWidth() ? $s->getWidth() : imagesx($tmp_img);
				$height = $s->getHeight() ? $s->getHeight() : imagesy($tmp_img);
				
				$width  *= $s->getScaleX();
				$height *= $s->getScaleY();
				
				imagecopyresized($img,
								 $tmp_img,
								 $center_x + ($body->getAttachPoint(0)->getX() - $frame->getAttachPoint(0)->getX() + $s->getX()) - ($width / 2),
								 $center_y + ($body->getAttachPoint(0)->getY() - $frame->getAttachPoint(0)->getY() + $s->getY()) - ($height / 2),
								 0,
								 0,
								 $width,
								 $height,
								 imagesx($tmp_img),
								 imagesy($tmp_img));
				imagedestroy($tmp_img);
			}
		}
		
		header("Content-Type: image/gif");
		imagegif($img);
		imagedestroy($img);
	}

	public function createImage() {
		
	}

	public function setBody($value) {
		$this->body = $value;
	}
	
	public function setHat($value) {
		$this->parts['hat'] = $value;
	}
	
	public function getHat() {
		return $this->parts['hat'];
	}

	public function getBody() {
		return $this->body;
	}

	public function setHead($value) {
		$this->parts['head'] = $value;
	}

	public function getHead() {
		return $this->parts['head'];
	}

	public function setWeapon($value) {
		$this->parts['weapon'] = $value;
	}

	public function getWeapon() {
		return $this->parts['weapon'];
	}

	public function setShield($value) {
		$this->parts['shield'] = $value;
	}

	public function getShield() {
		return $this->parts['shield'];
	}

	public function setCostume($value) {
		$this->parts['costume'] = $value;
	}

	public function getCostume() {
		return $this->parts['costume'];
	}
	
	public function setWidth($value) {
		$this->width = $value;
	}
	
	public function getWidth() {
		return $this->width;
	}
	
	public function setHeight($value) {
		$this->height = $value;
	}
	
	public function getHeight() {
		return $this->height;
	}
}
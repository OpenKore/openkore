<?php
/**
 * Representa um AttachPoint
 *
 * Essa classe representa um AttachPoint de um frame
 *
 * @package    Frame
 * @author     HwapX(aka Hacker_wap)
 * @copyright  2012-2013 HwapX
 * @license    http://www.php.net/license/3_01.txt  PHP License 3.01
 * @version    Release: @0.0.0@
 * @see        Action
 */

namespace RO\Action;

/**
 * Armazena os dados para o posicionamento da imagem
 */
class AttachPoint {
	protected $x = 0;
	protected $y = 0;
	protected $attr = 0;
	protected $extra = 0;

	public function __construct($x = 0, $y = 0, $attr = 0, $extra = 0) {
		$this->x = $x;
		$this->y = $y;
		$this->attr = $attr;
		$this->extra = $extra;
	}

	/**
	 * Seta a posição no eixo  X
	 */
	public function setX($value) {
		$this->x = $value;
	}

	/**
	 * Retorna a posição no eixo X
	 */
	public function getX() {
		return $this->x;
	}

	/**
	 * Seta a posição no eixo  Y
	 */
	public function setY($value) {
		$this->y = $value;
	}

	/**
	 * Retorna a posição no eixo Y
	 */
	public function getY() {
		return $this->y;
	}

	public function setAttributes($value) {
		$this->attr = $value;
	}

	public function getAttributes() {
		return $this->attr;
	}
}
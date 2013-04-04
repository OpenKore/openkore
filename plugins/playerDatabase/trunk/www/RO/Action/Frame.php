<?php
/**
 * Representa um frame da aчуo
 *
 * Essa classe representa um frame de uma aчуo
 *
 * @package    Frame
 * @author     HwapX(aka Hacker_wap)
 * @copyright  2012-2013 HwapX
 * @license    http://www.php.net/license/3_01.txt  PHP License 3.01
 * @version    Release: @0.0.0@
 * @see        Action
 */

namespace RO\Action;

use RO\Action\Sprite;
use RO\Action\AttachPoint;

class Frame {
	protected $sprites = [];
	protected $attachPoints = [];
	protected $eventId = -1;
	
	public function addSprite($sprite) {
		$this->sprites[] = $sprite;
	}

	public function addAttachPoint($attachPoint) {
		$this->attachPoints[] = $attachPoint;
	}
	
	public function getAttachPoint($index) {
		return $this->attachPoints[$index];
	}

	public function setEventId($value) {
		$this->eventId = $value;
	}

	public function getEventId() {
		return $this->eventId;
	}
	
	public function getSprites() {
		return $this->sprites;
	}
}
?>
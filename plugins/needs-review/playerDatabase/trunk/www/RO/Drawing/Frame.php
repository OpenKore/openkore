<?php

namespace RO\Drawing;

class Frame {
	protected $sprites;

	public function __construct() {

	}

	public function addSprite($sprite, $actionSprite) {
		$this->sprites[] = array('sprite' => $sprite) + $actionSprite;
	}

	public function getSprite($index) {
		return $this->sprites[$index];
	}
}
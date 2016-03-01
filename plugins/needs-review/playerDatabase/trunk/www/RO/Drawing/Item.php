<?php

namespace RO\Drawing;

use RO\Action\ActionListFile;
use RO\Sprite\SpriteList;

class Item {
	protected $actionList;
	protected $spriteList;

	public function __construct($actionList, $spriteList) {
		$this->actionList = is_string($actionList) ? new ActionListFile($actionList) : $actionList;
		$this->spriteList = is_string($spriteList) ? new SpriteList($spriteList) : $spriteList;
	}

	public function getActionList() {
		return $this->actionList;
	}

	public function getSpriteList() {
		return $this->spriteList;
	}
}
<?php

namespace RO\Drawing;

class Animation {
	protected $frames = [];

	public function __construct($frames) {
		if(isset($frames))
			$this->frames += $frames;
	}

	public function addFrame($frame) {

	}

	public function getFrame($index) {

	}
}
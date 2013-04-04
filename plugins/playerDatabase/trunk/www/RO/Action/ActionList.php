<?php

namespace RO\Action;

interface ActionList {
	public function getAction($index);
	
	public function getCount();
	
	public function getVersion();
}
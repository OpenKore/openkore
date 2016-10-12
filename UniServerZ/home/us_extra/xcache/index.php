<?php

chdir("common");
require_once "common.php";
if (!$modules) {
	die("no sub modules' php pages installed");
}
foreach ($modules as $k => $v) {
	header("Location: $k/");
	break;
}


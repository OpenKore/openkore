<?php

require('RO/autoloader.php');

error_reporting(E_ALL);

/*set_error_handler(function ($errno, $errstr, $errfile, $errline) {
					  throw new ErrorException($errstr, 0, $errno, $errfile, $errline);
				  }, E_ALL);

set_exception_handler(function ($exception) {
						echo htmlentities($exception->getMessage());
					  });*/
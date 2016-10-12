<?php

// DO NOT rename/delete/modify example file which will be overwritten when upgrade
// How To Custom Config:
// 1. copy config.example.php config.php; edit config.php
// 2. upgrading your config.php when config.example.php were upgraded
// XCache will load
// 1. ../config.default.php
// 2. ./config.default.php
// 3. ../config.php
// 4. ./config.php

// $config['include_paths'] = array("/www/my-php-project/");
// $config['exclude_paths'] = array("/www/my-php-project/tmp/");
$config['syntax_higlight'] = true;
$config['use_cache'] = false;
//// $config['datadir'] is default to ini_get("xcache.coveragedump_directory")
// $config['datadir'] = '';


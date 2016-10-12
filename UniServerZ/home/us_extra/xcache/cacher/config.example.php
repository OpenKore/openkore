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

// width of graph for free or usage blocks
$config['percent_graph_width'] = 120;
$config['percent_graph_type'] = 'used'; // either 'used' or 'free'

// only enable if you have password protection for admin page
// enabling this option will cause user to eval() whatever code they want
$config['enable_eval'] = false;


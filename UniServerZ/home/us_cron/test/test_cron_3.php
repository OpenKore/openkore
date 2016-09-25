<?php
// This file is used only for testing.
// Enable block [Test_cron_3] in Cron configuration file cron.ini

$path_array  = explode("\\us_cron",dirname(__FILE__));    // Split at folder us_cron
$base        = "$path_array[0]";                          // find drive letter and any sub-folders 
$base_f      = preg_replace('/\\\/','/', $base);          // Replace \ with /

define("UF_us_cron", "$base_f/us_cron/test/test_cron_3_php_result.txt");
file_put_contents(UF_us_cron, "Cron test 3 PHP CLI script\r\n", FILE_APPEND);
?>

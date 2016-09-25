<?php
// This file is used only for testing.
// Copy this file to folder www
// Enable block [Test_cron_4] in Cron configuration file cron.ini
//
$file     = 'us_cron_test_4.txt';
$current  = file_get_contents($file);     // Open file, get existing content
$current .= date("D M j G:i:s T Y")."\n"; // Append a new Date and Time to the file
file_put_contents($file, $current);       // Write contents back to the file
?>
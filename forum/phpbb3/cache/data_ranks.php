<?php
$expired = (time() > 1238590459) ? true : false;
if ($expired) { return; }

$data = array (
  'special' => 
  array (
    1 => 
    array (
      'rank_title' => 'Administrator',
      'rank_image' => '',
    ),
    2 => 
    array (
      'rank_title' => 'Global Moderator',
      'rank_image' => '',
    ),
    3 => 
    array (
      'rank_title' => 'Moderator',
      'rank_image' => '',
    ),
    4 => 
    array (
      'rank_title' => 'Sub-Moderator',
      'rank_image' => '',
    ),
    5 => 
    array (
      'rank_title' => 'OpenKore Partner',
      'rank_image' => '',
    ),
    6 => 
    array (
      'rank_title' => 'Developer',
      'rank_image' => '',
    ),
  ),
);
?>
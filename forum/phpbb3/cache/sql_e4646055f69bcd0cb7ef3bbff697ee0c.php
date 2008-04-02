<?php

/* SELECT forum_id, forum_name, parent_id, forum_type, left_id, right_id FROM phpbb3_forums ORDER BY left_id ASC */

$expired = (time() > 1207117741) ? true : false;
if ($expired) { return; }

$this->sql_rowset[$query_id] = array (
  0 => 
  array (
    'forum_id' => '3',
    'forum_name' => 'Announcements',
    'parent_id' => '0',
    'forum_type' => '0',
    'left_id' => '1',
    'right_id' => '4',
  ),
  1 => 
  array (
    'forum_id' => '4',
    'forum_name' => 'Announcements',
    'parent_id' => '3',
    'forum_type' => '1',
    'left_id' => '2',
    'right_id' => '3',
  ),
  2 => 
  array (
    'forum_id' => '5',
    'forum_name' => 'Support',
    'parent_id' => '0',
    'forum_type' => '0',
    'left_id' => '5',
    'right_id' => '48',
  ),
  3 => 
  array (
    'forum_id' => '6',
    'forum_name' => 'Frequently Asked Questions',
    'parent_id' => '5',
    'forum_type' => '1',
    'left_id' => '6',
    'right_id' => '7',
  ),
  4 => 
  array (
    'forum_id' => '7',
    'forum_name' => 'Resolved Questions',
    'parent_id' => '5',
    'forum_type' => '1',
    'left_id' => '8',
    'right_id' => '9',
  ),
  5 => 
  array (
    'forum_id' => '8',
    'forum_name' => 'Official Servers',
    'parent_id' => '5',
    'forum_type' => '0',
    'left_id' => '10',
    'right_id' => '31',
  ),
  6 => 
  array (
    'forum_id' => '9',
    'forum_name' => 'bRO',
    'parent_id' => '8',
    'forum_type' => '1',
    'left_id' => '11',
    'right_id' => '12',
  ),
  7 => 
  array (
    'forum_id' => '10',
    'forum_name' => 'pRO',
    'parent_id' => '8',
    'forum_type' => '1',
    'left_id' => '13',
    'right_id' => '14',
  ),
  8 => 
  array (
    'forum_id' => '11',
    'forum_name' => 'idRO',
    'parent_id' => '8',
    'forum_type' => '1',
    'left_id' => '15',
    'right_id' => '16',
  ),
  9 => 
  array (
    'forum_id' => '12',
    'forum_name' => 'euRO',
    'parent_id' => '8',
    'forum_type' => '1',
    'left_id' => '17',
    'right_id' => '18',
  ),
  10 => 
  array (
    'forum_id' => '13',
    'forum_name' => 'mRO',
    'parent_id' => '8',
    'forum_type' => '1',
    'left_id' => '19',
    'right_id' => '20',
  ),
  11 => 
  array (
    'forum_id' => '14',
    'forum_name' => 'iRO',
    'parent_id' => '8',
    'forum_type' => '1',
    'left_id' => '21',
    'right_id' => '22',
  ),
  12 => 
  array (
    'forum_id' => '15',
    'forum_name' => 'vRO',
    'parent_id' => '8',
    'forum_type' => '1',
    'left_id' => '23',
    'right_id' => '24',
  ),
  13 => 
  array (
    'forum_id' => '16',
    'forum_name' => 'kRO',
    'parent_id' => '8',
    'forum_type' => '1',
    'left_id' => '25',
    'right_id' => '26',
  ),
  14 => 
  array (
    'forum_id' => '17',
    'forum_name' => 'inRO',
    'parent_id' => '8',
    'forum_type' => '1',
    'left_id' => '27',
    'right_id' => '28',
  ),
  15 => 
  array (
    'forum_id' => '18',
    'forum_name' => 'Other official servers',
    'parent_id' => '8',
    'forum_type' => '1',
    'left_id' => '29',
    'right_id' => '30',
  ),
  16 => 
  array (
    'forum_id' => '19',
    'forum_name' => 'Private Servers',
    'parent_id' => '5',
    'forum_type' => '0',
    'left_id' => '32',
    'right_id' => '45',
  ),
  17 => 
  array (
    'forum_id' => '20',
    'forum_name' => 'AnthemRO',
    'parent_id' => '19',
    'forum_type' => '1',
    'left_id' => '33',
    'right_id' => '34',
  ),
  18 => 
  array (
    'forum_id' => '21',
    'forum_name' => 'AncientRO',
    'parent_id' => '19',
    'forum_type' => '1',
    'left_id' => '35',
    'right_id' => '36',
  ),
  19 => 
  array (
    'forum_id' => '22',
    'forum_name' => 'LegacyRO',
    'parent_id' => '19',
    'forum_type' => '1',
    'left_id' => '37',
    'right_id' => '38',
  ),
  20 => 
  array (
    'forum_id' => '23',
    'forum_name' => 'TrinityRO',
    'parent_id' => '19',
    'forum_type' => '1',
    'left_id' => '39',
    'right_id' => '40',
  ),
  21 => 
  array (
    'forum_id' => '24',
    'forum_name' => 'XileRO',
    'parent_id' => '19',
    'forum_type' => '1',
    'left_id' => '41',
    'right_id' => '42',
  ),
  22 => 
  array (
    'forum_id' => '25',
    'forum_name' => 'Other private servers',
    'parent_id' => '19',
    'forum_type' => '1',
    'left_id' => '43',
    'right_id' => '44',
  ),
  23 => 
  array (
    'forum_id' => '26',
    'forum_name' => 'Other OpenKore &amp; VisualKore Support',
    'parent_id' => '5',
    'forum_type' => '1',
    'left_id' => '46',
    'right_id' => '47',
  ),
  24 => 
  array (
    'forum_id' => '27',
    'forum_name' => 'Discussion',
    'parent_id' => '0',
    'forum_type' => '0',
    'left_id' => '49',
    'right_id' => '56',
  ),
  25 => 
  array (
    'forum_id' => '28',
    'forum_name' => 'Discussion',
    'parent_id' => '27',
    'forum_type' => '1',
    'left_id' => '50',
    'right_id' => '51',
  ),
  26 => 
  array (
    'forum_id' => '29',
    'forum_name' => 'Botting Tips &amp; Tricks',
    'parent_id' => '27',
    'forum_type' => '1',
    'left_id' => '52',
    'right_id' => '53',
  ),
  27 => 
  array (
    'forum_id' => '30',
    'forum_name' => 'Feature suggestions',
    'parent_id' => '27',
    'forum_type' => '1',
    'left_id' => '54',
    'right_id' => '55',
  ),
  28 => 
  array (
    'forum_id' => '31',
    'forum_name' => 'Plugins',
    'parent_id' => '0',
    'forum_type' => '0',
    'left_id' => '57',
    'right_id' => '66',
  ),
  29 => 
  array (
    'forum_id' => '32',
    'forum_name' => 'Howto write plugins',
    'parent_id' => '31',
    'forum_type' => '2',
    'left_id' => '58',
    'right_id' => '59',
  ),
  30 => 
  array (
    'forum_id' => '33',
    'forum_name' => 'Macro plugin',
    'parent_id' => '31',
    'forum_type' => '1',
    'left_id' => '60',
    'right_id' => '63',
  ),
  31 => 
  array (
    'forum_id' => '34',
    'forum_name' => 'Share your macro\'s',
    'parent_id' => '33',
    'forum_type' => '1',
    'left_id' => '61',
    'right_id' => '62',
  ),
  32 => 
  array (
    'forum_id' => '35',
    'forum_name' => 'Other Plugins',
    'parent_id' => '31',
    'forum_type' => '1',
    'left_id' => '64',
    'right_id' => '65',
  ),
  33 => 
  array (
    'forum_id' => '36',
    'forum_name' => 'Development',
    'parent_id' => '0',
    'forum_type' => '0',
    'left_id' => '67',
    'right_id' => '74',
  ),
  34 => 
  array (
    'forum_id' => '37',
    'forum_name' => 'Developer Corner',
    'parent_id' => '36',
    'forum_type' => '1',
    'left_id' => '68',
    'right_id' => '69',
  ),
  35 => 
  array (
    'forum_id' => '38',
    'forum_name' => 'Development Help',
    'parent_id' => '36',
    'forum_type' => '1',
    'left_id' => '70',
    'right_id' => '71',
  ),
  36 => 
  array (
    'forum_id' => '39',
    'forum_name' => 'Tester\'s corner',
    'parent_id' => '36',
    'forum_type' => '1',
    'left_id' => '72',
    'right_id' => '73',
  ),
  37 => 
  array (
    'forum_id' => '40',
    'forum_name' => 'Off Topic',
    'parent_id' => '0',
    'forum_type' => '0',
    'left_id' => '75',
    'right_id' => '80',
  ),
  38 => 
  array (
    'forum_id' => '41',
    'forum_name' => 'Trashcan',
    'parent_id' => '40',
    'forum_type' => '1',
    'left_id' => '76',
    'right_id' => '77',
  ),
  39 => 
  array (
    'forum_id' => '42',
    'forum_name' => 'Misc',
    'parent_id' => '40',
    'forum_type' => '1',
    'left_id' => '78',
    'right_id' => '79',
  ),
  40 => 
  array (
    'forum_id' => '43',
    'forum_name' => 'Internal',
    'parent_id' => '0',
    'forum_type' => '0',
    'left_id' => '81',
    'right_id' => '92',
  ),
  41 => 
  array (
    'forum_id' => '44',
    'forum_name' => 'Moderator\'s Lounge',
    'parent_id' => '43',
    'forum_type' => '1',
    'left_id' => '82',
    'right_id' => '83',
  ),
  42 => 
  array (
    'forum_id' => '45',
    'forum_name' => 'Documentor\'s Office',
    'parent_id' => '43',
    'forum_type' => '1',
    'left_id' => '84',
    'right_id' => '85',
  ),
  43 => 
  array (
    'forum_id' => '46',
    'forum_name' => 'Admins &amp; Global Moderators',
    'parent_id' => '43',
    'forum_type' => '1',
    'left_id' => '86',
    'right_id' => '87',
  ),
  44 => 
  array (
    'forum_id' => '48',
    'forum_name' => 'Secret Stuff',
    'parent_id' => '43',
    'forum_type' => '1',
    'left_id' => '88',
    'right_id' => '89',
  ),
  45 => 
  array (
    'forum_id' => '47',
    'forum_name' => 'Archive',
    'parent_id' => '43',
    'forum_type' => '1',
    'left_id' => '90',
    'right_id' => '91',
  ),
  46 => 
  array (
    'forum_id' => '49',
    'forum_name' => 'Links',
    'parent_id' => '0',
    'forum_type' => '0',
    'left_id' => '93',
    'right_id' => '104',
  ),
  47 => 
  array (
    'forum_id' => '50',
    'forum_name' => 'OpenKore Manual',
    'parent_id' => '49',
    'forum_type' => '2',
    'left_id' => '94',
    'right_id' => '95',
  ),
  48 => 
  array (
    'forum_id' => '51',
    'forum_name' => 'Developer Manual',
    'parent_id' => '49',
    'forum_type' => '2',
    'left_id' => '96',
    'right_id' => '97',
  ),
  49 => 
  array (
    'forum_id' => '52',
    'forum_name' => 'SVN Mirror #1',
    'parent_id' => '49',
    'forum_type' => '2',
    'left_id' => '98',
    'right_id' => '99',
  ),
  50 => 
  array (
    'forum_id' => '53',
    'forum_name' => 'SVN Mirror #2',
    'parent_id' => '49',
    'forum_type' => '2',
    'left_id' => '100',
    'right_id' => '101',
  ),
  51 => 
  array (
    'forum_id' => '54',
    'forum_name' => 'Java IRC Client',
    'parent_id' => '49',
    'forum_type' => '2',
    'left_id' => '102',
    'right_id' => '103',
  ),
);
?>
<?php
$expired = (time() > 1238589365) ? true : false;
if ($expired) { return; }

$data = array (
  'modules' => 
  array (
    0 => 
    array (
      'module_id' => '163',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'ucp',
      'parent_id' => '0',
      'left_id' => '1',
      'right_id' => '12',
      'module_langname' => 'UCP_MAIN',
      'module_mode' => '',
      'module_auth' => '',
    ),
    1 => 
    array (
      'module_id' => '172',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'main',
      'module_class' => 'ucp',
      'parent_id' => '163',
      'left_id' => '2',
      'right_id' => '3',
      'module_langname' => 'UCP_MAIN_FRONT',
      'module_mode' => 'front',
      'module_auth' => '',
    ),
    2 => 
    array (
      'module_id' => '173',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'main',
      'module_class' => 'ucp',
      'parent_id' => '163',
      'left_id' => '4',
      'right_id' => '5',
      'module_langname' => 'UCP_MAIN_SUBSCRIBED',
      'module_mode' => 'subscribed',
      'module_auth' => '',
    ),
    3 => 
    array (
      'module_id' => '174',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'main',
      'module_class' => 'ucp',
      'parent_id' => '163',
      'left_id' => '6',
      'right_id' => '7',
      'module_langname' => 'UCP_MAIN_BOOKMARKS',
      'module_mode' => 'bookmarks',
      'module_auth' => 'cfg_allow_bookmarks',
    ),
    4 => 
    array (
      'module_id' => '175',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'main',
      'module_class' => 'ucp',
      'parent_id' => '163',
      'left_id' => '8',
      'right_id' => '9',
      'module_langname' => 'UCP_MAIN_DRAFTS',
      'module_mode' => 'drafts',
      'module_auth' => '',
    ),
    5 => 
    array (
      'module_id' => '169',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'attachments',
      'module_class' => 'ucp',
      'parent_id' => '163',
      'left_id' => '10',
      'right_id' => '11',
      'module_langname' => 'UCP_MAIN_ATTACHMENTS',
      'module_mode' => 'attachments',
      'module_auth' => 'acl_u_attach',
    ),
    6 => 
    array (
      'module_id' => '164',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'ucp',
      'parent_id' => '0',
      'left_id' => '13',
      'right_id' => '22',
      'module_langname' => 'UCP_PROFILE',
      'module_mode' => '',
      'module_auth' => '',
    ),
    7 => 
    array (
      'module_id' => '184',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'profile',
      'module_class' => 'ucp',
      'parent_id' => '164',
      'left_id' => '14',
      'right_id' => '15',
      'module_langname' => 'UCP_PROFILE_PROFILE_INFO',
      'module_mode' => 'profile_info',
      'module_auth' => '',
    ),
    8 => 
    array (
      'module_id' => '185',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'profile',
      'module_class' => 'ucp',
      'parent_id' => '164',
      'left_id' => '16',
      'right_id' => '17',
      'module_langname' => 'UCP_PROFILE_SIGNATURE',
      'module_mode' => 'signature',
      'module_auth' => '',
    ),
    9 => 
    array (
      'module_id' => '186',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'profile',
      'module_class' => 'ucp',
      'parent_id' => '164',
      'left_id' => '18',
      'right_id' => '19',
      'module_langname' => 'UCP_PROFILE_AVATAR',
      'module_mode' => 'avatar',
      'module_auth' => '',
    ),
    10 => 
    array (
      'module_id' => '187',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'profile',
      'module_class' => 'ucp',
      'parent_id' => '164',
      'left_id' => '20',
      'right_id' => '21',
      'module_langname' => 'UCP_PROFILE_REG_DETAILS',
      'module_mode' => 'reg_details',
      'module_auth' => '',
    ),
    11 => 
    array (
      'module_id' => '165',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'ucp',
      'parent_id' => '0',
      'left_id' => '23',
      'right_id' => '30',
      'module_langname' => 'UCP_PREFS',
      'module_mode' => '',
      'module_auth' => '',
    ),
    12 => 
    array (
      'module_id' => '181',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'prefs',
      'module_class' => 'ucp',
      'parent_id' => '165',
      'left_id' => '24',
      'right_id' => '25',
      'module_langname' => 'UCP_PREFS_PERSONAL',
      'module_mode' => 'personal',
      'module_auth' => '',
    ),
    13 => 
    array (
      'module_id' => '182',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'prefs',
      'module_class' => 'ucp',
      'parent_id' => '165',
      'left_id' => '26',
      'right_id' => '27',
      'module_langname' => 'UCP_PREFS_POST',
      'module_mode' => 'post',
      'module_auth' => '',
    ),
    14 => 
    array (
      'module_id' => '183',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'prefs',
      'module_class' => 'ucp',
      'parent_id' => '165',
      'left_id' => '28',
      'right_id' => '29',
      'module_langname' => 'UCP_PREFS_VIEW',
      'module_mode' => 'view',
      'module_auth' => '',
    ),
    15 => 
    array (
      'module_id' => '166',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'ucp',
      'parent_id' => '0',
      'left_id' => '31',
      'right_id' => '42',
      'module_langname' => 'UCP_PM',
      'module_mode' => '',
      'module_auth' => '',
    ),
    16 => 
    array (
      'module_id' => '176',
      'module_enabled' => '1',
      'module_display' => '0',
      'module_basename' => 'pm',
      'module_class' => 'ucp',
      'parent_id' => '166',
      'left_id' => '32',
      'right_id' => '33',
      'module_langname' => 'UCP_PM_VIEW',
      'module_mode' => 'view',
      'module_auth' => 'cfg_allow_privmsg',
    ),
    17 => 
    array (
      'module_id' => '177',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'pm',
      'module_class' => 'ucp',
      'parent_id' => '166',
      'left_id' => '34',
      'right_id' => '35',
      'module_langname' => 'UCP_PM_COMPOSE',
      'module_mode' => 'compose',
      'module_auth' => 'cfg_allow_privmsg',
    ),
    18 => 
    array (
      'module_id' => '178',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'pm',
      'module_class' => 'ucp',
      'parent_id' => '166',
      'left_id' => '36',
      'right_id' => '37',
      'module_langname' => 'UCP_PM_DRAFTS',
      'module_mode' => 'drafts',
      'module_auth' => 'cfg_allow_privmsg',
    ),
    19 => 
    array (
      'module_id' => '179',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'pm',
      'module_class' => 'ucp',
      'parent_id' => '166',
      'left_id' => '38',
      'right_id' => '39',
      'module_langname' => 'UCP_PM_OPTIONS',
      'module_mode' => 'options',
      'module_auth' => 'cfg_allow_privmsg',
    ),
    20 => 
    array (
      'module_id' => '180',
      'module_enabled' => '1',
      'module_display' => '0',
      'module_basename' => 'pm',
      'module_class' => 'ucp',
      'parent_id' => '166',
      'left_id' => '40',
      'right_id' => '41',
      'module_langname' => 'UCP_PM_POPUP_TITLE',
      'module_mode' => 'popup',
      'module_auth' => 'cfg_allow_privmsg',
    ),
    21 => 
    array (
      'module_id' => '167',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'ucp',
      'parent_id' => '0',
      'left_id' => '43',
      'right_id' => '48',
      'module_langname' => 'UCP_USERGROUPS',
      'module_mode' => '',
      'module_auth' => '',
    ),
    22 => 
    array (
      'module_id' => '170',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'groups',
      'module_class' => 'ucp',
      'parent_id' => '167',
      'left_id' => '44',
      'right_id' => '45',
      'module_langname' => 'UCP_USERGROUPS_MEMBER',
      'module_mode' => 'membership',
      'module_auth' => '',
    ),
    23 => 
    array (
      'module_id' => '171',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'groups',
      'module_class' => 'ucp',
      'parent_id' => '167',
      'left_id' => '46',
      'right_id' => '47',
      'module_langname' => 'UCP_USERGROUPS_MANAGE',
      'module_mode' => 'manage',
      'module_auth' => '',
    ),
    24 => 
    array (
      'module_id' => '168',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'ucp',
      'parent_id' => '0',
      'left_id' => '49',
      'right_id' => '54',
      'module_langname' => 'UCP_ZEBRA',
      'module_mode' => '',
      'module_auth' => '',
    ),
    25 => 
    array (
      'module_id' => '188',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'zebra',
      'module_class' => 'ucp',
      'parent_id' => '168',
      'left_id' => '50',
      'right_id' => '51',
      'module_langname' => 'UCP_ZEBRA_FRIENDS',
      'module_mode' => 'friends',
      'module_auth' => '',
    ),
    26 => 
    array (
      'module_id' => '189',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'zebra',
      'module_class' => 'ucp',
      'parent_id' => '168',
      'left_id' => '52',
      'right_id' => '53',
      'module_langname' => 'UCP_ZEBRA_FOES',
      'module_mode' => 'foes',
      'module_auth' => '',
    ),
  ),
  'parents' => 
  array (
    163 => 
    array (
    ),
    172 => 
    array (
      163 => '0',
    ),
    173 => 
    array (
      163 => '0',
    ),
    174 => 
    array (
      163 => '0',
    ),
    175 => 
    array (
      163 => '0',
    ),
    169 => 
    array (
      163 => '0',
    ),
    164 => 
    array (
    ),
    184 => 
    array (
      164 => '0',
    ),
    185 => 
    array (
      164 => '0',
    ),
    186 => 
    array (
      164 => '0',
    ),
    187 => 
    array (
      164 => '0',
    ),
    165 => 
    array (
    ),
    181 => 
    array (
      165 => '0',
    ),
    182 => 
    array (
      165 => '0',
    ),
    183 => 
    array (
      165 => '0',
    ),
    166 => 
    array (
    ),
    176 => 
    array (
      166 => '0',
    ),
    177 => 
    array (
      166 => '0',
    ),
    178 => 
    array (
      166 => '0',
    ),
    179 => 
    array (
      166 => '0',
    ),
    180 => 
    array (
      166 => '0',
    ),
    167 => 
    array (
    ),
    170 => 
    array (
      167 => '0',
    ),
    171 => 
    array (
      167 => '0',
    ),
    168 => 
    array (
    ),
    188 => 
    array (
      168 => '0',
    ),
    189 => 
    array (
      168 => '0',
    ),
  ),
);
?>
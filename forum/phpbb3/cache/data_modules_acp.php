<?php
$expired = (time() > 1238589308) ? true : false;
if ($expired) { return; }

$data = array (
  'modules' => 
  array (
    0 => 
    array (
      'module_id' => '1',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '0',
      'left_id' => '1',
      'right_id' => '60',
      'module_langname' => 'ACP_CAT_GENERAL',
      'module_mode' => '',
      'module_auth' => '',
    ),
    1 => 
    array (
      'module_id' => '73',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'main',
      'module_class' => 'acp',
      'parent_id' => '1',
      'left_id' => '2',
      'right_id' => '3',
      'module_langname' => 'ACP_INDEX',
      'module_mode' => 'main',
      'module_auth' => '',
    ),
    2 => 
    array (
      'module_id' => '2',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '1',
      'left_id' => '4',
      'right_id' => '17',
      'module_langname' => 'ACP_QUICK_ACCESS',
      'module_mode' => '',
      'module_auth' => '',
    ),
    3 => 
    array (
      'module_id' => '124',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'users',
      'module_class' => 'acp',
      'parent_id' => '2',
      'left_id' => '5',
      'right_id' => '6',
      'module_langname' => 'ACP_MANAGE_USERS',
      'module_mode' => 'overview',
      'module_auth' => 'acl_a_user',
    ),
    4 => 
    array (
      'module_id' => '125',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'groups',
      'module_class' => 'acp',
      'parent_id' => '2',
      'left_id' => '7',
      'right_id' => '8',
      'module_langname' => 'ACP_GROUPS_MANAGE',
      'module_mode' => 'manage',
      'module_auth' => 'acl_a_group',
    ),
    5 => 
    array (
      'module_id' => '126',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'forums',
      'module_class' => 'acp',
      'parent_id' => '2',
      'left_id' => '9',
      'right_id' => '10',
      'module_langname' => 'ACP_MANAGE_FORUMS',
      'module_mode' => 'manage',
      'module_auth' => 'acl_a_forum',
    ),
    6 => 
    array (
      'module_id' => '127',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'logs',
      'module_class' => 'acp',
      'parent_id' => '2',
      'left_id' => '11',
      'right_id' => '12',
      'module_langname' => 'ACP_MOD_LOGS',
      'module_mode' => 'mod',
      'module_auth' => 'acl_a_viewlogs',
    ),
    7 => 
    array (
      'module_id' => '128',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'bots',
      'module_class' => 'acp',
      'parent_id' => '2',
      'left_id' => '13',
      'right_id' => '14',
      'module_langname' => 'ACP_BOTS',
      'module_mode' => 'bots',
      'module_auth' => 'acl_a_bots',
    ),
    8 => 
    array (
      'module_id' => '129',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'php_info',
      'module_class' => 'acp',
      'parent_id' => '2',
      'left_id' => '15',
      'right_id' => '16',
      'module_langname' => 'ACP_PHP_INFO',
      'module_mode' => 'info',
      'module_auth' => 'acl_a_phpinfo',
    ),
    9 => 
    array (
      'module_id' => '3',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '1',
      'left_id' => '18',
      'right_id' => '39',
      'module_langname' => 'ACP_BOARD_CONFIGURATION',
      'module_mode' => '',
      'module_auth' => '',
    ),
    10 => 
    array (
      'module_id' => '32',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'attachments',
      'module_class' => 'acp',
      'parent_id' => '3',
      'left_id' => '19',
      'right_id' => '20',
      'module_langname' => 'ACP_ATTACHMENT_SETTINGS',
      'module_mode' => 'attach',
      'module_auth' => 'acl_a_attach',
    ),
    11 => 
    array (
      'module_id' => '41',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'board',
      'module_class' => 'acp',
      'parent_id' => '3',
      'left_id' => '21',
      'right_id' => '22',
      'module_langname' => 'ACP_BOARD_SETTINGS',
      'module_mode' => 'settings',
      'module_auth' => 'acl_a_board',
    ),
    12 => 
    array (
      'module_id' => '42',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'board',
      'module_class' => 'acp',
      'parent_id' => '3',
      'left_id' => '23',
      'right_id' => '24',
      'module_langname' => 'ACP_BOARD_FEATURES',
      'module_mode' => 'features',
      'module_auth' => 'acl_a_board',
    ),
    13 => 
    array (
      'module_id' => '43',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'board',
      'module_class' => 'acp',
      'parent_id' => '3',
      'left_id' => '25',
      'right_id' => '26',
      'module_langname' => 'ACP_AVATAR_SETTINGS',
      'module_mode' => 'avatar',
      'module_auth' => 'acl_a_board',
    ),
    14 => 
    array (
      'module_id' => '44',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'board',
      'module_class' => 'acp',
      'parent_id' => '3',
      'left_id' => '27',
      'right_id' => '28',
      'module_langname' => 'ACP_MESSAGE_SETTINGS',
      'module_mode' => 'message',
      'module_auth' => 'acl_a_board',
    ),
    15 => 
    array (
      'module_id' => '46',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'board',
      'module_class' => 'acp',
      'parent_id' => '3',
      'left_id' => '29',
      'right_id' => '30',
      'module_langname' => 'ACP_POST_SETTINGS',
      'module_mode' => 'post',
      'module_auth' => 'acl_a_board',
    ),
    16 => 
    array (
      'module_id' => '47',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'board',
      'module_class' => 'acp',
      'parent_id' => '3',
      'left_id' => '31',
      'right_id' => '32',
      'module_langname' => 'ACP_SIGNATURE_SETTINGS',
      'module_mode' => 'signature',
      'module_auth' => 'acl_a_board',
    ),
    17 => 
    array (
      'module_id' => '48',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'board',
      'module_class' => 'acp',
      'parent_id' => '3',
      'left_id' => '33',
      'right_id' => '34',
      'module_langname' => 'ACP_REGISTER_SETTINGS',
      'module_mode' => 'registration',
      'module_auth' => 'acl_a_board',
    ),
    18 => 
    array (
      'module_id' => '56',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'captcha',
      'module_class' => 'acp',
      'parent_id' => '3',
      'left_id' => '35',
      'right_id' => '36',
      'module_langname' => 'ACP_VC_SETTINGS',
      'module_mode' => 'visual',
      'module_auth' => 'acl_a_board',
    ),
    19 => 
    array (
      'module_id' => '57',
      'module_enabled' => '1',
      'module_display' => '0',
      'module_basename' => 'captcha',
      'module_class' => 'acp',
      'parent_id' => '3',
      'left_id' => '37',
      'right_id' => '38',
      'module_langname' => 'ACP_VC_CAPTCHA_DISPLAY',
      'module_mode' => 'img',
      'module_auth' => 'acl_a_board',
    ),
    20 => 
    array (
      'module_id' => '4',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '1',
      'left_id' => '40',
      'right_id' => '47',
      'module_langname' => 'ACP_CLIENT_COMMUNICATION',
      'module_mode' => '',
      'module_auth' => '',
    ),
    21 => 
    array (
      'module_id' => '49',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'board',
      'module_class' => 'acp',
      'parent_id' => '4',
      'left_id' => '41',
      'right_id' => '42',
      'module_langname' => 'ACP_AUTH_SETTINGS',
      'module_mode' => 'auth',
      'module_auth' => 'acl_a_server',
    ),
    22 => 
    array (
      'module_id' => '50',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'board',
      'module_class' => 'acp',
      'parent_id' => '4',
      'left_id' => '43',
      'right_id' => '44',
      'module_langname' => 'ACP_EMAIL_SETTINGS',
      'module_mode' => 'email',
      'module_auth' => 'acl_a_server',
    ),
    23 => 
    array (
      'module_id' => '67',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'jabber',
      'module_class' => 'acp',
      'parent_id' => '4',
      'left_id' => '45',
      'right_id' => '46',
      'module_langname' => 'ACP_JABBER_SETTINGS',
      'module_mode' => 'settings',
      'module_auth' => 'acl_a_jabber',
    ),
    24 => 
    array (
      'module_id' => '5',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '1',
      'left_id' => '48',
      'right_id' => '59',
      'module_langname' => 'ACP_SERVER_CONFIGURATION',
      'module_mode' => '',
      'module_auth' => '',
    ),
    25 => 
    array (
      'module_id' => '51',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'board',
      'module_class' => 'acp',
      'parent_id' => '5',
      'left_id' => '49',
      'right_id' => '50',
      'module_langname' => 'ACP_COOKIE_SETTINGS',
      'module_mode' => 'cookie',
      'module_auth' => 'acl_a_server',
    ),
    26 => 
    array (
      'module_id' => '52',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'board',
      'module_class' => 'acp',
      'parent_id' => '5',
      'left_id' => '51',
      'right_id' => '52',
      'module_langname' => 'ACP_SERVER_SETTINGS',
      'module_mode' => 'server',
      'module_auth' => 'acl_a_server',
    ),
    27 => 
    array (
      'module_id' => '53',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'board',
      'module_class' => 'acp',
      'parent_id' => '5',
      'left_id' => '53',
      'right_id' => '54',
      'module_langname' => 'ACP_SECURITY_SETTINGS',
      'module_mode' => 'security',
      'module_auth' => 'acl_a_server',
    ),
    28 => 
    array (
      'module_id' => '54',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'board',
      'module_class' => 'acp',
      'parent_id' => '5',
      'left_id' => '55',
      'right_id' => '56',
      'module_langname' => 'ACP_LOAD_SETTINGS',
      'module_mode' => 'load',
      'module_auth' => 'acl_a_server',
    ),
    29 => 
    array (
      'module_id' => '106',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'search',
      'module_class' => 'acp',
      'parent_id' => '5',
      'left_id' => '57',
      'right_id' => '58',
      'module_langname' => 'ACP_SEARCH_SETTINGS',
      'module_mode' => 'settings',
      'module_auth' => 'acl_a_search',
    ),
    30 => 
    array (
      'module_id' => '6',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '0',
      'left_id' => '61',
      'right_id' => '78',
      'module_langname' => 'ACP_CAT_FORUMS',
      'module_mode' => '',
      'module_auth' => '',
    ),
    31 => 
    array (
      'module_id' => '7',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '6',
      'left_id' => '62',
      'right_id' => '67',
      'module_langname' => 'ACP_MANAGE_FORUMS',
      'module_mode' => '',
      'module_auth' => '',
    ),
    32 => 
    array (
      'module_id' => '62',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'forums',
      'module_class' => 'acp',
      'parent_id' => '7',
      'left_id' => '63',
      'right_id' => '64',
      'module_langname' => 'ACP_MANAGE_FORUMS',
      'module_mode' => 'manage',
      'module_auth' => 'acl_a_forum',
    ),
    33 => 
    array (
      'module_id' => '102',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'prune',
      'module_class' => 'acp',
      'parent_id' => '7',
      'left_id' => '65',
      'right_id' => '66',
      'module_langname' => 'ACP_PRUNE_FORUMS',
      'module_mode' => 'forums',
      'module_auth' => 'acl_a_prune',
    ),
    34 => 
    array (
      'module_id' => '8',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '6',
      'left_id' => '68',
      'right_id' => '77',
      'module_langname' => 'ACP_FORUM_BASED_PERMISSIONS',
      'module_mode' => '',
      'module_auth' => '',
    ),
    35 => 
    array (
      'module_id' => '130',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '8',
      'left_id' => '69',
      'right_id' => '70',
      'module_langname' => 'ACP_FORUM_PERMISSIONS',
      'module_mode' => 'setting_forum_local',
      'module_auth' => 'acl_a_fauth && (acl_a_authusers || acl_a_authgroups)',
    ),
    36 => 
    array (
      'module_id' => '131',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '8',
      'left_id' => '71',
      'right_id' => '72',
      'module_langname' => 'ACP_FORUM_MODERATORS',
      'module_mode' => 'setting_mod_local',
      'module_auth' => 'acl_a_mauth && (acl_a_authusers || acl_a_authgroups)',
    ),
    37 => 
    array (
      'module_id' => '132',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '8',
      'left_id' => '73',
      'right_id' => '74',
      'module_langname' => 'ACP_USERS_FORUM_PERMISSIONS',
      'module_mode' => 'setting_user_local',
      'module_auth' => 'acl_a_authusers && (acl_a_mauth || acl_a_fauth)',
    ),
    38 => 
    array (
      'module_id' => '133',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '8',
      'left_id' => '75',
      'right_id' => '76',
      'module_langname' => 'ACP_GROUPS_FORUM_PERMISSIONS',
      'module_mode' => 'setting_group_local',
      'module_auth' => 'acl_a_authgroups && (acl_a_mauth || acl_a_fauth)',
    ),
    39 => 
    array (
      'module_id' => '9',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '0',
      'left_id' => '79',
      'right_id' => '102',
      'module_langname' => 'ACP_CAT_POSTING',
      'module_mode' => '',
      'module_auth' => '',
    ),
    40 => 
    array (
      'module_id' => '10',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '9',
      'left_id' => '80',
      'right_id' => '91',
      'module_langname' => 'ACP_MESSAGES',
      'module_mode' => '',
      'module_auth' => '',
    ),
    41 => 
    array (
      'module_id' => '40',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'bbcodes',
      'module_class' => 'acp',
      'parent_id' => '10',
      'left_id' => '81',
      'right_id' => '82',
      'module_langname' => 'ACP_BBCODES',
      'module_mode' => 'bbcodes',
      'module_auth' => 'acl_a_bbcode',
    ),
    42 => 
    array (
      'module_id' => '45',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'board',
      'module_class' => 'acp',
      'parent_id' => '10',
      'left_id' => '83',
      'right_id' => '84',
      'module_langname' => 'ACP_MESSAGE_SETTINGS',
      'module_mode' => 'message',
      'module_auth' => 'acl_a_board',
    ),
    43 => 
    array (
      'module_id' => '64',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'icons',
      'module_class' => 'acp',
      'parent_id' => '10',
      'left_id' => '85',
      'right_id' => '86',
      'module_langname' => 'ACP_ICONS',
      'module_mode' => 'icons',
      'module_auth' => 'acl_a_icons',
    ),
    44 => 
    array (
      'module_id' => '65',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'icons',
      'module_class' => 'acp',
      'parent_id' => '10',
      'left_id' => '87',
      'right_id' => '88',
      'module_langname' => 'ACP_SMILIES',
      'module_mode' => 'smilies',
      'module_auth' => 'acl_a_icons',
    ),
    45 => 
    array (
      'module_id' => '123',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'words',
      'module_class' => 'acp',
      'parent_id' => '10',
      'left_id' => '89',
      'right_id' => '90',
      'module_langname' => 'ACP_WORDS',
      'module_mode' => 'words',
      'module_auth' => 'acl_a_words',
    ),
    46 => 
    array (
      'module_id' => '11',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '9',
      'left_id' => '92',
      'right_id' => '101',
      'module_langname' => 'ACP_ATTACHMENTS',
      'module_mode' => '',
      'module_auth' => '',
    ),
    47 => 
    array (
      'module_id' => '33',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'attachments',
      'module_class' => 'acp',
      'parent_id' => '11',
      'left_id' => '93',
      'right_id' => '94',
      'module_langname' => 'ACP_ATTACHMENT_SETTINGS',
      'module_mode' => 'attach',
      'module_auth' => 'acl_a_attach',
    ),
    48 => 
    array (
      'module_id' => '34',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'attachments',
      'module_class' => 'acp',
      'parent_id' => '11',
      'left_id' => '95',
      'right_id' => '96',
      'module_langname' => 'ACP_MANAGE_EXTENSIONS',
      'module_mode' => 'extensions',
      'module_auth' => 'acl_a_attach',
    ),
    49 => 
    array (
      'module_id' => '35',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'attachments',
      'module_class' => 'acp',
      'parent_id' => '11',
      'left_id' => '97',
      'right_id' => '98',
      'module_langname' => 'ACP_EXTENSION_GROUPS',
      'module_mode' => 'ext_groups',
      'module_auth' => 'acl_a_attach',
    ),
    50 => 
    array (
      'module_id' => '36',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'attachments',
      'module_class' => 'acp',
      'parent_id' => '11',
      'left_id' => '99',
      'right_id' => '100',
      'module_langname' => 'ACP_ORPHAN_ATTACHMENTS',
      'module_mode' => 'orphan',
      'module_auth' => 'acl_a_attach',
    ),
    51 => 
    array (
      'module_id' => '12',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '0',
      'left_id' => '103',
      'right_id' => '156',
      'module_langname' => 'ACP_CAT_USERGROUP',
      'module_mode' => '',
      'module_auth' => '',
    ),
    52 => 
    array (
      'module_id' => '13',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '12',
      'left_id' => '104',
      'right_id' => '135',
      'module_langname' => 'ACP_CAT_USERS',
      'module_mode' => '',
      'module_auth' => '',
    ),
    53 => 
    array (
      'module_id' => '113',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'users',
      'module_class' => 'acp',
      'parent_id' => '13',
      'left_id' => '105',
      'right_id' => '106',
      'module_langname' => 'ACP_MANAGE_USERS',
      'module_mode' => 'overview',
      'module_auth' => 'acl_a_user',
    ),
    54 => 
    array (
      'module_id' => '66',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'inactive',
      'module_class' => 'acp',
      'parent_id' => '13',
      'left_id' => '107',
      'right_id' => '108',
      'module_langname' => 'ACP_INACTIVE_USERS',
      'module_mode' => 'list',
      'module_auth' => 'acl_a_user',
    ),
    55 => 
    array (
      'module_id' => '86',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '13',
      'left_id' => '109',
      'right_id' => '110',
      'module_langname' => 'ACP_USERS_PERMISSIONS',
      'module_mode' => 'setting_user_global',
      'module_auth' => 'acl_a_authusers && (acl_a_aauth || acl_a_mauth || acl_a_uauth)',
    ),
    56 => 
    array (
      'module_id' => '88',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '13',
      'left_id' => '111',
      'right_id' => '112',
      'module_langname' => 'ACP_USERS_FORUM_PERMISSIONS',
      'module_mode' => 'setting_user_local',
      'module_auth' => 'acl_a_authusers && (acl_a_mauth || acl_a_fauth)',
    ),
    57 => 
    array (
      'module_id' => '101',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'profile',
      'module_class' => 'acp',
      'parent_id' => '13',
      'left_id' => '113',
      'right_id' => '114',
      'module_langname' => 'ACP_CUSTOM_PROFILE_FIELDS',
      'module_mode' => 'profile',
      'module_auth' => 'acl_a_profile',
    ),
    58 => 
    array (
      'module_id' => '104',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'ranks',
      'module_class' => 'acp',
      'parent_id' => '13',
      'left_id' => '115',
      'right_id' => '116',
      'module_langname' => 'ACP_MANAGE_RANKS',
      'module_mode' => 'ranks',
      'module_auth' => 'acl_a_ranks',
    ),
    59 => 
    array (
      'module_id' => '114',
      'module_enabled' => '1',
      'module_display' => '0',
      'module_basename' => 'users',
      'module_class' => 'acp',
      'parent_id' => '13',
      'left_id' => '117',
      'right_id' => '118',
      'module_langname' => 'ACP_USER_FEEDBACK',
      'module_mode' => 'feedback',
      'module_auth' => 'acl_a_user',
    ),
    60 => 
    array (
      'module_id' => '115',
      'module_enabled' => '1',
      'module_display' => '0',
      'module_basename' => 'users',
      'module_class' => 'acp',
      'parent_id' => '13',
      'left_id' => '119',
      'right_id' => '120',
      'module_langname' => 'ACP_USER_PROFILE',
      'module_mode' => 'profile',
      'module_auth' => 'acl_a_user',
    ),
    61 => 
    array (
      'module_id' => '116',
      'module_enabled' => '1',
      'module_display' => '0',
      'module_basename' => 'users',
      'module_class' => 'acp',
      'parent_id' => '13',
      'left_id' => '121',
      'right_id' => '122',
      'module_langname' => 'ACP_USER_PREFS',
      'module_mode' => 'prefs',
      'module_auth' => 'acl_a_user',
    ),
    62 => 
    array (
      'module_id' => '117',
      'module_enabled' => '1',
      'module_display' => '0',
      'module_basename' => 'users',
      'module_class' => 'acp',
      'parent_id' => '13',
      'left_id' => '123',
      'right_id' => '124',
      'module_langname' => 'ACP_USER_AVATAR',
      'module_mode' => 'avatar',
      'module_auth' => 'acl_a_user',
    ),
    63 => 
    array (
      'module_id' => '118',
      'module_enabled' => '1',
      'module_display' => '0',
      'module_basename' => 'users',
      'module_class' => 'acp',
      'parent_id' => '13',
      'left_id' => '125',
      'right_id' => '126',
      'module_langname' => 'ACP_USER_RANK',
      'module_mode' => 'rank',
      'module_auth' => 'acl_a_user',
    ),
    64 => 
    array (
      'module_id' => '119',
      'module_enabled' => '1',
      'module_display' => '0',
      'module_basename' => 'users',
      'module_class' => 'acp',
      'parent_id' => '13',
      'left_id' => '127',
      'right_id' => '128',
      'module_langname' => 'ACP_USER_SIG',
      'module_mode' => 'sig',
      'module_auth' => 'acl_a_user',
    ),
    65 => 
    array (
      'module_id' => '120',
      'module_enabled' => '1',
      'module_display' => '0',
      'module_basename' => 'users',
      'module_class' => 'acp',
      'parent_id' => '13',
      'left_id' => '129',
      'right_id' => '130',
      'module_langname' => 'ACP_USER_GROUPS',
      'module_mode' => 'groups',
      'module_auth' => 'acl_a_user && acl_a_group',
    ),
    66 => 
    array (
      'module_id' => '121',
      'module_enabled' => '1',
      'module_display' => '0',
      'module_basename' => 'users',
      'module_class' => 'acp',
      'parent_id' => '13',
      'left_id' => '131',
      'right_id' => '132',
      'module_langname' => 'ACP_USER_PERM',
      'module_mode' => 'perm',
      'module_auth' => 'acl_a_user && acl_a_viewauth',
    ),
    67 => 
    array (
      'module_id' => '122',
      'module_enabled' => '1',
      'module_display' => '0',
      'module_basename' => 'users',
      'module_class' => 'acp',
      'parent_id' => '13',
      'left_id' => '133',
      'right_id' => '134',
      'module_langname' => 'ACP_USER_ATTACH',
      'module_mode' => 'attach',
      'module_auth' => 'acl_a_user',
    ),
    68 => 
    array (
      'module_id' => '14',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '12',
      'left_id' => '136',
      'right_id' => '143',
      'module_langname' => 'ACP_GROUPS',
      'module_mode' => '',
      'module_auth' => '',
    ),
    69 => 
    array (
      'module_id' => '63',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'groups',
      'module_class' => 'acp',
      'parent_id' => '14',
      'left_id' => '137',
      'right_id' => '138',
      'module_langname' => 'ACP_GROUPS_MANAGE',
      'module_mode' => 'manage',
      'module_auth' => 'acl_a_group',
    ),
    70 => 
    array (
      'module_id' => '90',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '14',
      'left_id' => '139',
      'right_id' => '140',
      'module_langname' => 'ACP_GROUPS_PERMISSIONS',
      'module_mode' => 'setting_group_global',
      'module_auth' => 'acl_a_authgroups && (acl_a_aauth || acl_a_mauth || acl_a_uauth)',
    ),
    71 => 
    array (
      'module_id' => '92',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '14',
      'left_id' => '141',
      'right_id' => '142',
      'module_langname' => 'ACP_GROUPS_FORUM_PERMISSIONS',
      'module_mode' => 'setting_group_local',
      'module_auth' => 'acl_a_authgroups && (acl_a_mauth || acl_a_fauth)',
    ),
    72 => 
    array (
      'module_id' => '15',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '12',
      'left_id' => '144',
      'right_id' => '155',
      'module_langname' => 'ACP_USER_SECURITY',
      'module_mode' => '',
      'module_auth' => '',
    ),
    73 => 
    array (
      'module_id' => '37',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'ban',
      'module_class' => 'acp',
      'parent_id' => '15',
      'left_id' => '145',
      'right_id' => '146',
      'module_langname' => 'ACP_BAN_EMAILS',
      'module_mode' => 'email',
      'module_auth' => 'acl_a_ban',
    ),
    74 => 
    array (
      'module_id' => '38',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'ban',
      'module_class' => 'acp',
      'parent_id' => '15',
      'left_id' => '147',
      'right_id' => '148',
      'module_langname' => 'ACP_BAN_IPS',
      'module_mode' => 'ip',
      'module_auth' => 'acl_a_ban',
    ),
    75 => 
    array (
      'module_id' => '39',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'ban',
      'module_class' => 'acp',
      'parent_id' => '15',
      'left_id' => '149',
      'right_id' => '150',
      'module_langname' => 'ACP_BAN_USERNAMES',
      'module_mode' => 'user',
      'module_auth' => 'acl_a_ban',
    ),
    76 => 
    array (
      'module_id' => '60',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'disallow',
      'module_class' => 'acp',
      'parent_id' => '15',
      'left_id' => '151',
      'right_id' => '152',
      'module_langname' => 'ACP_DISALLOW_USERNAMES',
      'module_mode' => 'usernames',
      'module_auth' => 'acl_a_names',
    ),
    77 => 
    array (
      'module_id' => '103',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'prune',
      'module_class' => 'acp',
      'parent_id' => '15',
      'left_id' => '153',
      'right_id' => '154',
      'module_langname' => 'ACP_PRUNE_USERS',
      'module_mode' => 'users',
      'module_auth' => 'acl_a_userdel',
    ),
    78 => 
    array (
      'module_id' => '16',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '0',
      'left_id' => '157',
      'right_id' => '204',
      'module_langname' => 'ACP_CAT_PERMISSIONS',
      'module_mode' => '',
      'module_auth' => '',
    ),
    79 => 
    array (
      'module_id' => '81',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '16',
      'left_id' => '158',
      'right_id' => '159',
      'module_langname' => 'ACP_PERMISSIONS',
      'module_mode' => 'intro',
      'module_auth' => 'acl_a_authusers || acl_a_authgroups || acl_a_viewauth',
    ),
    80 => 
    array (
      'module_id' => '17',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '16',
      'left_id' => '160',
      'right_id' => '169',
      'module_langname' => 'ACP_GLOBAL_PERMISSIONS',
      'module_mode' => '',
      'module_auth' => '',
    ),
    81 => 
    array (
      'module_id' => '85',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '17',
      'left_id' => '161',
      'right_id' => '162',
      'module_langname' => 'ACP_USERS_PERMISSIONS',
      'module_mode' => 'setting_user_global',
      'module_auth' => 'acl_a_authusers && (acl_a_aauth || acl_a_mauth || acl_a_uauth)',
    ),
    82 => 
    array (
      'module_id' => '89',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '17',
      'left_id' => '163',
      'right_id' => '164',
      'module_langname' => 'ACP_GROUPS_PERMISSIONS',
      'module_mode' => 'setting_group_global',
      'module_auth' => 'acl_a_authgroups && (acl_a_aauth || acl_a_mauth || acl_a_uauth)',
    ),
    83 => 
    array (
      'module_id' => '93',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '17',
      'left_id' => '165',
      'right_id' => '166',
      'module_langname' => 'ACP_ADMINISTRATORS',
      'module_mode' => 'setting_admin_global',
      'module_auth' => 'acl_a_aauth && (acl_a_authusers || acl_a_authgroups)',
    ),
    84 => 
    array (
      'module_id' => '94',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '17',
      'left_id' => '167',
      'right_id' => '168',
      'module_langname' => 'ACP_GLOBAL_MODERATORS',
      'module_mode' => 'setting_mod_global',
      'module_auth' => 'acl_a_mauth && (acl_a_authusers || acl_a_authgroups)',
    ),
    85 => 
    array (
      'module_id' => '18',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '16',
      'left_id' => '170',
      'right_id' => '179',
      'module_langname' => 'ACP_FORUM_BASED_PERMISSIONS',
      'module_mode' => '',
      'module_auth' => '',
    ),
    86 => 
    array (
      'module_id' => '83',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '18',
      'left_id' => '171',
      'right_id' => '172',
      'module_langname' => 'ACP_FORUM_PERMISSIONS',
      'module_mode' => 'setting_forum_local',
      'module_auth' => 'acl_a_fauth && (acl_a_authusers || acl_a_authgroups)',
    ),
    87 => 
    array (
      'module_id' => '84',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '18',
      'left_id' => '173',
      'right_id' => '174',
      'module_langname' => 'ACP_FORUM_MODERATORS',
      'module_mode' => 'setting_mod_local',
      'module_auth' => 'acl_a_mauth && (acl_a_authusers || acl_a_authgroups)',
    ),
    88 => 
    array (
      'module_id' => '87',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '18',
      'left_id' => '175',
      'right_id' => '176',
      'module_langname' => 'ACP_USERS_FORUM_PERMISSIONS',
      'module_mode' => 'setting_user_local',
      'module_auth' => 'acl_a_authusers && (acl_a_mauth || acl_a_fauth)',
    ),
    89 => 
    array (
      'module_id' => '91',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '18',
      'left_id' => '177',
      'right_id' => '178',
      'module_langname' => 'ACP_GROUPS_FORUM_PERMISSIONS',
      'module_mode' => 'setting_group_local',
      'module_auth' => 'acl_a_authgroups && (acl_a_mauth || acl_a_fauth)',
    ),
    90 => 
    array (
      'module_id' => '19',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '16',
      'left_id' => '180',
      'right_id' => '189',
      'module_langname' => 'ACP_PERMISSION_ROLES',
      'module_mode' => '',
      'module_auth' => '',
    ),
    91 => 
    array (
      'module_id' => '77',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permission_roles',
      'module_class' => 'acp',
      'parent_id' => '19',
      'left_id' => '181',
      'right_id' => '182',
      'module_langname' => 'ACP_ADMIN_ROLES',
      'module_mode' => 'admin_roles',
      'module_auth' => 'acl_a_roles && acl_a_aauth',
    ),
    92 => 
    array (
      'module_id' => '78',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permission_roles',
      'module_class' => 'acp',
      'parent_id' => '19',
      'left_id' => '183',
      'right_id' => '184',
      'module_langname' => 'ACP_USER_ROLES',
      'module_mode' => 'user_roles',
      'module_auth' => 'acl_a_roles && acl_a_uauth',
    ),
    93 => 
    array (
      'module_id' => '79',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permission_roles',
      'module_class' => 'acp',
      'parent_id' => '19',
      'left_id' => '185',
      'right_id' => '186',
      'module_langname' => 'ACP_MOD_ROLES',
      'module_mode' => 'mod_roles',
      'module_auth' => 'acl_a_roles && acl_a_mauth',
    ),
    94 => 
    array (
      'module_id' => '80',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permission_roles',
      'module_class' => 'acp',
      'parent_id' => '19',
      'left_id' => '187',
      'right_id' => '188',
      'module_langname' => 'ACP_FORUM_ROLES',
      'module_mode' => 'forum_roles',
      'module_auth' => 'acl_a_roles && acl_a_fauth',
    ),
    95 => 
    array (
      'module_id' => '20',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '16',
      'left_id' => '190',
      'right_id' => '203',
      'module_langname' => 'ACP_PERMISSION_MASKS',
      'module_mode' => '',
      'module_auth' => '',
    ),
    96 => 
    array (
      'module_id' => '82',
      'module_enabled' => '1',
      'module_display' => '0',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '20',
      'left_id' => '191',
      'right_id' => '192',
      'module_langname' => 'ACP_PERMISSION_TRACE',
      'module_mode' => 'trace',
      'module_auth' => 'acl_a_viewauth',
    ),
    97 => 
    array (
      'module_id' => '95',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '20',
      'left_id' => '193',
      'right_id' => '194',
      'module_langname' => 'ACP_VIEW_ADMIN_PERMISSIONS',
      'module_mode' => 'view_admin_global',
      'module_auth' => 'acl_a_viewauth',
    ),
    98 => 
    array (
      'module_id' => '96',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '20',
      'left_id' => '195',
      'right_id' => '196',
      'module_langname' => 'ACP_VIEW_USER_PERMISSIONS',
      'module_mode' => 'view_user_global',
      'module_auth' => 'acl_a_viewauth',
    ),
    99 => 
    array (
      'module_id' => '97',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '20',
      'left_id' => '197',
      'right_id' => '198',
      'module_langname' => 'ACP_VIEW_GLOBAL_MOD_PERMISSIONS',
      'module_mode' => 'view_mod_global',
      'module_auth' => 'acl_a_viewauth',
    ),
    100 => 
    array (
      'module_id' => '98',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '20',
      'left_id' => '199',
      'right_id' => '200',
      'module_langname' => 'ACP_VIEW_FORUM_MOD_PERMISSIONS',
      'module_mode' => 'view_mod_local',
      'module_auth' => 'acl_a_viewauth',
    ),
    101 => 
    array (
      'module_id' => '99',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'permissions',
      'module_class' => 'acp',
      'parent_id' => '20',
      'left_id' => '201',
      'right_id' => '202',
      'module_langname' => 'ACP_VIEW_FORUM_PERMISSIONS',
      'module_mode' => 'view_forum_local',
      'module_auth' => 'acl_a_viewauth',
    ),
    102 => 
    array (
      'module_id' => '21',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '0',
      'left_id' => '205',
      'right_id' => '218',
      'module_langname' => 'ACP_CAT_STYLES',
      'module_mode' => '',
      'module_auth' => '',
    ),
    103 => 
    array (
      'module_id' => '22',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '21',
      'left_id' => '206',
      'right_id' => '209',
      'module_langname' => 'ACP_STYLE_MANAGEMENT',
      'module_mode' => '',
      'module_auth' => '',
    ),
    104 => 
    array (
      'module_id' => '108',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'styles',
      'module_class' => 'acp',
      'parent_id' => '22',
      'left_id' => '207',
      'right_id' => '208',
      'module_langname' => 'ACP_STYLES',
      'module_mode' => 'style',
      'module_auth' => 'acl_a_styles',
    ),
    105 => 
    array (
      'module_id' => '23',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '21',
      'left_id' => '210',
      'right_id' => '217',
      'module_langname' => 'ACP_STYLE_COMPONENTS',
      'module_mode' => '',
      'module_auth' => '',
    ),
    106 => 
    array (
      'module_id' => '109',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'styles',
      'module_class' => 'acp',
      'parent_id' => '23',
      'left_id' => '211',
      'right_id' => '212',
      'module_langname' => 'ACP_TEMPLATES',
      'module_mode' => 'template',
      'module_auth' => 'acl_a_styles',
    ),
    107 => 
    array (
      'module_id' => '110',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'styles',
      'module_class' => 'acp',
      'parent_id' => '23',
      'left_id' => '213',
      'right_id' => '214',
      'module_langname' => 'ACP_THEMES',
      'module_mode' => 'theme',
      'module_auth' => 'acl_a_styles',
    ),
    108 => 
    array (
      'module_id' => '111',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'styles',
      'module_class' => 'acp',
      'parent_id' => '23',
      'left_id' => '215',
      'right_id' => '216',
      'module_langname' => 'ACP_IMAGESETS',
      'module_mode' => 'imageset',
      'module_auth' => 'acl_a_styles',
    ),
    109 => 
    array (
      'module_id' => '24',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '0',
      'left_id' => '219',
      'right_id' => '238',
      'module_langname' => 'ACP_CAT_MAINTENANCE',
      'module_mode' => '',
      'module_auth' => '',
    ),
    110 => 
    array (
      'module_id' => '25',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '24',
      'left_id' => '220',
      'right_id' => '229',
      'module_langname' => 'ACP_FORUM_LOGS',
      'module_mode' => '',
      'module_auth' => '',
    ),
    111 => 
    array (
      'module_id' => '69',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'logs',
      'module_class' => 'acp',
      'parent_id' => '25',
      'left_id' => '221',
      'right_id' => '222',
      'module_langname' => 'ACP_ADMIN_LOGS',
      'module_mode' => 'admin',
      'module_auth' => 'acl_a_viewlogs',
    ),
    112 => 
    array (
      'module_id' => '70',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'logs',
      'module_class' => 'acp',
      'parent_id' => '25',
      'left_id' => '223',
      'right_id' => '224',
      'module_langname' => 'ACP_MOD_LOGS',
      'module_mode' => 'mod',
      'module_auth' => 'acl_a_viewlogs',
    ),
    113 => 
    array (
      'module_id' => '71',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'logs',
      'module_class' => 'acp',
      'parent_id' => '25',
      'left_id' => '225',
      'right_id' => '226',
      'module_langname' => 'ACP_USERS_LOGS',
      'module_mode' => 'users',
      'module_auth' => 'acl_a_viewlogs',
    ),
    114 => 
    array (
      'module_id' => '72',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'logs',
      'module_class' => 'acp',
      'parent_id' => '25',
      'left_id' => '227',
      'right_id' => '228',
      'module_langname' => 'ACP_CRITICAL_LOGS',
      'module_mode' => 'critical',
      'module_auth' => 'acl_a_viewlogs',
    ),
    115 => 
    array (
      'module_id' => '26',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '24',
      'left_id' => '230',
      'right_id' => '237',
      'module_langname' => 'ACP_CAT_DATABASE',
      'module_mode' => '',
      'module_auth' => '',
    ),
    116 => 
    array (
      'module_id' => '58',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'database',
      'module_class' => 'acp',
      'parent_id' => '26',
      'left_id' => '231',
      'right_id' => '232',
      'module_langname' => 'ACP_BACKUP',
      'module_mode' => 'backup',
      'module_auth' => 'acl_a_backup',
    ),
    117 => 
    array (
      'module_id' => '59',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'database',
      'module_class' => 'acp',
      'parent_id' => '26',
      'left_id' => '233',
      'right_id' => '234',
      'module_langname' => 'ACP_RESTORE',
      'module_mode' => 'restore',
      'module_auth' => 'acl_a_backup',
    ),
    118 => 
    array (
      'module_id' => '107',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'search',
      'module_class' => 'acp',
      'parent_id' => '26',
      'left_id' => '235',
      'right_id' => '236',
      'module_langname' => 'ACP_SEARCH_INDEX',
      'module_mode' => 'index',
      'module_auth' => 'acl_a_search',
    ),
    119 => 
    array (
      'module_id' => '27',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '0',
      'left_id' => '239',
      'right_id' => '264',
      'module_langname' => 'ACP_CAT_SYSTEM',
      'module_mode' => '',
      'module_auth' => '',
    ),
    120 => 
    array (
      'module_id' => '28',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '27',
      'left_id' => '240',
      'right_id' => '243',
      'module_langname' => 'ACP_AUTOMATION',
      'module_mode' => '',
      'module_auth' => '',
    ),
    121 => 
    array (
      'module_id' => '112',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'update',
      'module_class' => 'acp',
      'parent_id' => '28',
      'left_id' => '241',
      'right_id' => '242',
      'module_langname' => 'ACP_VERSION_CHECK',
      'module_mode' => 'version_check',
      'module_auth' => 'acl_a_board',
    ),
    122 => 
    array (
      'module_id' => '29',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '27',
      'left_id' => '244',
      'right_id' => '255',
      'module_langname' => 'ACP_GENERAL_TASKS',
      'module_mode' => '',
      'module_auth' => '',
    ),
    123 => 
    array (
      'module_id' => '55',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'bots',
      'module_class' => 'acp',
      'parent_id' => '29',
      'left_id' => '245',
      'right_id' => '246',
      'module_langname' => 'ACP_BOTS',
      'module_mode' => 'bots',
      'module_auth' => 'acl_a_bots',
    ),
    124 => 
    array (
      'module_id' => '61',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'email',
      'module_class' => 'acp',
      'parent_id' => '29',
      'left_id' => '247',
      'right_id' => '248',
      'module_langname' => 'ACP_MASS_EMAIL',
      'module_mode' => 'email',
      'module_auth' => 'acl_a_email',
    ),
    125 => 
    array (
      'module_id' => '68',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'language',
      'module_class' => 'acp',
      'parent_id' => '29',
      'left_id' => '249',
      'right_id' => '250',
      'module_langname' => 'ACP_LANGUAGE_PACKS',
      'module_mode' => 'lang_packs',
      'module_auth' => 'acl_a_language',
    ),
    126 => 
    array (
      'module_id' => '100',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'php_info',
      'module_class' => 'acp',
      'parent_id' => '29',
      'left_id' => '251',
      'right_id' => '252',
      'module_langname' => 'ACP_PHP_INFO',
      'module_mode' => 'info',
      'module_auth' => 'acl_a_phpinfo',
    ),
    127 => 
    array (
      'module_id' => '105',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'reasons',
      'module_class' => 'acp',
      'parent_id' => '29',
      'left_id' => '253',
      'right_id' => '254',
      'module_langname' => 'ACP_MANAGE_REASONS',
      'module_mode' => 'main',
      'module_auth' => 'acl_a_reasons',
    ),
    128 => 
    array (
      'module_id' => '30',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '27',
      'left_id' => '256',
      'right_id' => '263',
      'module_langname' => 'ACP_MODULE_MANAGEMENT',
      'module_mode' => '',
      'module_auth' => '',
    ),
    129 => 
    array (
      'module_id' => '74',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'modules',
      'module_class' => 'acp',
      'parent_id' => '30',
      'left_id' => '257',
      'right_id' => '258',
      'module_langname' => 'ACP',
      'module_mode' => 'acp',
      'module_auth' => 'acl_a_modules',
    ),
    130 => 
    array (
      'module_id' => '75',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'modules',
      'module_class' => 'acp',
      'parent_id' => '30',
      'left_id' => '259',
      'right_id' => '260',
      'module_langname' => 'UCP',
      'module_mode' => 'ucp',
      'module_auth' => 'acl_a_modules',
    ),
    131 => 
    array (
      'module_id' => '76',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'modules',
      'module_class' => 'acp',
      'parent_id' => '30',
      'left_id' => '261',
      'right_id' => '262',
      'module_langname' => 'MCP',
      'module_mode' => 'mcp',
      'module_auth' => 'acl_a_modules',
    ),
    132 => 
    array (
      'module_id' => '31',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'acp',
      'parent_id' => '0',
      'left_id' => '265',
      'right_id' => '266',
      'module_langname' => 'ACP_CAT_DOT_MODS',
      'module_mode' => '',
      'module_auth' => '',
    ),
  ),
  'parents' => 
  array (
    1 => 
    array (
    ),
    73 => 
    array (
      1 => '0',
    ),
    2 => 
    array (
      1 => '0',
    ),
    124 => 
    array (
      1 => '0',
      2 => '1',
    ),
    125 => 
    array (
      1 => '0',
      2 => '1',
    ),
    126 => 
    array (
      1 => '0',
      2 => '1',
    ),
    127 => 
    array (
      1 => '0',
      2 => '1',
    ),
    128 => 
    array (
      1 => '0',
      2 => '1',
    ),
    129 => 
    array (
      1 => '0',
      2 => '1',
    ),
    3 => 
    array (
      1 => '0',
    ),
    32 => 
    array (
      1 => '0',
      3 => '1',
    ),
    41 => 
    array (
      1 => '0',
      3 => '1',
    ),
    42 => 
    array (
      1 => '0',
      3 => '1',
    ),
    43 => 
    array (
      1 => '0',
      3 => '1',
    ),
    44 => 
    array (
      1 => '0',
      3 => '1',
    ),
    46 => 
    array (
      1 => '0',
      3 => '1',
    ),
    47 => 
    array (
      1 => '0',
      3 => '1',
    ),
    48 => 
    array (
      1 => '0',
      3 => '1',
    ),
    56 => 
    array (
      1 => '0',
      3 => '1',
    ),
    57 => 
    array (
      1 => '0',
      3 => '1',
    ),
    4 => 
    array (
      1 => '0',
    ),
    49 => 
    array (
      1 => '0',
      4 => '1',
    ),
    50 => 
    array (
      1 => '0',
      4 => '1',
    ),
    67 => 
    array (
      1 => '0',
      4 => '1',
    ),
    5 => 
    array (
      1 => '0',
    ),
    51 => 
    array (
      1 => '0',
      5 => '1',
    ),
    52 => 
    array (
      1 => '0',
      5 => '1',
    ),
    53 => 
    array (
      1 => '0',
      5 => '1',
    ),
    54 => 
    array (
      1 => '0',
      5 => '1',
    ),
    106 => 
    array (
      1 => '0',
      5 => '1',
    ),
    6 => 
    array (
    ),
    7 => 
    array (
      6 => '0',
    ),
    62 => 
    array (
      6 => '0',
      7 => '6',
    ),
    102 => 
    array (
      6 => '0',
      7 => '6',
    ),
    8 => 
    array (
      6 => '0',
    ),
    130 => 
    array (
      6 => '0',
      8 => '6',
    ),
    131 => 
    array (
      6 => '0',
      8 => '6',
    ),
    132 => 
    array (
      6 => '0',
      8 => '6',
    ),
    133 => 
    array (
      6 => '0',
      8 => '6',
    ),
    9 => 
    array (
    ),
    10 => 
    array (
      9 => '0',
    ),
    40 => 
    array (
      9 => '0',
      10 => '9',
    ),
    45 => 
    array (
      9 => '0',
      10 => '9',
    ),
    64 => 
    array (
      9 => '0',
      10 => '9',
    ),
    65 => 
    array (
      9 => '0',
      10 => '9',
    ),
    123 => 
    array (
      9 => '0',
      10 => '9',
    ),
    11 => 
    array (
      9 => '0',
    ),
    33 => 
    array (
      9 => '0',
      11 => '9',
    ),
    34 => 
    array (
      9 => '0',
      11 => '9',
    ),
    35 => 
    array (
      9 => '0',
      11 => '9',
    ),
    36 => 
    array (
      9 => '0',
      11 => '9',
    ),
    12 => 
    array (
    ),
    13 => 
    array (
      12 => '0',
    ),
    113 => 
    array (
      12 => '0',
      13 => '12',
    ),
    66 => 
    array (
      12 => '0',
      13 => '12',
    ),
    86 => 
    array (
      12 => '0',
      13 => '12',
    ),
    88 => 
    array (
      12 => '0',
      13 => '12',
    ),
    101 => 
    array (
      12 => '0',
      13 => '12',
    ),
    104 => 
    array (
      12 => '0',
      13 => '12',
    ),
    114 => 
    array (
      12 => '0',
      13 => '12',
    ),
    115 => 
    array (
      12 => '0',
      13 => '12',
    ),
    116 => 
    array (
      12 => '0',
      13 => '12',
    ),
    117 => 
    array (
      12 => '0',
      13 => '12',
    ),
    118 => 
    array (
      12 => '0',
      13 => '12',
    ),
    119 => 
    array (
      12 => '0',
      13 => '12',
    ),
    120 => 
    array (
      12 => '0',
      13 => '12',
    ),
    121 => 
    array (
      12 => '0',
      13 => '12',
    ),
    122 => 
    array (
      12 => '0',
      13 => '12',
    ),
    14 => 
    array (
      12 => '0',
    ),
    63 => 
    array (
      12 => '0',
      14 => '12',
    ),
    90 => 
    array (
      12 => '0',
      14 => '12',
    ),
    92 => 
    array (
      12 => '0',
      14 => '12',
    ),
    15 => 
    array (
      12 => '0',
    ),
    37 => 
    array (
      12 => '0',
      15 => '12',
    ),
    38 => 
    array (
      12 => '0',
      15 => '12',
    ),
    39 => 
    array (
      12 => '0',
      15 => '12',
    ),
    60 => 
    array (
      12 => '0',
      15 => '12',
    ),
    103 => 
    array (
      12 => '0',
      15 => '12',
    ),
    16 => 
    array (
    ),
    81 => 
    array (
      16 => '0',
    ),
    17 => 
    array (
      16 => '0',
    ),
    85 => 
    array (
      16 => '0',
      17 => '16',
    ),
    89 => 
    array (
      16 => '0',
      17 => '16',
    ),
    93 => 
    array (
      16 => '0',
      17 => '16',
    ),
    94 => 
    array (
      16 => '0',
      17 => '16',
    ),
    18 => 
    array (
      16 => '0',
    ),
    83 => 
    array (
      16 => '0',
      18 => '16',
    ),
    84 => 
    array (
      16 => '0',
      18 => '16',
    ),
    87 => 
    array (
      16 => '0',
      18 => '16',
    ),
    91 => 
    array (
      16 => '0',
      18 => '16',
    ),
    19 => 
    array (
      16 => '0',
    ),
    77 => 
    array (
      16 => '0',
      19 => '16',
    ),
    78 => 
    array (
      16 => '0',
      19 => '16',
    ),
    79 => 
    array (
      16 => '0',
      19 => '16',
    ),
    80 => 
    array (
      16 => '0',
      19 => '16',
    ),
    20 => 
    array (
      16 => '0',
    ),
    82 => 
    array (
      16 => '0',
      20 => '16',
    ),
    95 => 
    array (
      16 => '0',
      20 => '16',
    ),
    96 => 
    array (
      16 => '0',
      20 => '16',
    ),
    97 => 
    array (
      16 => '0',
      20 => '16',
    ),
    98 => 
    array (
      16 => '0',
      20 => '16',
    ),
    99 => 
    array (
      16 => '0',
      20 => '16',
    ),
    21 => 
    array (
    ),
    22 => 
    array (
      21 => '0',
    ),
    108 => 
    array (
      21 => '0',
      22 => '21',
    ),
    23 => 
    array (
      21 => '0',
    ),
    109 => 
    array (
      21 => '0',
      23 => '21',
    ),
    110 => 
    array (
      21 => '0',
      23 => '21',
    ),
    111 => 
    array (
      21 => '0',
      23 => '21',
    ),
    24 => 
    array (
    ),
    25 => 
    array (
      24 => '0',
    ),
    69 => 
    array (
      24 => '0',
      25 => '24',
    ),
    70 => 
    array (
      24 => '0',
      25 => '24',
    ),
    71 => 
    array (
      24 => '0',
      25 => '24',
    ),
    72 => 
    array (
      24 => '0',
      25 => '24',
    ),
    26 => 
    array (
      24 => '0',
    ),
    58 => 
    array (
      24 => '0',
      26 => '24',
    ),
    59 => 
    array (
      24 => '0',
      26 => '24',
    ),
    107 => 
    array (
      24 => '0',
      26 => '24',
    ),
    27 => 
    array (
    ),
    28 => 
    array (
      27 => '0',
    ),
    112 => 
    array (
      27 => '0',
      28 => '27',
    ),
    29 => 
    array (
      27 => '0',
    ),
    55 => 
    array (
      27 => '0',
      29 => '27',
    ),
    61 => 
    array (
      27 => '0',
      29 => '27',
    ),
    68 => 
    array (
      27 => '0',
      29 => '27',
    ),
    100 => 
    array (
      27 => '0',
      29 => '27',
    ),
    105 => 
    array (
      27 => '0',
      29 => '27',
    ),
    30 => 
    array (
      27 => '0',
    ),
    74 => 
    array (
      27 => '0',
      30 => '27',
    ),
    75 => 
    array (
      27 => '0',
      30 => '27',
    ),
    76 => 
    array (
      27 => '0',
      30 => '27',
    ),
    31 => 
    array (
    ),
  ),
);
?>
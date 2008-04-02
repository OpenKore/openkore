<?php
$expired = (time() > 1238600185) ? true : false;
if ($expired) { return; }

$data = array (
  'modules' => 
  array (
    0 => 
    array (
      'module_id' => '134',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'mcp',
      'parent_id' => '0',
      'left_id' => '1',
      'right_id' => '10',
      'module_langname' => 'MCP_MAIN',
      'module_mode' => '',
      'module_auth' => '',
    ),
    1 => 
    array (
      'module_id' => '147',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'main',
      'module_class' => 'mcp',
      'parent_id' => '134',
      'left_id' => '2',
      'right_id' => '3',
      'module_langname' => 'MCP_MAIN_FRONT',
      'module_mode' => 'front',
      'module_auth' => '',
    ),
    2 => 
    array (
      'module_id' => '148',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'main',
      'module_class' => 'mcp',
      'parent_id' => '134',
      'left_id' => '4',
      'right_id' => '5',
      'module_langname' => 'MCP_MAIN_FORUM_VIEW',
      'module_mode' => 'forum_view',
      'module_auth' => 'acl_m_,$id',
    ),
    3 => 
    array (
      'module_id' => '149',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'main',
      'module_class' => 'mcp',
      'parent_id' => '134',
      'left_id' => '6',
      'right_id' => '7',
      'module_langname' => 'MCP_MAIN_TOPIC_VIEW',
      'module_mode' => 'topic_view',
      'module_auth' => 'acl_m_,$id',
    ),
    4 => 
    array (
      'module_id' => '150',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'main',
      'module_class' => 'mcp',
      'parent_id' => '134',
      'left_id' => '8',
      'right_id' => '9',
      'module_langname' => 'MCP_MAIN_POST_DETAILS',
      'module_mode' => 'post_details',
      'module_auth' => 'acl_m_,$id || (!$id && aclf_m_)',
    ),
    5 => 
    array (
      'module_id' => '135',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'mcp',
      'parent_id' => '0',
      'left_id' => '11',
      'right_id' => '18',
      'module_langname' => 'MCP_QUEUE',
      'module_mode' => '',
      'module_auth' => '',
    ),
    6 => 
    array (
      'module_id' => '153',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'queue',
      'module_class' => 'mcp',
      'parent_id' => '135',
      'left_id' => '12',
      'right_id' => '13',
      'module_langname' => 'MCP_QUEUE_UNAPPROVED_TOPICS',
      'module_mode' => 'unapproved_topics',
      'module_auth' => 'aclf_m_approve',
    ),
    7 => 
    array (
      'module_id' => '154',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'queue',
      'module_class' => 'mcp',
      'parent_id' => '135',
      'left_id' => '14',
      'right_id' => '15',
      'module_langname' => 'MCP_QUEUE_UNAPPROVED_POSTS',
      'module_mode' => 'unapproved_posts',
      'module_auth' => 'aclf_m_approve',
    ),
    8 => 
    array (
      'module_id' => '155',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'queue',
      'module_class' => 'mcp',
      'parent_id' => '135',
      'left_id' => '16',
      'right_id' => '17',
      'module_langname' => 'MCP_QUEUE_APPROVE_DETAILS',
      'module_mode' => 'approve_details',
      'module_auth' => 'acl_m_approve,$id || (!$id && aclf_m_approve)',
    ),
    9 => 
    array (
      'module_id' => '136',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'mcp',
      'parent_id' => '0',
      'left_id' => '19',
      'right_id' => '26',
      'module_langname' => 'MCP_REPORTS',
      'module_mode' => '',
      'module_auth' => '',
    ),
    10 => 
    array (
      'module_id' => '156',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'reports',
      'module_class' => 'mcp',
      'parent_id' => '136',
      'left_id' => '20',
      'right_id' => '21',
      'module_langname' => 'MCP_REPORTS_OPEN',
      'module_mode' => 'reports',
      'module_auth' => 'aclf_m_report',
    ),
    11 => 
    array (
      'module_id' => '157',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'reports',
      'module_class' => 'mcp',
      'parent_id' => '136',
      'left_id' => '22',
      'right_id' => '23',
      'module_langname' => 'MCP_REPORTS_CLOSED',
      'module_mode' => 'reports_closed',
      'module_auth' => 'aclf_m_report',
    ),
    12 => 
    array (
      'module_id' => '158',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'reports',
      'module_class' => 'mcp',
      'parent_id' => '136',
      'left_id' => '24',
      'right_id' => '25',
      'module_langname' => 'MCP_REPORT_DETAILS',
      'module_mode' => 'report_details',
      'module_auth' => 'acl_m_report,$id || (!$id && aclf_m_report)',
    ),
    13 => 
    array (
      'module_id' => '137',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'mcp',
      'parent_id' => '0',
      'left_id' => '27',
      'right_id' => '32',
      'module_langname' => 'MCP_NOTES',
      'module_mode' => '',
      'module_auth' => '',
    ),
    14 => 
    array (
      'module_id' => '151',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'notes',
      'module_class' => 'mcp',
      'parent_id' => '137',
      'left_id' => '28',
      'right_id' => '29',
      'module_langname' => 'MCP_NOTES_FRONT',
      'module_mode' => 'front',
      'module_auth' => '',
    ),
    15 => 
    array (
      'module_id' => '152',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'notes',
      'module_class' => 'mcp',
      'parent_id' => '137',
      'left_id' => '30',
      'right_id' => '31',
      'module_langname' => 'MCP_NOTES_USER',
      'module_mode' => 'user_notes',
      'module_auth' => '',
    ),
    16 => 
    array (
      'module_id' => '138',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'mcp',
      'parent_id' => '0',
      'left_id' => '33',
      'right_id' => '42',
      'module_langname' => 'MCP_WARN',
      'module_mode' => '',
      'module_auth' => '',
    ),
    17 => 
    array (
      'module_id' => '159',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'warn',
      'module_class' => 'mcp',
      'parent_id' => '138',
      'left_id' => '34',
      'right_id' => '35',
      'module_langname' => 'MCP_WARN_FRONT',
      'module_mode' => 'front',
      'module_auth' => 'aclf_m_warn',
    ),
    18 => 
    array (
      'module_id' => '160',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'warn',
      'module_class' => 'mcp',
      'parent_id' => '138',
      'left_id' => '36',
      'right_id' => '37',
      'module_langname' => 'MCP_WARN_LIST',
      'module_mode' => 'list',
      'module_auth' => 'aclf_m_warn',
    ),
    19 => 
    array (
      'module_id' => '161',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'warn',
      'module_class' => 'mcp',
      'parent_id' => '138',
      'left_id' => '38',
      'right_id' => '39',
      'module_langname' => 'MCP_WARN_USER',
      'module_mode' => 'warn_user',
      'module_auth' => 'aclf_m_warn',
    ),
    20 => 
    array (
      'module_id' => '162',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'warn',
      'module_class' => 'mcp',
      'parent_id' => '138',
      'left_id' => '40',
      'right_id' => '41',
      'module_langname' => 'MCP_WARN_POST',
      'module_mode' => 'warn_post',
      'module_auth' => 'acl_m_warn && acl_f_read,$id',
    ),
    21 => 
    array (
      'module_id' => '139',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'mcp',
      'parent_id' => '0',
      'left_id' => '43',
      'right_id' => '50',
      'module_langname' => 'MCP_LOGS',
      'module_mode' => '',
      'module_auth' => '',
    ),
    22 => 
    array (
      'module_id' => '144',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'logs',
      'module_class' => 'mcp',
      'parent_id' => '139',
      'left_id' => '44',
      'right_id' => '45',
      'module_langname' => 'MCP_LOGS_FRONT',
      'module_mode' => 'front',
      'module_auth' => 'acl_m_ || aclf_m_',
    ),
    23 => 
    array (
      'module_id' => '145',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'logs',
      'module_class' => 'mcp',
      'parent_id' => '139',
      'left_id' => '46',
      'right_id' => '47',
      'module_langname' => 'MCP_LOGS_FORUM_VIEW',
      'module_mode' => 'forum_logs',
      'module_auth' => 'acl_m_,$id',
    ),
    24 => 
    array (
      'module_id' => '146',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'logs',
      'module_class' => 'mcp',
      'parent_id' => '139',
      'left_id' => '48',
      'right_id' => '49',
      'module_langname' => 'MCP_LOGS_TOPIC_VIEW',
      'module_mode' => 'topic_logs',
      'module_auth' => 'acl_m_,$id',
    ),
    25 => 
    array (
      'module_id' => '140',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => '',
      'module_class' => 'mcp',
      'parent_id' => '0',
      'left_id' => '51',
      'right_id' => '58',
      'module_langname' => 'MCP_BAN',
      'module_mode' => '',
      'module_auth' => '',
    ),
    26 => 
    array (
      'module_id' => '141',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'ban',
      'module_class' => 'mcp',
      'parent_id' => '140',
      'left_id' => '52',
      'right_id' => '53',
      'module_langname' => 'MCP_BAN_USERNAMES',
      'module_mode' => 'user',
      'module_auth' => 'acl_m_ban',
    ),
    27 => 
    array (
      'module_id' => '142',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'ban',
      'module_class' => 'mcp',
      'parent_id' => '140',
      'left_id' => '54',
      'right_id' => '55',
      'module_langname' => 'MCP_BAN_IPS',
      'module_mode' => 'ip',
      'module_auth' => 'acl_m_ban',
    ),
    28 => 
    array (
      'module_id' => '143',
      'module_enabled' => '1',
      'module_display' => '1',
      'module_basename' => 'ban',
      'module_class' => 'mcp',
      'parent_id' => '140',
      'left_id' => '56',
      'right_id' => '57',
      'module_langname' => 'MCP_BAN_EMAILS',
      'module_mode' => 'email',
      'module_auth' => 'acl_m_ban',
    ),
  ),
  'parents' => 
  array (
    134 => 
    array (
    ),
    147 => 
    array (
      134 => '0',
    ),
    148 => 
    array (
      134 => '0',
    ),
    149 => 
    array (
      134 => '0',
    ),
    150 => 
    array (
      134 => '0',
    ),
    135 => 
    array (
    ),
    153 => 
    array (
      135 => '0',
    ),
    154 => 
    array (
      135 => '0',
    ),
    155 => 
    array (
      135 => '0',
    ),
    136 => 
    array (
    ),
    156 => 
    array (
      136 => '0',
    ),
    157 => 
    array (
      136 => '0',
    ),
    158 => 
    array (
      136 => '0',
    ),
    137 => 
    array (
    ),
    151 => 
    array (
      137 => '0',
    ),
    152 => 
    array (
      137 => '0',
    ),
    138 => 
    array (
    ),
    159 => 
    array (
      138 => '0',
    ),
    160 => 
    array (
      138 => '0',
    ),
    161 => 
    array (
      138 => '0',
    ),
    162 => 
    array (
      138 => '0',
    ),
    139 => 
    array (
    ),
    144 => 
    array (
      139 => '0',
    ),
    145 => 
    array (
      139 => '0',
    ),
    146 => 
    array (
      139 => '0',
    ),
    140 => 
    array (
    ),
    141 => 
    array (
      140 => '0',
    ),
    142 => 
    array (
      140 => '0',
    ),
    143 => 
    array (
      140 => '0',
    ),
  ),
);
?>
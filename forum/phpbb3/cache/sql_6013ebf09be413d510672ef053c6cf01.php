<?php

/* SELECT * FROM phpbb3_styles_imageset_data WHERE imageset_id = 1 AND image_lang IN ('en', '') */

$expired = (time() > 1207120596) ? true : false;
if ($expired) { return; }

$this->sql_rowset[$query_id] = array (
  0 => 
  array (
    'image_id' => '1',
    'image_name' => 'site_logo',
    'image_filename' => 'site_logo.gif',
    'image_lang' => '',
    'image_height' => '52',
    'image_width' => '139',
    'imageset_id' => '1',
  ),
  1 => 
  array (
    'image_id' => '2',
    'image_name' => 'forum_link',
    'image_filename' => 'forum_link.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  2 => 
  array (
    'image_id' => '3',
    'image_name' => 'forum_read',
    'image_filename' => 'forum_read.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  3 => 
  array (
    'image_id' => '4',
    'image_name' => 'forum_read_locked',
    'image_filename' => 'forum_read_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  4 => 
  array (
    'image_id' => '5',
    'image_name' => 'forum_read_subforum',
    'image_filename' => 'forum_read_subforum.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  5 => 
  array (
    'image_id' => '6',
    'image_name' => 'forum_unread',
    'image_filename' => 'forum_unread.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  6 => 
  array (
    'image_id' => '7',
    'image_name' => 'forum_unread_locked',
    'image_filename' => 'forum_unread_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  7 => 
  array (
    'image_id' => '8',
    'image_name' => 'forum_unread_subforum',
    'image_filename' => 'forum_unread_subforum.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  8 => 
  array (
    'image_id' => '9',
    'image_name' => 'topic_moved',
    'image_filename' => 'topic_moved.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  9 => 
  array (
    'image_id' => '10',
    'image_name' => 'topic_read',
    'image_filename' => 'topic_read.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  10 => 
  array (
    'image_id' => '11',
    'image_name' => 'topic_read_mine',
    'image_filename' => 'topic_read_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  11 => 
  array (
    'image_id' => '12',
    'image_name' => 'topic_read_hot',
    'image_filename' => 'topic_read_hot.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  12 => 
  array (
    'image_id' => '13',
    'image_name' => 'topic_read_hot_mine',
    'image_filename' => 'topic_read_hot_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  13 => 
  array (
    'image_id' => '14',
    'image_name' => 'topic_read_locked',
    'image_filename' => 'topic_read_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  14 => 
  array (
    'image_id' => '15',
    'image_name' => 'topic_read_locked_mine',
    'image_filename' => 'topic_read_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  15 => 
  array (
    'image_id' => '16',
    'image_name' => 'topic_unread',
    'image_filename' => 'topic_unread.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  16 => 
  array (
    'image_id' => '17',
    'image_name' => 'topic_unread_mine',
    'image_filename' => 'topic_unread_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  17 => 
  array (
    'image_id' => '18',
    'image_name' => 'topic_unread_hot',
    'image_filename' => 'topic_unread_hot.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  18 => 
  array (
    'image_id' => '19',
    'image_name' => 'topic_unread_hot_mine',
    'image_filename' => 'topic_unread_hot_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  19 => 
  array (
    'image_id' => '20',
    'image_name' => 'topic_unread_locked',
    'image_filename' => 'topic_unread_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  20 => 
  array (
    'image_id' => '21',
    'image_name' => 'topic_unread_locked_mine',
    'image_filename' => 'topic_unread_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  21 => 
  array (
    'image_id' => '22',
    'image_name' => 'sticky_read',
    'image_filename' => 'sticky_read.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  22 => 
  array (
    'image_id' => '23',
    'image_name' => 'sticky_read_mine',
    'image_filename' => 'sticky_read_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  23 => 
  array (
    'image_id' => '24',
    'image_name' => 'sticky_read_locked',
    'image_filename' => 'sticky_read_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  24 => 
  array (
    'image_id' => '25',
    'image_name' => 'sticky_read_locked_mine',
    'image_filename' => 'sticky_read_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  25 => 
  array (
    'image_id' => '26',
    'image_name' => 'sticky_unread',
    'image_filename' => 'sticky_unread.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  26 => 
  array (
    'image_id' => '27',
    'image_name' => 'sticky_unread_mine',
    'image_filename' => 'sticky_unread_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  27 => 
  array (
    'image_id' => '28',
    'image_name' => 'sticky_unread_locked',
    'image_filename' => 'sticky_unread_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  28 => 
  array (
    'image_id' => '29',
    'image_name' => 'sticky_unread_locked_mine',
    'image_filename' => 'sticky_unread_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  29 => 
  array (
    'image_id' => '30',
    'image_name' => 'announce_read',
    'image_filename' => 'announce_read.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  30 => 
  array (
    'image_id' => '31',
    'image_name' => 'announce_read_mine',
    'image_filename' => 'announce_read_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  31 => 
  array (
    'image_id' => '32',
    'image_name' => 'announce_read_locked',
    'image_filename' => 'announce_read_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  32 => 
  array (
    'image_id' => '33',
    'image_name' => 'announce_read_locked_mine',
    'image_filename' => 'announce_read_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  33 => 
  array (
    'image_id' => '34',
    'image_name' => 'announce_unread',
    'image_filename' => 'announce_unread.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  34 => 
  array (
    'image_id' => '35',
    'image_name' => 'announce_unread_mine',
    'image_filename' => 'announce_unread_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  35 => 
  array (
    'image_id' => '36',
    'image_name' => 'announce_unread_locked',
    'image_filename' => 'announce_unread_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  36 => 
  array (
    'image_id' => '37',
    'image_name' => 'announce_unread_locked_mine',
    'image_filename' => 'announce_unread_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  37 => 
  array (
    'image_id' => '38',
    'image_name' => 'global_read',
    'image_filename' => 'announce_read.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  38 => 
  array (
    'image_id' => '39',
    'image_name' => 'global_read_mine',
    'image_filename' => 'announce_read_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  39 => 
  array (
    'image_id' => '40',
    'image_name' => 'global_read_locked',
    'image_filename' => 'announce_read_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  40 => 
  array (
    'image_id' => '41',
    'image_name' => 'global_read_locked_mine',
    'image_filename' => 'announce_read_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  41 => 
  array (
    'image_id' => '42',
    'image_name' => 'global_unread',
    'image_filename' => 'announce_unread.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  42 => 
  array (
    'image_id' => '43',
    'image_name' => 'global_unread_mine',
    'image_filename' => 'announce_unread_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  43 => 
  array (
    'image_id' => '44',
    'image_name' => 'global_unread_locked',
    'image_filename' => 'announce_unread_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  44 => 
  array (
    'image_id' => '45',
    'image_name' => 'global_unread_locked_mine',
    'image_filename' => 'announce_unread_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  45 => 
  array (
    'image_id' => '46',
    'image_name' => 'pm_read',
    'image_filename' => 'topic_read.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  46 => 
  array (
    'image_id' => '47',
    'image_name' => 'pm_unread',
    'image_filename' => 'topic_unread.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
    'imageset_id' => '1',
  ),
  47 => 
  array (
    'image_id' => '48',
    'image_name' => 'icon_back_top',
    'image_filename' => 'icon_back_top.gif',
    'image_lang' => '',
    'image_height' => '11',
    'image_width' => '11',
    'imageset_id' => '1',
  ),
  48 => 
  array (
    'image_id' => '49',
    'image_name' => 'icon_contact_aim',
    'image_filename' => 'icon_contact_aim.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
    'imageset_id' => '1',
  ),
  49 => 
  array (
    'image_id' => '50',
    'image_name' => 'icon_contact_email',
    'image_filename' => 'icon_contact_email.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
    'imageset_id' => '1',
  ),
  50 => 
  array (
    'image_id' => '51',
    'image_name' => 'icon_contact_icq',
    'image_filename' => 'icon_contact_icq.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
    'imageset_id' => '1',
  ),
  51 => 
  array (
    'image_id' => '52',
    'image_name' => 'icon_contact_jabber',
    'image_filename' => 'icon_contact_jabber.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
    'imageset_id' => '1',
  ),
  52 => 
  array (
    'image_id' => '53',
    'image_name' => 'icon_contact_msnm',
    'image_filename' => 'icon_contact_msnm.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
    'imageset_id' => '1',
  ),
  53 => 
  array (
    'image_id' => '54',
    'image_name' => 'icon_contact_www',
    'image_filename' => 'icon_contact_www.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
    'imageset_id' => '1',
  ),
  54 => 
  array (
    'image_id' => '55',
    'image_name' => 'icon_contact_yahoo',
    'image_filename' => 'icon_contact_yahoo.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
    'imageset_id' => '1',
  ),
  55 => 
  array (
    'image_id' => '56',
    'image_name' => 'icon_post_delete',
    'image_filename' => 'icon_post_delete.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
    'imageset_id' => '1',
  ),
  56 => 
  array (
    'image_id' => '57',
    'image_name' => 'icon_post_info',
    'image_filename' => 'icon_post_info.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
    'imageset_id' => '1',
  ),
  57 => 
  array (
    'image_id' => '58',
    'image_name' => 'icon_post_report',
    'image_filename' => 'icon_post_report.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
    'imageset_id' => '1',
  ),
  58 => 
  array (
    'image_id' => '59',
    'image_name' => 'icon_post_target',
    'image_filename' => 'icon_post_target.gif',
    'image_lang' => '',
    'image_height' => '9',
    'image_width' => '11',
    'imageset_id' => '1',
  ),
  59 => 
  array (
    'image_id' => '60',
    'image_name' => 'icon_post_target_unread',
    'image_filename' => 'icon_post_target_unread.gif',
    'image_lang' => '',
    'image_height' => '9',
    'image_width' => '11',
    'imageset_id' => '1',
  ),
  60 => 
  array (
    'image_id' => '61',
    'image_name' => 'icon_topic_attach',
    'image_filename' => 'icon_topic_attach.gif',
    'image_lang' => '',
    'image_height' => '10',
    'image_width' => '7',
    'imageset_id' => '1',
  ),
  61 => 
  array (
    'image_id' => '62',
    'image_name' => 'icon_topic_latest',
    'image_filename' => 'icon_topic_latest.gif',
    'image_lang' => '',
    'image_height' => '9',
    'image_width' => '11',
    'imageset_id' => '1',
  ),
  62 => 
  array (
    'image_id' => '63',
    'image_name' => 'icon_topic_newest',
    'image_filename' => 'icon_topic_newest.gif',
    'image_lang' => '',
    'image_height' => '9',
    'image_width' => '11',
    'imageset_id' => '1',
  ),
  63 => 
  array (
    'image_id' => '64',
    'image_name' => 'icon_topic_reported',
    'image_filename' => 'icon_topic_reported.gif',
    'image_lang' => '',
    'image_height' => '14',
    'image_width' => '16',
    'imageset_id' => '1',
  ),
  64 => 
  array (
    'image_id' => '65',
    'image_name' => 'icon_topic_unapproved',
    'image_filename' => 'icon_topic_unapproved.gif',
    'image_lang' => '',
    'image_height' => '14',
    'image_width' => '16',
    'imageset_id' => '1',
  ),
  65 => 
  array (
    'image_id' => '66',
    'image_name' => 'icon_user_warn',
    'image_filename' => 'icon_user_warn.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
    'imageset_id' => '1',
  ),
  66 => 
  array (
    'image_id' => '67',
    'image_name' => 'subforum_read',
    'image_filename' => 'subforum_read.gif',
    'image_lang' => '',
    'image_height' => '9',
    'image_width' => '11',
    'imageset_id' => '1',
  ),
  67 => 
  array (
    'image_id' => '68',
    'image_name' => 'subforum_unread',
    'image_filename' => 'subforum_unread.gif',
    'image_lang' => '',
    'image_height' => '9',
    'image_width' => '11',
    'imageset_id' => '1',
  ),
  68 => 
  array (
    'image_id' => '69',
    'image_name' => 'icon_contact_pm',
    'image_filename' => 'icon_contact_pm.gif',
    'image_lang' => 'en',
    'image_height' => '20',
    'image_width' => '28',
    'imageset_id' => '1',
  ),
  69 => 
  array (
    'image_id' => '70',
    'image_name' => 'icon_post_edit',
    'image_filename' => 'icon_post_edit.gif',
    'image_lang' => 'en',
    'image_height' => '20',
    'image_width' => '42',
    'imageset_id' => '1',
  ),
  70 => 
  array (
    'image_id' => '71',
    'image_name' => 'icon_post_quote',
    'image_filename' => 'icon_post_quote.gif',
    'image_lang' => 'en',
    'image_height' => '20',
    'image_width' => '54',
    'imageset_id' => '1',
  ),
  71 => 
  array (
    'image_id' => '72',
    'image_name' => 'icon_user_online',
    'image_filename' => 'icon_user_online.gif',
    'image_lang' => 'en',
    'image_height' => '58',
    'image_width' => '58',
    'imageset_id' => '1',
  ),
  72 => 
  array (
    'image_id' => '73',
    'image_name' => 'button_pm_forward',
    'image_filename' => 'button_pm_forward.gif',
    'image_lang' => 'en',
    'image_height' => '25',
    'image_width' => '96',
    'imageset_id' => '1',
  ),
  73 => 
  array (
    'image_id' => '74',
    'image_name' => 'button_pm_new',
    'image_filename' => 'button_pm_new.gif',
    'image_lang' => 'en',
    'image_height' => '25',
    'image_width' => '84',
    'imageset_id' => '1',
  ),
  74 => 
  array (
    'image_id' => '75',
    'image_name' => 'button_pm_reply',
    'image_filename' => 'button_pm_reply.gif',
    'image_lang' => 'en',
    'image_height' => '25',
    'image_width' => '96',
    'imageset_id' => '1',
  ),
  75 => 
  array (
    'image_id' => '76',
    'image_name' => 'button_topic_locked',
    'image_filename' => 'button_topic_locked.gif',
    'image_lang' => 'en',
    'image_height' => '25',
    'image_width' => '88',
    'imageset_id' => '1',
  ),
  76 => 
  array (
    'image_id' => '77',
    'image_name' => 'button_topic_new',
    'image_filename' => 'button_topic_new.gif',
    'image_lang' => 'en',
    'image_height' => '25',
    'image_width' => '96',
    'imageset_id' => '1',
  ),
  77 => 
  array (
    'image_id' => '78',
    'image_name' => 'button_topic_reply',
    'image_filename' => 'button_topic_reply.gif',
    'image_lang' => 'en',
    'image_height' => '25',
    'image_width' => '96',
    'imageset_id' => '1',
  ),
);
?>
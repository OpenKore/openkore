<?php

/* SELECT image_name, image_filename, image_lang, image_height, image_width FROM phpbb3_styles_imageset_data WHERE imageset_id = 1 AND image_lang IN ('en', '') */

$expired = (time() > 1207120582) ? true : false;
if ($expired) { return; }

$this->sql_rowset[$query_id] = array (
  0 => 
  array (
    'image_name' => 'site_logo',
    'image_filename' => 'site_logo.gif',
    'image_lang' => '',
    'image_height' => '52',
    'image_width' => '139',
  ),
  1 => 
  array (
    'image_name' => 'forum_link',
    'image_filename' => 'forum_link.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  2 => 
  array (
    'image_name' => 'forum_read',
    'image_filename' => 'forum_read.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  3 => 
  array (
    'image_name' => 'forum_read_locked',
    'image_filename' => 'forum_read_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  4 => 
  array (
    'image_name' => 'forum_read_subforum',
    'image_filename' => 'forum_read_subforum.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  5 => 
  array (
    'image_name' => 'forum_unread',
    'image_filename' => 'forum_unread.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  6 => 
  array (
    'image_name' => 'forum_unread_locked',
    'image_filename' => 'forum_unread_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  7 => 
  array (
    'image_name' => 'forum_unread_subforum',
    'image_filename' => 'forum_unread_subforum.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  8 => 
  array (
    'image_name' => 'topic_moved',
    'image_filename' => 'topic_moved.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  9 => 
  array (
    'image_name' => 'topic_read',
    'image_filename' => 'topic_read.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  10 => 
  array (
    'image_name' => 'topic_read_mine',
    'image_filename' => 'topic_read_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  11 => 
  array (
    'image_name' => 'topic_read_hot',
    'image_filename' => 'topic_read_hot.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  12 => 
  array (
    'image_name' => 'topic_read_hot_mine',
    'image_filename' => 'topic_read_hot_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  13 => 
  array (
    'image_name' => 'topic_read_locked',
    'image_filename' => 'topic_read_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  14 => 
  array (
    'image_name' => 'topic_read_locked_mine',
    'image_filename' => 'topic_read_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  15 => 
  array (
    'image_name' => 'topic_unread',
    'image_filename' => 'topic_unread.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  16 => 
  array (
    'image_name' => 'topic_unread_mine',
    'image_filename' => 'topic_unread_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  17 => 
  array (
    'image_name' => 'topic_unread_hot',
    'image_filename' => 'topic_unread_hot.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  18 => 
  array (
    'image_name' => 'topic_unread_hot_mine',
    'image_filename' => 'topic_unread_hot_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  19 => 
  array (
    'image_name' => 'topic_unread_locked',
    'image_filename' => 'topic_unread_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  20 => 
  array (
    'image_name' => 'topic_unread_locked_mine',
    'image_filename' => 'topic_unread_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  21 => 
  array (
    'image_name' => 'sticky_read',
    'image_filename' => 'sticky_read.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  22 => 
  array (
    'image_name' => 'sticky_read_mine',
    'image_filename' => 'sticky_read_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  23 => 
  array (
    'image_name' => 'sticky_read_locked',
    'image_filename' => 'sticky_read_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  24 => 
  array (
    'image_name' => 'sticky_read_locked_mine',
    'image_filename' => 'sticky_read_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  25 => 
  array (
    'image_name' => 'sticky_unread',
    'image_filename' => 'sticky_unread.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  26 => 
  array (
    'image_name' => 'sticky_unread_mine',
    'image_filename' => 'sticky_unread_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  27 => 
  array (
    'image_name' => 'sticky_unread_locked',
    'image_filename' => 'sticky_unread_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  28 => 
  array (
    'image_name' => 'sticky_unread_locked_mine',
    'image_filename' => 'sticky_unread_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  29 => 
  array (
    'image_name' => 'announce_read',
    'image_filename' => 'announce_read.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  30 => 
  array (
    'image_name' => 'announce_read_mine',
    'image_filename' => 'announce_read_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  31 => 
  array (
    'image_name' => 'announce_read_locked',
    'image_filename' => 'announce_read_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  32 => 
  array (
    'image_name' => 'announce_read_locked_mine',
    'image_filename' => 'announce_read_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  33 => 
  array (
    'image_name' => 'announce_unread',
    'image_filename' => 'announce_unread.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  34 => 
  array (
    'image_name' => 'announce_unread_mine',
    'image_filename' => 'announce_unread_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  35 => 
  array (
    'image_name' => 'announce_unread_locked',
    'image_filename' => 'announce_unread_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  36 => 
  array (
    'image_name' => 'announce_unread_locked_mine',
    'image_filename' => 'announce_unread_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  37 => 
  array (
    'image_name' => 'global_read',
    'image_filename' => 'announce_read.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  38 => 
  array (
    'image_name' => 'global_read_mine',
    'image_filename' => 'announce_read_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  39 => 
  array (
    'image_name' => 'global_read_locked',
    'image_filename' => 'announce_read_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  40 => 
  array (
    'image_name' => 'global_read_locked_mine',
    'image_filename' => 'announce_read_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  41 => 
  array (
    'image_name' => 'global_unread',
    'image_filename' => 'announce_unread.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  42 => 
  array (
    'image_name' => 'global_unread_mine',
    'image_filename' => 'announce_unread_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  43 => 
  array (
    'image_name' => 'global_unread_locked',
    'image_filename' => 'announce_unread_locked.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  44 => 
  array (
    'image_name' => 'global_unread_locked_mine',
    'image_filename' => 'announce_unread_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  45 => 
  array (
    'image_name' => 'pm_read',
    'image_filename' => 'topic_read.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  46 => 
  array (
    'image_name' => 'pm_unread',
    'image_filename' => 'topic_unread.gif',
    'image_lang' => '',
    'image_height' => '27',
    'image_width' => '27',
  ),
  47 => 
  array (
    'image_name' => 'icon_back_top',
    'image_filename' => 'icon_back_top.gif',
    'image_lang' => '',
    'image_height' => '11',
    'image_width' => '11',
  ),
  48 => 
  array (
    'image_name' => 'icon_contact_aim',
    'image_filename' => 'icon_contact_aim.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
  ),
  49 => 
  array (
    'image_name' => 'icon_contact_email',
    'image_filename' => 'icon_contact_email.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
  ),
  50 => 
  array (
    'image_name' => 'icon_contact_icq',
    'image_filename' => 'icon_contact_icq.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
  ),
  51 => 
  array (
    'image_name' => 'icon_contact_jabber',
    'image_filename' => 'icon_contact_jabber.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
  ),
  52 => 
  array (
    'image_name' => 'icon_contact_msnm',
    'image_filename' => 'icon_contact_msnm.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
  ),
  53 => 
  array (
    'image_name' => 'icon_contact_www',
    'image_filename' => 'icon_contact_www.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
  ),
  54 => 
  array (
    'image_name' => 'icon_contact_yahoo',
    'image_filename' => 'icon_contact_yahoo.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
  ),
  55 => 
  array (
    'image_name' => 'icon_post_delete',
    'image_filename' => 'icon_post_delete.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
  ),
  56 => 
  array (
    'image_name' => 'icon_post_info',
    'image_filename' => 'icon_post_info.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
  ),
  57 => 
  array (
    'image_name' => 'icon_post_report',
    'image_filename' => 'icon_post_report.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
  ),
  58 => 
  array (
    'image_name' => 'icon_post_target',
    'image_filename' => 'icon_post_target.gif',
    'image_lang' => '',
    'image_height' => '9',
    'image_width' => '11',
  ),
  59 => 
  array (
    'image_name' => 'icon_post_target_unread',
    'image_filename' => 'icon_post_target_unread.gif',
    'image_lang' => '',
    'image_height' => '9',
    'image_width' => '11',
  ),
  60 => 
  array (
    'image_name' => 'icon_topic_attach',
    'image_filename' => 'icon_topic_attach.gif',
    'image_lang' => '',
    'image_height' => '10',
    'image_width' => '7',
  ),
  61 => 
  array (
    'image_name' => 'icon_topic_latest',
    'image_filename' => 'icon_topic_latest.gif',
    'image_lang' => '',
    'image_height' => '9',
    'image_width' => '11',
  ),
  62 => 
  array (
    'image_name' => 'icon_topic_newest',
    'image_filename' => 'icon_topic_newest.gif',
    'image_lang' => '',
    'image_height' => '9',
    'image_width' => '11',
  ),
  63 => 
  array (
    'image_name' => 'icon_topic_reported',
    'image_filename' => 'icon_topic_reported.gif',
    'image_lang' => '',
    'image_height' => '14',
    'image_width' => '16',
  ),
  64 => 
  array (
    'image_name' => 'icon_topic_unapproved',
    'image_filename' => 'icon_topic_unapproved.gif',
    'image_lang' => '',
    'image_height' => '14',
    'image_width' => '16',
  ),
  65 => 
  array (
    'image_name' => 'icon_user_warn',
    'image_filename' => 'icon_user_warn.gif',
    'image_lang' => '',
    'image_height' => '20',
    'image_width' => '20',
  ),
  66 => 
  array (
    'image_name' => 'subforum_read',
    'image_filename' => 'subforum_read.gif',
    'image_lang' => '',
    'image_height' => '9',
    'image_width' => '11',
  ),
  67 => 
  array (
    'image_name' => 'subforum_unread',
    'image_filename' => 'subforum_unread.gif',
    'image_lang' => '',
    'image_height' => '9',
    'image_width' => '11',
  ),
  68 => 
  array (
    'image_name' => 'icon_contact_pm',
    'image_filename' => 'icon_contact_pm.gif',
    'image_lang' => 'en',
    'image_height' => '20',
    'image_width' => '28',
  ),
  69 => 
  array (
    'image_name' => 'icon_post_edit',
    'image_filename' => 'icon_post_edit.gif',
    'image_lang' => 'en',
    'image_height' => '20',
    'image_width' => '42',
  ),
  70 => 
  array (
    'image_name' => 'icon_post_quote',
    'image_filename' => 'icon_post_quote.gif',
    'image_lang' => 'en',
    'image_height' => '20',
    'image_width' => '54',
  ),
  71 => 
  array (
    'image_name' => 'icon_user_online',
    'image_filename' => 'icon_user_online.gif',
    'image_lang' => 'en',
    'image_height' => '58',
    'image_width' => '58',
  ),
  72 => 
  array (
    'image_name' => 'button_pm_forward',
    'image_filename' => 'button_pm_forward.gif',
    'image_lang' => 'en',
    'image_height' => '25',
    'image_width' => '96',
  ),
  73 => 
  array (
    'image_name' => 'button_pm_new',
    'image_filename' => 'button_pm_new.gif',
    'image_lang' => 'en',
    'image_height' => '25',
    'image_width' => '84',
  ),
  74 => 
  array (
    'image_name' => 'button_pm_reply',
    'image_filename' => 'button_pm_reply.gif',
    'image_lang' => 'en',
    'image_height' => '25',
    'image_width' => '96',
  ),
  75 => 
  array (
    'image_name' => 'button_topic_locked',
    'image_filename' => 'button_topic_locked.gif',
    'image_lang' => 'en',
    'image_height' => '25',
    'image_width' => '88',
  ),
  76 => 
  array (
    'image_name' => 'button_topic_new',
    'image_filename' => 'button_topic_new.gif',
    'image_lang' => 'en',
    'image_height' => '25',
    'image_width' => '96',
  ),
  77 => 
  array (
    'image_name' => 'button_topic_reply',
    'image_filename' => 'button_topic_reply.gif',
    'image_lang' => 'en',
    'image_height' => '25',
    'image_width' => '96',
  ),
);
?>
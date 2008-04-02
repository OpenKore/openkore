<?php

/* SELECT image_name, image_filename, image_lang, image_height, image_width FROM phpbb3_styles_imageset_data WHERE imageset_id = 2 AND image_lang IN ('en', '') */

$expired = (time() > 1207120781) ? true : false;
if ($expired) { return; }

$this->sql_rowset[$query_id] = array (
  0 => 
  array (
    'image_name' => 'site_logo',
    'image_filename' => 'site_logo.gif',
    'image_lang' => '',
    'image_height' => '94',
    'image_width' => '170',
  ),
  1 => 
  array (
    'image_name' => 'upload_bar',
    'image_filename' => 'upload_bar.gif',
    'image_lang' => '',
    'image_height' => '16',
    'image_width' => '280',
  ),
  2 => 
  array (
    'image_name' => 'poll_left',
    'image_filename' => 'poll_left.gif',
    'image_lang' => '',
    'image_height' => '12',
    'image_width' => '4',
  ),
  3 => 
  array (
    'image_name' => 'poll_center',
    'image_filename' => 'poll_center.gif',
    'image_lang' => '',
    'image_height' => '12',
    'image_width' => '0',
  ),
  4 => 
  array (
    'image_name' => 'poll_right',
    'image_filename' => 'poll_right.gif',
    'image_lang' => '',
    'image_height' => '12',
    'image_width' => '4',
  ),
  5 => 
  array (
    'image_name' => 'forum_link',
    'image_filename' => 'forum_link.gif',
    'image_lang' => '',
    'image_height' => '25',
    'image_width' => '46',
  ),
  6 => 
  array (
    'image_name' => 'forum_read',
    'image_filename' => 'forum_read.gif',
    'image_lang' => '',
    'image_height' => '25',
    'image_width' => '46',
  ),
  7 => 
  array (
    'image_name' => 'forum_read_locked',
    'image_filename' => 'forum_read_locked.gif',
    'image_lang' => '',
    'image_height' => '25',
    'image_width' => '46',
  ),
  8 => 
  array (
    'image_name' => 'forum_read_subforum',
    'image_filename' => 'forum_read_subforum.gif',
    'image_lang' => '',
    'image_height' => '25',
    'image_width' => '46',
  ),
  9 => 
  array (
    'image_name' => 'forum_unread',
    'image_filename' => 'forum_unread.gif',
    'image_lang' => '',
    'image_height' => '25',
    'image_width' => '46',
  ),
  10 => 
  array (
    'image_name' => 'forum_unread_locked',
    'image_filename' => 'forum_unread_locked.gif',
    'image_lang' => '',
    'image_height' => '25',
    'image_width' => '46',
  ),
  11 => 
  array (
    'image_name' => 'forum_unread_subforum',
    'image_filename' => 'forum_unread_subforum.gif',
    'image_lang' => '',
    'image_height' => '25',
    'image_width' => '46',
  ),
  12 => 
  array (
    'image_name' => 'topic_moved',
    'image_filename' => 'topic_moved.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  13 => 
  array (
    'image_name' => 'topic_read',
    'image_filename' => 'topic_read.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  14 => 
  array (
    'image_name' => 'topic_read_mine',
    'image_filename' => 'topic_read_mine.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  15 => 
  array (
    'image_name' => 'topic_read_hot',
    'image_filename' => 'topic_read_hot.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  16 => 
  array (
    'image_name' => 'topic_read_hot_mine',
    'image_filename' => 'topic_read_hot_mine.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  17 => 
  array (
    'image_name' => 'topic_read_locked',
    'image_filename' => 'topic_read_locked.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  18 => 
  array (
    'image_name' => 'topic_read_locked_mine',
    'image_filename' => 'topic_read_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  19 => 
  array (
    'image_name' => 'topic_unread',
    'image_filename' => 'topic_unread.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  20 => 
  array (
    'image_name' => 'topic_unread_mine',
    'image_filename' => 'topic_unread_mine.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  21 => 
  array (
    'image_name' => 'topic_unread_hot',
    'image_filename' => 'topic_unread_hot.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  22 => 
  array (
    'image_name' => 'topic_unread_hot_mine',
    'image_filename' => 'topic_unread_hot_mine.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  23 => 
  array (
    'image_name' => 'topic_unread_locked',
    'image_filename' => 'topic_unread_locked.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  24 => 
  array (
    'image_name' => 'topic_unread_locked_mine',
    'image_filename' => 'topic_unread_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  25 => 
  array (
    'image_name' => 'sticky_read',
    'image_filename' => 'sticky_read.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  26 => 
  array (
    'image_name' => 'sticky_read_mine',
    'image_filename' => 'sticky_read_mine.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  27 => 
  array (
    'image_name' => 'sticky_read_locked',
    'image_filename' => 'sticky_read_locked.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  28 => 
  array (
    'image_name' => 'sticky_read_locked_mine',
    'image_filename' => 'sticky_read_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  29 => 
  array (
    'image_name' => 'sticky_unread',
    'image_filename' => 'sticky_unread.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  30 => 
  array (
    'image_name' => 'sticky_unread_mine',
    'image_filename' => 'sticky_unread_mine.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  31 => 
  array (
    'image_name' => 'sticky_unread_locked',
    'image_filename' => 'sticky_unread_locked.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  32 => 
  array (
    'image_name' => 'sticky_unread_locked_mine',
    'image_filename' => 'sticky_unread_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  33 => 
  array (
    'image_name' => 'announce_read',
    'image_filename' => 'announce_read.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  34 => 
  array (
    'image_name' => 'announce_read_mine',
    'image_filename' => 'announce_read_mine.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  35 => 
  array (
    'image_name' => 'announce_read_locked',
    'image_filename' => 'announce_read_locked.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  36 => 
  array (
    'image_name' => 'announce_read_locked_mine',
    'image_filename' => 'announce_read_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  37 => 
  array (
    'image_name' => 'announce_unread',
    'image_filename' => 'announce_unread.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  38 => 
  array (
    'image_name' => 'announce_unread_mine',
    'image_filename' => 'announce_unread_mine.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  39 => 
  array (
    'image_name' => 'announce_unread_locked',
    'image_filename' => 'announce_unread_locked.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  40 => 
  array (
    'image_name' => 'announce_unread_locked_mine',
    'image_filename' => 'announce_unread_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  41 => 
  array (
    'image_name' => 'global_read',
    'image_filename' => 'announce_read.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  42 => 
  array (
    'image_name' => 'global_read_mine',
    'image_filename' => 'announce_read_mine.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  43 => 
  array (
    'image_name' => 'global_read_locked',
    'image_filename' => 'announce_read_locked.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  44 => 
  array (
    'image_name' => 'global_read_locked_mine',
    'image_filename' => 'announce_read_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  45 => 
  array (
    'image_name' => 'global_unread',
    'image_filename' => 'announce_unread.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  46 => 
  array (
    'image_name' => 'global_unread_mine',
    'image_filename' => 'announce_unread_mine.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  47 => 
  array (
    'image_name' => 'global_unread_locked',
    'image_filename' => 'announce_unread_locked.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  48 => 
  array (
    'image_name' => 'global_unread_locked_mine',
    'image_filename' => 'announce_unread_locked_mine.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  49 => 
  array (
    'image_name' => 'pm_read',
    'image_filename' => 'topic_read.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  50 => 
  array (
    'image_name' => 'pm_unread',
    'image_filename' => 'topic_unread.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  51 => 
  array (
    'image_name' => 'icon_post_target',
    'image_filename' => 'icon_post_target.gif',
    'image_lang' => '',
    'image_height' => '9',
    'image_width' => '12',
  ),
  52 => 
  array (
    'image_name' => 'icon_post_target_unread',
    'image_filename' => 'icon_post_target_unread.gif',
    'image_lang' => '',
    'image_height' => '9',
    'image_width' => '12',
  ),
  53 => 
  array (
    'image_name' => 'icon_topic_attach',
    'image_filename' => 'icon_topic_attach.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '14',
  ),
  54 => 
  array (
    'image_name' => 'icon_topic_latest',
    'image_filename' => 'icon_topic_latest.gif',
    'image_lang' => '',
    'image_height' => '9',
    'image_width' => '18',
  ),
  55 => 
  array (
    'image_name' => 'icon_topic_newest',
    'image_filename' => 'icon_topic_newest.gif',
    'image_lang' => '',
    'image_height' => '9',
    'image_width' => '18',
  ),
  56 => 
  array (
    'image_name' => 'icon_topic_reported',
    'image_filename' => 'icon_topic_reported.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  57 => 
  array (
    'image_name' => 'icon_topic_unapproved',
    'image_filename' => 'icon_topic_unapproved.gif',
    'image_lang' => '',
    'image_height' => '18',
    'image_width' => '19',
  ),
  58 => 
  array (
    'image_name' => 'icon_contact_aim',
    'image_filename' => 'icon_contact_aim.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  59 => 
  array (
    'image_name' => 'icon_contact_email',
    'image_filename' => 'icon_contact_email.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  60 => 
  array (
    'image_name' => 'icon_contact_icq',
    'image_filename' => 'icon_contact_icq.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  61 => 
  array (
    'image_name' => 'icon_contact_jabber',
    'image_filename' => 'icon_contact_jabber.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  62 => 
  array (
    'image_name' => 'icon_contact_msnm',
    'image_filename' => 'icon_contact_msnm.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  63 => 
  array (
    'image_name' => 'icon_contact_pm',
    'image_filename' => 'icon_contact_pm.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  64 => 
  array (
    'image_name' => 'icon_contact_yahoo',
    'image_filename' => 'icon_contact_yahoo.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  65 => 
  array (
    'image_name' => 'icon_contact_www',
    'image_filename' => 'icon_contact_www.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  66 => 
  array (
    'image_name' => 'icon_post_delete',
    'image_filename' => 'icon_post_delete.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  67 => 
  array (
    'image_name' => 'icon_post_edit',
    'image_filename' => 'icon_post_edit.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  68 => 
  array (
    'image_name' => 'icon_post_info',
    'image_filename' => 'icon_post_info.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  69 => 
  array (
    'image_name' => 'icon_post_quote',
    'image_filename' => 'icon_post_quote.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  70 => 
  array (
    'image_name' => 'icon_post_report',
    'image_filename' => 'icon_post_report.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  71 => 
  array (
    'image_name' => 'icon_user_online',
    'image_filename' => 'icon_user_online.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  72 => 
  array (
    'image_name' => 'icon_user_offline',
    'image_filename' => 'icon_user_offline.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  73 => 
  array (
    'image_name' => 'icon_user_profile',
    'image_filename' => 'icon_user_profile.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  74 => 
  array (
    'image_name' => 'icon_user_search',
    'image_filename' => 'icon_user_search.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  75 => 
  array (
    'image_name' => 'icon_user_warn',
    'image_filename' => 'icon_user_warn.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  76 => 
  array (
    'image_name' => 'button_pm_new',
    'image_filename' => 'button_pm_new.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  77 => 
  array (
    'image_name' => 'button_pm_reply',
    'image_filename' => 'button_pm_reply.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  78 => 
  array (
    'image_name' => 'button_topic_locked',
    'image_filename' => 'button_topic_locked.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  79 => 
  array (
    'image_name' => 'button_topic_new',
    'image_filename' => 'button_topic_new.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
  80 => 
  array (
    'image_name' => 'button_topic_reply',
    'image_filename' => 'button_topic_reply.gif',
    'image_lang' => 'en',
    'image_height' => '0',
    'image_width' => '0',
  ),
);
?>
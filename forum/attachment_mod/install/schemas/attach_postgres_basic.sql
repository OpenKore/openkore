/*
  Basic DB Data for Attachment Mod - Postgresql
 
  $Id: attach_postgres_basic.sql,v 1.14 2005/07/16 14:32:28 acydburn Exp $

*/

/* -- attachments_config */
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('upload_dir','files');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('upload_img','images/icon_clip.gif');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('topic_icon','images/icon_clip.gif');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('display_order','0');

INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('max_filesize','262144');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('attachment_quota','52428800');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('max_filesize_pm','262144');

INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('max_attachments','3');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('max_attachments_pm','1');

INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('disable_mod','0');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('allow_pm_attach','1');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('attachment_topic_review','0');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('allow_ftp_upload','0');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('show_apcp','0');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('attach_version','2.3.14');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('default_upload_quota', '0');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('default_pm_quota', '0');

INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('ftp_server','');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('ftp_path','');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('download_path','');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('ftp_user','');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('ftp_pass','');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('ftp_pasv_mode','1');

INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('img_display_inlined','1');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('img_max_width','0');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('img_max_height','0');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('img_link_width','0');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('img_link_height','0');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('img_create_thumbnail','0');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('img_min_thumb_filesize','12000');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('img_imagick', '');
INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('use_gd2','0');

INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('wma_autoplay','0');

INSERT INTO phpbb_attachments_config (config_name, config_value) VALUES ('flash_autoplay','0');

/* -- forbidden_extensions */
INSERT INTO phpbb_forbidden_extensions (extension) VALUES ('php');
INSERT INTO phpbb_forbidden_extensions (extension) VALUES ('php3');
INSERT INTO phpbb_forbidden_extensions (extension) VALUES ('php4');
INSERT INTO phpbb_forbidden_extensions (extension) VALUES ('phtml');
INSERT INTO phpbb_forbidden_extensions (extension) VALUES ('pl');
INSERT INTO phpbb_forbidden_extensions (extension) VALUES ('asp');
INSERT INTO phpbb_forbidden_extensions (extension) VALUES ('cgi');

/* -- extension_groups */
INSERT INTO phpbb_extension_groups (group_name, cat_id, allow_group, download_mode, upload_icon, max_filesize, forum_permissions) VALUES ('Images',1,1,1,'',0,'');
INSERT INTO phpbb_extension_groups (group_name, cat_id, allow_group, download_mode, upload_icon, max_filesize, forum_permissions) VALUES ('Archives',0,1,1,'',0,'');
INSERT INTO phpbb_extension_groups (group_name, cat_id, allow_group, download_mode, upload_icon, max_filesize, forum_permissions) VALUES ('Plain Text',0,0,1,'',0,'');
INSERT INTO phpbb_extension_groups (group_name, cat_id, allow_group, download_mode, upload_icon, max_filesize, forum_permissions) VALUES ('Documents',0,0,1,'',0,'');
INSERT INTO phpbb_extension_groups (group_name, cat_id, allow_group, download_mode, upload_icon, max_filesize, forum_permissions) VALUES ('Real Media',0,0,2,'',0,'');
INSERT INTO phpbb_extension_groups (group_name, cat_id, allow_group, download_mode, upload_icon, max_filesize, forum_permissions) VALUES ('Streams',2,0,1,'',0,'');
INSERT INTO phpbb_extension_groups (group_name, cat_id, allow_group, download_mode, upload_icon, max_filesize, forum_permissions) VALUES ('Flash Files',3,0,1,'',0,'');

/* -- extensions */
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (1,'gif', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (1,'png', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (1,'jpeg', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (1,'jpg', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (1,'tif', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (1,'tga', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (2,'gtar', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (2,'gz', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (2,'tar', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (2,'zip', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (2,'rar', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (2,'ace', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (3,'txt', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (3,'c', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (3,'h', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (3,'cpp', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (3,'hpp', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (3,'diz', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (4,'xls', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (4,'doc', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (4,'dot', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (4,'pdf', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (4,'ai', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (4,'ps', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (4,'ppt', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (5,'rm', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (6,'wma', '');
INSERT INTO phpbb_extensions (group_id, extension, comment) VALUES (7,'swf', '');

/* -- default quota limits */
INSERT INTO phpbb_quota_limits (quota_desc, quota_limit) VALUES ('Low', 262144);
INSERT INTO phpbb_quota_limits (quota_desc, quota_limit) VALUES ('Medium', 2097152);
INSERT INTO phpbb_quota_limits (quota_desc, quota_limit) VALUES ('High', 5242880);

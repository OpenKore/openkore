/*
  phpBB2 - attach_mod schema - Postgresql

  $Id: attach_postgres_schema.sql,v 1.4 2004/10/31 16:47:00 acydburn Exp $

*/

/*
  Create auto_increment values
*/

CREATE SEQUENCE phpbb_extensions_id_seq start 1 increment 1 maxvalue 2147483647 minvalue 1 cache 1;
CREATE SEQUENCE phpbb_forbidden_extensions_id_seq start 1 increment 1 maxvalue 2147483647 minvalue 1 cache 1;
CREATE SEQUENCE phpbb_extension_groups_id_seq start 1 increment 1 maxvalue 2147483647 minvalue 1 cache 1;
CREATE SEQUENCE phpbb_attachments_desc_id_seq start 1 increment 1 maxvalue 2147483647 minvalue 1 cache 1;
CREATE SEQUENCE phpbb_quota_limits_id_seq start 1 increment 1 maxvalue 2147483647 minvalue 1 cache 1;

/* --- Table structure for table 'phpbb_attachments_config' */
CREATE TABLE phpbb_attachments_config (
   config_name varchar(255) NOT NULL,
   config_value varchar(255) NOT NULL,
   CONSTRAINT phpbb_attachments_config_pkey PRIMARY KEY (config_name)
);

/* --- Table structure for table 'phpbb_forbidden_extensions' */
CREATE TABLE phpbb_forbidden_extensions (
  ext_id int2 DEFAULT nextval('phpbb_forbidden_extensions_id_seq'::text) NOT NULL,
  extension varchar(100) DEFAULT '' NOT NULL, 
  CONSTRAINT phpbb_forbidden_extensions_pkey PRIMARY KEY (ext_id)
);

/* --- Table structure for table 'phpbb_extension_groups' */
CREATE TABLE phpbb_extension_groups (
  group_id int4 DEFAULT nextval('phpbb_extension_groups_id_seq'::text) NOT NULL,
  group_name varchar(20) NOT NULL,
  cat_id int2 DEFAULT 0 NOT NULL,
  allow_group int2 DEFAULT 0 NOT NULL,
  download_mode int2 DEFAULT 1 NOT NULL,
  upload_icon varchar(100) DEFAULT '',
  max_filesize int4 DEFAULT 0 NOT NULL,
  forum_permissions varchar(255) NOT NULL,
  CONSTRAINT phpbb_extension_groups_pkey PRIMARY KEY (group_id)
);

/* --- Table structure for table 'phpbb_extensions' */
CREATE TABLE phpbb_extensions (
  ext_id int2 DEFAULT nextval('phpbb_extensions_id_seq'::text) NOT NULL,
  group_id int4 DEFAULT 0 NOT NULL,
  extension varchar(100) NOT NULL,
  comment varchar(100),
  CONSTRAINT phpbb_extensions_pkey PRIMARY KEY (ext_id)
);

/* --- Table structure for table 'phpbb_attachments_desc' */
CREATE TABLE phpbb_attachments_desc (
  attach_id int4 DEFAULT nextval('phpbb_attachments_desc_id_seq'::text) NOT NULL,
  physical_filename varchar(255) NOT NULL,
  real_filename varchar(255) NOT NULL,
  download_count int4 DEFAULT 0 NOT NULL,
  comment varchar(255) DEFAULT '',
  extension varchar(100),
  mimetype varchar(100),
  filesize int4 NOT NULL,
  filetime int4 DEFAULT 0 NOT NULL,
  thumbnail int2 DEFAULT 0 NOT NULL,
  CONSTRAINT phpbb_attachments_desc_pkey PRIMARY KEY (attach_id)
);

/* --- Table structure for table 'phpbb_attachments' */
CREATE TABLE phpbb_attachments (
  attach_id int4 DEFAULT 0 NOT NULL, 
  post_id int4 DEFAULT 0 NOT NULL, 
  privmsgs_id int4 DEFAULT 0 NOT NULL,
  user_id_1 int4 NOT NULL,
  user_id_2 int4 NOT NULL
); 
CREATE INDEX attach_id_post_id_phpbb_attachments_index ON phpbb_attachments (attach_id, post_id);
CREATE INDEX attach_id_privmsgs_id_phpbb_attachments_index ON phpbb_attachments (attach_id, privmsgs_id);
CREATE INDEX post_id_phpbb_attachments_index ON phpbb_attachments (post_id);
CREATE INDEX privmsgs_id_phpbb_attachments_index ON phpbb_attachments (privmsgs_id);

/* --- Table structure for table 'phpbb_quota_limits' */
CREATE TABLE phpbb_quota_limits (
  quota_limit_id int4 DEFAULT nextval('phpbb_quota_limits_id_seq'::text) NOT NULL,
  quota_desc varchar(20) DEFAULT '' NOT NULL,
  quota_limit int8 DEFAULT 0 NOT NULL,
  CONSTRAINT phpbb_quota_limits_pkey PRIMARY KEY (quota_limit_id)
);

/* --- Table structure for table 'phpbb_attach_quota' */
CREATE TABLE phpbb_attach_quota (
  user_id int4 DEFAULT 0 NOT NULL,
  group_id int4 DEFAULT 0 NOT NULL,
  quota_type int2 DEFAULT 0 NOT NULL,
  quota_limit_id int4 DEFAULT 0 NOT NULL
);
CREATE INDEX quota_type_phpbb_attach_quota_index ON phpbb_attach_quota (quota_type);

/* --- Alter Table Schema */
ALTER TABLE phpbb_forums ADD auth_download int2;
UPDATE phpbb_forums SET auth_download = 0;
ALTER TABLE phpbb_forums ALTER COLUMN auth_download SET DEFAULT 0;
ALTER TABLE phpbb_forums ADD CONSTRAINT auth_download_notnull CHECK (auth_download NOTNULL);

ALTER TABLE phpbb_auth_access ADD auth_download int2;
UPDATE phpbb_auth_access SET auth_download = 0;
ALTER TABLE phpbb_auth_access ALTER COLUMN auth_download SET DEFAULT 0;
ALTER TABLE phpbb_auth_access ADD CONSTRAINT auth_download_notnull CHECK (auth_download NOTNULL);

ALTER TABLE phpbb_posts ADD post_attachment int2;
UPDATE phpbb_posts SET post_attachment = 0;
ALTER TABLE phpbb_posts ALTER COLUMN post_attachment SET DEFAULT 0;
ALTER TABLE phpbb_posts ADD CONSTRAINT post_attachment_notnull CHECK (post_attachment NOTNULL);

ALTER TABLE phpbb_topics ADD topic_attachment int2;
UPDATE phpbb_topics SET topic_attachment = 0;
ALTER TABLE phpbb_topics ALTER COLUMN topic_attachment SET DEFAULT 0;
ALTER TABLE phpbb_topics ADD CONSTRAINT topic_attachment_notnull CHECK (topic_attachment NOTNULL);

ALTER TABLE phpbb_privmsgs ADD privmsgs_attachment int2;
UPDATE phpbb_privmsgs SET privmsgs_attachment = 0;
ALTER TABLE phpbb_privmsgs ALTER COLUMN privmsgs_attachment SET DEFAULT 0;
ALTER TABLE phpbb_privmsgs ADD CONSTRAINT privmsgs_attachment_notnull CHECK (privmsgs_attachment NOTNULL);

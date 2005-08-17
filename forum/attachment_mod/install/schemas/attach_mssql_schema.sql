/*
 phpBB2 - attach_mod schema - mssql

 $Id: attach_mssql_schema.sql,v 1.3 2003/01/29 11:43:58 acydburn Exp $

*/

BEGIN TRANSACTION
GO

CREATE TABLE [phpbb_attachments_config] (
	[config_name] [varchar] (100) NOT NULL ,
	[config_value] [varchar] (100) NOT NULL 
) ON [PRIMARY]
GO

CREATE TABLE [phpbb_forbidden_extensions] (
	[ext_id] [int] IDENTITY (1, 1) NOT NULL ,
	[extension] [char] (100) NOT NULL 
) ON [PRIMARY]
GO

CREATE TABLE [phpbb_extension_groups] (
	[group_id] [int] IDENTITY (1, 1) NOT NULL ,
	[group_name] [char] (20) NOT NULL ,
	[cat_id] [tinyint] NOT NULL ,
	[allow_group] [tinyint] NOT NULL ,
	[download_mode] [tinyint] NOT NULL ,
        [upload_icon] [varchar] (100) NOT NULL ,
        [max_filesize] [int] NOT NULL ,
	[forum_permissions] [varchar] (255) NOT NULL 
) ON [PRIMARY]
GO

CREATE TABLE [phpbb_extensions] (
	[ext_id] [int] IDENTITY (1, 1) NOT NULL ,
	[group_id] [int] NOT NULL ,
	[extension] [varchar] (100) NOT NULL ,
	[comment] [varchar] (100) NOT NULL 
) ON [PRIMARY] 
GO

CREATE TABLE [phpbb_attachments_desc] (
	[attach_id] [int] IDENTITY (1, 1) NOT NULL ,
	[physical_filename] [varchar] (100) NOT NULL ,
	[real_filename] [varchar] (100) NOT NULL ,
	[download_count] [int] NOT NULL ,
	[comment] [varchar] (100) NULL ,
	[extension] [varchar] (100) NULL ,
	[mimetype] [varchar] (50) NULL ,
	[filesize] [int] NOT NULL ,
	[filetime] [int] NOT NULL ,
	[thumbnail] [tinyint] NOT NULL
) ON [PRIMARY]
GO

CREATE TABLE [phpbb_attachments] (
	[attach_id] [int] NOT NULL ,
	[post_id] [int] NOT NULL ,
	[privmsgs_id] [int] NOT NULL ,
	[user_id_1] [int] NOT NULL,
	[user_id_2] [int] NOT NULL
)
GO

CREATE TABLE [phpbb_quota_limits] (
  [quota_limit_id] [int] IDENTITY (1, 1) NOT NULL ,
  [quota_desc] [varchar] (20) NOT NULL,
  [quota_limit] [bigint] NOT NULL
) ON [PRIMARY];
GO

CREATE TABLE [phpbb_attach_quota] (
  [user_id] [int] NOT NULL,
  [group_id] [int] NOT NULL,
  [quota_type] [tinyint] NOT NULL,
  [quota_limit_id] [int] NOT NULL
);
GO

ALTER TABLE [phpbb_attachments_config] WITH NOCHECK ADD 
	CONSTRAINT [PK_phpbb_attachments_config] PRIMARY KEY CLUSTERED 
	(
		[config_name]
	)  ON [PRIMARY] 
GO

ALTER TABLE [phpbb_forbidden_extensions] WITH NOCHECK ADD 
	CONSTRAINT [PK_phpbb_forbidden_extensions] PRIMARY KEY CLUSTERED 
	(
		[ext_id]
	)  ON [PRIMARY] 
GO

ALTER TABLE [phpbb_extension_groups] WITH NOCHECK ADD 
	CONSTRAINT [PK_phpbb_extension_groups] PRIMARY KEY  CLUSTERED 
	(
		[group_id]
	)  ON [PRIMARY] 
GO

ALTER TABLE [phpbb_extension_groups] WITH NOCHECK ADD 
	CONSTRAINT [DF_phpbb_extension_groups_cat_id] DEFAULT (0) FOR [cat_id],
	CONSTRAINT [DF_phpbb_extension_groups_allow_group] DEFAULT (0) FOR [allow_group],
	CONSTRAINT [DF_phpbb_extension_groups_download_mode] DEFAULT (1) FOR [download_mode],
	CONSTRAINT [DF_phpbb_extension_groups_max_filesize] DEFAULT (0) FOR [max_filesize]
GO

ALTER TABLE [phpbb_extensions] WITH NOCHECK ADD 
	CONSTRAINT [PK_phpbb_extensions] PRIMARY KEY  CLUSTERED 
	(
		[ext_id]
	)  ON [PRIMARY] 
GO

ALTER TABLE [phpbb_extensions] WITH NOCHECK ADD 
	CONSTRAINT [DF_phpbb_extensions_group_id] DEFAULT (0) FOR [group_id]
GO

ALTER TABLE [phpbb_attachments_desc] WITH NOCHECK ADD 
	CONSTRAINT [PK_phpbb_attachments_desc] PRIMARY KEY  CLUSTERED 
	(
		[attach_id]
	)  ON [PRIMARY] 
GO

ALTER TABLE [phpbb_attachments_desc] WITH NOCHECK ADD 
	CONSTRAINT [DF_phpbb_attachments_desc_download_count] DEFAULT (0) FOR [download_count],
	CONSTRAINT [DF_phpbb_attachments_desc_thumbnail] DEFAULT (0) FOR [thumbnail],
	CONSTRAINT [DF_phpbb_attachments_desc_filetime] DEFAULT (0) FOR [filetime]
GO


ALTER TABLE [phpbb_attachments] WITH NOCHECK ADD 
	CONSTRAINT [DF_phpbb_attachments_attach_id] DEFAULT (0) FOR [attach_id],
	CONSTRAINT [DF_phpbb_attachments_post_id] DEFAULT (0) FOR [post_id],
	CONSTRAINT [DF_phpbb_attachments_privmsgs_id] DEFAULT (0) FOR [privmsgs_id]
GO

ALTER TABLE [phpbb_quota_limits] WITH NOCHECK ADD 
	CONSTRAINT [PK_phpbb_quota_limits] PRIMARY KEY  CLUSTERED 
	(
		[quota_limit_id]
	)  ON [PRIMARY] 
GO

ALTER TABLE [phpbb_quota_limits] WITH NOCHECK ADD 
	CONSTRAINT [DF_phpbb_quota_limits_quota_limit] DEFAULT (0) FOR [quota_limit]
GO

ALTER TABLE [phpbb_attach_quota] WITH NOCHECK ADD 
	CONSTRAINT [DF_phpbb_attach_quota_user_id] DEFAULT (0) FOR [user_id],
	CONSTRAINT [DF_phpbb_attach_quota_group_id] DEFAULT (0) FOR [group_id],
	CONSTRAINT [DF_phpbb_attach_quota_quota_type] DEFAULT (0) FOR [quota_type],
	CONSTRAINT [DF_phpbb_attach_quota_quota_limit_id] DEFAULT (0) FOR [quota_limit_id]
GO

ALTER TABLE [phpbb_forums] WITH NOCHECK ADD 
	[auth_download] [int] NOT NULL,
	CONSTRAINT [DF_phpbb_forums_auth_download] DEFAULT (0) FOR [auth_download]
GO

ALTER TABLE [phpbb_auth_access] WITH NOCHECK ADD
	[auth_download] [int] NOT NULL,
	CONSTRAINT [DF_phpbb_auth_access_auth_download] DEFAULT (0) FOR [auth_download]
GO

ALTER TABLE [phpbb_posts] WITH NOCHECK ADD 
	[post_attachment] [int] NOT NULL,
	CONSTRAINT [DF_phpbb_posts_post_attachment] DEFAULT (0) FOR [post_attachment]
GO

ALTER TABLE [phpbb_topics] WITH NOCHECK ADD 
	[topic_attachment] [int] NOT NULL,
	CONSTRAINT [DF_phpbb_topics_topic_attachment] DEFAULT (0) FOR [topic_attachment]
GO

ALTER TABLE [phpbb_privmsgs] WITH NOCHECK ADD 
	[privmsgs_attachment] [int] NOT NULL,
	CONSTRAINT [DF_phpbb_privmsgs_privmsgs_attachment] DEFAULT (0) FOR [privmsgs_attachment]
GO

COMMIT
GO
pragma auto_vacuum=0;
pragma default_cache_size=2000;
pragma encoding='UTF-8';
pragma page_size=1024;
drop table if exists [CommandsDescription];

CREATE TABLE [CommandsDescription] (
  [Name] VARCHAR(15) NOT NULL ON CONFLICT ROLLBACK, 
  [Desc] VARCHAR(2048));



drop table if exists [Directions];

CREATE TABLE [Directions] (
  [ID] INT NOT NULL ON CONFLICT ROLLBACK, 
  [Desc] VARCHAR(255));



drop table if exists [Elements];

CREATE TABLE [Elements] (
  [ID] INT NOT NULL ON CONFLICT ROLLBACK, 
  [Desc] VARCHAR(255));



drop table if exists [Emotions];

CREATE TABLE [Emotions] (
  [ID] INT NOT NULL ON CONFLICT ROLLBACK, 
  [Cmd] VARCHAR(15) NOT NULL ON CONFLICT ROLLBACK, 
  [Desc] VARCHAR(255));



drop table if exists [EquipTypes];

CREATE TABLE [EquipTypes] (
  [ID] INT NOT NULL ON CONFLICT ROLLBACK, 
  [Desc] VARCHAR(255) NOT NULL ON CONFLICT ROLLBACK);



drop table if exists [HairColor];

CREATE TABLE [HairColor] (
  [ID] INT NOT NULL ON CONFLICT ROLLBACK, 
  [Desc] VARCHAR(255));



drop table if exists [Item];

CREATE TABLE [Item] (
  [ID] INT NOT NULL ON CONFLICT ROLLBACK, 
  [Name] VARCHAR(255) NOT NULL ON CONFLICT ROLLBACK, 
  [Desc] VARCHAR(1024), 
  [Type] INT NOT NULL ON CONFLICT ROLLBACK, 
  [Slot] INT);



drop table if exists [ItemTypes];

CREATE TABLE [ItemTypes] (
  [ID] INT NOT NULL ON CONFLICT ROLLBACK, 
  [Desc] VARCHAR(255));



drop table if exists [Maps];

CREATE TABLE [Maps] (
  [FileName] VARCHAR(255) NOT NULL ON CONFLICT ROLLBACK, 
  [Desc] VARCHAR(1024), 
  [IsCitiy] BOOLEAN);



drop table if exists [Monsters];

CREATE TABLE [Monsters] (
  [ID] INT NOT NULL ON CONFLICT ROLLBACK, 
  [Name] VARCHAR(255) NOT NULL ON CONFLICT ROLLBACK, 
  [HP] INT);



drop table if exists [NPC];

CREATE TABLE [NPC] (
  [ID] INT NOT NULL ON CONFLICT ROLLBACK, 
  [Name] VARCHAR(255), 
  [Map] VARCHAR(255) NOT NULL ON CONFLICT ROLLBACK, 
  [X] INT NOT NULL ON CONFLICT ROLLBACK, 
  [Y] INT NOT NULL ON CONFLICT ROLLBACK);



drop table if exists [Portals];

CREATE TABLE [Portals] (
  [SrcMap] VARCHAR(255) NOT NULL ON CONFLICT ROLLBACK, 
  [SrcX] INT NOT NULL ON CONFLICT ROLLBACK, 
  [SrcY] INT NOT NULL ON CONFLICT ROLLBACK, 
  [DestMap] VARCHAR(255) NOT NULL ON CONFLICT ROLLBACK, 
  [DestX] INT NOT NULL ON CONFLICT ROLLBACK, 
  [DestY] INT NOT NULL ON CONFLICT ROLLBACK, 
  [Zenny] INT, 
  [ConSequ] VARCHAR(1024));



drop table if exists [Sex];

CREATE TABLE [Sex] (
  [ID] INT NOT NULL ON CONFLICT ROLLBACK, 
  [Desc] VARCHAR(255));



drop table if exists [Skills];

CREATE TABLE [Skills] (
  [ID] INT NOT NULL ON CONFLICT ROLLBACK, 
  [StrID] VARCHAR(255) NOT NULL ON CONFLICT ROLLBACK, 
  [Name] VARCHAR(255), 
  [Desc] VARCHAR(1024), 
  [IsArea] BOOLEAN);



drop table if exists [SkillsSp];

CREATE TABLE [SkillsSp] (
  [SkillID] INT NOT NULL ON CONFLICT ROLLBACK, 
  [Lvl] INT NOT NULL ON CONFLICT ROLLBACK, 
  [SP] INT NOT NULL ON CONFLICT ROLLBACK);




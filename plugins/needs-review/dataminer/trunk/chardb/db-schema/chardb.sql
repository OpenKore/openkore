-- MySQL dump 9.11
--
-- Host: leetbox.de    Database: chardb
-- ------------------------------------------------------
-- Server version	4.1.15-Debian_1-log

--
-- Table structure for table `account`
--

DROP TABLE IF EXISTS `account`;
CREATE TABLE `account` (
  `acacid` int(11) NOT NULL auto_increment,
  `acroacid` int(11) NOT NULL default '0',
  `actimestamp` timestamp NOT NULL,
  `acnote` mediumtext,
  `acserver` varchar(40) NOT NULL default '[FULL] Chaos',
  PRIMARY KEY  (`acacid`),
  KEY `acroacid` (`acroacid`)
) ENGINE=InnoDB;

--
-- Dumping data for table `account`
--


--
-- Table structure for table `char2guild`
--

DROP TABLE IF EXISTS `char2guild`;
CREATE TABLE `char2guild` (
  `c2gchid` int(11) NOT NULL default '0',
  `c2ggiid` int(11) NOT NULL default '0',
  `c2gtimestamp` timestamp NOT NULL,
  PRIMARY KEY  (`c2gchid`,`c2ggiid`)
) ENGINE=InnoDB;

--
-- Dumping data for table `char2guild`
--

--
-- Table structure for table `chars`
--

DROP TABLE IF EXISTS `chars`;
CREATE TABLE `chars` (
  `chchid` int(11) NOT NULL auto_increment,
  `chtimestamp` timestamp NOT NULL,
  `chacid` int(11) NOT NULL default '0',
  `chname` varchar(40) default NULL,
  `chlevel` int(11) NOT NULL default '0',
  `chsex` varchar(5) default NULL,
  `chclass` varchar(40) default NULL,
  PRIMARY KEY  (`chchid`),
  KEY `chacid` (`chacid`),
  KEY `chname` (`chname`),
  KEY `chtimestamp` (`chtimestamp`)
) ENGINE=InnoDB;

--
-- Dumping data for table `chars`
--

--
-- Table structure for table `guild`
--

DROP TABLE IF EXISTS `guild`;
CREATE TABLE `guild` (
  `gigiid` int(11) NOT NULL auto_increment,
  `giname` varchar(40) default NULL,
  `ginote` mediumtext,
  `gitimestamp` timestamp NOT NULL,
  PRIMARY KEY  (`gigiid`),
  KEY `giname` (`giname`)
) ENGINE=InnoDB;

--
-- Dumping data for table `guild`
--

--
-- Table structure for table `guildpos`
--

DROP TABLE IF EXISTS `guildpos`;
CREATE TABLE `guildpos` (
  `gpgpid` int(11) NOT NULL auto_increment,
  `gpchid` int(11) NOT NULL default '0',
  `gpgiid` int(11) NOT NULL default '0',
  `gpposition` varchar(40) default NULL,
  `gptimestamp` timestamp NOT NULL,
  PRIMARY KEY  (`gpgpid`),
  KEY `gpposition` (`gpposition`),
  KEY `gpchid` (`gpchid`),
  KEY `gpgiid` (`gpgiid`)
) ENGINE=InnoDB;

--
-- Dumping data for table `guildpos`
--

--
-- Table structure for table `logins`
--

DROP TABLE IF EXISTS `logins`;
CREATE TABLE `logins` (
  `lglgid` int(11) NOT NULL auto_increment,
  `lgdate` timestamp NOT NULL,
  `lgusid` int(11) NOT NULL default '0',
  `lgip` varchar(255) default NULL,
  PRIMARY KEY  (`lglgid`)
) ENGINE=InnoDB;

--
-- Dumping data for table `logins`
--

--
-- Table structure for table `party`
--

DROP TABLE IF EXISTS `party`;
CREATE TABLE `party` (
  `papaid` int(11) NOT NULL auto_increment,
  `pachid` int(11) NOT NULL default '0',
  `patimestamp` timestamp NOT NULL,
  `paname` varchar(40) default NULL,
  PRIMARY KEY  (`papaid`),
  KEY `paname` (`paname`),
  KEY `pachid` (`pachid`)
) ENGINE=InnoDB;

--
-- Dumping data for table `party`
--

--
-- Table structure for table `queryhist`
--

DROP TABLE IF EXISTS `queryhist`;
CREATE TABLE `queryhist` (
  `qhqhid` int(11) NOT NULL auto_increment,
  `qhdate` timestamp NOT NULL,
  `qhusid` int(11) NOT NULL default '0',
  `qhquery` varchar(255) default NULL,
  PRIMARY KEY  (`qhqhid`)
) ENGINE=InnoDB;

--
-- Dumping data for table `queryhist`
--


--
-- Table structure for table `seen`
--

DROP TABLE IF EXISTS `seen`;
CREATE TABLE `seen` (
  `seseid` int(11) NOT NULL auto_increment,
  `sechid` int(11) NOT NULL default '0',
  `segiid` int(11) NOT NULL default '0',
  `sepaid` int(11) NOT NULL default '0',
  `semap` varchar(40) default NULL,
  `seposx` int(11) NOT NULL default '0',
  `seposy` int(11) NOT NULL default '0',
  `selevel` int(11) NOT NULL default '0',
  `seseenbyacid` int(11) NOT NULL default '0',
  `setimestamp` timestamp NOT NULL,
  PRIMARY KEY  (`seseid`)
) ENGINE=InnoDB;

--
-- Dumping data for table `seen`
--

--
-- Table structure for table `shoutbox`
--

DROP TABLE IF EXISTS `shoutbox`;
CREATE TABLE `shoutbox` (
  `sbsbid` int(11) NOT NULL auto_increment,
  `sbdate` timestamp NOT NULL,
  `sbusid` int(11) NOT NULL default '0',
  `sbmessage` text,
  PRIMARY KEY  (`sbsbid`)
) ENGINE=InnoDB;

--
-- Dumping data for table `shoutbox`
--

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `ususid` int(11) NOT NULL default '0',
  `usname` varchar(255) default NULL,
  `uspass` varchar(255) default NULL,
  `uscomment` varchar(255) default NULL,
  `usadmin` enum('Yes','No') NOT NULL default 'No',
  `usshortsearch` enum('Yes','No') NOT NULL default 'No',
  `usrefresh` int(11) NOT NULL default '0',
  PRIMARY KEY  (`ususid`)
) ENGINE=InnoDB;

--
-- Dumping data for table `users`
--

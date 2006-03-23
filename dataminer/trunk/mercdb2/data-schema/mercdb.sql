-- MySQL dump 9.11
--
-- Host: leetbox.de    Database: mercdb
-- ------------------------------------------------------
-- Server version	4.1.15-Debian_1-log

--
-- Table structure for table `botcont`
--

DROP TABLE IF EXISTS `botcont`;
CREATE TABLE `botcont` (
  `bcbcid` int(11) NOT NULL auto_increment,
  `bcdate` timestamp NOT NULL,
  `bcusid` int(11) NOT NULL default '0',
  `bccommand` varchar(255) default NULL,
  `bcdone` enum('Yes','No') NOT NULL default 'No',
  PRIMARY KEY  (`bcbcid`)
) ENGINE=InnoDB;

--
-- Table structure for table `botpos`
--

DROP TABLE IF EXISTS `botpos`;
CREATE TABLE `botpos` (
  `bpbpid` int(11) NOT NULL auto_increment,
  `bpdate` timestamp NOT NULL,
  `bpposx` int(11) NOT NULL default '0',
  `bpposy` int(11) NOT NULL default '0',
  `bpmap` varchar(30) default NULL,
  PRIMARY KEY  (`bpbpid`)
) ENGINE=InnoDB;

--
-- Table structure for table `botruns`
--

DROP TABLE IF EXISTS `botruns`;
CREATE TABLE `botruns` (
  `brbrid` int(11) NOT NULL auto_increment,
  `brdate` timestamp NOT NULL,
  `brdone` enum('Yes','No') NOT NULL default 'No',
  PRIMARY KEY  (`brbrid`)
) ENGINE=InnoDB;

--
-- Table structure for table `logins`
--

DROP TABLE IF EXISTS `logins`;
CREATE TABLE `logins` (
  `lglgid` int(11) NOT NULL auto_increment,
  `lgdate` timestamp NOT NULL,
  `lgusid` int(11) NOT NULL default '0',
  `lgip` varchar(255) default NULL,
  KEY `lgdate` (`lgdate`),
  PRIMARY KEY  (`lglgid`)
) ENGINE=InnoDB;

--
-- Table structure for table `queryhist`
--

DROP TABLE IF EXISTS `queryhist`;
CREATE TABLE `queryhist` (
  `qhqhid` int(11) NOT NULL auto_increment,
  `qhdate` timestamp NOT NULL,
  `qhusid` int(11) NOT NULL default '0',
  `qhquery` varchar(255) default NULL,
  KEY `qhdate` (`qhdate`),
  PRIMARY KEY  (`qhqhid`)
) ENGINE=InnoDB;

--
-- Table structure for table `shopcont`
--

DROP TABLE IF EXISTS `shopcont`;
CREATE TABLE `shopcont` (
  `id` int(11) NOT NULL auto_increment,
  `shopOwnerID` int NOT NULL default '0',
  `shopOwner` varchar(254) NOT NULL default '',
  `shopName` varchar(50) NOT NULL default '',
  `itemID` int NOT NULL default '0',
  `name` varchar(254) NOT NULL default '',
  `amount` int(6) NOT NULL default '0',
  `typus` varchar(254) NOT NULL default '',
  `identified` tinyint(3) NOT NULL default '0',
  `custom` tinyint(3) NOT NULL default '0',
  `broken` tinyint(3) NOT NULL default '0',
  `slots` int(4) NOT NULL default '0',
  `card1ID` int NOT NULL default '0',
  `card1` varchar(254) NOT NULL default '',
  `card2ID` int NOT NULL default '0',
  `card2` varchar(254) NOT NULL default '',
  `card3ID` int NOT NULL default '0',
  `card3` varchar(254) NOT NULL default '',
  `card4ID` int NOT NULL default '0',
  `card4` varchar(254) NOT NULL default '',
  `crafted_by` varchar(30) NOT NULL default '',
  `element` varchar(5) NOT NULL default '',
  `star_crumb` char(2) NOT NULL default '',
  `price` bigint(12) NOT NULL default '0',
  `time` varchar(50) NOT NULL default '0',
  `posx` int(4) NOT NULL default '0',
  `posy` int(4) NOT NULL default '0',
  `datum` datetime default NULL,
  `map` varchar(254) NOT NULL default '',
  `server` varchar(40) NOT NULL default 'Chaos',
  `timstamp` datetime default NULL,
  `isstillin` enum('Yes','No') NOT NULL default 'Yes',
  UNIQUE KEY `id` (`id`),
  KEY `shopOwnerID` (`shopOwnerID`),
  KEY `shopName` (`shopName`),
  KEY `price` (`price`),
  KEY `custom` (`custom`),
  KEY `broken` (`broken`),
  KEY `card1ID` (`card1ID`),
  KEY `card2ID` (`card2ID`),
  KEY `card3ID` (`card3ID`),
  KEY `card4ID` (`card4ID`),
  KEY `element` (`element`),
  KEY `star_crumb` (`star_crumb`),
  KEY `datum` (`datum`),
  KEY `timstamp` (`timstamp`),
  KEY `GroupBy` (`itemID`,`custom`,`broken`,`slots`,`card1`,`card2`,`card3`),
  KEY `itemID` (`itemID`),
  KEY `isstillin` (`isstillin`),
  KEY `map` (`map`),
  KEY `card1` (`card1`),
  KEY `card2` (`card2`),
  KEY `card3` (`card3`),
  KEY `card4` (`card4`),
  KEY `slots` (`slots`),
  KEY `server` (`server`)
) ENGINE=InnoDB COMMENT='RO Shop Database';

--
-- Table structure for table `shopvisit`
--

DROP TABLE IF EXISTS `shopvisit`;
CREATE TABLE `shopvisit` (
  `id` int(11) NOT NULL auto_increment,
  `shopOwnerID` varchar(20) NOT NULL default '0',
  `time` varchar(50) NOT NULL default '0',
  `server` varchar(40) NOT NULL default 'Chaos',
  UNIQUE KEY `id` (`id`),
  KEY `shopOwnerID` (`shopOwnerID`)
) ENGINE=InnoDB;

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
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `ususid` int(11) NOT NULL default '0',
  `usname` varchar(255) default NULL,
  `uspass` varchar(255) default NULL,
  `uscomment` varchar(255) default NULL,
  `usadmin` enum('Yes','No') NOT NULL default 'No',
  `usbotpos` enum('Yes','No') NOT NULL default 'No',
  `usbotcont` enum('Yes','No') NOT NULL default 'No',
  `usshortsearch` enum('Yes','No') NOT NULL default 'No',
  `usrefresh` int(11) NOT NULL default '0',
  PRIMARY KEY  (`ususid`)
) ENGINE=InnoDB;


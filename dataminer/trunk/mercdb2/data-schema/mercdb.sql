-- MySQL dump 10.9
--
-- Host: localhost    Database: mercdb
-- ------------------------------------------------------
-- Server version	4.1.15-Debian_1-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `botcont`
--

DROP TABLE IF EXISTS `botcont`;
CREATE TABLE `botcont` (
  `bcbcid` int(11) NOT NULL auto_increment,
  `bcdate` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `bcusid` int(11) NOT NULL default '0',
  `bccommand` varchar(255) default NULL,
  `bcdone` enum('Yes','No') NOT NULL default 'No',
  PRIMARY KEY  (`bcbcid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `botcont`
--


/*!40000 ALTER TABLE `botcont` DISABLE KEYS */;
LOCK TABLES `botcont` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `botcont` ENABLE KEYS */;

--
-- Table structure for table `botpos`
--

DROP TABLE IF EXISTS `botpos`;
CREATE TABLE `botpos` (
  `bpbpid` int(11) NOT NULL auto_increment,
  `bpdate` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `bpposx` int(11) NOT NULL default '0',
  `bpposy` int(11) NOT NULL default '0',
  `bpmap` varchar(30) default NULL,
  PRIMARY KEY  (`bpbpid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `botpos`
--


/*!40000 ALTER TABLE `botpos` DISABLE KEYS */;
LOCK TABLES `botpos` WRITE;
INSERT INTO `botpos` VALUES (14324,'2006-03-16 21:01:58',176,186,'Connecting');
UNLOCK TABLES;
/*!40000 ALTER TABLE `botpos` ENABLE KEYS */;

--
-- Table structure for table `botruns`
--

DROP TABLE IF EXISTS `botruns`;
CREATE TABLE `botruns` (
  `brbrid` int(11) NOT NULL auto_increment,
  `brdate` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `brdone` enum('Yes','No') NOT NULL default 'No',
  PRIMARY KEY  (`brbrid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `botruns`
--


/*!40000 ALTER TABLE `botruns` DISABLE KEYS */;
LOCK TABLES `botruns` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `botruns` ENABLE KEYS */;

--
-- Table structure for table `logins`
--

DROP TABLE IF EXISTS `logins`;
CREATE TABLE `logins` (
  `lglgid` int(11) NOT NULL auto_increment,
  `lgdate` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `lgusid` int(11) NOT NULL default '0',
  `lgip` varchar(255) default NULL,
  PRIMARY KEY  (`lglgid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `logins`
--


/*!40000 ALTER TABLE `logins` DISABLE KEYS */;
LOCK TABLES `logins` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `logins` ENABLE KEYS */;

--
-- Table structure for table `queryhist`
--

DROP TABLE IF EXISTS `queryhist`;
CREATE TABLE `queryhist` (
  `qhqhid` int(11) NOT NULL auto_increment,
  `qhdate` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `qhusid` int(11) NOT NULL default '0',
  `qhquery` varchar(255) default NULL,
  PRIMARY KEY  (`qhqhid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `queryhist`
--


/*!40000 ALTER TABLE `queryhist` DISABLE KEYS */;
LOCK TABLES `queryhist` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `queryhist` ENABLE KEYS */;

--
-- Table structure for table `shopcont`
--

DROP TABLE IF EXISTS `shopcont`;
CREATE TABLE `shopcont` (
  `id` int(11) NOT NULL auto_increment,
  `shopOwnerID` varchar(20) NOT NULL default '0',
  `shopOwner` varchar(254) NOT NULL default '',
  `shopName` varchar(30) NOT NULL default '',
  `itemID` varchar(20) NOT NULL default '0',
  `name` varchar(254) NOT NULL default '',
  `amount` int(6) NOT NULL default '0',
  `typus` varchar(254) NOT NULL default '',
  `identified` tinyint(3) NOT NULL default '0',
  `custom` tinyint(3) NOT NULL default '0',
  `broken` tinyint(3) NOT NULL default '0',
  `slots` int(4) NOT NULL default '0',
  `card1ID` varchar(20) NOT NULL default '0',
  `card1` varchar(254) NOT NULL default '',
  `card2ID` varchar(20) NOT NULL default '0',
  `card2` varchar(254) NOT NULL default '',
  `card3ID` varchar(20) NOT NULL default '0',
  `card3` varchar(254) NOT NULL default '',
  `card4ID` varchar(20) NOT NULL default '0',
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
  KEY `server` (`server`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='RO Shop Database';

--
-- Dumping data for table `shopcont`
--


/*!40000 ALTER TABLE `shopcont` DISABLE KEYS */;
LOCK TABLES `shopcont` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `shopcont` ENABLE KEYS */;

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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `shopvisit`
--


/*!40000 ALTER TABLE `shopvisit` DISABLE KEYS */;
LOCK TABLES `shopvisit` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `shopvisit` ENABLE KEYS */;

--
-- Table structure for table `shoutbox`
--

DROP TABLE IF EXISTS `shoutbox`;
CREATE TABLE `shoutbox` (
  `sbsbid` int(11) NOT NULL auto_increment,
  `sbdate` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `sbusid` int(11) NOT NULL default '0',
  `sbmessage` text,
  PRIMARY KEY  (`sbsbid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `shoutbox`
--


/*!40000 ALTER TABLE `shoutbox` DISABLE KEYS */;
LOCK TABLES `shoutbox` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `shoutbox` ENABLE KEYS */;

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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `users`
--


/*!40000 ALTER TABLE `users` DISABLE KEYS */;
LOCK TABLES `users` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `users` ENABLE KEYS */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;


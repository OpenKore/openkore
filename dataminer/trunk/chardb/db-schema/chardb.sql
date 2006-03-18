-- MySQL dump 10.9
--
-- Host: localhost    Database: chardb
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
-- Table structure for table `account`
--

DROP TABLE IF EXISTS `account`;
CREATE TABLE `account` (
  `acacid` int(11) NOT NULL auto_increment,
  `acroacid` int(11) NOT NULL default '0',
  `actimestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `acnote` mediumtext,
  `acserver` varchar(40) NOT NULL default '[FULL] Chaos',
  PRIMARY KEY  (`acacid`),
  KEY `acroacid` (`acroacid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `account`
--


/*!40000 ALTER TABLE `account` DISABLE KEYS */;
LOCK TABLES `account` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `account` ENABLE KEYS */;

--
-- Table structure for table `char2guild`
--

DROP TABLE IF EXISTS `char2guild`;
CREATE TABLE `char2guild` (
  `c2gchid` int(11) NOT NULL default '0',
  `c2ggiid` int(11) NOT NULL default '0',
  `c2gtimestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`c2gchid`,`c2ggiid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `char2guild`
--


/*!40000 ALTER TABLE `char2guild` DISABLE KEYS */;
LOCK TABLES `char2guild` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `char2guild` ENABLE KEYS */;

--
-- Table structure for table `chars`
--

DROP TABLE IF EXISTS `chars`;
CREATE TABLE `chars` (
  `chchid` int(11) NOT NULL auto_increment,
  `chtimestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `chacid` int(11) NOT NULL default '0',
  `chname` varchar(40) default NULL,
  `chlevel` int(11) NOT NULL default '0',
  `chsex` varchar(5) default NULL,
  `chclass` varchar(40) default NULL,
  PRIMARY KEY  (`chchid`),
  KEY `chacid` (`chacid`),
  KEY `chname` (`chname`),
  KEY `chtimestamp` (`chtimestamp`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `chars`
--


/*!40000 ALTER TABLE `chars` DISABLE KEYS */;
LOCK TABLES `chars` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `chars` ENABLE KEYS */;

--
-- Table structure for table `guild`
--

DROP TABLE IF EXISTS `guild`;
CREATE TABLE `guild` (
  `gigiid` int(11) NOT NULL auto_increment,
  `giname` varchar(40) default NULL,
  `ginote` mediumtext,
  `gitimestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`gigiid`),
  KEY `giname` (`giname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `guild`
--


/*!40000 ALTER TABLE `guild` DISABLE KEYS */;
LOCK TABLES `guild` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `guild` ENABLE KEYS */;

--
-- Table structure for table `guildpos`
--

DROP TABLE IF EXISTS `guildpos`;
CREATE TABLE `guildpos` (
  `gpgpid` int(11) NOT NULL auto_increment,
  `gpchid` int(11) NOT NULL default '0',
  `gpgiid` int(11) NOT NULL default '0',
  `gpposition` varchar(40) default NULL,
  `gptimestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`gpgpid`),
  KEY `gpposition` (`gpposition`),
  KEY `gpchid` (`gpchid`),
  KEY `gpgiid` (`gpgiid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `guildpos`
--


/*!40000 ALTER TABLE `guildpos` DISABLE KEYS */;
LOCK TABLES `guildpos` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `guildpos` ENABLE KEYS */;

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
-- Table structure for table `party`
--

DROP TABLE IF EXISTS `party`;
CREATE TABLE `party` (
  `papaid` int(11) NOT NULL auto_increment,
  `pachid` int(11) NOT NULL default '0',
  `patimestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `paname` varchar(40) default NULL,
  PRIMARY KEY  (`papaid`),
  KEY `paname` (`paname`),
  KEY `pachid` (`pachid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `party`
--


/*!40000 ALTER TABLE `party` DISABLE KEYS */;
LOCK TABLES `party` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `party` ENABLE KEYS */;

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
  `setimestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`seseid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `seen`
--


/*!40000 ALTER TABLE `seen` DISABLE KEYS */;
LOCK TABLES `seen` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `seen` ENABLE KEYS */;

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
INSERT INTO `shoutbox` VALUES (1,'2006-03-12 00:06:43',1,'test'),(2,'2006-03-13 00:33:10',3,'nub'),(3,'2006-03-15 23:02:16',7,'*SchÃ¶nheitsfehler* nimma in \"Guild HE was in\" das HE raus bzw Abfrage nach geschlecht fÃ¼r he/she');
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


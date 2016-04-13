# --------------------------------------------------------
# Host:                         localhost
# Server version:               5.0.67-community-nt
# Server OS:                    Win32
# HeidiSQL version:             6.0.0.3603
# Date/time:                    2013-05-26 21:10:05
# --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;

# Dumping database structure for ragna4fun
CREATE DATABASE IF NOT EXISTS `ragna4fun` /*!40100 DEFAULT CHARACTER SET latin1 */;
USE `ragna4fun`;


# Dumping structure for table ragna4fun.hangman_comment
CREATE TABLE IF NOT EXISTS `hangman_comment` (
  `server` char(255) default NULL,
  `nick` char(255) default NULL,
  `comment` char(255) default NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1 ROW_FORMAT=FIXED;

# Data exporting was unselected.


# Dumping structure for table ragna4fun.hangman_server
CREATE TABLE IF NOT EXISTS `hangman_server` (
  `nick` char(50) NOT NULL,
  `points` int(10) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1 ROW_FORMAT=FIXED;

# Data exporting was unselected.
/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;

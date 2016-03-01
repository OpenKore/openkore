SET FOREIGN_KEY_CHECKS=0;
-- ----------------------------
-- Table structure for castle
-- ----------------------------
CREATE TABLE `castle` (
  `castle_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `name` tinytext CHARACTER SET utf8 NOT NULL,
  `breaks` tinyint(2) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`castle_id`),
  KEY `name` (`name`(48))
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- ----------------------------
-- Table structure for guild
-- ----------------------------	
CREATE TABLE `guild` (
  `guild_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `name` tinytext CHARACTER SET latin1 NOT NULL,
  `added` int(11) unsigned NOT NULL,
  PRIMARY KEY (`guild_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- ----------------------------
-- Table structure for takeover
-- ----------------------------
CREATE TABLE `takeover` (
  `takeover_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `guild_id` int(11) unsigned NOT NULL,
  `castle_id` int(11) NOT NULL,
  `timestamp` int(12) unsigned NOT NULL,
  PRIMARY KEY (`takeover_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- ----------------------------
-- Records 
-- ----------------------------
INSERT INTO `castle` VALUES ('1', 'Luina 1', '0');
INSERT INTO `castle` VALUES ('2', 'Luina 2', '0');
INSERT INTO `castle` VALUES ('3', 'Luina 3', '0');
INSERT INTO `castle` VALUES ('4', 'Luina 4', '0');
INSERT INTO `castle` VALUES ('5', 'Luina 5', '0');
INSERT INTO `castle` VALUES ('6', 'Balder 1', '0');
INSERT INTO `castle` VALUES ('7', 'Balder 2', '0');
INSERT INTO `castle` VALUES ('8', 'Balder 3', '0');
INSERT INTO `castle` VALUES ('9', 'Balder 4', '0');
INSERT INTO `castle` VALUES ('10', 'Balder 5', '0');
INSERT INTO `castle` VALUES ('11', 'Valkyrie 1', '0');
INSERT INTO `castle` VALUES ('12', 'Valkyrie 2', '0');
INSERT INTO `castle` VALUES ('13', 'Valkyrie 3', '0');
INSERT INTO `castle` VALUES ('14', 'Valkyrie 4', '0');
INSERT INTO `castle` VALUES ('15', 'Valkyrie 5', '0');
INSERT INTO `castle` VALUES ('16', 'Britoniah 1', '0');
INSERT INTO `castle` VALUES ('17', 'Britoniah 2', '0');
INSERT INTO `castle` VALUES ('18', 'Britoniah 3', '0');
INSERT INTO `castle` VALUES ('19', 'Britoniah 4', '0');
INSERT INTO `castle` VALUES ('20', 'Britoniah 5', '0');

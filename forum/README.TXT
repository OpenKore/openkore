Introduction
------------
This repository contains a modified version of PhpBB, which
is the forum software used by forums.openkore.com. Our PhpBB
contains a lot of third party mods, as well as some of our
own.


Branches
--------
* The 'orig' folder contains the original, unmodified PhpBB sources.
* All other folders (except 'trunk') are PhpBB with exactly one mod
  installed. This makes it easier to keep track of new mod versions.
* The 'trunk' folder contains the sources that forums.openkore.com
  uses. It's a merge of all the other mods, plus some of our own.

The branches can be visualized as follows:
orig
 |
 +- trunk
 +- attachment_mod
 +- multi-bbcode
 +- quick_reply_mod
 |  |
 |  +- bbcode-buttons-organizer
 |     |
 |     +- syntax_mod
 +- seperate_announcements_mod
 +- simply-merge-threads
 +- multivote_mod
 +- xs_mod
    |
    +- simple_subforums_mod


Installation
------------
The installation is very similar to a normal PhpBB installation:
1. Copy the 'trunk' folder to a location reachable by your web server.
   That will be your root PhpBB folder.
2. Copy the 'orig/install' folder to the folder you copied to in step 1.
3. Start your web server.
4. Start your web browser and go to the URL for install.php.

5. Run post-installation SQL queries. See appendix A.
6. Create the following forums (with these exact names):
   - Trash
   - Other OpenKore & VisualKore Support
7. Create the following user group:
   Forum Contributors


Appendix A: SQL queries
-----------------------
### ==== SQL queries begin ==== ###

# OOptions
CREATE TABLE openkore_forum_config (
    config_name VARCHAR(255) NOT NULL,
    config_value TEXT
);

# "User must wait x days before he can post" (timeblock) mod
ALTER TABLE phpbb_users ADD user_timeblock TINYINT(1) default '1';
INSERT INTO phpbb_config (config_name, config_value) VALUES ('user_block_time','0');

# Quiz
ALTER TABLE phpbb_users ADD user_done_quiz TINYINT(1) default '0';

# multivote_mod
ALTER TABLE `phpbb_vote_desc` ADD `vote_max` INT( 3 ) DEFAULT '1' NOT NULL;
ALTER TABLE `phpbb_vote_desc` ADD `vote_voted` INT( 7 ) DEFAULT '0' NOT NULL;
ALTER TABLE `phpbb_vote_desc` ADD `vote_hide` TINYINT( 1 ) DEFAULT '0' NOT NULL;
ALTER TABLE `phpbb_vote_desc` ADD `vote_tothide` TINYINT( 1 ) DEFAULT '0' NOT NULL;

# Syntax highlighting mod
INSERT INTO phpbb_config (config_name, config_value) VALUES ('syntax_status', '2');
INSERT INTO phpbb_config (config_name, config_value) VALUES ('syntax_enable_cache', '1');
INSERT INTO phpbb_config (config_name, config_value) VALUES ('syntax_cache_check_time', '5000');
INSERT INTO phpbb_config (config_name, config_value) VALUES ('syntax_cache_dir_size', '20971520');
INSERT INTO phpbb_config (config_name, config_value) VALUES ('syntax_cache_files_expire', '2592000');
INSERT INTO phpbb_config (config_name, config_value) VALUES ('syntax_enable_line_numbers', '0');
INSERT INTO phpbb_config (config_name, config_value) VALUES ('syntax_enable_urls', '1');
INSERT INTO phpbb_config (config_name, config_value) VALUES ('syntax_version', '0.4.0');

CREATE TABLE phpbb_syntax_language_config (language_file_name VARCHAR(30), lang_identifier VARCHAR(15), lang_display_name VARCHAR(25));

INSERT INTO phpbb_syntax_language_config VALUES ('actionscript.php', 'actionscript', 'actionscript');
INSERT INTO phpbb_syntax_language_config VALUES ('ada.php', 'ada', 'ada');
INSERT INTO phpbb_syntax_language_config VALUES ('apache.php', 'apache', 'apache');
INSERT INTO phpbb_syntax_language_config VALUES ('asm.php', 'asm', 'asm');
INSERT INTO phpbb_syntax_language_config VALUES ('asp.php', 'asp', 'asp');
INSERT INTO phpbb_syntax_language_config VALUES ('bash.php', 'bash', 'bash');
INSERT INTO phpbb_syntax_language_config VALUES ('caddcl.php', 'caddcl', 'CAD DCL');
INSERT INTO phpbb_syntax_language_config VALUES ('cadlisp.php', 'cadlisp', 'CAD Lisp');
INSERT INTO phpbb_syntax_language_config VALUES ('c_mac.php', 'c_mac', 'C (Mac)');
INSERT INTO phpbb_syntax_language_config VALUES ('c.php', 'c', 'c');
INSERT INTO phpbb_syntax_language_config VALUES ('cpp.php', 'c++', 'c++');
INSERT INTO phpbb_syntax_language_config VALUES ('csharp.php', 'c#', 'C#');
INSERT INTO phpbb_syntax_language_config VALUES ('css.php', 'css', 'css');
INSERT INTO phpbb_syntax_language_config VALUES ('delphi.php', 'delphi', 'delphi');
INSERT INTO phpbb_syntax_language_config VALUES ('diff.php', 'diff', 'Diff Output');
INSERT INTO phpbb_syntax_language_config VALUES ('div.php', 'div', 'DIV');
INSERT INTO phpbb_syntax_language_config VALUES ('d.php', 'd', 'd');
INSERT INTO phpbb_syntax_language_config VALUES ('eiffel.php', 'eiffel', 'Eiffel');
INSERT INTO phpbb_syntax_language_config VALUES ('gml.php', 'gml', 'GML');
INSERT INTO phpbb_syntax_language_config VALUES ('html4strict.php', 'html', 'HTML');
INSERT INTO phpbb_syntax_language_config VALUES ('java.php', 'java', 'Java');
INSERT INTO phpbb_syntax_language_config VALUES ('javascript.php', 'javascript', 'Javascript');
INSERT INTO phpbb_syntax_language_config VALUES ('lisp.php', 'lisp', 'Lisp');
INSERT INTO phpbb_syntax_language_config VALUES ('lua.php', 'lua', 'Lua');
INSERT INTO phpbb_syntax_language_config VALUES ('matlab.php', 'matlab', 'Matlab');
INSERT INTO phpbb_syntax_language_config VALUES ('mpasm.php', 'mpasm', 'Microprocessor ASM');
INSERT INTO phpbb_syntax_language_config VALUES ('nsis.php', 'nsis', 'NullSoft Installer Script');
INSERT INTO phpbb_syntax_language_config VALUES ('objc.php', 'objc', 'Objective C');
INSERT INTO phpbb_syntax_language_config VALUES ('oobas.php', 'oobas', 'Openoffice.org BASIC');
INSERT INTO phpbb_syntax_language_config VALUES ('oracle8.php', 'oracle8', 'Oracle 8');
INSERT INTO phpbb_syntax_language_config VALUES ('pascal.php', 'pascal', 'Pascal');
INSERT INTO phpbb_syntax_language_config VALUES ('perl.php', 'perl', 'Perl');
INSERT INTO phpbb_syntax_language_config VALUES ('php-brief.php', 'php-brief', 'php (brief)');
INSERT INTO phpbb_syntax_language_config VALUES ('php.php', 'php', 'php');
INSERT INTO phpbb_syntax_language_config VALUES ('python.php', 'python', 'Python');
INSERT INTO phpbb_syntax_language_config VALUES ('qbasic.php', 'qbasic', 'QBasic');
INSERT INTO phpbb_syntax_language_config VALUES ('smarty.php', 'smarty', 'Smarty');
INSERT INTO phpbb_syntax_language_config VALUES ('sql.php', 'sql', 'SQL');
INSERT INTO phpbb_syntax_language_config VALUES ('vbnet.php', 'vbnet', 'VB.NET');
INSERT INTO phpbb_syntax_language_config VALUES ('vb.php', 'vb', 'VisualBASIC');
INSERT INTO phpbb_syntax_language_config VALUES ('vhdl.php', 'vhdl', 'VHDL');
INSERT INTO phpbb_syntax_language_config VALUES ('visualfoxpro.php', 'vfp', 'Visual FoxPro');
INSERT INTO phpbb_syntax_language_config VALUES ('xml.php', 'xml', 'XML');

# Simple subforums mod
ALTER TABLE phpbb_forums ADD forum_parent INT NOT NULL DEFAULT '0';

### ==== SQL queries end ==== ###

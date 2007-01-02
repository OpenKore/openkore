<?php
//  ==========================================================================
//  phpBB Google Sitemap Generator v1.0.1
//  http://www.gotaxe.com/phpbb-sitemap.php
//  ==========================================================================
//  Script created by John Brookes
//  Copyright John Brookes ©2005
//  http://www.gotaxe.com
//  ==========================================================================
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
//  ==========================================================================

// Some configuration options!

define('FORUM_DOMAIN_ROOT', 'http://forums.openkore.com/'); // Full URL with trailing slash!

define('FORUM_URL_PREFIX', 'viewforum.php?f='); // What comes up before the forum ID?
define('FORUM_URL_SUFFIX', ''); // What comes up after the forum ID?
define('THREAD_URL_PREFIX', 'viewtopic.php?t='); // What comes up before the thread ID?
define('THREAD_URL_SUFFIX', ''); // What comes up after the thread ID?

define('PHPBB_PREFIX', 'phpbb_'); // Your phpBB tables prefix, WITHOUT the _ character.

// --------------------------------------------------
// You don't need to edit anything below this line!!!
// --------------------------------------------------

define('IN_PHPBB', true);
$phpbb_root_path = './';
include($phpbb_root_path . 'extension.inc');
include($phpbb_root_path . 'common.'.$phpEx);

if ($_GET['fid']) { $fid = $_GET['fid']; }

// Sitemap File    <sitemapindex xmlns="http://www.google.com/schemas/sitemap/0.84">
// URL Index File  <urlset xmlns="http://www.google.com/schemas/sitemap/0.84">';
if (isset($fid)) {
  echo '<?xml version="1.0" encoding="UTF-8"?>'."\n";
  if ($fid == '65535') {
    // Let's first send out the header & homepage
    echo '  <urlset xmlns="http://www.google.com/schemas/sitemap/0.84">'."\n";
    echo '    <url>
      <loc>'.FORUM_DOMAIN_ROOT.'</loc>
      <changefreq>daily</changefreq>
    </url>';
    // Let's send out a URL list of forums
    $sql = 'SELECT forum_id FROM '.PHPBB_PREFIX.'forums WHERE auth_view = "0" and auth_read = "0" and forum_id not like "%-%"';
    $result = mysql_query($sql);
    while ($data = mysql_fetch_assoc($result)) {
      echo '    <url>
      <loc>'.FORUM_DOMAIN_ROOT.FORUM_URL_PREFIX.$data['forum_id'].FORUM_URL_SUFFIX.'</loc>
      <changefreq>daily</changefreq>
    </url>';
    }
    echo '  </urlset>';
  } else {
    // Let's check it's not a restricted forum
    $sql = 'SELECT forum_id FROM '.PHPBB_PREFIX.'forums WHERE auth_view = "0" and auth_read = "0" and forum_id = "'.$fid.'" and forum_id not like "%-%"';
    $result = mysql_query($sql);
    $data = mysql_fetch_assoc($result);
    if ($data['forum_id'] == $fid) {
      echo '  <urlset xmlns="http://www.google.com/schemas/sitemap/0.84">'."\n";
      $sql = 'SELECT t.*, u.username, u.user_id, u2.username as user2, u2.user_id as id2, p.post_username, p2.post_username AS post_username2, p2.post_time FROM '.PHPBB_PREFIX.'topics t, '.PHPBB_PREFIX.'users u, '.PHPBB_PREFIX.'posts p, '.PHPBB_PREFIX.'posts p2, '.PHPBB_PREFIX.'users u2 WHERE t.forum_id = '.$fid.' AND t.topic_poster = u.user_id AND p.post_id = t.topic_first_post_id AND p2.post_id = t.topic_last_post_id AND u2.user_id = p2.poster_id ORDER BY t.topic_type DESC, t.topic_last_post_id DESC';
      $result = mysql_query($sql);
      while ($data = mysql_fetch_assoc($result)) {
        echo '    <url>
      <loc>'.FORUM_DOMAIN_ROOT.THREAD_URL_PREFIX.$data['topic_id'].THREAD_URL_SUFFIX.'</loc>
      <lastmod>'.date('Y-m-d', $data['post_time']),'</lastmod>
    </url>';
      }
      echo '  </urlset>';
    }
  }
} else {
  echo '<?xml version="1.0" encoding="UTF-8"?>'."\n";
  echo '  <sitemapindex xmlns="http://www.google.com/schemas/sitemap/0.84">'."\n";
    // Let's create a link to the main forum index sitemap
  echo '    <sitemap>
      <loc>'.FORUM_DOMAIN_ROOT.'forum-65535.xml</loc>
      <changefreq>monthly</changefreq>
   </sitemap>';
    // Let's do a loop here and list all the forums!
    $sql = 'SELECT forum_id FROM '.PHPBB_PREFIX.'forums WHERE auth_view = "0" and auth_read = "0" and forum_id not like "%-%"';
    $result = mysql_query($sql);
    while ($data = mysql_fetch_assoc($result)) {
      echo '    <sitemap>
      <loc>'.FORUM_DOMAIN_ROOT.'forum-'.$data['forum_id'].'.xml</loc>
      <changefreq>daily</changefreq>
   </sitemap>';
    }
  echo "\n".'  </sitemapindex>';
}

?>

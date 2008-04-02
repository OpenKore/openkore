<?php

/* SELECT m.*, u.user_colour, g.group_colour, g.group_type FROM (phpbb3_moderator_cache m) LEFT JOIN phpbb3_users u ON (m.user_id = u.user_id) LEFT JOIN phpbb3_groups g ON (m.group_id = g.group_id) WHERE m.display_on_index = 1 AND m.forum_id IN (4, 6, 7, 26, 28, 29, 30, 32, 33, 35, 37, 38, 39, 41, 42, 44, 45, 46, 48, 47, 50, 51, 52, 53, 54) */

$expired = (time() > 1207116988) ? true : false;
if ($expired) { return; }

$this->sql_rowset[$query_id] = array (
);
?>
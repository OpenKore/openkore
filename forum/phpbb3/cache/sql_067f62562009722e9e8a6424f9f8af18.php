<?php

/* SELECT m.*, u.user_colour, g.group_colour, g.group_type FROM (phpbb3_moderator_cache m) LEFT JOIN phpbb3_users u ON (m.user_id = u.user_id) LEFT JOIN phpbb3_groups g ON (m.group_id = g.group_id) WHERE m.display_on_index = 1 AND m.forum_id IN (9, 10, 11, 12, 13, 14, 15, 16, 17, 18, '8') */

$expired = (time() > 1207117626) ? true : false;
if ($expired) { return; }

$this->sql_rowset[$query_id] = array (
);
?>
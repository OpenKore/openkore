<?php

/* SELECT s.style_id, t.template_storedb, t.template_path, t.template_id, t.bbcode_bitfield, c.theme_path, c.theme_name, c.theme_storedb, c.theme_id, i.imageset_path, i.imageset_id, i.imageset_name FROM phpbb3_styles s, phpbb3_styles_template t, phpbb3_styles_theme c, phpbb3_styles_imageset i WHERE s.style_id = 2 AND t.template_id = s.template_id AND c.theme_id = s.theme_id AND i.imageset_id = s.imageset_id */

$expired = (time() > 1207120781) ? true : false;
if ($expired) { return; }

$this->sql_rowset[$query_id] = array (
  0 => 
  array (
    'style_id' => '2',
    'template_storedb' => '0',
    'template_path' => 'subsilver2',
    'template_id' => '2',
    'bbcode_bitfield' => 'kNg=',
    'theme_path' => 'subsilver2',
    'theme_name' => 'subsilver2',
    'theme_storedb' => '0',
    'theme_id' => '2',
    'imageset_path' => 'subsilver2',
    'imageset_id' => '2',
    'imageset_name' => 'subsilver2',
  ),
);
?>
<?php 
/***************************************************************************
 *                              quick_reply.php
 *                            -------------------
 *   begin                : Tuesday, Aug 20, 2002
 *   copyright            : RustyDragon 
 *   original work by     : Smartor <smartor_xp@hotmail.com>
 *   contact              : <dev@RustyDragon.com>, http://www.RustyDragon.com
 *   $Id: quick_reply.php,v 1.4.1.1 2002/11/18 13:35:54 RustyDragon Exp $
 *
 ***************************************************************************/

/***************************************************************************
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 ***************************************************************************/

// Do not display the quick reply box for people who have less than x posts,
// in order to avoid n00b replies.
require_once($phpbb_root_path . 'includes/openkore.' . $phpEx);
if ($userdata['user_posts'] < OConstants::MIN_USER_POSTS) {
	return;
}

//
// BEGIN OUTPUT
//

$phpbb_root_path = "./";

if($_GET['mode'] == 'smilies') 
{
        define('IN_PHPBB', true);
        include($phpbb_root_path . 'extension.inc');
        include($phpbb_root_path . 'common.'.$phpEx);
        include($phpbb_root_path . 'includes/functions_post.'.$phpEx);
        generate_smilies('window', PAGE_POSTING);
        exit;
}

if ( !defined('IN_PHPBB') )
{
        die('Hacking attempt1');
}

$template->set_filenames(array(
        'quick_reply_output' => 'quick_reply.tpl')
);
        

if ( !(((!$is_auth['auth_reply']) or 
($forum_topic_data['forum_status'] == FORUM_LOCKED) or 
($forum_topic_data['topic_status'] == TOPIC_LOCKED)) and ($userdata['user_level'] != ADMIN)))
{
        $bbcode_uid = $postrow[$total_posts - 1]['bbcode_uid'];
        $last_poster = $postrow[$total_posts - 1]['username'];
        $last_msg = $postrow[$total_posts - 1]['post_text'];
        $last_msg = str_replace(":1:$bbcode_uid", '', $last_msg);
        $last_msg = str_replace(":$bbcode_uid", '', $last_msg);        
        $last_msg = str_replace("'", '&#39;', $last_msg);
        $last_msg = "[quote=\"$last_poster\"]" . $last_msg . '[/quote]';
        $attach_sig = (( $userdata['session_logged_in'] ) ? $userdata['user_attachsig'] : 0)?"checked='checked'":'';
        $notify_user = (( $userdata['session_logged_in'] ) ? $userdata['user_notify'] : 0)?"checked='checked'":'';
        
        $template->assign_block_vars('quick_reply', array(
                'POST_ACTION' => append_sid("posting.$phpEx"),
                'TOPIC_ID' => $topic_id,
                'SID' => $userdata['session_id'],
                'LAST_MESSAGE' => $last_msg)
        );

        if( $userdata['session_logged_in'])
        {
                $template->assign_block_vars('quick_reply.user_logged_in', array(
                        'ATTACH_SIGNATURE' => $attach_sig,
                        'NOTIFY_ON_REPLY' => $notify_user)
                );
        }else
        {
                $template->assign_block_vars('quick_reply.user_logged_out', array());
        }


        generate_smilies_row();

        $template->assign_vars(array(
                'U_MORE_SMILIES' => append_sid("quick_reply.$phpEx?mode=smilies"),
                'L_USERNAME' => $lang['Username'],
                'L_PREVIEW' => $lang['Preview'],
                'L_OPTIONS' => $lang['Options'],
                'L_SUBMIT' => $lang['Submit'],
                'L_CANCEL' => $lang['Cancel'],
                'L_ATTACH_SIGNATURE' => $lang['Attach_signature'], 
                'L_NOTIFY_ON_REPLY' => $lang['Notify'],
                'L_NOTIFY_ON_REPLY' => $lang['Notify'],
                'L_ATTACH_SIGNATURE' => $lang['Attach_signature'],
                'L_ALL_SMILIES' => $lang['Quick_Reply_smilies'],
                'L_QUOTE_SELECTED' => $lang['QuoteSelelected'],
                'L_NO_TEXT_SELECTED' => $lang['QuoteSelelectedEmpty'],
                'L_EMPTY_MESSAGE' => $lang['Empty_message'],
                'L_QUOTE_LAST_MESSAGE' => $lang['Quick_quote'],
                'L_QUICK_REPLY' => $lang['Quick_Reply'],
                'L_PREVIEW' => $lang['Preview'],
                'L_SUBMIT' => $lang['Submit'])
);
}
$template->assign_var_from_handle('QUICKREPLY_OUTPUT', 'quick_reply_output');
        
function generate_smilies_row()
{
        global $db, $board_config, $template;

        $max_smilies = 24;

        switch ( SQL_LAYER )
        {
                case 'mssql':
                        $sql = 'SELECT TOP ' . $max_smilies . ' min(emoticon) AS emoticon,
                        min(code) AS code, smile_url
                        FROM ' . SMILIES_TABLE . ' 
                        GROUP BY [smile_url]';
                break;

                default:
                        $sql = 'SELECT emoticon, code, smile_url
                        FROM ' . SMILIES_TABLE . ' 
                        GROUP BY smile_url
                        ORDER BY smilies_id LIMIT ' . $max_smilies;
                break;
        }
        if (!$result = $db->sql_query($sql))
        {
                message_die(GENERAL_ERROR, "Couldn't retrieve smilies list", '', __LINE__, __FILE__, $sql);
        }
        $smilies_count = $db->sql_numrows($result);
        $smilies_data = $db->sql_fetchrowset($result);
        for ($i = 0; $i < $smilies_count; $i++)
        {
                        $template->assign_block_vars('quick_reply.smilies', array(
                                'CODE' => $smilies_data[$i]['code'],
                                'URL' => $board_config['smilies_path'] . '/' . $smilies_data[$i]['smile_url'],
                                'DESC' => $smilies_data[$i]['emoticon'])
                        );
        }
}
?>

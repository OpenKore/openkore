<?php
/** 
*
* @author Tobi Schäfer http://www.tobischaefer.net/
*
* @package acp
* @version $Id: acp_ads.php, v0.2.0 2008-03-22 17:05:19 tas2580 $
* @copyright (c) 2007 SEO phpBB http://www.seo-phpbb.org
* @license http://opensource.org/licenses/gpl-license.php GNU Public License
*
*/

/**
* @package acp
*/


class acp_ads
{

	function make_grouplist($id)
	{
		global $db, $user, $config;
		$id = explode(',', $id);
		$sql_where = (!$config['coppa_enable']) ? " WHERE group_name <> 'REGISTERED_COPPA'" : '';
		$cat_option = '';
		$sql = 'SELECT group_id, group_name, group_type
			FROM ' . GROUPS_TABLE .
			$sql_where;
		$result = $db->sql_query($sql);
		while ($row = $db->sql_fetchrow($result))
		{
			$group_name = ($row['group_type'] == GROUP_SPECIAL) ? $user->lang['G_' . $row['group_name']] : $row['group_name'];
			$cat_option .= (in_array($row['group_id'], $id)) ? '<option selected value="' . $row['group_id'] . '">' . $group_name . '</option>' : '<option value="' . $row['group_id'] . '">' . $group_name . '</option>';
		}
		$db->sql_freeresult($result);
		return $cat_option;
	}

	function make_ranklist($id)
	{
		global $db, $user;
		$id = explode(',', $id);
		$cat_option = '';
		$sql = 'SELECT rank_id, rank_title
			FROM ' . RANKS_TABLE;
		$result = $db->sql_query($sql);
		while ($row = $db->sql_fetchrow($result))
		{	
			$cat_option1 = (in_array($row['rank_id'], $id)) ? '<option selected value="0">' . $user->lang['NO_RANK'] . '</option>' : '<option value="0">' . $user->lang['NO_RANK'] . '</option>';
			$cat_option .= (in_array($row['rank_id'], $id)) ? '<option selected value="' . $row['rank_id'] . '">' . $row['rank_title'] . '</option>' : '<option value="' .$row['rank_id']. '">' . $row['rank_title'] . '</option>';
		}
		$db->sql_freeresult($result);
		return $cat_option1 . $cat_option;
	}

	function option_list($start, $end, $selected = 0)
	{
		$option = '';
		for($i = $start; $i <= $end; $i++)
		{
			$option .= ($i == $selected) ? '<option selected>' . sprintf ("%02d", $i) . '</option>' : '<option>' .  sprintf ("%02d", $i) . '</option>';
		}
		return $option;
	}

	function main($id, $mode)
	{
		global $db, $user, $template;

		$user->add_lang('mods/ads');
		$this->tpl_name = 'acp_ads';
		$form_action = $this->u_action. '&amp;action=add';
		switch($mode)
		{
			case 'html':
				$page_title = 'HTML_AD';
				$html_ads = true;
			break;

			case 'banner':
				$page_title = 'BANNER_AD';
				$html_ads = false;
			break;
		}

		$action	= (!isset($_GET['action'])) ? '' : $_GET['action'];
		$action	= ((isset($_POST['submit']) && !$_POST['id']) ? 'add' : $action );
		$ad_id	= request_var('id', 0);
		$show_forums = request_var('show_forums', '');
		$group_id = request_var('group_id', array(0));
		$rank_id = request_var('rank_id', array(0));
		$name	= utf8_normalize_nfc(request_var('name', '', true));
		$code	= request_var('code', '', true);
		$image	= request_var('image', '');
		$url	= request_var('url', '');

		$start_day = $start_month = $start_year = $end_day = $end_month = $end_year = '0';
		$start_time = gmmktime(0, 0, 0, request_var('start_month', 0), request_var('start_day', 0), request_var('start_year', 0)) - (int) ($user->timezone + $user->dst); 
		$end_time = gmmktime(0, 0, 0, request_var('end_month', 0), request_var('end_day', 0), request_var('end_year', 0)) - (int) ($user->timezone + $user->dst); 

		$ad_type = ($html_ads == true) ? 1 : 2;
		$groups = '';
		foreach ($group_id as $group)
		{
				$groups .= $group . ',';
		}

		$ranks = '';
		foreach ($rank_id as $rank)
		{
				$ranks .= $rank . ',';
		}

		//Make SQL Array
		$sql_ary = array(
			'name'				=> $db->sql_escape($name),
			'code'				=> $code,
			'groups '			=> $groups,
			'ranks '			=> $ranks,
			'show_forums'		=> $db->sql_escape($show_forums),
			'show_all_forums'	=> request_var('show_all_forums', 0),
			'views'				=> request_var('views', 0),
			'max_views'			=> request_var('max_views', 0),
			'start_time'		=> $start_time,
			'end_time'			=> $end_time,
			'clicks'			=> request_var('clicks', 0),
			'max_clicks'		=> request_var('max_clicks', 0),
			'position'			=> request_var('position', 0),
			'image'				=> $image,
			'url'				=> $url,
			'height'			=> request_var('height', 0),
			'width'				=> request_var('width', 0),
			'type'				=> $ad_type,
		);

		switch ($action)
		{
			// Add new Adcode
			case 'add':
				if ((!$name || !$code) && $html_ads)
				{
					trigger_error($user->lang['NEED_CODE'] . adm_back_link($this->u_action), E_USER_WARNING);
				}
				elseif ((!$name || !$image || !$url) && !$html_ads)
				{
					trigger_error($user->lang['NEED_IMAGE'] . adm_back_link($this->u_action), E_USER_WARNING);
				}
				else
				{
					$db->sql_query('INSERT INTO ' . AD_TABLE .' ' . $db->sql_build_array('INSERT', $sql_ary));
					trigger_error($user->lang['ADDED'] . adm_back_link($this->u_action));
				}
			break;

			// Edit Ad
			case 'edit':
				$form_action = $this->u_action. '&amp;action=update';
				$sql = 'SELECT ad_id, name, code, show_forums, show_all_forums, views, max_views, clicks, max_clicks, position, groups, ranks, image, url, height, width, start_time, end_time
					FROM ' . AD_TABLE . ' 
					WHERE ad_id = ' . $ad_id;
				$result = $db->sql_query($sql);
				$row = $db->sql_fetchrow($result);
				$group_list = $this->make_grouplist($row['groups']);
				$rank_list = $this->make_ranklist($row['ranks']);
		
				$start_day = date('d', $row['start_time']);
				$start_month = date('n', $row['start_time']);
				$start_year = date('Y', $row['start_time']);
				$end_day = date('d', $row['end_time']);
				$end_month = date('n', $row['end_time']);
				$end_year = date('Y', $row['end_time']);

				$template->assign_vars(array(
					'POST_POSITION_1' 		=> (($row['position'] == '1') ? 'selected' : '' ),
					'POST_POSITION_2'		=> (($row['position'] == '2') ? 'selected' : '' ),
					'POST_POSITION_3'		=> (($row['position'] == '3') ? 'selected' : '' ),
					'POST_POSITION_4'		=> (($row['position'] == '4') ? 'selected' : '' ),
					'POST_POSITION_5'		=> (($row['position'] == '5') ? 'selected' : '' ),
					'POST_POSITION_6'		=> (($row['position'] == '6') ? 'selected' : '' ),
					'POST_SHOW_ALL_FORUMS'	=> (($row['show_all_forums'] == '1') ? 'checked' : '' ),
					'POST_NAME'  			=> $row['name'],
					'POST_VIEWS'  			=> $row['views'],
					'POST_MAX_VIEWS'		=> $row['max_views'],
					'POST_CLICKS'			=> $row['clicks'],
					'POST_MAX_CLICKS'		=> $row['max_clicks'],
					'POST_CODE'				=> $row['code'],
					'POST_IMAGE'			=> $row['image'],
					'POST_URL'				=> $row['url'],
					'POST_HEIGHT'			=> $row['height'],
					'POST_WIDTH'			=> $row['width'],
					'AD_PREVIEW'			=> html_entity_decode($row['code']),
					'BANNER_PREVIEW'		=> '<img src="' . $row['image'] . '" height="' . $row['height'] . '" width="' . $row['width'] . '" alt="" />',
					'AD_ID'  				=> $row['ad_id'],
					'POST_FORUMS' 			=> $row['show_forums'])
				);
			break;

			// Update an Ad
			case 'update':
				$db->sql_query('UPDATE ' . AD_TABLE . ' SET ' . $db->sql_build_array('UPDATE', $sql_ary) . ' WHERE ad_id = ' . $ad_id);
				trigger_error($user->lang['UPDATED'] . adm_back_link($this->u_action));
			break;

			// Delete Ad from System
			case 'delete':
				if (confirm_box(true))
				{
					$sql = 'DELETE FROM ' . AD_TABLE . '
						WHERE ad_id =' . $ad_id;
					$db->sql_query($sql);
					trigger_error($user->lang['DELETED'] . adm_back_link($this->u_action));
				}
				else
				{
					confirm_box(false, $user->lang['REALY_DELETE'], build_hidden_fields(array(
						'id'		=> $ad_id,
						'action'	=> 'delete',
					)));
				}
			break;
		}

		//
		// Start output the page
		//
		// List all Ads in the System
		$sql = 'SELECT ad_id, name, show_all_forums, views, max_views, position, clicks
			FROM ' . AD_TABLE . '
			WHERE type = ' . $ad_type . '
			ORDER by name';
		$result = $db->sql_query($sql);
		while ($row = $db->sql_fetchrow($result))
		{
			$template->assign_block_vars('ad_in_system', array(
				'U_BANNEREDIT'	=> $this->u_action . '&amp;action=edit&amp;id=' .$row['ad_id'],
				'U_BANNERDEL'	=> $this->u_action . '&amp;action=delete&amp;id=' .$row['ad_id'],
				'NAME'			=> $row['name'],
				'CLICKS'		=> $row['clicks'],
				'ALLFORUM'		=> ($row['show_all_forums'] == '1') ? $user->lang['YES'] : $user->lang['NO'],
				'MAX_VIEWS'		=> $row['max_views'],
				'POSITION'		=> $user->lang['POSITION'.$row['position']],
				'VIEWS'			=> $row['views'])
			);
		}
		$db->sql_freeresult($result);

		$this->page_title = $page_title;

		$template->assign_vars(array(
			'POST_START_DAY'	=> $this->option_list(1, 31, $start_day),
			'POST_START_MONTH'	=> $this->option_list(1, 12, $start_month),
			'POST_START_YEAR'	=> $this->option_list(2008, 2020, $start_year),
			'POST_END_DAY'		=> $this->option_list(1, 31, $end_day),
			'POST_END_MONTH'	=> $this->option_list(1, 12, $end_month),
			'POST_END_YEAR'		=> $this->option_list(2008, 2020, $end_year),
			'PAGE_TITLE'		=> $page_title,
			'S_HTML_AD'			=> $html_ads,
			'AD_MODE'			=> ($action == 'edit') ? $user->lang['EDIT_AD'] : $user->lang['NEW_AD'],
			'GROUP_LIST'		=> isset($group_list) ? $group_list : $this->make_grouplist(false),
			'RANK_LIST'			=> isset($rank_list) ? $rank_list : $this->make_ranklist(false),
			'U_ACTION'			=> $form_action )
		);

	}
}

?>
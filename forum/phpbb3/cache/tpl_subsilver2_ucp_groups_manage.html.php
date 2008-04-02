<?php $this->_tpl_include('ucp_header.html'); if ($this->_rootref['S_EDIT']) {  if ($this->_rootref['S_ERROR']) {  ?>
		<div class="errorbox">
			<h3><?php echo ((isset($this->_rootref['L_WARNING'])) ? $this->_rootref['L_WARNING'] : ((isset($user->lang['WARNING'])) ? $user->lang['WARNING'] : '{ WARNING }')); ?></h3>
			<p><?php echo (isset($this->_rootref['ERROR_MSG'])) ? $this->_rootref['ERROR_MSG'] : ''; ?></p>
		</div>
	<?php } ?>

	<table class="tablebg" width="100%" cellspacing="1">
	<tr>
		<th colspan="2"><?php echo ((isset($this->_rootref['L_USERGROUPS'])) ? $this->_rootref['L_USERGROUPS'] : ((isset($user->lang['USERGROUPS'])) ? $user->lang['USERGROUPS'] : '{ USERGROUPS }')); ?></th>
	</tr>
	<tr>
		<td class="row1" colspan="2"><span class="genmed"><?php echo ((isset($this->_rootref['L_GROUPS_EXPLAIN'])) ? $this->_rootref['L_GROUPS_EXPLAIN'] : ((isset($user->lang['GROUPS_EXPLAIN'])) ? $user->lang['GROUPS_EXPLAIN'] : '{ GROUPS_EXPLAIN }')); ?></span></td>
	</tr>

	<tr>
		<th colspan="2"><?php echo ((isset($this->_rootref['L_GROUP_DETAILS'])) ? $this->_rootref['L_GROUP_DETAILS'] : ((isset($user->lang['GROUP_DETAILS'])) ? $user->lang['GROUP_DETAILS'] : '{ GROUP_DETAILS }')); ?></th>
	</tr>
	<tr>
		<td class="row1" width="35%"><label<?php if (! $this->_rootref['S_SPECIAL_GROUP']) {  ?> for="group_name"<?php } ?>><?php echo ((isset($this->_rootref['L_GROUP_NAME'])) ? $this->_rootref['L_GROUP_NAME'] : ((isset($user->lang['GROUP_NAME'])) ? $user->lang['GROUP_NAME'] : '{ GROUP_NAME }')); ?>:</label></td>
		<td class="row2"><?php if ($this->_rootref['S_SPECIAL_GROUP']) {  ?><b<?php if ($this->_rootref['GROUP_COLOUR']) {  ?> style="color: #<?php echo (isset($this->_rootref['GROUP_COLOUR'])) ? $this->_rootref['GROUP_COLOUR'] : ''; ?>;"<?php } ?>><?php echo (isset($this->_rootref['GROUP_NAME'])) ? $this->_rootref['GROUP_NAME'] : ''; ?></b><?php } ?><input name="group_name" type="<?php if ($this->_rootref['S_SPECIAL_GROUP']) {  ?>hidden<?php } else { ?>text<?php } ?>" id="group_name" value="<?php echo (isset($this->_rootref['GROUP_INTERNAL_NAME'])) ? $this->_rootref['GROUP_INTERNAL_NAME'] : ''; ?>" /></td>
	</tr>
	<tr>
		<td class="row1" width="35%"><label for="group_desc"><?php echo ((isset($this->_rootref['L_GROUP_DESC'])) ? $this->_rootref['L_GROUP_DESC'] : ((isset($user->lang['GROUP_DESC'])) ? $user->lang['GROUP_DESC'] : '{ GROUP_DESC }')); ?>:</label></td>
		<td class="row2"><textarea id="group_desc" name="group_desc" rows="5" cols="45"><?php echo (isset($this->_rootref['GROUP_DESC'])) ? $this->_rootref['GROUP_DESC'] : ''; ?></textarea>
			<br /><input type="checkbox" class="radio" name="desc_parse_bbcode"<?php if ($this->_rootref['S_DESC_BBCODE_CHECKED']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_PARSE_BBCODE'])) ? $this->_rootref['L_PARSE_BBCODE'] : ((isset($user->lang['PARSE_BBCODE'])) ? $user->lang['PARSE_BBCODE'] : '{ PARSE_BBCODE }')); ?> &nbsp; <input type="checkbox" class="radio" name="desc_parse_smilies"<?php if ($this->_rootref['S_DESC_SMILIES_CHECKED']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_PARSE_SMILIES'])) ? $this->_rootref['L_PARSE_SMILIES'] : ((isset($user->lang['PARSE_SMILIES'])) ? $user->lang['PARSE_SMILIES'] : '{ PARSE_SMILIES }')); ?> &nbsp; <input type="checkbox" class="radio" name="desc_parse_urls"<?php if ($this->_rootref['S_DESC_URLS_CHECKED']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_PARSE_URLS'])) ? $this->_rootref['L_PARSE_URLS'] : ((isset($user->lang['PARSE_URLS'])) ? $user->lang['PARSE_URLS'] : '{ PARSE_URLS }')); ?>
		</td>
	</tr>
	<?php if (! $this->_rootref['S_SPECIAL_GROUP']) {  ?>
		<tr>
			<td class="row1" width="35%"><label for="group_type"><?php echo ((isset($this->_rootref['L_GROUP_TYPE'])) ? $this->_rootref['L_GROUP_TYPE'] : ((isset($user->lang['GROUP_TYPE'])) ? $user->lang['GROUP_TYPE'] : '{ GROUP_TYPE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_GROUP_TYPE_EXPLAIN'])) ? $this->_rootref['L_GROUP_TYPE_EXPLAIN'] : ((isset($user->lang['GROUP_TYPE_EXPLAIN'])) ? $user->lang['GROUP_TYPE_EXPLAIN'] : '{ GROUP_TYPE_EXPLAIN }')); ?></span></td>
			<td class="row2">
				<input name="group_type" type="radio" class="radio" id="group_type" value="<?php echo (isset($this->_rootref['GROUP_TYPE_FREE'])) ? $this->_rootref['GROUP_TYPE_FREE'] : ''; ?>"<?php echo (isset($this->_rootref['GROUP_FREE'])) ? $this->_rootref['GROUP_FREE'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_GROUP_OPEN'])) ? $this->_rootref['L_GROUP_OPEN'] : ((isset($user->lang['GROUP_OPEN'])) ? $user->lang['GROUP_OPEN'] : '{ GROUP_OPEN }')); ?> &nbsp;
				<input name="group_type" type="radio" class="radio" value="<?php echo (isset($this->_rootref['GROUP_TYPE_OPEN'])) ? $this->_rootref['GROUP_TYPE_OPEN'] : ''; ?>"<?php echo (isset($this->_rootref['GROUP_OPEN'])) ? $this->_rootref['GROUP_OPEN'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_GROUP_REQUEST'])) ? $this->_rootref['L_GROUP_REQUEST'] : ((isset($user->lang['GROUP_REQUEST'])) ? $user->lang['GROUP_REQUEST'] : '{ GROUP_REQUEST }')); ?> &nbsp;
				<input name="group_type" type="radio" class="radio" value="<?php echo (isset($this->_rootref['GROUP_TYPE_CLOSED'])) ? $this->_rootref['GROUP_TYPE_CLOSED'] : ''; ?>"<?php echo (isset($this->_rootref['GROUP_CLOSED'])) ? $this->_rootref['GROUP_CLOSED'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_GROUP_CLOSED'])) ? $this->_rootref['L_GROUP_CLOSED'] : ((isset($user->lang['GROUP_CLOSED'])) ? $user->lang['GROUP_CLOSED'] : '{ GROUP_CLOSED }')); ?> &nbsp;
				<input name="group_type" type="radio" class="radio" value="<?php echo (isset($this->_rootref['GROUP_TYPE_HIDDEN'])) ? $this->_rootref['GROUP_TYPE_HIDDEN'] : ''; ?>"<?php echo (isset($this->_rootref['GROUP_HIDDEN'])) ? $this->_rootref['GROUP_HIDDEN'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_GROUP_HIDDEN'])) ? $this->_rootref['L_GROUP_HIDDEN'] : ((isset($user->lang['GROUP_HIDDEN'])) ? $user->lang['GROUP_HIDDEN'] : '{ GROUP_HIDDEN }')); ?>
			</td>
		</tr>
	<?php } else { ?>
		<tr style="display:none;"><td><input name="group_type" type="hidden" value="<?php echo (isset($this->_rootref['GROUP_TYPE_SPECIAL'])) ? $this->_rootref['GROUP_TYPE_SPECIAL'] : ''; ?>" /></td></tr>
	<?php } ?>

	<tr>
		<th colspan="2"><?php echo ((isset($this->_rootref['L_GROUP_SETTINGS_SAVE'])) ? $this->_rootref['L_GROUP_SETTINGS_SAVE'] : ((isset($user->lang['GROUP_SETTINGS_SAVE'])) ? $user->lang['GROUP_SETTINGS_SAVE'] : '{ GROUP_SETTINGS_SAVE }')); ?></th>
	</tr>
	<tr>
		<td class="row1" width="35%"><label for="group_colour"><?php echo ((isset($this->_rootref['L_GROUP_COLOR'])) ? $this->_rootref['L_GROUP_COLOR'] : ((isset($user->lang['GROUP_COLOR'])) ? $user->lang['GROUP_COLOR'] : '{ GROUP_COLOR }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_GROUP_COLOR_EXPLAIN'])) ? $this->_rootref['L_GROUP_COLOR_EXPLAIN'] : ((isset($user->lang['GROUP_COLOR_EXPLAIN'])) ? $user->lang['GROUP_COLOR_EXPLAIN'] : '{ GROUP_COLOR_EXPLAIN }')); ?></span></td>
		<td class="row2"><input name="group_colour" type="text" id="group_colour" value="<?php echo (isset($this->_rootref['GROUP_COLOUR'])) ? $this->_rootref['GROUP_COLOUR'] : ''; ?>" size="6" maxlength="6" />&nbsp;&nbsp;<span>[ <a href="<?php echo (isset($this->_rootref['U_SWATCH'])) ? $this->_rootref['U_SWATCH'] : ''; ?>" onclick="popup(this.href, 636, 150, '_swatch'); return false;"><?php echo ((isset($this->_rootref['L_COLOUR_SWATCH'])) ? $this->_rootref['L_COLOUR_SWATCH'] : ((isset($user->lang['COLOUR_SWATCH'])) ? $user->lang['COLOUR_SWATCH'] : '{ COLOUR_SWATCH }')); ?></a> ]</span></td>
	</tr>
	<tr>
		<td class="row1" width="35%"><label for="group_rank"><?php echo ((isset($this->_rootref['L_GROUP_RANK'])) ? $this->_rootref['L_GROUP_RANK'] : ((isset($user->lang['GROUP_RANK'])) ? $user->lang['GROUP_RANK'] : '{ GROUP_RANK }')); ?>:</label></td>
		<td class="row2"><select name="group_rank" id="group_rank"><?php echo (isset($this->_rootref['S_RANK_OPTIONS'])) ? $this->_rootref['S_RANK_OPTIONS'] : ''; ?></select></td>
	</tr>
	<tr>
		<th colspan="2"><?php echo ((isset($this->_rootref['L_GROUP_AVATAR'])) ? $this->_rootref['L_GROUP_AVATAR'] : ((isset($user->lang['GROUP_AVATAR'])) ? $user->lang['GROUP_AVATAR'] : '{ GROUP_AVATAR }')); ?></th>
	</tr>
	<tr>
		<td class="row1" width="35%"><label><?php echo ((isset($this->_rootref['L_CURRENT_IMAGE'])) ? $this->_rootref['L_CURRENT_IMAGE'] : ((isset($user->lang['CURRENT_IMAGE'])) ? $user->lang['CURRENT_IMAGE'] : '{ CURRENT_IMAGE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_AVATAR_EXPLAIN'])) ? $this->_rootref['L_AVATAR_EXPLAIN'] : ((isset($user->lang['AVATAR_EXPLAIN'])) ? $user->lang['AVATAR_EXPLAIN'] : '{ AVATAR_EXPLAIN }')); ?></span></td>
		<td class="row2"><?php echo (isset($this->_rootref['AVATAR_IMAGE'])) ? $this->_rootref['AVATAR_IMAGE'] : ''; ?><br /><br /><input type="checkbox" class="radio" name="delete" />&nbsp;<span><?php echo ((isset($this->_rootref['L_DELETE_AVATAR'])) ? $this->_rootref['L_DELETE_AVATAR'] : ((isset($user->lang['DELETE_AVATAR'])) ? $user->lang['DELETE_AVATAR'] : '{ DELETE_AVATAR }')); ?></span></td>
	</tr>
	<?php if (! $this->_rootref['S_IN_AVATAR_GALLERY']) {  if ($this->_rootref['S_CAN_UPLOAD']) {  ?>
			<tr>
				<td class="row1" width="35%"><label for="uploadfile"><?php echo ((isset($this->_rootref['L_UPLOAD_AVATAR_FILE'])) ? $this->_rootref['L_UPLOAD_AVATAR_FILE'] : ((isset($user->lang['UPLOAD_AVATAR_FILE'])) ? $user->lang['UPLOAD_AVATAR_FILE'] : '{ UPLOAD_AVATAR_FILE }')); ?>:</label></td>
				<td class="row2"><input type="hidden" name="MAX_FILE_SIZE" value="<?php echo (isset($this->_rootref['AVATAR_MAX_FILESIZE'])) ? $this->_rootref['AVATAR_MAX_FILESIZE'] : ''; ?>" /><input type="file" id="uploadfile" name="uploadfile" /></td>
			</tr>
			<tr>
				<td class="row1" width="35%"><label for="uploadurl"><?php echo ((isset($this->_rootref['L_UPLOAD_AVATAR_URL'])) ? $this->_rootref['L_UPLOAD_AVATAR_URL'] : ((isset($user->lang['UPLOAD_AVATAR_URL'])) ? $user->lang['UPLOAD_AVATAR_URL'] : '{ UPLOAD_AVATAR_URL }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_UPLOAD_AVATAR_URL_EXPLAIN'])) ? $this->_rootref['L_UPLOAD_AVATAR_URL_EXPLAIN'] : ((isset($user->lang['UPLOAD_AVATAR_URL_EXPLAIN'])) ? $user->lang['UPLOAD_AVATAR_URL_EXPLAIN'] : '{ UPLOAD_AVATAR_URL_EXPLAIN }')); ?></span></td>
				<td class="row2"><input name="uploadurl" type="text" id="uploadurl" value="" /></td>
			</tr>
		<?php } ?>
		<tr>
			<td class="row1" width="35%"><label for="remotelink"><?php echo ((isset($this->_rootref['L_LINK_REMOTE_AVATAR'])) ? $this->_rootref['L_LINK_REMOTE_AVATAR'] : ((isset($user->lang['LINK_REMOTE_AVATAR'])) ? $user->lang['LINK_REMOTE_AVATAR'] : '{ LINK_REMOTE_AVATAR }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_LINK_REMOTE_AVATAR_EXPLAIN'])) ? $this->_rootref['L_LINK_REMOTE_AVATAR_EXPLAIN'] : ((isset($user->lang['LINK_REMOTE_AVATAR_EXPLAIN'])) ? $user->lang['LINK_REMOTE_AVATAR_EXPLAIN'] : '{ LINK_REMOTE_AVATAR_EXPLAIN }')); ?></span></td>
			<td class="row2"><input name="remotelink" type="text" id="remotelink" value="" /></td>
		</tr>
		<tr>
			<td class="row1" width="35%"><label for="width"><?php echo ((isset($this->_rootref['L_LINK_REMOTE_SIZE'])) ? $this->_rootref['L_LINK_REMOTE_SIZE'] : ((isset($user->lang['LINK_REMOTE_SIZE'])) ? $user->lang['LINK_REMOTE_SIZE'] : '{ LINK_REMOTE_SIZE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_LINK_REMOTE_SIZE_EXPLAIN'])) ? $this->_rootref['L_LINK_REMOTE_SIZE_EXPLAIN'] : ((isset($user->lang['LINK_REMOTE_SIZE_EXPLAIN'])) ? $user->lang['LINK_REMOTE_SIZE_EXPLAIN'] : '{ LINK_REMOTE_SIZE_EXPLAIN }')); ?></span></td>
			<td class="row2"><input name="width" type="text" id="width" size="3" value="<?php echo (isset($this->_rootref['AVATAR_WIDTH'])) ? $this->_rootref['AVATAR_WIDTH'] : ''; ?>" /> <span>px X </span> <input type="text" name="height" size="3" value="<?php echo (isset($this->_rootref['AVATAR_HEIGHT'])) ? $this->_rootref['AVATAR_HEIGHT'] : ''; ?>" /> <span>px</span></td>
		</tr>
		<?php if ($this->_rootref['S_DISPLAY_GALLERY']) {  ?>
			<tr>
				<td class="row1" width="35%"><label><?php echo ((isset($this->_rootref['L_AVATAR_GALLERY'])) ? $this->_rootref['L_AVATAR_GALLERY'] : ((isset($user->lang['AVATAR_GALLERY'])) ? $user->lang['AVATAR_GALLERY'] : '{ AVATAR_GALLERY }')); ?>:</label></td>
				<td class="row2"><input class="btnmain" type="submit" name="display_gallery" value="<?php echo ((isset($this->_rootref['L_DISPLAY_GALLERY'])) ? $this->_rootref['L_DISPLAY_GALLERY'] : ((isset($user->lang['DISPLAY_GALLERY'])) ? $user->lang['DISPLAY_GALLERY'] : '{ DISPLAY_GALLERY }')); ?>" /></td>
			</tr>
		<?php } } else { ?>

		<tr>
			<th colspan="2"><?php echo ((isset($this->_rootref['L_AVATAR_GALLERY'])) ? $this->_rootref['L_AVATAR_GALLERY'] : ((isset($user->lang['AVATAR_GALLERY'])) ? $user->lang['AVATAR_GALLERY'] : '{ AVATAR_GALLERY }')); ?></th>
		</tr>
		<tr>
			<td class="row1" width="35%"><label for="category"><?php echo ((isset($this->_rootref['L_AVATAR_CATEGORY'])) ? $this->_rootref['L_AVATAR_CATEGORY'] : ((isset($user->lang['AVATAR_CATEGORY'])) ? $user->lang['AVATAR_CATEGORY'] : '{ AVATAR_CATEGORY }')); ?>:</label></td>
			<td class="row2"><select name="category" id="category"><?php echo (isset($this->_rootref['S_CAT_OPTIONS'])) ? $this->_rootref['S_CAT_OPTIONS'] : ''; ?></select>&nbsp;<input class="btnmain" type="submit" value="<?php echo ((isset($this->_rootref['L_GO'])) ? $this->_rootref['L_GO'] : ((isset($user->lang['GO'])) ? $user->lang['GO'] : '{ GO }')); ?>" name="display_gallery" /></td>
		</tr>
		<tr>
			<td class="row1" width="35%">
				<table cellspacing="1">
				<?php $_avatar_row_count = (isset($this->_tpldata['avatar_row'])) ? sizeof($this->_tpldata['avatar_row']) : 0;if ($_avatar_row_count) {for ($_avatar_row_i = 0; $_avatar_row_i < $_avatar_row_count; ++$_avatar_row_i){$_avatar_row_val = &$this->_tpldata['avatar_row'][$_avatar_row_i]; ?>
				<tr>
					<?php $_avatar_column_count = (isset($_avatar_row_val['avatar_column'])) ? sizeof($_avatar_row_val['avatar_column']) : 0;if ($_avatar_column_count) {for ($_avatar_column_i = 0; $_avatar_column_i < $_avatar_column_count; ++$_avatar_column_i){$_avatar_column_val = &$_avatar_row_val['avatar_column'][$_avatar_column_i]; ?>
						<td class="row1" style="text-align: center;"><img src="<?php echo $_avatar_column_val['AVATAR_IMAGE']; ?>" alt="<?php echo $_avatar_column_val['AVATAR_NAME']; ?>" title="<?php echo $_avatar_column_val['AVATAR_NAME']; ?>" /></td>
					<?php }} ?>
				</tr>
				<tr>
					<?php $_avatar_option_column_count = (isset($_avatar_row_val['avatar_option_column'])) ? sizeof($_avatar_row_val['avatar_option_column']) : 0;if ($_avatar_option_column_count) {for ($_avatar_option_column_i = 0; $_avatar_option_column_i < $_avatar_option_column_count; ++$_avatar_option_column_i){$_avatar_option_column_val = &$_avatar_row_val['avatar_option_column'][$_avatar_option_column_i]; ?>
						<td class="row2" style="text-align: center;"><input type="radio" class="radio" name="avatar_select" value="<?php echo $_avatar_option_column_val['S_OPTIONS_AVATAR']; ?>" /></td>
					<?php }} ?>
				</tr>
				<?php }} ?>
				</table>
			</td>
			<td class="row2"><input class="btnmain" type="submit" name="cancel" value="<?php echo ((isset($this->_rootref['L_CANCEL'])) ? $this->_rootref['L_CANCEL'] : ((isset($user->lang['CANCEL'])) ? $user->lang['CANCEL'] : '{ CANCEL }')); ?>" /></td>
		</tr>

	<?php } ?>

	<tr>
		<td class="cat" colspan="2" align="center"><input class="btnlite" type="submit" id="submit" name="update" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />&nbsp;
		<input class="btnmain" type="reset" id="reset" name="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" /></td>
	</tr>
	</table>

<?php } else if ($this->_rootref['S_LIST']) {  ?>

	<h1><?php echo ((isset($this->_rootref['L_GROUP_MEMBERS'])) ? $this->_rootref['L_GROUP_MEMBERS'] : ((isset($user->lang['GROUP_MEMBERS'])) ? $user->lang['GROUP_MEMBERS'] : '{ GROUP_MEMBERS }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_GROUP_MEMBERS_EXPLAIN'])) ? $this->_rootref['L_GROUP_MEMBERS_EXPLAIN'] : ((isset($user->lang['GROUP_MEMBERS_EXPLAIN'])) ? $user->lang['GROUP_MEMBERS_EXPLAIN'] : '{ GROUP_MEMBERS_EXPLAIN }')); ?></p>

	<table class="tablebg" width="100%" cellspacing="1">
	<tr>
		<th><?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_GROUP_DEFAULT'])) ? $this->_rootref['L_GROUP_DEFAULT'] : ((isset($user->lang['GROUP_DEFAULT'])) ? $user->lang['GROUP_DEFAULT'] : '{ GROUP_DEFAULT }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_JOINED'])) ? $this->_rootref['L_JOINED'] : ((isset($user->lang['JOINED'])) ? $user->lang['JOINED'] : '{ JOINED }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_POSTS'])) ? $this->_rootref['L_POSTS'] : ((isset($user->lang['POSTS'])) ? $user->lang['POSTS'] : '{ POSTS }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_MARK'])) ? $this->_rootref['L_MARK'] : ((isset($user->lang['MARK'])) ? $user->lang['MARK'] : '{ MARK }')); ?></th>
	</tr>

	<tr>
		<td class="row3" colspan="5"><b><?php echo ((isset($this->_rootref['L_GROUP_LEAD'])) ? $this->_rootref['L_GROUP_LEAD'] : ((isset($user->lang['GROUP_LEAD'])) ? $user->lang['GROUP_LEAD'] : '{ GROUP_LEAD }')); ?></b></td>
	</tr>
	<?php $_leader_count = (isset($this->_tpldata['leader'])) ? sizeof($this->_tpldata['leader']) : 0;if ($_leader_count) {for ($_leader_i = 0; $_leader_i < $_leader_count; ++$_leader_i){$_leader_val = &$this->_tpldata['leader'][$_leader_i]; if (!($_leader_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>
			<td><?php echo $_leader_val['USERNAME_FULL']; ?></td>
			<td style="text-align: center;"><?php if ($_leader_val['S_GROUP_DEFAULT']) {  echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); } else { echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); } ?></td>
			<td style="text-align: center;"><?php echo $_leader_val['JOINED']; ?></td>
			<td style="text-align: center;"><?php echo $_leader_val['USER_POSTS']; ?></td>
			<td style="text-align: center;"></td>
		</tr>
	<?php }} ?>
	<tr>
		<td class="row3" colspan="5"><b><?php echo ((isset($this->_rootref['L_GROUP_APPROVED'])) ? $this->_rootref['L_GROUP_APPROVED'] : ((isset($user->lang['GROUP_APPROVED'])) ? $user->lang['GROUP_APPROVED'] : '{ GROUP_APPROVED }')); ?></b></td>
	</tr>
	<?php $_member_count = (isset($this->_tpldata['member'])) ? sizeof($this->_tpldata['member']) : 0;if ($_member_count) {for ($_member_i = 0; $_member_i < $_member_count; ++$_member_i){$_member_val = &$this->_tpldata['member'][$_member_i]; if ($_member_val['S_PENDING']) {  ?>
			<tr>
				<td class="row3" colspan="5"><b><?php echo ((isset($this->_rootref['L_GROUP_PENDING'])) ? $this->_rootref['L_GROUP_PENDING'] : ((isset($user->lang['GROUP_PENDING'])) ? $user->lang['GROUP_PENDING'] : '{ GROUP_PENDING }')); ?></b></td>
			</tr>
		<?php } else { if (!($_member_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>
				<td><?php echo $_member_val['USERNAME_FULL']; ?></td>
				<td style="text-align: center;"><?php if ($_member_val['S_GROUP_DEFAULT']) {  echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); } else { echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); } ?></td>
				<td style="text-align: center;"><?php echo $_member_val['JOINED']; ?></td>
				<td style="text-align: center;"><?php echo $_member_val['USER_POSTS']; ?></td>
				<td style="text-align: center;"><input type="checkbox" class="radio" name="mark[]" value="<?php echo $_member_val['USER_ID']; ?>" /></td>
			</tr>
		<?php } }} else { ?>
		<tr>
			<td class="row1" colspan="5" style="text-align: center;"><?php echo ((isset($this->_rootref['L_GROUPS_NO_MEMBERS'])) ? $this->_rootref['L_GROUPS_NO_MEMBERS'] : ((isset($user->lang['GROUPS_NO_MEMBERS'])) ? $user->lang['GROUPS_NO_MEMBERS'] : '{ GROUPS_NO_MEMBERS }')); ?></td>
		</tr>
	<?php } ?>
	<tr>
		<td class="cat" colspan="5" align="center"><div style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>;"><span class="small"><a href="#" onclick="marklist('ucp', 'mark', true); return false;"><?php echo ((isset($this->_rootref['L_MARK_ALL'])) ? $this->_rootref['L_MARK_ALL'] : ((isset($user->lang['MARK_ALL'])) ? $user->lang['MARK_ALL'] : '{ MARK_ALL }')); ?></a> :: <a href="#" onclick="marklist('ucp', 'mark', false); return false;"><?php echo ((isset($this->_rootref['L_UNMARK_ALL'])) ? $this->_rootref['L_UNMARK_ALL'] : ((isset($user->lang['UNMARK_ALL'])) ? $user->lang['UNMARK_ALL'] : '{ UNMARK_ALL }')); ?></a></span></div><div style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>;"><select name="action"><option class="sep" value=""><?php echo ((isset($this->_rootref['L_SELECT_OPTION'])) ? $this->_rootref['L_SELECT_OPTION'] : ((isset($user->lang['SELECT_OPTION'])) ? $user->lang['SELECT_OPTION'] : '{ SELECT_OPTION }')); ?></option><?php echo (isset($this->_rootref['S_ACTION_OPTIONS'])) ? $this->_rootref['S_ACTION_OPTIONS'] : ''; ?></select> <input class="btnmain" type="submit" name="update" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" /></div></td>
	</tr>
	</table>

	<div class="pagination" style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>;">
		<?php if ($this->_rootref['PAGINATION']) {  $this->_tpl_include('pagination.html'); } else { ?>
			<?php echo (isset($this->_rootref['S_ON_PAGE'])) ? $this->_rootref['S_ON_PAGE'] : ''; ?>
		<?php } ?>
	</div>

	<br />
	<br />

	<h1><?php echo ((isset($this->_rootref['L_ADD_USERS'])) ? $this->_rootref['L_ADD_USERS'] : ((isset($user->lang['ADD_USERS'])) ? $user->lang['ADD_USERS'] : '{ ADD_USERS }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_ADD_USERS_EXPLAIN'])) ? $this->_rootref['L_ADD_USERS_EXPLAIN'] : ((isset($user->lang['ADD_USERS_EXPLAIN'])) ? $user->lang['ADD_USERS_EXPLAIN'] : '{ ADD_USERS_EXPLAIN }')); ?></p>

	<table class="tablebg" width="100%" cellspacing="1">
	<tr>
		<th colspan="2"><?php echo ((isset($this->_rootref['L_ADD_USERS'])) ? $this->_rootref['L_ADD_USERS'] : ((isset($user->lang['ADD_USERS'])) ? $user->lang['ADD_USERS'] : '{ ADD_USERS }')); ?></th>
	</tr>
	<tr>
		<td class="row1"><label for="default"><?php echo ((isset($this->_rootref['L_USER_GROUP_DEFAULT'])) ? $this->_rootref['L_USER_GROUP_DEFAULT'] : ((isset($user->lang['USER_GROUP_DEFAULT'])) ? $user->lang['USER_GROUP_DEFAULT'] : '{ USER_GROUP_DEFAULT }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_USER_GROUP_DEFAULT_EXPLAIN'])) ? $this->_rootref['L_USER_GROUP_DEFAULT_EXPLAIN'] : ((isset($user->lang['USER_GROUP_DEFAULT_EXPLAIN'])) ? $user->lang['USER_GROUP_DEFAULT_EXPLAIN'] : '{ USER_GROUP_DEFAULT_EXPLAIN }')); ?></span></td>
		<td class="row2"><input name="default" type="radio" class="radio" value="1" /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?> &nbsp; <input name="default" type="radio" class="radio" id="default" value="0" checked="checked" /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></td>
	</tr>
	<tr>
		<td class="row1"><label for="usernames"><?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_USERNAMES_EXPLAIN'])) ? $this->_rootref['L_USERNAMES_EXPLAIN'] : ((isset($user->lang['USERNAMES_EXPLAIN'])) ? $user->lang['USERNAMES_EXPLAIN'] : '{ USERNAMES_EXPLAIN }')); ?></span></td>
		<td class="row2"><textarea id="usernames" name="usernames" cols="40" rows="5"></textarea><br />[ <a href="<?php echo (isset($this->_rootref['U_FIND_USERNAME'])) ? $this->_rootref['U_FIND_USERNAME'] : ''; ?>" onclick="find_username(this.href); return false;"><?php echo ((isset($this->_rootref['L_FIND_USERNAME'])) ? $this->_rootref['L_FIND_USERNAME'] : ((isset($user->lang['FIND_USERNAME'])) ? $user->lang['FIND_USERNAME'] : '{ FIND_USERNAME }')); ?></a> ]</td>
	</tr>
	<tr>
		<td class="cat" colspan="2" align="center"><input class="btnmain" type="submit" name="addusers" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" /></td>
	</tr>
	</table>

<?php } else { ?>

	<table class="tablebg" width="100%" cellspacing="1">
	<tr>
		<th colspan="3"><?php echo ((isset($this->_rootref['L_USERGROUPS'])) ? $this->_rootref['L_USERGROUPS'] : ((isset($user->lang['USERGROUPS'])) ? $user->lang['USERGROUPS'] : '{ USERGROUPS }')); ?></th>
	</tr>
	<tr>
		<td class="row1" colspan="3"><span class="genmed"><?php echo ((isset($this->_rootref['L_GROUPS_EXPLAIN'])) ? $this->_rootref['L_GROUPS_EXPLAIN'] : ((isset($user->lang['GROUPS_EXPLAIN'])) ? $user->lang['GROUPS_EXPLAIN'] : '{ GROUPS_EXPLAIN }')); ?></span></td>
	</tr>

	<tr>
		<th><?php echo ((isset($this->_rootref['L_GROUP_DETAILS'])) ? $this->_rootref['L_GROUP_DETAILS'] : ((isset($user->lang['GROUP_DETAILS'])) ? $user->lang['GROUP_DETAILS'] : '{ GROUP_DETAILS }')); ?></th>
		<th colspan="2"><?php echo ((isset($this->_rootref['L_OPTIONS'])) ? $this->_rootref['L_OPTIONS'] : ((isset($user->lang['OPTIONS'])) ? $user->lang['OPTIONS'] : '{ OPTIONS }')); ?></th>
	</tr>
	<tr>
		<td class="row3" colspan="3"><b class="gensmall"><?php echo ((isset($this->_rootref['L_GROUP_LEADER'])) ? $this->_rootref['L_GROUP_LEADER'] : ((isset($user->lang['GROUP_LEADER'])) ? $user->lang['GROUP_LEADER'] : '{ GROUP_LEADER }')); ?></b></td>
	</tr>
	<?php $_leader_count = (isset($this->_tpldata['leader'])) ? sizeof($this->_tpldata['leader']) : 0;if ($_leader_count) {for ($_leader_i = 0; $_leader_i < $_leader_count; ++$_leader_i){$_leader_val = &$this->_tpldata['leader'][$_leader_i]; if (($_leader_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>

		<td><b class="genmed"<?php if ($_leader_val['GROUP_COLOUR']) {  ?> style="color: #<?php echo $_leader_val['GROUP_COLOUR']; ?>;"<?php } ?>><?php echo $_leader_val['GROUP_NAME']; ?></b><?php if ($_leader_val['GROUP_DESC']) {  ?><p class="forumdesc"><?php echo $_leader_val['GROUP_DESC']; ?></p><?php } ?></td>
		<td style="text-align: center;"><a href="<?php echo $_leader_val['U_EDIT']; ?>"><?php echo ((isset($this->_rootref['L_EDIT'])) ? $this->_rootref['L_EDIT'] : ((isset($user->lang['EDIT'])) ? $user->lang['EDIT'] : '{ EDIT }')); ?></a></td>
		<td style="text-align: center;"><a href="<?php echo $_leader_val['U_LIST']; ?>"><?php echo ((isset($this->_rootref['L_GROUP_LIST'])) ? $this->_rootref['L_GROUP_LIST'] : ((isset($user->lang['GROUP_LIST'])) ? $user->lang['GROUP_LIST'] : '{ GROUP_LIST }')); ?></a></td>

	</tr>
	<?php }} else { ?>
		<tr>
			<td class="row2" align="center" colspan="3"><b class="genmed"><?php echo ((isset($this->_rootref['L_NO_LEADERS'])) ? $this->_rootref['L_NO_LEADERS'] : ((isset($user->lang['NO_LEADERS'])) ? $user->lang['NO_LEADERS'] : '{ NO_LEADERS }')); ?></b></td>
		</tr>
	<?php } ?>

	<tr>
		<td class="cat" align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>" colspan="3">&nbsp;</td>
	</tr>
	</table>

<?php } $this->_tpl_include('ucp_footer.html'); ?>
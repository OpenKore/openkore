<?php $this->_tpl_include('overall_header.html'); ?>

<a name="maincontent"></a>

<?php if ($this->_rootref['S_EDIT']) {  ?>

	<a href="<?php echo (isset($this->_rootref['U_BACK'])) ? $this->_rootref['U_BACK'] : ''; ?>" style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>;">&laquo; <?php echo ((isset($this->_rootref['L_BACK'])) ? $this->_rootref['L_BACK'] : ((isset($user->lang['BACK'])) ? $user->lang['BACK'] : '{ BACK }')); ?></a>

	<h1><?php echo ((isset($this->_rootref['L_ACP_GROUPS_MANAGE'])) ? $this->_rootref['L_ACP_GROUPS_MANAGE'] : ((isset($user->lang['ACP_GROUPS_MANAGE'])) ? $user->lang['ACP_GROUPS_MANAGE'] : '{ ACP_GROUPS_MANAGE }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_GROUP_EDIT_EXPLAIN'])) ? $this->_rootref['L_GROUP_EDIT_EXPLAIN'] : ((isset($user->lang['GROUP_EDIT_EXPLAIN'])) ? $user->lang['GROUP_EDIT_EXPLAIN'] : '{ GROUP_EDIT_EXPLAIN }')); ?></p>

	<?php if ($this->_rootref['S_ERROR']) {  ?>
		<div class="errorbox">
			<h3><?php echo ((isset($this->_rootref['L_WARNING'])) ? $this->_rootref['L_WARNING'] : ((isset($user->lang['WARNING'])) ? $user->lang['WARNING'] : '{ WARNING }')); ?></h3>
			<p><?php echo (isset($this->_rootref['ERROR_MSG'])) ? $this->_rootref['ERROR_MSG'] : ''; ?></p>
		</div>
	<?php } ?>

	<form id="settings" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>"<?php if ($this->_rootref['S_CAN_UPLOAD']) {  ?> enctype="multipart/form-data"<?php } ?>>

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_GROUP_DETAILS'])) ? $this->_rootref['L_GROUP_DETAILS'] : ((isset($user->lang['GROUP_DETAILS'])) ? $user->lang['GROUP_DETAILS'] : '{ GROUP_DETAILS }')); ?></legend>
	<dl>
		<dt><label<?php if (! $this->_rootref['S_SPECIAL_GROUP']) {  ?> for="group_name"<?php } ?>><?php echo ((isset($this->_rootref['L_GROUP_NAME'])) ? $this->_rootref['L_GROUP_NAME'] : ((isset($user->lang['GROUP_NAME'])) ? $user->lang['GROUP_NAME'] : '{ GROUP_NAME }')); ?>:</label></dt>
		<dd><?php if ($this->_rootref['S_SPECIAL_GROUP']) {  ?><strong><?php echo (isset($this->_rootref['GROUP_NAME'])) ? $this->_rootref['GROUP_NAME'] : ''; ?></strong><?php } ?><input name="group_name" type="<?php if ($this->_rootref['S_SPECIAL_GROUP']) {  ?>hidden<?php } else { ?>text<?php } ?>" id="group_name" value="<?php echo (isset($this->_rootref['GROUP_INTERNAL_NAME'])) ? $this->_rootref['GROUP_INTERNAL_NAME'] : ''; ?>" /></dd>
	</dl>
	<dl>
		<dt><label for="group_desc"><?php echo ((isset($this->_rootref['L_GROUP_DESC'])) ? $this->_rootref['L_GROUP_DESC'] : ((isset($user->lang['GROUP_DESC'])) ? $user->lang['GROUP_DESC'] : '{ GROUP_DESC }')); ?>:</label></dt>
		<dd><textarea id="group_desc" name="group_desc" rows="5" cols="45"><?php echo (isset($this->_rootref['GROUP_DESC'])) ? $this->_rootref['GROUP_DESC'] : ''; ?></textarea></dd>
		<dd><label><input type="checkbox" class="radio" name="desc_parse_bbcode"<?php if ($this->_rootref['S_DESC_BBCODE_CHECKED']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_PARSE_BBCODE'])) ? $this->_rootref['L_PARSE_BBCODE'] : ((isset($user->lang['PARSE_BBCODE'])) ? $user->lang['PARSE_BBCODE'] : '{ PARSE_BBCODE }')); ?></label>
			<label><input type="checkbox" class="radio" name="desc_parse_smilies"<?php if ($this->_rootref['S_DESC_SMILIES_CHECKED']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_PARSE_SMILIES'])) ? $this->_rootref['L_PARSE_SMILIES'] : ((isset($user->lang['PARSE_SMILIES'])) ? $user->lang['PARSE_SMILIES'] : '{ PARSE_SMILIES }')); ?></label>
			<label><input type="checkbox" class="radio" name="desc_parse_urls"<?php if ($this->_rootref['S_DESC_URLS_CHECKED']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_PARSE_URLS'])) ? $this->_rootref['L_PARSE_URLS'] : ((isset($user->lang['PARSE_URLS'])) ? $user->lang['PARSE_URLS'] : '{ PARSE_URLS }')); ?></label></dd>
	</dl>
	<?php if (! $this->_rootref['S_SPECIAL_GROUP']) {  ?>
		<dl>
			<dt><label for="group_type"><?php echo ((isset($this->_rootref['L_GROUP_TYPE'])) ? $this->_rootref['L_GROUP_TYPE'] : ((isset($user->lang['GROUP_TYPE'])) ? $user->lang['GROUP_TYPE'] : '{ GROUP_TYPE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_GROUP_TYPE_EXPLAIN'])) ? $this->_rootref['L_GROUP_TYPE_EXPLAIN'] : ((isset($user->lang['GROUP_TYPE_EXPLAIN'])) ? $user->lang['GROUP_TYPE_EXPLAIN'] : '{ GROUP_TYPE_EXPLAIN }')); ?></span></dt>
			<dd>
				<label><input name="group_type" type="radio" class="radio" id="group_type" value="<?php echo (isset($this->_rootref['GROUP_TYPE_FREE'])) ? $this->_rootref['GROUP_TYPE_FREE'] : ''; ?>"<?php echo (isset($this->_rootref['GROUP_FREE'])) ? $this->_rootref['GROUP_FREE'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_GROUP_OPEN'])) ? $this->_rootref['L_GROUP_OPEN'] : ((isset($user->lang['GROUP_OPEN'])) ? $user->lang['GROUP_OPEN'] : '{ GROUP_OPEN }')); ?></label>
				<label><input name="group_type" type="radio" class="radio" value="<?php echo (isset($this->_rootref['GROUP_TYPE_OPEN'])) ? $this->_rootref['GROUP_TYPE_OPEN'] : ''; ?>"<?php echo (isset($this->_rootref['GROUP_OPEN'])) ? $this->_rootref['GROUP_OPEN'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_GROUP_REQUEST'])) ? $this->_rootref['L_GROUP_REQUEST'] : ((isset($user->lang['GROUP_REQUEST'])) ? $user->lang['GROUP_REQUEST'] : '{ GROUP_REQUEST }')); ?></label>
				<label><input name="group_type" type="radio" class="radio" value="<?php echo (isset($this->_rootref['GROUP_TYPE_CLOSED'])) ? $this->_rootref['GROUP_TYPE_CLOSED'] : ''; ?>"<?php echo (isset($this->_rootref['GROUP_CLOSED'])) ? $this->_rootref['GROUP_CLOSED'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_GROUP_CLOSED'])) ? $this->_rootref['L_GROUP_CLOSED'] : ((isset($user->lang['GROUP_CLOSED'])) ? $user->lang['GROUP_CLOSED'] : '{ GROUP_CLOSED }')); ?></label>
				<label><input name="group_type" type="radio" class="radio" value="<?php echo (isset($this->_rootref['GROUP_TYPE_HIDDEN'])) ? $this->_rootref['GROUP_TYPE_HIDDEN'] : ''; ?>"<?php echo (isset($this->_rootref['GROUP_HIDDEN'])) ? $this->_rootref['GROUP_HIDDEN'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_GROUP_HIDDEN'])) ? $this->_rootref['L_GROUP_HIDDEN'] : ((isset($user->lang['GROUP_HIDDEN'])) ? $user->lang['GROUP_HIDDEN'] : '{ GROUP_HIDDEN }')); ?></label>
			</dd>
		</dl>
	<?php } else { ?>
		<input name="group_type" type="hidden" value="<?php echo (isset($this->_rootref['GROUP_TYPE_SPECIAL'])) ? $this->_rootref['GROUP_TYPE_SPECIAL'] : ''; ?>" />
	<?php } if ($this->_rootref['S_ADD_GROUP'] && $this->_rootref['S_GROUP_PERM']) {  ?>
		<dl>
			<dt><label for="group_perm_from"><?php echo ((isset($this->_rootref['L_COPY_PERMISSIONS'])) ? $this->_rootref['L_COPY_PERMISSIONS'] : ((isset($user->lang['COPY_PERMISSIONS'])) ? $user->lang['COPY_PERMISSIONS'] : '{ COPY_PERMISSIONS }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_COPY_PERMISSIONS_EXPLAIN'])) ? $this->_rootref['L_COPY_PERMISSIONS_EXPLAIN'] : ((isset($user->lang['COPY_PERMISSIONS_EXPLAIN'])) ? $user->lang['COPY_PERMISSIONS_EXPLAIN'] : '{ COPY_PERMISSIONS_EXPLAIN }')); ?></span></dt>
			<dd><select id="group_perm_from" name="group_perm_from"><option value="0"><?php echo ((isset($this->_rootref['L_NO_PERMISSIONS'])) ? $this->_rootref['L_NO_PERMISSIONS'] : ((isset($user->lang['NO_PERMISSIONS'])) ? $user->lang['NO_PERMISSIONS'] : '{ NO_PERMISSIONS }')); ?></option><?php echo (isset($this->_rootref['S_GROUP_OPTIONS'])) ? $this->_rootref['S_GROUP_OPTIONS'] : ''; ?></select></dd>
		</dl>
	<?php } ?>
	</fieldset>

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_GROUP_SETTINGS_SAVE'])) ? $this->_rootref['L_GROUP_SETTINGS_SAVE'] : ((isset($user->lang['GROUP_SETTINGS_SAVE'])) ? $user->lang['GROUP_SETTINGS_SAVE'] : '{ GROUP_SETTINGS_SAVE }')); ?></legend>
	<?php if ($this->_rootref['S_USER_FOUNDER']) {  ?>
	<dl>
		<dt><label for="group_founder_manage"><?php echo ((isset($this->_rootref['L_GROUP_FOUNDER_MANAGE'])) ? $this->_rootref['L_GROUP_FOUNDER_MANAGE'] : ((isset($user->lang['GROUP_FOUNDER_MANAGE'])) ? $user->lang['GROUP_FOUNDER_MANAGE'] : '{ GROUP_FOUNDER_MANAGE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_GROUP_FOUNDER_MANAGE_EXPLAIN'])) ? $this->_rootref['L_GROUP_FOUNDER_MANAGE_EXPLAIN'] : ((isset($user->lang['GROUP_FOUNDER_MANAGE_EXPLAIN'])) ? $user->lang['GROUP_FOUNDER_MANAGE_EXPLAIN'] : '{ GROUP_FOUNDER_MANAGE_EXPLAIN }')); ?></span></dt>
		<dd><input name="group_founder_manage" type="checkbox" class="radio" id="group_founder_manage"<?php echo (isset($this->_rootref['GROUP_FOUNDER_MANAGE'])) ? $this->_rootref['GROUP_FOUNDER_MANAGE'] : ''; ?> /></dd>
	</dl>
	<?php } ?>
	<dl>
		<dt><label for="group_legend"><?php echo ((isset($this->_rootref['L_GROUP_LEGEND'])) ? $this->_rootref['L_GROUP_LEGEND'] : ((isset($user->lang['GROUP_LEGEND'])) ? $user->lang['GROUP_LEGEND'] : '{ GROUP_LEGEND }')); ?>:</label></dt>
		<dd><input name="group_legend" type="checkbox" class="radio" id="group_legend"<?php echo (isset($this->_rootref['GROUP_LEGEND'])) ? $this->_rootref['GROUP_LEGEND'] : ''; ?> /></dd>
	</dl>
	<dl>
		<dt><label for="group_receive_pm"><?php echo ((isset($this->_rootref['L_GROUP_RECEIVE_PM'])) ? $this->_rootref['L_GROUP_RECEIVE_PM'] : ((isset($user->lang['GROUP_RECEIVE_PM'])) ? $user->lang['GROUP_RECEIVE_PM'] : '{ GROUP_RECEIVE_PM }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_GROUP_RECEIVE_PM_EXPLAIN'])) ? $this->_rootref['L_GROUP_RECEIVE_PM_EXPLAIN'] : ((isset($user->lang['GROUP_RECEIVE_PM_EXPLAIN'])) ? $user->lang['GROUP_RECEIVE_PM_EXPLAIN'] : '{ GROUP_RECEIVE_PM_EXPLAIN }')); ?></span></dt>
		<dd><input name="group_receive_pm" type="checkbox" class="radio" id="group_receive_pm"<?php echo (isset($this->_rootref['GROUP_RECEIVE_PM'])) ? $this->_rootref['GROUP_RECEIVE_PM'] : ''; ?> /></dd>
	</dl>
	<dl>
		<dt><label for="group_message_limit"><?php echo ((isset($this->_rootref['L_GROUP_MESSAGE_LIMIT'])) ? $this->_rootref['L_GROUP_MESSAGE_LIMIT'] : ((isset($user->lang['GROUP_MESSAGE_LIMIT'])) ? $user->lang['GROUP_MESSAGE_LIMIT'] : '{ GROUP_MESSAGE_LIMIT }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_GROUP_MESSAGE_LIMIT_EXPLAIN'])) ? $this->_rootref['L_GROUP_MESSAGE_LIMIT_EXPLAIN'] : ((isset($user->lang['GROUP_MESSAGE_LIMIT_EXPLAIN'])) ? $user->lang['GROUP_MESSAGE_LIMIT_EXPLAIN'] : '{ GROUP_MESSAGE_LIMIT_EXPLAIN }')); ?></span></dt>
		<dd><input name="group_message_limit" type="text" id="group_message_limit" maxlength="4" size="4" value="<?php echo (isset($this->_rootref['GROUP_MESSAGE_LIMIT'])) ? $this->_rootref['GROUP_MESSAGE_LIMIT'] : ''; ?>" /></dd>
	</dl>
	<dl>
		<dt><label for="group_colour"><?php echo ((isset($this->_rootref['L_GROUP_COLOR'])) ? $this->_rootref['L_GROUP_COLOR'] : ((isset($user->lang['GROUP_COLOR'])) ? $user->lang['GROUP_COLOR'] : '{ GROUP_COLOR }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_GROUP_COLOR_EXPLAIN'])) ? $this->_rootref['L_GROUP_COLOR_EXPLAIN'] : ((isset($user->lang['GROUP_COLOR_EXPLAIN'])) ? $user->lang['GROUP_COLOR_EXPLAIN'] : '{ GROUP_COLOR_EXPLAIN }')); ?></span></dt>
		<dd><input name="group_colour" type="text" id="group_colour" value="<?php echo (isset($this->_rootref['GROUP_COLOUR'])) ? $this->_rootref['GROUP_COLOUR'] : ''; ?>" size="6" maxlength="6" />&nbsp;&nbsp;<span>[ <a href="<?php echo (isset($this->_rootref['U_SWATCH'])) ? $this->_rootref['U_SWATCH'] : ''; ?>" onclick="popup(this.href, 636, 150, '_swatch'); return false"><?php echo ((isset($this->_rootref['L_COLOUR_SWATCH'])) ? $this->_rootref['L_COLOUR_SWATCH'] : ((isset($user->lang['COLOUR_SWATCH'])) ? $user->lang['COLOUR_SWATCH'] : '{ COLOUR_SWATCH }')); ?></a> ]</span></dd>
	</dl>
	<dl>
		<dt><label for="group_rank"><?php echo ((isset($this->_rootref['L_GROUP_RANK'])) ? $this->_rootref['L_GROUP_RANK'] : ((isset($user->lang['GROUP_RANK'])) ? $user->lang['GROUP_RANK'] : '{ GROUP_RANK }')); ?>:</label></dt>
		<dd><select name="group_rank" id="group_rank"><?php echo (isset($this->_rootref['S_RANK_OPTIONS'])) ? $this->_rootref['S_RANK_OPTIONS'] : ''; ?></select></dd>
	</dl>
	</fieldset>

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_GROUP_AVATAR'])) ? $this->_rootref['L_GROUP_AVATAR'] : ((isset($user->lang['GROUP_AVATAR'])) ? $user->lang['GROUP_AVATAR'] : '{ GROUP_AVATAR }')); ?></legend>
	<dl>
		<dt><label><?php echo ((isset($this->_rootref['L_CURRENT_IMAGE'])) ? $this->_rootref['L_CURRENT_IMAGE'] : ((isset($user->lang['CURRENT_IMAGE'])) ? $user->lang['CURRENT_IMAGE'] : '{ CURRENT_IMAGE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_AVATAR_EXPLAIN'])) ? $this->_rootref['L_AVATAR_EXPLAIN'] : ((isset($user->lang['AVATAR_EXPLAIN'])) ? $user->lang['AVATAR_EXPLAIN'] : '{ AVATAR_EXPLAIN }')); ?></span></dt>
		<dd><?php echo (isset($this->_rootref['AVATAR_IMAGE'])) ? $this->_rootref['AVATAR_IMAGE'] : ''; ?></dd>
		<dd><label><input type="checkbox" class="radio" name="delete" /> <?php echo ((isset($this->_rootref['L_DELETE_AVATAR'])) ? $this->_rootref['L_DELETE_AVATAR'] : ((isset($user->lang['DELETE_AVATAR'])) ? $user->lang['DELETE_AVATAR'] : '{ DELETE_AVATAR }')); ?></label></dd>
	</dl>
	<?php if (! $this->_rootref['S_IN_AVATAR_GALLERY']) {  if ($this->_rootref['S_CAN_UPLOAD']) {  ?>
			<dl> 
				<dt><label for="uploadfile"><?php echo ((isset($this->_rootref['L_UPLOAD_AVATAR_FILE'])) ? $this->_rootref['L_UPLOAD_AVATAR_FILE'] : ((isset($user->lang['UPLOAD_AVATAR_FILE'])) ? $user->lang['UPLOAD_AVATAR_FILE'] : '{ UPLOAD_AVATAR_FILE }')); ?>:</label></dt>
				<dd><input type="file" id="uploadfile" name="uploadfile" /></dd>
			</dl>
			<dl>
				<dt><label for="uploadurl"><?php echo ((isset($this->_rootref['L_UPLOAD_AVATAR_URL'])) ? $this->_rootref['L_UPLOAD_AVATAR_URL'] : ((isset($user->lang['UPLOAD_AVATAR_URL'])) ? $user->lang['UPLOAD_AVATAR_URL'] : '{ UPLOAD_AVATAR_URL }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_UPLOAD_AVATAR_URL_EXPLAIN'])) ? $this->_rootref['L_UPLOAD_AVATAR_URL_EXPLAIN'] : ((isset($user->lang['UPLOAD_AVATAR_URL_EXPLAIN'])) ? $user->lang['UPLOAD_AVATAR_URL_EXPLAIN'] : '{ UPLOAD_AVATAR_URL_EXPLAIN }')); ?></span></dt>
				<dd><input name="uploadurl" type="text" id="uploadurl" value="" /></dd>
			</dl>
		<?php } ?>
		<dl>
			<dt><label for="remotelink"><?php echo ((isset($this->_rootref['L_LINK_REMOTE_AVATAR'])) ? $this->_rootref['L_LINK_REMOTE_AVATAR'] : ((isset($user->lang['LINK_REMOTE_AVATAR'])) ? $user->lang['LINK_REMOTE_AVATAR'] : '{ LINK_REMOTE_AVATAR }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_LINK_REMOTE_AVATAR_EXPLAIN'])) ? $this->_rootref['L_LINK_REMOTE_AVATAR_EXPLAIN'] : ((isset($user->lang['LINK_REMOTE_AVATAR_EXPLAIN'])) ? $user->lang['LINK_REMOTE_AVATAR_EXPLAIN'] : '{ LINK_REMOTE_AVATAR_EXPLAIN }')); ?></span></dt>
			<dd><input name="remotelink" type="text" id="remotelink" value="" /></dd>
		</dl>
		<dl>
			<dt><label for="width"><?php echo ((isset($this->_rootref['L_LINK_REMOTE_SIZE'])) ? $this->_rootref['L_LINK_REMOTE_SIZE'] : ((isset($user->lang['LINK_REMOTE_SIZE'])) ? $user->lang['LINK_REMOTE_SIZE'] : '{ LINK_REMOTE_SIZE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_LINK_REMOTE_SIZE_EXPLAIN'])) ? $this->_rootref['L_LINK_REMOTE_SIZE_EXPLAIN'] : ((isset($user->lang['LINK_REMOTE_SIZE_EXPLAIN'])) ? $user->lang['LINK_REMOTE_SIZE_EXPLAIN'] : '{ LINK_REMOTE_SIZE_EXPLAIN }')); ?></span></dt>
			<dd><input name="width" type="text" id="width" size="3" value="<?php echo (isset($this->_rootref['AVATAR_WIDTH'])) ? $this->_rootref['AVATAR_WIDTH'] : ''; ?>" /> <span>px X </span> <input type="text" name="height" size="3" value="<?php echo (isset($this->_rootref['AVATAR_HEIGHT'])) ? $this->_rootref['AVATAR_HEIGHT'] : ''; ?>" /> <span>px</span></dd>
		</dl>
		<?php if ($this->_rootref['S_DISPLAY_GALLERY']) {  ?>
			<dl> 
				<dt><label><?php echo ((isset($this->_rootref['L_AVATAR_GALLERY'])) ? $this->_rootref['L_AVATAR_GALLERY'] : ((isset($user->lang['AVATAR_GALLERY'])) ? $user->lang['AVATAR_GALLERY'] : '{ AVATAR_GALLERY }')); ?>:</label></dt>
				<dd><input class="button2" type="submit" name="display_gallery" value="<?php echo ((isset($this->_rootref['L_DISPLAY_GALLERY'])) ? $this->_rootref['L_DISPLAY_GALLERY'] : ((isset($user->lang['DISPLAY_GALLERY'])) ? $user->lang['DISPLAY_GALLERY'] : '{ DISPLAY_GALLERY }')); ?>" /></dd>
			</dl>
		<?php } } else { ?>
		</fieldset>

		<fieldset>
			<legend><?php echo ((isset($this->_rootref['L_AVATAR_GALLERY'])) ? $this->_rootref['L_AVATAR_GALLERY'] : ((isset($user->lang['AVATAR_GALLERY'])) ? $user->lang['AVATAR_GALLERY'] : '{ AVATAR_GALLERY }')); ?></legend>
		<dl>
			<dt><label for="category"><?php echo ((isset($this->_rootref['L_AVATAR_CATEGORY'])) ? $this->_rootref['L_AVATAR_CATEGORY'] : ((isset($user->lang['AVATAR_CATEGORY'])) ? $user->lang['AVATAR_CATEGORY'] : '{ AVATAR_CATEGORY }')); ?>:</label></dt>
			<dd><select name="category" id="category"><?php echo (isset($this->_rootref['S_CAT_OPTIONS'])) ? $this->_rootref['S_CAT_OPTIONS'] : ''; ?></select>&nbsp;<input class="button2" type="submit" value="<?php echo ((isset($this->_rootref['L_GO'])) ? $this->_rootref['L_GO'] : ((isset($user->lang['GO'])) ? $user->lang['GO'] : '{ GO }')); ?>" name="display_gallery" /></dd>
		</dl>
		<dl>
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
		</dl>
		</fieldset>
		
		<fieldset class="quick" style="margin-top: -15px;">
			<input class="button2" type="submit" name="cancel" value="<?php echo ((isset($this->_rootref['L_CANCEL'])) ? $this->_rootref['L_CANCEL'] : ((isset($user->lang['CANCEL'])) ? $user->lang['CANCEL'] : '{ CANCEL }')); ?>" />
		</fieldset>
	
	<?php } ?>
	</fieldset>

	<fieldset class="submit-buttons">
		<legend><?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?></legend>
		<input class="button1" type="submit" id="submit" name="update" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />&nbsp;
		<input class="button2" type="reset" id="reset" name="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" />
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
	</form>

<?php } else if ($this->_rootref['S_LIST']) {  ?>

	<a href="<?php echo (isset($this->_rootref['U_BACK'])) ? $this->_rootref['U_BACK'] : ''; ?>" style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>;">&laquo; <?php echo ((isset($this->_rootref['L_BACK'])) ? $this->_rootref['L_BACK'] : ((isset($user->lang['BACK'])) ? $user->lang['BACK'] : '{ BACK }')); ?></a>

	<h1><?php echo ((isset($this->_rootref['L_GROUP_MEMBERS'])) ? $this->_rootref['L_GROUP_MEMBERS'] : ((isset($user->lang['GROUP_MEMBERS'])) ? $user->lang['GROUP_MEMBERS'] : '{ GROUP_MEMBERS }')); ?> :: <?php echo (isset($this->_rootref['GROUP_NAME'])) ? $this->_rootref['GROUP_NAME'] : ''; ?></h1>

	<p><?php echo ((isset($this->_rootref['L_GROUP_MEMBERS_EXPLAIN'])) ? $this->_rootref['L_GROUP_MEMBERS_EXPLAIN'] : ((isset($user->lang['GROUP_MEMBERS_EXPLAIN'])) ? $user->lang['GROUP_MEMBERS_EXPLAIN'] : '{ GROUP_MEMBERS_EXPLAIN }')); ?></p>

	<form id="list" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

	<fieldset class="quick">
		<a href="<?php echo (isset($this->_rootref['U_DEFAULT_ALL'])) ? $this->_rootref['U_DEFAULT_ALL'] : ''; ?>">&raquo; <?php echo ((isset($this->_rootref['L_MAKE_DEFAULT_FOR_ALL'])) ? $this->_rootref['L_MAKE_DEFAULT_FOR_ALL'] : ((isset($user->lang['MAKE_DEFAULT_FOR_ALL'])) ? $user->lang['MAKE_DEFAULT_FOR_ALL'] : '{ MAKE_DEFAULT_FOR_ALL }')); ?></a>
	</fieldset>

	<table cellspacing="1">
	<thead>
	<tr>
		<th><?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_GROUP_DEFAULT'])) ? $this->_rootref['L_GROUP_DEFAULT'] : ((isset($user->lang['GROUP_DEFAULT'])) ? $user->lang['GROUP_DEFAULT'] : '{ GROUP_DEFAULT }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_JOINED'])) ? $this->_rootref['L_JOINED'] : ((isset($user->lang['JOINED'])) ? $user->lang['JOINED'] : '{ JOINED }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_POSTS'])) ? $this->_rootref['L_POSTS'] : ((isset($user->lang['POSTS'])) ? $user->lang['POSTS'] : '{ POSTS }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_MARK'])) ? $this->_rootref['L_MARK'] : ((isset($user->lang['MARK'])) ? $user->lang['MARK'] : '{ MARK }')); ?></th>
	</tr>
	</thead>
	<tbody>
	<tr>
		<td class="row3" colspan="5"><strong><?php echo ((isset($this->_rootref['L_GROUP_LEAD'])) ? $this->_rootref['L_GROUP_LEAD'] : ((isset($user->lang['GROUP_LEAD'])) ? $user->lang['GROUP_LEAD'] : '{ GROUP_LEAD }')); ?></strong></td>
	</tr>
	<?php $_leader_count = (isset($this->_tpldata['leader'])) ? sizeof($this->_tpldata['leader']) : 0;if ($_leader_count) {for ($_leader_i = 0; $_leader_i < $_leader_count; ++$_leader_i){$_leader_val = &$this->_tpldata['leader'][$_leader_i]; if (!($_leader_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>
			<td><a href="<?php echo $_leader_val['U_USER_EDIT']; ?>"><?php echo $_leader_val['USERNAME']; ?></a></td>
			<td style="text-align: center;"><?php if ($_leader_val['S_GROUP_DEFAULT']) {  echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); } else { echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); } ?></td>
			<td style="text-align: center;"><?php echo $_leader_val['JOINED']; ?></td>
			<td style="text-align: center;"><?php echo $_leader_val['USER_POSTS']; ?></td>
			<td style="text-align: center;"><input type="checkbox" class="radio" name="mark[]" value="<?php echo $_leader_val['USER_ID']; ?>" /></td>
		</tr>
	<?php }} else { ?>
		<tr>
			<td class="row1" colspan="5" style="text-align: center;"><?php echo ((isset($this->_rootref['L_GROUPS_NO_MODS'])) ? $this->_rootref['L_GROUPS_NO_MODS'] : ((isset($user->lang['GROUPS_NO_MODS'])) ? $user->lang['GROUPS_NO_MODS'] : '{ GROUPS_NO_MODS }')); ?></td>
		</tr>
	<?php } ?>
	<tr>
		<td class="row3" colspan="5"><strong><?php echo ((isset($this->_rootref['L_GROUP_APPROVED'])) ? $this->_rootref['L_GROUP_APPROVED'] : ((isset($user->lang['GROUP_APPROVED'])) ? $user->lang['GROUP_APPROVED'] : '{ GROUP_APPROVED }')); ?></strong></td>
	</tr>
	<?php $_member_count = (isset($this->_tpldata['member'])) ? sizeof($this->_tpldata['member']) : 0;if ($_member_count) {for ($_member_i = 0; $_member_i < $_member_count; ++$_member_i){$_member_val = &$this->_tpldata['member'][$_member_i]; if ($_member_val['S_PENDING']) {  ?>
		<tr>
			<td class="row3" colspan="5"><strong><?php echo ((isset($this->_rootref['L_GROUP_PENDING'])) ? $this->_rootref['L_GROUP_PENDING'] : ((isset($user->lang['GROUP_PENDING'])) ? $user->lang['GROUP_PENDING'] : '{ GROUP_PENDING }')); ?></strong></td>
		</tr>
		<?php } else { if (!($_member_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>
			<td><a href="<?php echo $_member_val['U_USER_EDIT']; ?>"><?php echo $_member_val['USERNAME']; ?></a></td>
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
	</tbody>
	</table>
	<?php if ($this->_rootref['PAGINATION']) {  ?>
	<div class="pagination">
			<a href="#" onclick="jumpto(); return false;" title="<?php echo ((isset($this->_rootref['L_JUMP_TO_PAGE'])) ? $this->_rootref['L_JUMP_TO_PAGE'] : ((isset($user->lang['JUMP_TO_PAGE'])) ? $user->lang['JUMP_TO_PAGE'] : '{ JUMP_TO_PAGE }')); ?>"><?php echo (isset($this->_rootref['S_ON_PAGE'])) ? $this->_rootref['S_ON_PAGE'] : ''; ?></a> &bull; <span><?php echo (isset($this->_rootref['PAGINATION'])) ? $this->_rootref['PAGINATION'] : ''; ?></span>
	</div>
	<?php } ?>	

	<fieldset class="quick">
		<select name="action"><option class="sep" value=""><?php echo ((isset($this->_rootref['L_SELECT_OPTION'])) ? $this->_rootref['L_SELECT_OPTION'] : ((isset($user->lang['SELECT_OPTION'])) ? $user->lang['SELECT_OPTION'] : '{ SELECT_OPTION }')); ?></option><?php echo (isset($this->_rootref['S_ACTION_OPTIONS'])) ? $this->_rootref['S_ACTION_OPTIONS'] : ''; ?></select>
		<input class="button2" type="submit" name="update" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />
		<p class="small"><a href="#" onclick="marklist('list', 'mark', true); return false;"><?php echo ((isset($this->_rootref['L_MARK_ALL'])) ? $this->_rootref['L_MARK_ALL'] : ((isset($user->lang['MARK_ALL'])) ? $user->lang['MARK_ALL'] : '{ MARK_ALL }')); ?></a> &bull; <a href="#" onclick="marklist('list', 'mark', false); return false;"><?php echo ((isset($this->_rootref['L_UNMARK_ALL'])) ? $this->_rootref['L_UNMARK_ALL'] : ((isset($user->lang['UNMARK_ALL'])) ? $user->lang['UNMARK_ALL'] : '{ UNMARK_ALL }')); ?></a></p>		
	</fieldset>

	<h1><?php echo ((isset($this->_rootref['L_ADD_USERS'])) ? $this->_rootref['L_ADD_USERS'] : ((isset($user->lang['ADD_USERS'])) ? $user->lang['ADD_USERS'] : '{ ADD_USERS }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_ADD_USERS_EXPLAIN'])) ? $this->_rootref['L_ADD_USERS_EXPLAIN'] : ((isset($user->lang['ADD_USERS_EXPLAIN'])) ? $user->lang['ADD_USERS_EXPLAIN'] : '{ ADD_USERS_EXPLAIN }')); ?></p>

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_ADD_USERS'])) ? $this->_rootref['L_ADD_USERS'] : ((isset($user->lang['ADD_USERS'])) ? $user->lang['ADD_USERS'] : '{ ADD_USERS }')); ?></legend>
	<dl>
		<dt><label for="leader"><?php echo ((isset($this->_rootref['L_USER_GROUP_LEADER'])) ? $this->_rootref['L_USER_GROUP_LEADER'] : ((isset($user->lang['USER_GROUP_LEADER'])) ? $user->lang['USER_GROUP_LEADER'] : '{ USER_GROUP_LEADER }')); ?>:</label></dt>
		<dd><label><input name="leader" type="radio" class="radio" value="1" /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input name="leader" type="radio" class="radio" id="leader" value="0" checked="checked" /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<dl>
		<dt><label for="default"><?php echo ((isset($this->_rootref['L_USER_GROUP_DEFAULT'])) ? $this->_rootref['L_USER_GROUP_DEFAULT'] : ((isset($user->lang['USER_GROUP_DEFAULT'])) ? $user->lang['USER_GROUP_DEFAULT'] : '{ USER_GROUP_DEFAULT }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_USER_GROUP_DEFAULT_EXPLAIN'])) ? $this->_rootref['L_USER_GROUP_DEFAULT_EXPLAIN'] : ((isset($user->lang['USER_GROUP_DEFAULT_EXPLAIN'])) ? $user->lang['USER_GROUP_DEFAULT_EXPLAIN'] : '{ USER_GROUP_DEFAULT_EXPLAIN }')); ?></span></dt>
		<dd><label><input name="default" type="radio" class="radio" value="1" /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input name="default" type="radio" class="radio" id="default" value="0" checked="checked" /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<dl>
		<dt><label for="usernames"><?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_USERNAMES_EXPLAIN'])) ? $this->_rootref['L_USERNAMES_EXPLAIN'] : ((isset($user->lang['USERNAMES_EXPLAIN'])) ? $user->lang['USERNAMES_EXPLAIN'] : '{ USERNAMES_EXPLAIN }')); ?></span></dt>
		<dd><textarea id="usernames" name="usernames" cols="40" rows="5"></textarea></dd>
		<dd>[ <a href="<?php echo (isset($this->_rootref['U_FIND_USERNAME'])) ? $this->_rootref['U_FIND_USERNAME'] : ''; ?>" onclick="find_username(this.href); return false;"><?php echo ((isset($this->_rootref['L_FIND_USERNAME'])) ? $this->_rootref['L_FIND_USERNAME'] : ((isset($user->lang['FIND_USERNAME'])) ? $user->lang['FIND_USERNAME'] : '{ FIND_USERNAME }')); ?></a> ]</dd>
	</dl>

	<p class="quick">
		<input class="button2" type="submit" name="addusers" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />
	</p>
	<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
	</form>

<?php } else { ?>

	<h1><?php echo ((isset($this->_rootref['L_ACP_GROUPS_MANAGE'])) ? $this->_rootref['L_ACP_GROUPS_MANAGE'] : ((isset($user->lang['ACP_GROUPS_MANAGE'])) ? $user->lang['ACP_GROUPS_MANAGE'] : '{ ACP_GROUPS_MANAGE }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_ACP_GROUPS_MANAGE_EXPLAIN'])) ? $this->_rootref['L_ACP_GROUPS_MANAGE_EXPLAIN'] : ((isset($user->lang['ACP_GROUPS_MANAGE_EXPLAIN'])) ? $user->lang['ACP_GROUPS_MANAGE_EXPLAIN'] : '{ ACP_GROUPS_MANAGE_EXPLAIN }')); ?></p>

	<?php if ($this->_rootref['S_ERROR']) {  ?>
		<div class="errorbox">
			<h3><?php echo ((isset($this->_rootref['L_WARNING'])) ? $this->_rootref['L_WARNING'] : ((isset($user->lang['WARNING'])) ? $user->lang['WARNING'] : '{ WARNING }')); ?></h3>
			<p><?php echo (isset($this->_rootref['ERROR_MSG'])) ? $this->_rootref['ERROR_MSG'] : ''; ?></p>
		</div>
	<?php } ?>

	<h1><?php echo ((isset($this->_rootref['L_USER_DEF_GROUPS'])) ? $this->_rootref['L_USER_DEF_GROUPS'] : ((isset($user->lang['USER_DEF_GROUPS'])) ? $user->lang['USER_DEF_GROUPS'] : '{ USER_DEF_GROUPS }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_USER_DEF_GROUPS_EXPLAIN'])) ? $this->_rootref['L_USER_DEF_GROUPS_EXPLAIN'] : ((isset($user->lang['USER_DEF_GROUPS_EXPLAIN'])) ? $user->lang['USER_DEF_GROUPS_EXPLAIN'] : '{ USER_DEF_GROUPS_EXPLAIN }')); ?></p>

	<form id="acp_groups" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

	<table cellspacing="1">
		<col class="col1" /><col class="col1" /><col class="col2" /><col class="col2" /><col class="col2" />
	<thead>
	<tr>
		<th style="width: 50%"><?php echo ((isset($this->_rootref['L_GROUP'])) ? $this->_rootref['L_GROUP'] : ((isset($user->lang['GROUP'])) ? $user->lang['GROUP'] : '{ GROUP }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_TOTAL_MEMBERS'])) ? $this->_rootref['L_TOTAL_MEMBERS'] : ((isset($user->lang['TOTAL_MEMBERS'])) ? $user->lang['TOTAL_MEMBERS'] : '{ TOTAL_MEMBERS }')); ?></th>
		<th colspan="2"><?php echo ((isset($this->_rootref['L_OPTIONS'])) ? $this->_rootref['L_OPTIONS'] : ((isset($user->lang['OPTIONS'])) ? $user->lang['OPTIONS'] : '{ OPTIONS }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_ACTION'])) ? $this->_rootref['L_ACTION'] : ((isset($user->lang['ACTION'])) ? $user->lang['ACTION'] : '{ ACTION }')); ?></th>
	</tr>
	</thead>
	<tbody>
	<?php $_groups_count = (isset($this->_tpldata['groups'])) ? sizeof($this->_tpldata['groups']) : 0;if ($_groups_count) {for ($_groups_i = 0; $_groups_i < $_groups_count; ++$_groups_i){$_groups_val = &$this->_tpldata['groups'][$_groups_i]; if ($_groups_val['S_SPECIAL']) {  if ($_groups_val['S_FIRST_ROW']) {  ?>
			<tr>
				<td colspan="5" class="row3"><?php echo ((isset($this->_rootref['L_NO_GROUPS_CREATED'])) ? $this->_rootref['L_NO_GROUPS_CREATED'] : ((isset($user->lang['NO_GROUPS_CREATED'])) ? $user->lang['NO_GROUPS_CREATED'] : '{ NO_GROUPS_CREATED }')); ?></td>
			</tr>
		<?php } ?>
	</tbody>
	</table>

	<fieldset class="quick">
		<?php if ($this->_rootref['S_GROUP_ADD']) {  ?>
			<?php echo ((isset($this->_rootref['L_CREATE_GROUP'])) ? $this->_rootref['L_CREATE_GROUP'] : ((isset($user->lang['CREATE_GROUP'])) ? $user->lang['CREATE_GROUP'] : '{ CREATE_GROUP }')); ?>: <input type="text" name="group_name" value="" /> <input class="button2" type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />
			<input type="hidden" name="add" value="1" />
		<?php } ?>
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
	</form>

	<h1><?php echo ((isset($this->_rootref['L_SPECIAL_GROUPS'])) ? $this->_rootref['L_SPECIAL_GROUPS'] : ((isset($user->lang['SPECIAL_GROUPS'])) ? $user->lang['SPECIAL_GROUPS'] : '{ SPECIAL_GROUPS }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_SPECIAL_GROUPS_EXPLAIN'])) ? $this->_rootref['L_SPECIAL_GROUPS_EXPLAIN'] : ((isset($user->lang['SPECIAL_GROUPS_EXPLAIN'])) ? $user->lang['SPECIAL_GROUPS_EXPLAIN'] : '{ SPECIAL_GROUPS_EXPLAIN }')); ?></p>

	<table cellspacing="1">
		<col class="col1" /><col class="col1" /><col class="col2" /><col class="col2" /><col class="col2" />
	<thead>
	<tr>
		<th style="width: 50%"><?php echo ((isset($this->_rootref['L_GROUP'])) ? $this->_rootref['L_GROUP'] : ((isset($user->lang['GROUP'])) ? $user->lang['GROUP'] : '{ GROUP }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_TOTAL_MEMBERS'])) ? $this->_rootref['L_TOTAL_MEMBERS'] : ((isset($user->lang['TOTAL_MEMBERS'])) ? $user->lang['TOTAL_MEMBERS'] : '{ TOTAL_MEMBERS }')); ?></th>
		<th colspan="2"><?php echo ((isset($this->_rootref['L_OPTIONS'])) ? $this->_rootref['L_OPTIONS'] : ((isset($user->lang['OPTIONS'])) ? $user->lang['OPTIONS'] : '{ OPTIONS }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_ACTION'])) ? $this->_rootref['L_ACTION'] : ((isset($user->lang['ACTION'])) ? $user->lang['ACTION'] : '{ ACTION }')); ?></th>
	</tr>
	</thead>
	<tbody>
		<?php } else { ?>
		<tr>
			<td><strong><?php echo $_groups_val['GROUP_NAME']; ?></strong></td>
			<td style="text-align: center;"><?php echo $_groups_val['TOTAL_MEMBERS']; ?></td>
			<td style="text-align: center;"><a href="<?php echo $_groups_val['U_EDIT']; ?>"><?php echo ((isset($this->_rootref['L_SETTINGS'])) ? $this->_rootref['L_SETTINGS'] : ((isset($user->lang['SETTINGS'])) ? $user->lang['SETTINGS'] : '{ SETTINGS }')); ?></a></td>
			<td style="text-align: center;"><a href="<?php echo $_groups_val['U_LIST']; ?>"><?php echo ((isset($this->_rootref['L_MEMBERS'])) ? $this->_rootref['L_MEMBERS'] : ((isset($user->lang['MEMBERS'])) ? $user->lang['MEMBERS'] : '{ MEMBERS }')); ?></a></td>
			<td style="text-align: center;"><?php if (! $_groups_val['S_GROUP_SPECIAL'] && $_groups_val['U_DELETE']) {  ?><a href="<?php echo $_groups_val['U_DELETE']; ?>"><?php echo ((isset($this->_rootref['L_DELETE'])) ? $this->_rootref['L_DELETE'] : ((isset($user->lang['DELETE'])) ? $user->lang['DELETE'] : '{ DELETE }')); ?></a><?php } else { echo ((isset($this->_rootref['L_DELETE'])) ? $this->_rootref['L_DELETE'] : ((isset($user->lang['DELETE'])) ? $user->lang['DELETE'] : '{ DELETE }')); } ?></td>
		</tr>
		<?php } }} ?>
	</tbody>
	</table>

<?php } $this->_tpl_include('overall_footer.html'); ?>
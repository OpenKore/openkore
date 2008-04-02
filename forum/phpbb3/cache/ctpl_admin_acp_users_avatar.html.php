<form id="avatar_settings" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>"<?php if ($this->_rootref['S_CAN_UPLOAD']) {  ?> enctype="multipart/form-data"<?php } ?>>

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_ACP_USER_AVATAR'])) ? $this->_rootref['L_ACP_USER_AVATAR'] : ((isset($user->lang['ACP_USER_AVATAR'])) ? $user->lang['ACP_USER_AVATAR'] : '{ ACP_USER_AVATAR }')); ?></legend>
	<dl>
		<dt><label><?php echo ((isset($this->_rootref['L_CURRENT_IMAGE'])) ? $this->_rootref['L_CURRENT_IMAGE'] : ((isset($user->lang['CURRENT_IMAGE'])) ? $user->lang['CURRENT_IMAGE'] : '{ CURRENT_IMAGE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_AVATAR_EXPLAIN'])) ? $this->_rootref['L_AVATAR_EXPLAIN'] : ((isset($user->lang['AVATAR_EXPLAIN'])) ? $user->lang['AVATAR_EXPLAIN'] : '{ AVATAR_EXPLAIN }')); ?></span></dt>
		<dd><?php echo (isset($this->_rootref['AVATAR_IMAGE'])) ? $this->_rootref['AVATAR_IMAGE'] : ''; ?></dd>
		<dd><label><input type="checkbox" class="radio" name="delete" /> <?php echo ((isset($this->_rootref['L_DELETE_AVATAR'])) ? $this->_rootref['L_DELETE_AVATAR'] : ((isset($user->lang['DELETE_AVATAR'])) ? $user->lang['DELETE_AVATAR'] : '{ DELETE_AVATAR }')); ?></label></dd>
	</dl>
	<?php if (! $this->_rootref['S_IN_AVATAR_GALLERY']) {  if ($this->_rootref['S_CAN_UPLOAD']) {  ?>
			<dl> 
				<dt><label for="uploadfile"><?php echo ((isset($this->_rootref['L_UPLOAD_AVATAR_FILE'])) ? $this->_rootref['L_UPLOAD_AVATAR_FILE'] : ((isset($user->lang['UPLOAD_AVATAR_FILE'])) ? $user->lang['UPLOAD_AVATAR_FILE'] : '{ UPLOAD_AVATAR_FILE }')); ?>:</label></dt>
				<dd><input type="hidden" name="MAX_FILE_SIZE" value="<?php echo (isset($this->_rootref['AVATAR_MAX_FILESIZE'])) ? $this->_rootref['AVATAR_MAX_FILESIZE'] : ''; ?>" /><input type="file" id="uploadfile" name="uploadfile" /></dd>
			</dl>
			<dl>
				<dt><label for="uploadurl"><?php echo ((isset($this->_rootref['L_UPLOAD_AVATAR_URL'])) ? $this->_rootref['L_UPLOAD_AVATAR_URL'] : ((isset($user->lang['UPLOAD_AVATAR_URL'])) ? $user->lang['UPLOAD_AVATAR_URL'] : '{ UPLOAD_AVATAR_URL }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_UPLOAD_AVATAR_URL_EXPLAIN'])) ? $this->_rootref['L_UPLOAD_AVATAR_URL_EXPLAIN'] : ((isset($user->lang['UPLOAD_AVATAR_URL_EXPLAIN'])) ? $user->lang['UPLOAD_AVATAR_URL_EXPLAIN'] : '{ UPLOAD_AVATAR_URL_EXPLAIN }')); ?></span></dt>
				<dd><input name="uploadurl" type="text" id="uploadurl" value="" /></dd>
			</dl>
		<?php } if ($this->_rootref['S_ALLOW_REMOTE']) {  ?>
			<dl>
				<dt><label for="remotelink"><?php echo ((isset($this->_rootref['L_LINK_REMOTE_AVATAR'])) ? $this->_rootref['L_LINK_REMOTE_AVATAR'] : ((isset($user->lang['LINK_REMOTE_AVATAR'])) ? $user->lang['LINK_REMOTE_AVATAR'] : '{ LINK_REMOTE_AVATAR }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_LINK_REMOTE_AVATAR_EXPLAIN'])) ? $this->_rootref['L_LINK_REMOTE_AVATAR_EXPLAIN'] : ((isset($user->lang['LINK_REMOTE_AVATAR_EXPLAIN'])) ? $user->lang['LINK_REMOTE_AVATAR_EXPLAIN'] : '{ LINK_REMOTE_AVATAR_EXPLAIN }')); ?></span></dt>
				<dd><input name="remotelink" type="text" id="remotelink" value="" /></dd>
			</dl>
			<dl>
				<dt><label for="width"><?php echo ((isset($this->_rootref['L_LINK_REMOTE_SIZE'])) ? $this->_rootref['L_LINK_REMOTE_SIZE'] : ((isset($user->lang['LINK_REMOTE_SIZE'])) ? $user->lang['LINK_REMOTE_SIZE'] : '{ LINK_REMOTE_SIZE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_LINK_REMOTE_SIZE_EXPLAIN'])) ? $this->_rootref['L_LINK_REMOTE_SIZE_EXPLAIN'] : ((isset($user->lang['LINK_REMOTE_SIZE_EXPLAIN'])) ? $user->lang['LINK_REMOTE_SIZE_EXPLAIN'] : '{ LINK_REMOTE_SIZE_EXPLAIN }')); ?></span></dt>
				<dd><input name="width" type="text" id="width" size="3" value="<?php echo (isset($this->_rootref['USER_AVATAR_WIDTH'])) ? $this->_rootref['USER_AVATAR_WIDTH'] : ''; ?>" /> <span>px X </span> <input type="text" name="height" size="3" value="<?php echo (isset($this->_rootref['USER_AVATAR_HEIGHT'])) ? $this->_rootref['USER_AVATAR_HEIGHT'] : ''; ?>" /> <span>px</span></dd>
			</dl>
		<?php } if ($this->_rootref['S_DISPLAY_GALLERY']) {  ?>
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

	<fieldset class="quick">
		<input class="button1" type="submit" name="update" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
	
	</form>
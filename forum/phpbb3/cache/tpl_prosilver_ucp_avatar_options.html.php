<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>
	<?php if (! $this->_rootref['S_AVATARS_ENABLED']) {  ?>
		<p><?php echo ((isset($this->_rootref['L_AVATAR_FEATURES_DISABLED'])) ? $this->_rootref['L_AVATAR_FEATURES_DISABLED'] : ((isset($user->lang['AVATAR_FEATURES_DISABLED'])) ? $user->lang['AVATAR_FEATURES_DISABLED'] : '{ AVATAR_FEATURES_DISABLED }')); ?></p>
	<?php } ?>

	<fieldset>
	<?php if ($this->_rootref['ERROR']) {  ?><p class="error"><?php echo (isset($this->_rootref['ERROR'])) ? $this->_rootref['ERROR'] : ''; ?></p><?php } ?>
	<dl>
		<dt><label><?php echo ((isset($this->_rootref['L_CURRENT_IMAGE'])) ? $this->_rootref['L_CURRENT_IMAGE'] : ((isset($user->lang['CURRENT_IMAGE'])) ? $user->lang['CURRENT_IMAGE'] : '{ CURRENT_IMAGE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_AVATAR_EXPLAIN'])) ? $this->_rootref['L_AVATAR_EXPLAIN'] : ((isset($user->lang['AVATAR_EXPLAIN'])) ? $user->lang['AVATAR_EXPLAIN'] : '{ AVATAR_EXPLAIN }')); ?></span></dt>
		<dd><?php if ($this->_rootref['AVATAR']) {  echo (isset($this->_rootref['AVATAR'])) ? $this->_rootref['AVATAR'] : ''; } else { ?><img src="<?php echo (isset($this->_rootref['T_THEME_PATH'])) ? $this->_rootref['T_THEME_PATH'] : ''; ?>/images/no_avatar.gif" alt="" /><?php } ?></dd>
		<dd><label for="delete"><input type="checkbox" name="delete" id="delete" /> <?php echo ((isset($this->_rootref['L_DELETE_AVATAR'])) ? $this->_rootref['L_DELETE_AVATAR'] : ((isset($user->lang['DELETE_AVATAR'])) ? $user->lang['DELETE_AVATAR'] : '{ DELETE_AVATAR }')); ?></label></dd>
	</dl>

	<?php if ($this->_rootref['S_UPLOAD_AVATAR_FILE'] || $this->_rootref['S_CAN_UPLOAD']) {  ?>
		<dl>
			<dt><label for="uploadfile"><?php echo ((isset($this->_rootref['L_UPLOAD_AVATAR_FILE'])) ? $this->_rootref['L_UPLOAD_AVATAR_FILE'] : ((isset($user->lang['UPLOAD_AVATAR_FILE'])) ? $user->lang['UPLOAD_AVATAR_FILE'] : '{ UPLOAD_AVATAR_FILE }')); ?>:</label></dt>
			<dd><input type="hidden" name="MAX_FILE_SIZE" value="<?php echo (isset($this->_rootref['AVATAR_SIZE'])) ? $this->_rootref['AVATAR_SIZE'] : ''; ?>" /><input type="file" name="uploadfile" id="uploadfile" class="inputbox autowidth" /></dd>
		</dl>
	<?php } if ($this->_rootref['S_UPLOAD_AVATAR_URL'] || $this->_rootref['S_EDIT']) {  ?>
		<dl>
			<dt><label for="uploadurl"><?php echo ((isset($this->_rootref['L_UPLOAD_AVATAR_URL'])) ? $this->_rootref['L_UPLOAD_AVATAR_URL'] : ((isset($user->lang['UPLOAD_AVATAR_URL'])) ? $user->lang['UPLOAD_AVATAR_URL'] : '{ UPLOAD_AVATAR_URL }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_UPLOAD_AVATAR_URL_EXPLAIN'])) ? $this->_rootref['L_UPLOAD_AVATAR_URL_EXPLAIN'] : ((isset($user->lang['UPLOAD_AVATAR_URL_EXPLAIN'])) ? $user->lang['UPLOAD_AVATAR_URL_EXPLAIN'] : '{ UPLOAD_AVATAR_URL_EXPLAIN }')); ?></span></dt>
			<dd><input type="text" name="uploadurl" id="uploadurl" value="<?php echo (isset($this->_rootref['AVATAR_URL'])) ? $this->_rootref['AVATAR_URL'] : ''; ?>" class="inputbox" /></dd>
		</dl>
	<?php } if ($this->_rootref['S_LINK_AVATAR'] || $this->_rootref['S_EDIT']) {  ?>
		<dl>
			<dt><label for="remotelink"><?php echo ((isset($this->_rootref['L_LINK_REMOTE_AVATAR'])) ? $this->_rootref['L_LINK_REMOTE_AVATAR'] : ((isset($user->lang['LINK_REMOTE_AVATAR'])) ? $user->lang['LINK_REMOTE_AVATAR'] : '{ LINK_REMOTE_AVATAR }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_LINK_REMOTE_AVATAR_EXPLAIN'])) ? $this->_rootref['L_LINK_REMOTE_AVATAR_EXPLAIN'] : ((isset($user->lang['LINK_REMOTE_AVATAR_EXPLAIN'])) ? $user->lang['LINK_REMOTE_AVATAR_EXPLAIN'] : '{ LINK_REMOTE_AVATAR_EXPLAIN }')); ?></span></dt>
			<dd><input type="text" name="remotelink" id="remotelink" value="<?php echo (isset($this->_rootref['AVATAR_REMOTE'])) ? $this->_rootref['AVATAR_REMOTE'] : ''; ?>" class="inputbox" /></dd>
		</dl>
		<dl>
			<dt><label for="width"><?php echo ((isset($this->_rootref['L_LINK_REMOTE_SIZE'])) ? $this->_rootref['L_LINK_REMOTE_SIZE'] : ((isset($user->lang['LINK_REMOTE_SIZE'])) ? $user->lang['LINK_REMOTE_SIZE'] : '{ LINK_REMOTE_SIZE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_LINK_REMOTE_SIZE_EXPLAIN'])) ? $this->_rootref['L_LINK_REMOTE_SIZE_EXPLAIN'] : ((isset($user->lang['LINK_REMOTE_SIZE_EXPLAIN'])) ? $user->lang['LINK_REMOTE_SIZE_EXPLAIN'] : '{ LINK_REMOTE_SIZE_EXPLAIN }')); ?></span></dt>
			<dd>
				<label for="width"><input type="text" name="width" id="width" size="3" value="<?php echo (isset($this->_rootref['AVATAR_WIDTH'])) ? $this->_rootref['AVATAR_WIDTH'] : ''; ?>" class="inputbox autowidth" /> px</label> &times;&nbsp; 
				<label for="height"><input type="text" name="height" id="height" size="3" value="<?php echo (isset($this->_rootref['AVATAR_HEIGHT'])) ? $this->_rootref['AVATAR_HEIGHT'] : ''; ?>" class="inputbox autowidth" /> px</label>
			</dd>
		</dl>
	<?php } ?>
	</fieldset>
	
	<?php if ($this->_rootref['S_IN_AVATAR_GALLERY']) {  ?>
		<span class="corners-bottom"><span></span></span></div>
	</div>

	<div class="panel">
		<div class="inner"><span class="corners-top"><span></span></span>

		<h3><?php echo ((isset($this->_rootref['L_AVATAR_GALLERY'])) ? $this->_rootref['L_AVATAR_GALLERY'] : ((isset($user->lang['AVATAR_GALLERY'])) ? $user->lang['AVATAR_GALLERY'] : '{ AVATAR_GALLERY }')); ?></h3>
	
		<fieldset>
			<label for="category"><?php echo ((isset($this->_rootref['L_AVATAR_CATEGORY'])) ? $this->_rootref['L_AVATAR_CATEGORY'] : ((isset($user->lang['AVATAR_CATEGORY'])) ? $user->lang['AVATAR_CATEGORY'] : '{ AVATAR_CATEGORY }')); ?>: <select name="category" id="category"><?php echo (isset($this->_rootref['S_CAT_OPTIONS'])) ? $this->_rootref['S_CAT_OPTIONS'] : ''; ?></select></label>
			<input type="submit" value="<?php echo ((isset($this->_rootref['L_GO'])) ? $this->_rootref['L_GO'] : ((isset($user->lang['GO'])) ? $user->lang['GO'] : '{ GO }')); ?>" name="display_gallery" class="button2" />
			<input type="submit" name="cancel" value="<?php echo ((isset($this->_rootref['L_CANCEL'])) ? $this->_rootref['L_CANCEL'] : ((isset($user->lang['CANCEL'])) ? $user->lang['CANCEL'] : '{ CANCEL }')); ?>" class="button2" />
		</fieldset>

		<div id="gallery">
		<?php $_avatar_row_count = (isset($this->_tpldata['avatar_row'])) ? sizeof($this->_tpldata['avatar_row']) : 0;if ($_avatar_row_count) {for ($_avatar_row_i = 0; $_avatar_row_i < $_avatar_row_count; ++$_avatar_row_i){$_avatar_row_val = &$this->_tpldata['avatar_row'][$_avatar_row_i]; $_avatar_column_count = (isset($_avatar_row_val['avatar_column'])) ? sizeof($_avatar_row_val['avatar_column']) : 0;if ($_avatar_column_count) {for ($_avatar_column_i = 0; $_avatar_column_i < $_avatar_column_count; ++$_avatar_column_i){$_avatar_column_val = &$_avatar_row_val['avatar_column'][$_avatar_column_i]; ?>
			<label for="av-<?php echo $_avatar_row_val['S_ROW_COUNT']; ?>-<?php echo $_avatar_column_val['S_ROW_COUNT']; ?>"><img src="<?php echo $_avatar_column_val['AVATAR_IMAGE']; ?>" alt="" /><br />
				<input type="radio" name="avatar_select" id="av-<?php echo $_avatar_row_val['S_ROW_COUNT']; ?>-<?php echo $_avatar_column_val['S_ROW_COUNT']; ?>" value="<?php echo $_avatar_column_val['AVATAR_FILE']; ?>" /></label>
		<?php }} }} ?>
		</div>
	
	<?php } ?>

	<span class="corners-bottom"><span></span></span></div>
</div>
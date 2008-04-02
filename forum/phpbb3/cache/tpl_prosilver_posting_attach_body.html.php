<div class="panel bg3" id="attach-panel">
	<div class="inner"><span class="corners-top"><span></span></span>

	<p><?php echo ((isset($this->_rootref['L_ADD_ATTACHMENT_EXPLAIN'])) ? $this->_rootref['L_ADD_ATTACHMENT_EXPLAIN'] : ((isset($user->lang['ADD_ATTACHMENT_EXPLAIN'])) ? $user->lang['ADD_ATTACHMENT_EXPLAIN'] : '{ ADD_ATTACHMENT_EXPLAIN }')); ?></p>
	
	<fieldset class="fields2">
	<dl>
		<dt><label for="fileupload"><?php echo ((isset($this->_rootref['L_FILENAME'])) ? $this->_rootref['L_FILENAME'] : ((isset($user->lang['FILENAME'])) ? $user->lang['FILENAME'] : '{ FILENAME }')); ?>:</label></dt>
		<dd>
			<input type="file" name="fileupload" id="fileupload" maxlength="<?php echo (isset($this->_rootref['FILESIZE'])) ? $this->_rootref['FILESIZE'] : ''; ?>" value="" class="inputbox autowidth" /> 
			<input type="submit" name="add_file" value="<?php echo ((isset($this->_rootref['L_ADD_FILE'])) ? $this->_rootref['L_ADD_FILE'] : ((isset($user->lang['ADD_FILE'])) ? $user->lang['ADD_FILE'] : '{ ADD_FILE }')); ?>" class="button2" onclick="upload = true;" />
		</dd>
	</dl>
	<dl>
		<dt><label for="filecomment"><?php echo ((isset($this->_rootref['L_FILE_COMMENT'])) ? $this->_rootref['L_FILE_COMMENT'] : ((isset($user->lang['FILE_COMMENT'])) ? $user->lang['FILE_COMMENT'] : '{ FILE_COMMENT }')); ?>:</label></dt>
		<dd><textarea name="filecomment" id="filecomment" rows="1" cols="40" class="inputbox autowidth"><?php echo (isset($this->_rootref['FILE_COMMENT'])) ? $this->_rootref['FILE_COMMENT'] : ''; ?></textarea></dd>
	</dl>
	</fieldset>

	<span class="corners-bottom"><span></span></span></div>
</div>
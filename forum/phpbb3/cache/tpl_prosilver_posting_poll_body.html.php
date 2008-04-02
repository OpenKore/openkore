<div class="panel bg3" id="poll-panel">
	<div class="inner"><span class="corners-top"><span></span></span>

	<?php if ($this->_rootref['S_SHOW_POLL_BOX']) {  ?>
	<p><?php echo ((isset($this->_rootref['L_ADD_POLL_EXPLAIN'])) ? $this->_rootref['L_ADD_POLL_EXPLAIN'] : ((isset($user->lang['ADD_POLL_EXPLAIN'])) ? $user->lang['ADD_POLL_EXPLAIN'] : '{ ADD_POLL_EXPLAIN }')); ?></p>
	<?php } ?>

	<fieldset class="fields2">
	<?php if ($this->_rootref['S_SHOW_POLL_BOX']) {  if ($this->_rootref['S_POLL_DELETE']) {  ?>
			<dl>
				<dt><label for="poll_delete"><?php echo ((isset($this->_rootref['L_POLL_DELETE'])) ? $this->_rootref['L_POLL_DELETE'] : ((isset($user->lang['POLL_DELETE'])) ? $user->lang['POLL_DELETE'] : '{ POLL_DELETE }')); ?>:</label></dt>
				<dd><label for="poll_delete"><input type="checkbox" name="poll_delete" id="poll_delete"<?php if ($this->_rootref['S_POLL_DELETE_CHECKED']) {  ?> checked="checked"<?php } ?> /> </label></dd>
			</dl>
		<?php } ?>
		<dl>
			<dt><label for="poll_title"><?php echo ((isset($this->_rootref['L_POLL_QUESTION'])) ? $this->_rootref['L_POLL_QUESTION'] : ((isset($user->lang['POLL_QUESTION'])) ? $user->lang['POLL_QUESTION'] : '{ POLL_QUESTION }')); ?>:</label></dt>
			<dd><input type="text" name="poll_title" id="poll_title" maxlength="255" value="<?php echo (isset($this->_rootref['POLL_TITLE'])) ? $this->_rootref['POLL_TITLE'] : ''; ?>" class="inputbox" /></dd>
		</dl>
		<dl>
			<dt><label for="poll_option_text"><?php echo ((isset($this->_rootref['L_POLL_OPTIONS'])) ? $this->_rootref['L_POLL_OPTIONS'] : ((isset($user->lang['POLL_OPTIONS'])) ? $user->lang['POLL_OPTIONS'] : '{ POLL_OPTIONS }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_POLL_OPTIONS_EXPLAIN'])) ? $this->_rootref['L_POLL_OPTIONS_EXPLAIN'] : ((isset($user->lang['POLL_OPTIONS_EXPLAIN'])) ? $user->lang['POLL_OPTIONS_EXPLAIN'] : '{ POLL_OPTIONS_EXPLAIN }')); ?></span></dt>
			<dd><textarea name="poll_option_text" id="poll_option_text" rows="5" cols="35" class="inputbox"><?php echo (isset($this->_rootref['POLL_OPTIONS'])) ? $this->_rootref['POLL_OPTIONS'] : ''; ?></textarea></dd>
		</dl>

		<hr class="dashed" />

		<dl>
			<dt><label for="poll_max_options"><?php echo ((isset($this->_rootref['L_POLL_MAX_OPTIONS'])) ? $this->_rootref['L_POLL_MAX_OPTIONS'] : ((isset($user->lang['POLL_MAX_OPTIONS'])) ? $user->lang['POLL_MAX_OPTIONS'] : '{ POLL_MAX_OPTIONS }')); ?>:</label></dt>
			<dd><input type="text" name="poll_max_options" id="poll_max_options" size="3" maxlength="3" value="<?php echo (isset($this->_rootref['POLL_MAX_OPTIONS'])) ? $this->_rootref['POLL_MAX_OPTIONS'] : ''; ?>" class="inputbox autowidth" /></dd>
			<dd><?php echo ((isset($this->_rootref['L_POLL_MAX_OPTIONS_EXPLAIN'])) ? $this->_rootref['L_POLL_MAX_OPTIONS_EXPLAIN'] : ((isset($user->lang['POLL_MAX_OPTIONS_EXPLAIN'])) ? $user->lang['POLL_MAX_OPTIONS_EXPLAIN'] : '{ POLL_MAX_OPTIONS_EXPLAIN }')); ?></dd>
		</dl>
		<dl>
			<dt><label for="poll_length"><?php echo ((isset($this->_rootref['L_POLL_FOR'])) ? $this->_rootref['L_POLL_FOR'] : ((isset($user->lang['POLL_FOR'])) ? $user->lang['POLL_FOR'] : '{ POLL_FOR }')); ?>:</label></dt>
			<dd><label for="poll_length"><input type="text" name="poll_length" id="poll_length" size="3" maxlength="3" value="<?php echo (isset($this->_rootref['POLL_LENGTH'])) ? $this->_rootref['POLL_LENGTH'] : ''; ?>" class="inputbox autowidth" /> <?php echo ((isset($this->_rootref['L_DAYS'])) ? $this->_rootref['L_DAYS'] : ((isset($user->lang['DAYS'])) ? $user->lang['DAYS'] : '{ DAYS }')); ?></label></dd>
			<dd><?php echo ((isset($this->_rootref['L_POLL_FOR_EXPLAIN'])) ? $this->_rootref['L_POLL_FOR_EXPLAIN'] : ((isset($user->lang['POLL_FOR_EXPLAIN'])) ? $user->lang['POLL_FOR_EXPLAIN'] : '{ POLL_FOR_EXPLAIN }')); ?></dd>
		</dl>

		<?php if ($this->_rootref['S_POLL_VOTE_CHANGE']) {  ?>
			<hr class="dashed" />
			
			<dl>
				<dt><label for="poll_vote_change"><?php echo ((isset($this->_rootref['L_POLL_VOTE_CHANGE'])) ? $this->_rootref['L_POLL_VOTE_CHANGE'] : ((isset($user->lang['POLL_VOTE_CHANGE'])) ? $user->lang['POLL_VOTE_CHANGE'] : '{ POLL_VOTE_CHANGE }')); ?>:</label></dt>
				<dd><label for="poll_vote_change"><input type="checkbox" id="poll_vote_change" name="poll_vote_change"<?php echo (isset($this->_rootref['VOTE_CHANGE_CHECKED'])) ? $this->_rootref['VOTE_CHANGE_CHECKED'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_POLL_VOTE_CHANGE_EXPLAIN'])) ? $this->_rootref['L_POLL_VOTE_CHANGE_EXPLAIN'] : ((isset($user->lang['POLL_VOTE_CHANGE_EXPLAIN'])) ? $user->lang['POLL_VOTE_CHANGE_EXPLAIN'] : '{ POLL_VOTE_CHANGE_EXPLAIN }')); ?></label></dd>
			</dl>
		<?php } } else if ($this->_rootref['S_POLL_DELETE']) {  ?>
		<dl class="fields1">
			<dt><label for="poll_delete"><?php echo ((isset($this->_rootref['L_POLL_DELETE'])) ? $this->_rootref['L_POLL_DELETE'] : ((isset($user->lang['POLL_DELETE'])) ? $user->lang['POLL_DELETE'] : '{ POLL_DELETE }')); ?>:</label></dt>
			<dd><label for="poll_delete"><input type="checkbox" name="poll_delete" id="poll_delete"<?php if ($this->_rootref['S_POLL_DELETE_CHECKED']) {  ?> checked="checked"<?php } ?> /> </label></dd>
		</dl>
	<?php } ?>
	</fieldset>

	<span class="corners-bottom"><span></span></span></div>
</div>
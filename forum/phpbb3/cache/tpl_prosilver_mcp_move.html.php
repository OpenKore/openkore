<?php $this->_tpl_include('overall_header.html'); ?>

<form id="confirm" action="<?php echo (isset($this->_rootref['S_CONFIRM_ACTION'])) ? $this->_rootref['S_CONFIRM_ACTION'] : ''; ?>" method="post">

<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>

	<div class="content">
		<h2><?php echo (isset($this->_rootref['MESSAGE_TITLE'])) ? $this->_rootref['MESSAGE_TITLE'] : ''; ?></h2>
		<?php if ($this->_rootref['ADDITIONAL_MSG']) {  ?><p><?php echo (isset($this->_rootref['ADDITIONAL_MSG'])) ? $this->_rootref['ADDITIONAL_MSG'] : ''; ?></p><?php } ?>

		<fieldset>
		<dl class="fields2">
			<dt><label><?php echo ((isset($this->_rootref['L_SELECT_DESTINATION_FORUM'])) ? $this->_rootref['L_SELECT_DESTINATION_FORUM'] : ((isset($user->lang['SELECT_DESTINATION_FORUM'])) ? $user->lang['SELECT_DESTINATION_FORUM'] : '{ SELECT_DESTINATION_FORUM }')); ?>:</label></dt>
			<dd><select name="to_forum_id"><?php echo (isset($this->_rootref['S_FORUM_SELECT'])) ? $this->_rootref['S_FORUM_SELECT'] : ''; ?></select></dd>
			<?php if ($this->_rootref['S_CAN_LEAVE_SHADOW']) {  ?><dd><label for="move_leave_shadow"><input type="checkbox" name="move_leave_shadow" id="move_leave_shadow" checked="checked" /><?php echo ((isset($this->_rootref['L_LEAVE_SHADOW'])) ? $this->_rootref['L_LEAVE_SHADOW'] : ((isset($user->lang['LEAVE_SHADOW'])) ? $user->lang['LEAVE_SHADOW'] : '{ LEAVE_SHADOW }')); ?></label></dd><?php } ?>
		</dl>
		<dl class="fields2">
			<dt>&nbsp;</dt>
			<dd><strong><?php echo (isset($this->_rootref['MESSAGE_TEXT'])) ? $this->_rootref['MESSAGE_TEXT'] : ''; ?></strong></dd>
		</dl>
		</fieldset>

		<fieldset class="submit-buttons">
			<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?><input type="submit" name="confirm" value="<?php echo (isset($this->_rootref['YES_VALUE'])) ? $this->_rootref['YES_VALUE'] : ''; ?>" class="button1" />&nbsp; 
			<input type="submit" name="cancel" value="<?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?>" class="button2" />
			<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
		</fieldset>

	</div>

	<span class="corners-bottom"><span></span></span></div>
</div>
</form>

<?php $this->_tpl_include('overall_footer.html'); ?>
<?php $this->_tpl_include('ucp_header.html'); ?>

<form id="ucp" method="post" action="<?php echo (isset($this->_rootref['S_UCP_ACTION'])) ? $this->_rootref['S_UCP_ACTION'] : ''; ?>"<?php echo (isset($this->_rootref['S_FORM_ENCTYPE'])) ? $this->_rootref['S_FORM_ENCTYPE'] : ''; ?>>

<h2><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></h2>
<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>

	<fieldset>
	<?php if ($this->_rootref['ERROR']) {  ?><p class="error"><?php echo (isset($this->_rootref['ERROR'])) ? $this->_rootref['ERROR'] : ''; ?></p><?php } ?>
	<dl>
		<dt><label for="bbcode1"><?php echo ((isset($this->_rootref['L_DEFAULT_BBCODE'])) ? $this->_rootref['L_DEFAULT_BBCODE'] : ((isset($user->lang['DEFAULT_BBCODE'])) ? $user->lang['DEFAULT_BBCODE'] : '{ DEFAULT_BBCODE }')); ?>:</label></dt>
		<dd>
			<label for="bbcode1"><input type="radio" name="bbcode" id="bbcode1" value="1"<?php if ($this->_rootref['S_BBCODE']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label> 
			<label for="bbcode0"><input type="radio" name="bbcode" id="bbcode0" value="0"<?php if (! $this->_rootref['S_BBCODE']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label>
		</dd>
	</dl>
	<dl>
		<dt><label for="smilies1"><?php echo ((isset($this->_rootref['L_DEFAULT_SMILIES'])) ? $this->_rootref['L_DEFAULT_SMILIES'] : ((isset($user->lang['DEFAULT_SMILIES'])) ? $user->lang['DEFAULT_SMILIES'] : '{ DEFAULT_SMILIES }')); ?>:</label></dt>
		<dd>
			<label for="smilies1"><input type="radio" name="smilies" id="smilies1" value="1"<?php if ($this->_rootref['S_SMILIES']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label> 
			<label for="smilies0"><input type="radio" name="smilies" id="smilies0" value="0"<?php if (! $this->_rootref['S_SMILIES']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label>
		</dd>
	</dl>
	<dl>
		<dt><label for="sig1"><?php echo ((isset($this->_rootref['L_DEFAULT_ADD_SIG'])) ? $this->_rootref['L_DEFAULT_ADD_SIG'] : ((isset($user->lang['DEFAULT_ADD_SIG'])) ? $user->lang['DEFAULT_ADD_SIG'] : '{ DEFAULT_ADD_SIG }')); ?>:</label></dt>
		<dd>
			<label for="sig1"><input type="radio" name="sig" id="sig1" value="1"<?php if ($this->_rootref['S_SIG']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label> 
			<label for="sig0"><input type="radio" name="sig" id="sig0" value="0"<?php if (! $this->_rootref['S_SIG']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label>
		</dd>
	</dl>
	<dl>
		<dt><label for="notify1"><?php echo ((isset($this->_rootref['L_DEFAULT_NOTIFY'])) ? $this->_rootref['L_DEFAULT_NOTIFY'] : ((isset($user->lang['DEFAULT_NOTIFY'])) ? $user->lang['DEFAULT_NOTIFY'] : '{ DEFAULT_NOTIFY }')); ?>:</label></dt>
		<dd>
			<label for="notify1"><input type="radio" name="notify" id="notify1" value="1"<?php if ($this->_rootref['S_NOTIFY']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label> 
			<label for="notify0"><input type="radio" name="notify" id="notify0" value="0"<?php if (! $this->_rootref['S_NOTIFY']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label>
		</dd>
	</dl>
	</fieldset>
	
	<span class="corners-bottom"><span></span></span></div>
</div>

<fieldset class="submit-buttons">
	<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?><input type="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" name="reset" class="button2" />&nbsp; 
	<input type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" class="button1" />
	<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
</fieldset>
</form>

<?php $this->_tpl_include('ucp_footer.html'); ?>
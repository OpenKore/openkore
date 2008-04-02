<?php $this->_tpl_include('ucp_header.html'); ?>

<form id="ucp" method="post" action="<?php echo (isset($this->_rootref['S_UCP_ACTION'])) ? $this->_rootref['S_UCP_ACTION'] : ''; ?>"<?php echo (isset($this->_rootref['S_FORM_ENCTYPE'])) ? $this->_rootref['S_FORM_ENCTYPE'] : ''; ?>>

<h2><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></h2>

<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>

	<p><?php echo ((isset($this->_rootref['L_FOES_EXPLAIN'])) ? $this->_rootref['L_FOES_EXPLAIN'] : ((isset($user->lang['FOES_EXPLAIN'])) ? $user->lang['FOES_EXPLAIN'] : '{ FOES_EXPLAIN }')); ?></p>

	<fieldset class="fields2">
	<?php if ($this->_rootref['ERROR']) {  ?><p class="error"><?php echo (isset($this->_rootref['ERROR'])) ? $this->_rootref['ERROR'] : ''; ?></p><?php } ?>
	<dl>
		<dt><label <?php if ($this->_rootref['S_USERNAME_OPTIONS']) {  ?>for="usernames"<?php } ?>><?php echo ((isset($this->_rootref['L_YOUR_FOES'])) ? $this->_rootref['L_YOUR_FOES'] : ((isset($user->lang['YOUR_FOES'])) ? $user->lang['YOUR_FOES'] : '{ YOUR_FOES }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_YOUR_FOES_EXPLAIN'])) ? $this->_rootref['L_YOUR_FOES_EXPLAIN'] : ((isset($user->lang['YOUR_FOES_EXPLAIN'])) ? $user->lang['YOUR_FOES_EXPLAIN'] : '{ YOUR_FOES_EXPLAIN }')); ?></span></dt>
		<dd>
			<?php if ($this->_rootref['S_USERNAME_OPTIONS']) {  ?>
				<select name="usernames[]" id="usernames" multiple="multiple" size="5"><?php echo (isset($this->_rootref['S_USERNAME_OPTIONS'])) ? $this->_rootref['S_USERNAME_OPTIONS'] : ''; ?></select>
			<?php } else { ?>
				<strong><?php echo ((isset($this->_rootref['L_NO_FOES'])) ? $this->_rootref['L_NO_FOES'] : ((isset($user->lang['NO_FOES'])) ? $user->lang['NO_FOES'] : '{ NO_FOES }')); ?></strong>
			<?php } ?>
		</dd>
	</dl>
	<dl>
		<dt><label for="add"><?php echo ((isset($this->_rootref['L_ADD_FOES'])) ? $this->_rootref['L_ADD_FOES'] : ((isset($user->lang['ADD_FOES'])) ? $user->lang['ADD_FOES'] : '{ ADD_FOES }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_ADD_FOES_EXPLAIN'])) ? $this->_rootref['L_ADD_FOES_EXPLAIN'] : ((isset($user->lang['ADD_FOES_EXPLAIN'])) ? $user->lang['ADD_FOES_EXPLAIN'] : '{ ADD_FOES_EXPLAIN }')); ?></span></dt>
		<dd><textarea name="add" id="add" rows="3" cols="30" class="inputbox"><?php echo (isset($this->_rootref['USERNAMES'])) ? $this->_rootref['USERNAMES'] : ''; ?></textarea></dd>
		<dd><strong><a href="<?php echo (isset($this->_rootref['U_FIND_USERNAME'])) ? $this->_rootref['U_FIND_USERNAME'] : ''; ?>" onclick="find_username(this.href); return false;"><?php echo ((isset($this->_rootref['L_FIND_USERNAME'])) ? $this->_rootref['L_FIND_USERNAME'] : ((isset($user->lang['FIND_USERNAME'])) ? $user->lang['FIND_USERNAME'] : '{ FIND_USERNAME }')); ?></a></strong></dd>
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
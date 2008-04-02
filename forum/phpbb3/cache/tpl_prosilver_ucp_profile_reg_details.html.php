<?php $this->_tpl_include('ucp_header.html'); ?>

<form id="ucp" method="post" action="<?php echo (isset($this->_rootref['S_UCP_ACTION'])) ? $this->_rootref['S_UCP_ACTION'] : ''; ?>"<?php echo (isset($this->_rootref['S_FORM_ENCTYPE'])) ? $this->_rootref['S_FORM_ENCTYPE'] : ''; ?>>

<h2><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></h2>
<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>

	<?php if ($this->_rootref['S_FORCE_PASSWORD']) {  ?>
		<p><?php echo ((isset($this->_rootref['L_FORCE_PASSWORD_EXPLAIN'])) ? $this->_rootref['L_FORCE_PASSWORD_EXPLAIN'] : ((isset($user->lang['FORCE_PASSWORD_EXPLAIN'])) ? $user->lang['FORCE_PASSWORD_EXPLAIN'] : '{ FORCE_PASSWORD_EXPLAIN }')); ?></p>
	<?php } ?>

	<fieldset>
	<?php if ($this->_rootref['ERROR']) {  ?><p class="error"><?php echo (isset($this->_rootref['ERROR'])) ? $this->_rootref['ERROR'] : ''; ?></p><?php } ?>
	<dl>
		<dt><label <?php if ($this->_rootref['S_CHANGE_USERNAME']) {  ?>for="username"<?php } ?>><?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_USERNAME_EXPLAIN'])) ? $this->_rootref['L_USERNAME_EXPLAIN'] : ((isset($user->lang['USERNAME_EXPLAIN'])) ? $user->lang['USERNAME_EXPLAIN'] : '{ USERNAME_EXPLAIN }')); ?></span></dt>
		<dd><?php if ($this->_rootref['S_CHANGE_USERNAME']) {  ?><input type="text" name="username" id="username" value="<?php echo (isset($this->_rootref['USERNAME'])) ? $this->_rootref['USERNAME'] : ''; ?>" class="inputbox" title="<?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?>" /><?php } else { ?><strong><?php echo (isset($this->_rootref['USERNAME'])) ? $this->_rootref['USERNAME'] : ''; ?></strong><?php } ?></dd>
	</dl>
	<dl>
		<dt><label for="email"><?php echo ((isset($this->_rootref['L_EMAIL_ADDRESS'])) ? $this->_rootref['L_EMAIL_ADDRESS'] : ((isset($user->lang['EMAIL_ADDRESS'])) ? $user->lang['EMAIL_ADDRESS'] : '{ EMAIL_ADDRESS }')); ?>:</label></dt>
		<dd><?php if ($this->_rootref['S_CHANGE_EMAIL']) {  ?><input type="text" name="email" id="email" maxlength="100" value="<?php echo (isset($this->_rootref['EMAIL'])) ? $this->_rootref['EMAIL'] : ''; ?>" class="inputbox" title="<?php echo ((isset($this->_rootref['L_EMAIL_ADDRESS'])) ? $this->_rootref['L_EMAIL_ADDRESS'] : ((isset($user->lang['EMAIL_ADDRESS'])) ? $user->lang['EMAIL_ADDRESS'] : '{ EMAIL_ADDRESS }')); ?>" /><?php } else { ?><strong><?php echo (isset($this->_rootref['EMAIL'])) ? $this->_rootref['EMAIL'] : ''; ?></strong><?php } ?></dd>
	</dl>
	<?php if ($this->_rootref['S_CHANGE_EMAIL']) {  ?>
		<dl>
			<dt><label for="email_confirm"><?php echo ((isset($this->_rootref['L_CONFIRM_EMAIL'])) ? $this->_rootref['L_CONFIRM_EMAIL'] : ((isset($user->lang['CONFIRM_EMAIL'])) ? $user->lang['CONFIRM_EMAIL'] : '{ CONFIRM_EMAIL }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_CONFIRM_EMAIL_EXPLAIN'])) ? $this->_rootref['L_CONFIRM_EMAIL_EXPLAIN'] : ((isset($user->lang['CONFIRM_EMAIL_EXPLAIN'])) ? $user->lang['CONFIRM_EMAIL_EXPLAIN'] : '{ CONFIRM_EMAIL_EXPLAIN }')); ?></span></dt>
			<dd><input type="text" name="email_confirm" id="email_confirm" maxlength="100" value="<?php echo (isset($this->_rootref['CONFIRM_EMAIL'])) ? $this->_rootref['CONFIRM_EMAIL'] : ''; ?>" class="inputbox" title="<?php echo ((isset($this->_rootref['L_CONFIRM_EMAIL'])) ? $this->_rootref['L_CONFIRM_EMAIL'] : ((isset($user->lang['CONFIRM_EMAIL'])) ? $user->lang['CONFIRM_EMAIL'] : '{ CONFIRM_EMAIL }')); ?>" /></dd>
		</dl>
	<?php } if ($this->_rootref['S_CHANGE_PASSWORD']) {  ?>
		<dl>
			<dt><label for="new_password"><?php echo ((isset($this->_rootref['L_NEW_PASSWORD'])) ? $this->_rootref['L_NEW_PASSWORD'] : ((isset($user->lang['NEW_PASSWORD'])) ? $user->lang['NEW_PASSWORD'] : '{ NEW_PASSWORD }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_CHANGE_PASSWORD_EXPLAIN'])) ? $this->_rootref['L_CHANGE_PASSWORD_EXPLAIN'] : ((isset($user->lang['CHANGE_PASSWORD_EXPLAIN'])) ? $user->lang['CHANGE_PASSWORD_EXPLAIN'] : '{ CHANGE_PASSWORD_EXPLAIN }')); ?></span></dt>
			<dd><input type="password" name="new_password" id="new_password" maxlength="255" value="<?php echo (isset($this->_rootref['NEW_PASSWORD'])) ? $this->_rootref['NEW_PASSWORD'] : ''; ?>" class="inputbox" title="<?php echo ((isset($this->_rootref['L_CHANGE_PASSWORD'])) ? $this->_rootref['L_CHANGE_PASSWORD'] : ((isset($user->lang['CHANGE_PASSWORD'])) ? $user->lang['CHANGE_PASSWORD'] : '{ CHANGE_PASSWORD }')); ?>" /></dd>
		</dl>
		<dl>
			<dt><label for="password_confirm"><?php echo ((isset($this->_rootref['L_CONFIRM_PASSWORD'])) ? $this->_rootref['L_CONFIRM_PASSWORD'] : ((isset($user->lang['CONFIRM_PASSWORD'])) ? $user->lang['CONFIRM_PASSWORD'] : '{ CONFIRM_PASSWORD }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_CONFIRM_PASSWORD_EXPLAIN'])) ? $this->_rootref['L_CONFIRM_PASSWORD_EXPLAIN'] : ((isset($user->lang['CONFIRM_PASSWORD_EXPLAIN'])) ? $user->lang['CONFIRM_PASSWORD_EXPLAIN'] : '{ CONFIRM_PASSWORD_EXPLAIN }')); ?></span></dt>
			<dd><input type="password" name="password_confirm" id="password_confirm" maxlength="255" value="<?php echo (isset($this->_rootref['PASSWORD_CONFIRM'])) ? $this->_rootref['PASSWORD_CONFIRM'] : ''; ?>" class="inputbox" title="<?php echo ((isset($this->_rootref['L_CONFIRM_PASSWORD'])) ? $this->_rootref['L_CONFIRM_PASSWORD'] : ((isset($user->lang['CONFIRM_PASSWORD'])) ? $user->lang['CONFIRM_PASSWORD'] : '{ CONFIRM_PASSWORD }')); ?>" /></dd>
		</dl>
	<?php } ?>
	</fieldset>
	<span class="corners-bottom"><span></span></span></div>
</div>

<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>

	<fieldset>
	<dl>
		<dt><label for="cur_password"><?php echo ((isset($this->_rootref['L_CURRENT_PASSWORD'])) ? $this->_rootref['L_CURRENT_PASSWORD'] : ((isset($user->lang['CURRENT_PASSWORD'])) ? $user->lang['CURRENT_PASSWORD'] : '{ CURRENT_PASSWORD }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_CURRENT_PASSWORD_EXPLAIN'])) ? $this->_rootref['L_CURRENT_PASSWORD_EXPLAIN'] : ((isset($user->lang['CURRENT_PASSWORD_EXPLAIN'])) ? $user->lang['CURRENT_PASSWORD_EXPLAIN'] : '{ CURRENT_PASSWORD_EXPLAIN }')); ?></span></dt>
		<dd><input type="password" name="cur_password" id="cur_password" maxlength="255" value="<?php echo (isset($this->_rootref['CUR_PASSWORD'])) ? $this->_rootref['CUR_PASSWORD'] : ''; ?>" class="inputbox" title="<?php echo ((isset($this->_rootref['L_CURRENT_PASSWORD'])) ? $this->_rootref['L_CURRENT_PASSWORD'] : ((isset($user->lang['CURRENT_PASSWORD'])) ? $user->lang['CURRENT_PASSWORD'] : '{ CURRENT_PASSWORD }')); ?>" /></dd>
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
<?php $this->_tpl_include('overall_header.html'); ?>

<form action="<?php echo (isset($this->_rootref['S_LOGIN_ACTION'])) ? $this->_rootref['S_LOGIN_ACTION'] : ''; ?>" method="post" id="login">
<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>

	<div class="content">
		<h2><?php if ($this->_rootref['LOGIN_EXPLAIN']) {  echo (isset($this->_rootref['LOGIN_EXPLAIN'])) ? $this->_rootref['LOGIN_EXPLAIN'] : ''; } else { echo ((isset($this->_rootref['L_LOGIN'])) ? $this->_rootref['L_LOGIN'] : ((isset($user->lang['LOGIN'])) ? $user->lang['LOGIN'] : '{ LOGIN }')); } ?></h2>
		
		<fieldset <?php if (! $this->_rootref['S_CONFIRM_CODE']) {  ?>class="fields1"<?php } else { ?>class="fields2"<?php } ?>>
		<?php if ($this->_rootref['LOGIN_ERROR']) {  ?><div class="error"><?php echo (isset($this->_rootref['LOGIN_ERROR'])) ? $this->_rootref['LOGIN_ERROR'] : ''; ?></div><?php } ?>
		<dl>
			<dt><label for="<?php echo (isset($this->_rootref['USERNAME_CREDENTIAL'])) ? $this->_rootref['USERNAME_CREDENTIAL'] : ''; ?>"><?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?>:</label></dt>
			<dd><input type="text" tabindex="1" name="<?php echo (isset($this->_rootref['USERNAME_CREDENTIAL'])) ? $this->_rootref['USERNAME_CREDENTIAL'] : ''; ?>" id="<?php echo (isset($this->_rootref['USERNAME_CREDENTIAL'])) ? $this->_rootref['USERNAME_CREDENTIAL'] : ''; ?>" size="25" value="<?php echo (isset($this->_rootref['USERNAME'])) ? $this->_rootref['USERNAME'] : ''; ?>" class="inputbox autowidth" /></dd>
		</dl>
		<dl>
			<dt><label for="<?php echo (isset($this->_rootref['PASSWORD_CREDENTIAL'])) ? $this->_rootref['PASSWORD_CREDENTIAL'] : ''; ?>"><?php echo ((isset($this->_rootref['L_PASSWORD'])) ? $this->_rootref['L_PASSWORD'] : ((isset($user->lang['PASSWORD'])) ? $user->lang['PASSWORD'] : '{ PASSWORD }')); ?>:</label></dt>
			<dd><input type="password" tabindex="2" id="<?php echo (isset($this->_rootref['PASSWORD_CREDENTIAL'])) ? $this->_rootref['PASSWORD_CREDENTIAL'] : ''; ?>" name="<?php echo (isset($this->_rootref['PASSWORD_CREDENTIAL'])) ? $this->_rootref['PASSWORD_CREDENTIAL'] : ''; ?>" size="25" class="inputbox autowidth" /></dd>
			<?php if ($this->_rootref['S_DISPLAY_FULL_LOGIN'] && ( $this->_rootref['U_SEND_PASSWORD'] || $this->_rootref['U_RESEND_ACTIVATION'] )) {  if ($this->_rootref['U_SEND_PASSWORD']) {  ?><dd><a href="<?php echo (isset($this->_rootref['U_SEND_PASSWORD'])) ? $this->_rootref['U_SEND_PASSWORD'] : ''; ?>"><?php echo ((isset($this->_rootref['L_FORGOT_PASS'])) ? $this->_rootref['L_FORGOT_PASS'] : ((isset($user->lang['FORGOT_PASS'])) ? $user->lang['FORGOT_PASS'] : '{ FORGOT_PASS }')); ?></a></dd><?php } if ($this->_rootref['U_RESEND_ACTIVATION']) {  ?><dd><a href="<?php echo (isset($this->_rootref['U_RESEND_ACTIVATION'])) ? $this->_rootref['U_RESEND_ACTIVATION'] : ''; ?>"><?php echo ((isset($this->_rootref['L_RESEND_ACTIVATION'])) ? $this->_rootref['L_RESEND_ACTIVATION'] : ((isset($user->lang['RESEND_ACTIVATION'])) ? $user->lang['RESEND_ACTIVATION'] : '{ RESEND_ACTIVATION }')); ?></a></dd><?php } } ?>
		</dl>
		
		<?php if ($this->_rootref['S_CONFIRM_CODE']) {  ?>
		<dl>
			<dt><label for="confirm_code"><?php echo ((isset($this->_rootref['L_CONFIRM_CODE'])) ? $this->_rootref['L_CONFIRM_CODE'] : ((isset($user->lang['CONFIRM_CODE'])) ? $user->lang['CONFIRM_CODE'] : '{ CONFIRM_CODE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_CONFIRM_CODE_EXPLAIN'])) ? $this->_rootref['L_CONFIRM_CODE_EXPLAIN'] : ((isset($user->lang['CONFIRM_CODE_EXPLAIN'])) ? $user->lang['CONFIRM_CODE_EXPLAIN'] : '{ CONFIRM_CODE_EXPLAIN }')); ?></span></dt>
				<dd><input type="hidden" name="confirm_id" value="<?php echo (isset($this->_rootref['CONFIRM_ID'])) ? $this->_rootref['CONFIRM_ID'] : ''; ?>" /><?php echo (isset($this->_rootref['CONFIRM_IMAGE'])) ? $this->_rootref['CONFIRM_IMAGE'] : ''; ?></dd>
				<dd><input type="text" name="confirm_code" id="confirm_code" size="8" maxlength="8" tabindex="3" class="inputbox narrow" title="<?php echo ((isset($this->_rootref['L_CONFIRM_CODE'])) ? $this->_rootref['L_CONFIRM_CODE'] : ((isset($user->lang['CONFIRM_CODE'])) ? $user->lang['CONFIRM_CODE'] : '{ CONFIRM_CODE }')); ?>" /></dd>
		</dl>
		<?php } if ($this->_rootref['S_DISPLAY_FULL_LOGIN']) {  ?>
		<dl>
			<?php if ($this->_rootref['S_AUTOLOGIN_ENABLED']) {  ?><dd><label for="autologin"><input type="checkbox" name="autologin" id="autologin" tabindex="4" /> <?php echo ((isset($this->_rootref['L_LOG_ME_IN'])) ? $this->_rootref['L_LOG_ME_IN'] : ((isset($user->lang['LOG_ME_IN'])) ? $user->lang['LOG_ME_IN'] : '{ LOG_ME_IN }')); ?></label></dd><?php } ?>
			<dd><label for="viewonline"><input type="checkbox" name="viewonline" id="viewonline" tabindex="5" /> <?php echo ((isset($this->_rootref['L_HIDE_ME'])) ? $this->_rootref['L_HIDE_ME'] : ((isset($user->lang['HIDE_ME'])) ? $user->lang['HIDE_ME'] : '{ HIDE_ME }')); ?></label></dd>
		</dl>
		<?php } ?>
		<dl>
			<dt>&nbsp;</dt>
			<dd><?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?><input type="submit" name="login" tabindex="6" value="<?php echo ((isset($this->_rootref['L_LOGIN'])) ? $this->_rootref['L_LOGIN'] : ((isset($user->lang['LOGIN'])) ? $user->lang['LOGIN'] : '{ LOGIN }')); ?>" class="button1" /></dd>
		</dl>
	
		</fieldset>
	</div>
	<span class="corners-bottom"><span></span></span></div>
</div>

<?php if (! $this->_rootref['S_ADMIN_AUTH']) {  ?>
	<div class="panel">
		<div class="inner"><span class="corners-top"><span></span></span>

		<div class="content">
			<h3><?php echo ((isset($this->_rootref['L_REGISTER'])) ? $this->_rootref['L_REGISTER'] : ((isset($user->lang['REGISTER'])) ? $user->lang['REGISTER'] : '{ REGISTER }')); ?></h3>
			<p><?php echo ((isset($this->_rootref['L_LOGIN_INFO'])) ? $this->_rootref['L_LOGIN_INFO'] : ((isset($user->lang['LOGIN_INFO'])) ? $user->lang['LOGIN_INFO'] : '{ LOGIN_INFO }')); ?></p>
			<p><strong><a href="<?php echo (isset($this->_rootref['U_TERMS_USE'])) ? $this->_rootref['U_TERMS_USE'] : ''; ?>"><?php echo ((isset($this->_rootref['L_TERMS_USE'])) ? $this->_rootref['L_TERMS_USE'] : ((isset($user->lang['TERMS_USE'])) ? $user->lang['TERMS_USE'] : '{ TERMS_USE }')); ?></a> | <a href="<?php echo (isset($this->_rootref['U_PRIVACY'])) ? $this->_rootref['U_PRIVACY'] : ''; ?>"><?php echo ((isset($this->_rootref['L_PRIVACY'])) ? $this->_rootref['L_PRIVACY'] : ((isset($user->lang['PRIVACY'])) ? $user->lang['PRIVACY'] : '{ PRIVACY }')); ?></a></strong></p>
			<hr class="dashed" />
			<p><a href="<?php echo (isset($this->_rootref['U_REGISTER'])) ? $this->_rootref['U_REGISTER'] : ''; ?>" class="button2"><?php echo ((isset($this->_rootref['L_REGISTER'])) ? $this->_rootref['L_REGISTER'] : ((isset($user->lang['REGISTER'])) ? $user->lang['REGISTER'] : '{ REGISTER }')); ?></a></p>
		</div>

		<span class="corners-bottom"><span></span></span></div>
	</div>
<?php } ?>

</form>

<?php $this->_tpl_include('overall_footer.html'); ?>
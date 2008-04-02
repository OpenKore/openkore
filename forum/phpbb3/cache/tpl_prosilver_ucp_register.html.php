<?php $this->_tpl_include('overall_header.html'); ?>

<script type="text/javascript">
// <![CDATA[
	/**
	* Change language
	*/
	function change_language(lang_iso)
	{
		document.forms['register'].change_lang.value = lang_iso;
		document.forms['register'].submit.click();
	}

	function disable(disabl, name)
	{
		document.getElementById(name).disabled = disabl;
		if (disabl)
		{
			document.getElementById(name).className = 'button1 disabled';
		}
		else
		{
			document.getElementById(name).className = 'button1 enabled';
		}
	}

	<?php if ($this->_rootref['S_TIME']) {  ?>
		onload_functions.push('disable(true, "submit")');
		setInterval('disable(false, "submit")', <?php echo (isset($this->_rootref['S_TIME'])) ? $this->_rootref['S_TIME'] : ''; ?>);
	<?php } ?>

// ]]>
</script>

<form method="post" action="<?php echo (isset($this->_rootref['S_UCP_ACTION'])) ? $this->_rootref['S_UCP_ACTION'] : ''; ?>" id="register">

<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>

	<h2><?php echo (isset($this->_rootref['SITENAME'])) ? $this->_rootref['SITENAME'] : ''; ?> - <?php echo ((isset($this->_rootref['L_REGISTRATION'])) ? $this->_rootref['L_REGISTRATION'] : ((isset($user->lang['REGISTRATION'])) ? $user->lang['REGISTRATION'] : '{ REGISTRATION }')); ?></h2>

	<fieldset class="fields2">
	<?php if ($this->_rootref['ERROR']) {  ?><dl><dd class="error"><?php echo (isset($this->_rootref['ERROR'])) ? $this->_rootref['ERROR'] : ''; ?></dd></dl><?php } if ($this->_rootref['L_REG_COND']) {  ?>
		<dl><dd><strong><?php echo ((isset($this->_rootref['L_REG_COND'])) ? $this->_rootref['L_REG_COND'] : ((isset($user->lang['REG_COND'])) ? $user->lang['REG_COND'] : '{ REG_COND }')); ?></strong></dd></dl>
	<?php } if (sizeof($this->_tpldata['profile_fields'])) {  ?>
		<dl><dd><strong><?php echo ((isset($this->_rootref['L_ITEMS_REQUIRED'])) ? $this->_rootref['L_ITEMS_REQUIRED'] : ((isset($user->lang['ITEMS_REQUIRED'])) ? $user->lang['ITEMS_REQUIRED'] : '{ ITEMS_REQUIRED }')); ?></strong></dd></dl>
	<?php } ?>

	<dl>
		<dt><label for="username"><?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_USERNAME_EXPLAIN'])) ? $this->_rootref['L_USERNAME_EXPLAIN'] : ((isset($user->lang['USERNAME_EXPLAIN'])) ? $user->lang['USERNAME_EXPLAIN'] : '{ USERNAME_EXPLAIN }')); ?></span></dt>
		<dd><input type="text" tabindex="1" name="username" id="username" size="25" value="<?php echo (isset($this->_rootref['USERNAME'])) ? $this->_rootref['USERNAME'] : ''; ?>" class="inputbox autowidth" title="<?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?>" /></dd>
	</dl>
	<dl>
		<dt><label for="email"><?php echo ((isset($this->_rootref['L_EMAIL_ADDRESS'])) ? $this->_rootref['L_EMAIL_ADDRESS'] : ((isset($user->lang['EMAIL_ADDRESS'])) ? $user->lang['EMAIL_ADDRESS'] : '{ EMAIL_ADDRESS }')); ?>:</label></dt>
		<dd><input type="text" tabindex="2" name="email" id="email" size="25" maxlength="100" value="<?php echo (isset($this->_rootref['EMAIL'])) ? $this->_rootref['EMAIL'] : ''; ?>" class="inputbox autowidth" title="<?php echo ((isset($this->_rootref['L_EMAIL_ADDRESS'])) ? $this->_rootref['L_EMAIL_ADDRESS'] : ((isset($user->lang['EMAIL_ADDRESS'])) ? $user->lang['EMAIL_ADDRESS'] : '{ EMAIL_ADDRESS }')); ?>" /></dd>
	</dl>
	<dl>
		<dt><label for="email_confirm"><?php echo ((isset($this->_rootref['L_CONFIRM_EMAIL'])) ? $this->_rootref['L_CONFIRM_EMAIL'] : ((isset($user->lang['CONFIRM_EMAIL'])) ? $user->lang['CONFIRM_EMAIL'] : '{ CONFIRM_EMAIL }')); ?>:</label></dt>
		<dd><input type="text" tabindex="3" name="email_confirm" id="email_confirm" size="25" maxlength="100" value="<?php echo (isset($this->_rootref['EMAIL_CONFIRM'])) ? $this->_rootref['EMAIL_CONFIRM'] : ''; ?>" class="inputbox autowidth" title="<?php echo ((isset($this->_rootref['L_CONFIRM_EMAIL'])) ? $this->_rootref['L_CONFIRM_EMAIL'] : ((isset($user->lang['CONFIRM_EMAIL'])) ? $user->lang['CONFIRM_EMAIL'] : '{ CONFIRM_EMAIL }')); ?>" /></dd>
	</dl>
	<dl>
		<dt><label for="new_password"><?php echo ((isset($this->_rootref['L_PASSWORD'])) ? $this->_rootref['L_PASSWORD'] : ((isset($user->lang['PASSWORD'])) ? $user->lang['PASSWORD'] : '{ PASSWORD }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_PASSWORD_EXPLAIN'])) ? $this->_rootref['L_PASSWORD_EXPLAIN'] : ((isset($user->lang['PASSWORD_EXPLAIN'])) ? $user->lang['PASSWORD_EXPLAIN'] : '{ PASSWORD_EXPLAIN }')); ?></span></dt>
		<dd><input type="password" tabindex="4" name="new_password" id="new_password" size="25" value="<?php echo (isset($this->_rootref['PASSWORD'])) ? $this->_rootref['PASSWORD'] : ''; ?>" class="inputbox autowidth" title="<?php echo ((isset($this->_rootref['L_NEW_PASSWORD'])) ? $this->_rootref['L_NEW_PASSWORD'] : ((isset($user->lang['NEW_PASSWORD'])) ? $user->lang['NEW_PASSWORD'] : '{ NEW_PASSWORD }')); ?>" /></dd>
	</dl>
	<dl>
		<dt><label for="password_confirm"><?php echo ((isset($this->_rootref['L_CONFIRM_PASSWORD'])) ? $this->_rootref['L_CONFIRM_PASSWORD'] : ((isset($user->lang['CONFIRM_PASSWORD'])) ? $user->lang['CONFIRM_PASSWORD'] : '{ CONFIRM_PASSWORD }')); ?>:</label></dt>
		<dd><input type="password" tabindex="5" name="password_confirm" id="password_confirm" size="25" value="<?php echo (isset($this->_rootref['PASSWORD_CONFIRM'])) ? $this->_rootref['PASSWORD_CONFIRM'] : ''; ?>" class="inputbox autowidth" title="<?php echo ((isset($this->_rootref['L_CONFIRM_PASSWORD'])) ? $this->_rootref['L_CONFIRM_PASSWORD'] : ((isset($user->lang['CONFIRM_PASSWORD'])) ? $user->lang['CONFIRM_PASSWORD'] : '{ CONFIRM_PASSWORD }')); ?>" /></dd>
	</dl>

	<hr />

	<dl>
		<dt><label for="lang"><?php echo ((isset($this->_rootref['L_LANGUAGE'])) ? $this->_rootref['L_LANGUAGE'] : ((isset($user->lang['LANGUAGE'])) ? $user->lang['LANGUAGE'] : '{ LANGUAGE }')); ?>:</label></dt>
		<dd><select name="lang" id="lang" onchange="change_language(this.value); return false;" title="<?php echo ((isset($this->_rootref['L_LANGUAGE'])) ? $this->_rootref['L_LANGUAGE'] : ((isset($user->lang['LANGUAGE'])) ? $user->lang['LANGUAGE'] : '{ LANGUAGE }')); ?>"><?php echo (isset($this->_rootref['S_LANG_OPTIONS'])) ? $this->_rootref['S_LANG_OPTIONS'] : ''; ?></select></dd>
	</dl>
	<dl>
		<dt><label for="tz"><?php echo ((isset($this->_rootref['L_TIMEZONE'])) ? $this->_rootref['L_TIMEZONE'] : ((isset($user->lang['TIMEZONE'])) ? $user->lang['TIMEZONE'] : '{ TIMEZONE }')); ?>:</label></dt>
		<dd><select name="tz" id="tz" class="autowidth"><?php echo (isset($this->_rootref['S_TZ_OPTIONS'])) ? $this->_rootref['S_TZ_OPTIONS'] : ''; ?></select></dd>
	</dl>

	<?php $_profile_fields_count = (isset($this->_tpldata['profile_fields'])) ? sizeof($this->_tpldata['profile_fields']) : 0;if ($_profile_fields_count) {for ($_profile_fields_i = 0; $_profile_fields_i < $_profile_fields_count; ++$_profile_fields_i){$_profile_fields_val = &$this->_tpldata['profile_fields'][$_profile_fields_i]; ?>
		<dl>
			<dt><label<?php if ($_profile_fields_val['FIELD_ID']) {  ?> for="<?php echo $_profile_fields_val['FIELD_ID']; ?>"<?php } ?>><?php echo $_profile_fields_val['LANG_NAME']; ?>:<?php if ($_profile_fields_val['S_REQUIRED']) {  ?> *<?php } ?></label>
			<?php if ($_profile_fields_val['LANG_EXPLAIN']) {  ?><br /><span><?php echo $_profile_fields_val['LANG_EXPLAIN']; ?></span><?php } if ($_profile_fields_val['ERROR']) {  ?><br /><span class="error"><?php echo $_profile_fields_val['ERROR']; ?></span><?php } ?></dt>
			<dd><?php echo $_profile_fields_val['FIELD']; ?></dd>
		</dl>
	<?php }} ?>
	</fieldset>

<?php if ($this->_rootref['S_CONFIRM_CODE']) {  ?>
	<span class="corners-bottom"><span></span></span></div>
</div>

<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>

	<h3><?php echo ((isset($this->_rootref['L_CONFIRMATION'])) ? $this->_rootref['L_CONFIRMATION'] : ((isset($user->lang['CONFIRMATION'])) ? $user->lang['CONFIRMATION'] : '{ CONFIRMATION }')); ?></h3>
	<p><?php echo ((isset($this->_rootref['L_CONFIRM_EXPLAIN'])) ? $this->_rootref['L_CONFIRM_EXPLAIN'] : ((isset($user->lang['CONFIRM_EXPLAIN'])) ? $user->lang['CONFIRM_EXPLAIN'] : '{ CONFIRM_EXPLAIN }')); ?></p>

	<fieldset class="fields2">
	<dl>
		<dt><label for="confirm_code"><?php echo ((isset($this->_rootref['L_CONFIRM_CODE'])) ? $this->_rootref['L_CONFIRM_CODE'] : ((isset($user->lang['CONFIRM_CODE'])) ? $user->lang['CONFIRM_CODE'] : '{ CONFIRM_CODE }')); ?>:</label></dt>
		<dd><?php echo (isset($this->_rootref['CONFIRM_IMG'])) ? $this->_rootref['CONFIRM_IMG'] : ''; ?></dd>
		<dd><input type="text" name="confirm_code" id="confirm_code" size="8" maxlength="8" class="inputbox narrow" title="<?php echo ((isset($this->_rootref['L_CONFIRM_CODE'])) ? $this->_rootref['L_CONFIRM_CODE'] : ((isset($user->lang['CONFIRM_CODE'])) ? $user->lang['CONFIRM_CODE'] : '{ CONFIRM_CODE }')); ?>" /></dd>
		<dd><?php echo ((isset($this->_rootref['L_CONFIRM_CODE_EXPLAIN'])) ? $this->_rootref['L_CONFIRM_CODE_EXPLAIN'] : ((isset($user->lang['CONFIRM_CODE_EXPLAIN'])) ? $user->lang['CONFIRM_CODE_EXPLAIN'] : '{ CONFIRM_CODE_EXPLAIN }')); ?></dd>
	</dl>
	</fieldset>
<?php } if ($this->_rootref['S_COPPA']) {  ?>
	<span class="corners-bottom"><span></span></span></div>
</div>

<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>

	<h4><?php echo ((isset($this->_rootref['L_COPPA_COMPLIANCE'])) ? $this->_rootref['L_COPPA_COMPLIANCE'] : ((isset($user->lang['COPPA_COMPLIANCE'])) ? $user->lang['COPPA_COMPLIANCE'] : '{ COPPA_COMPLIANCE }')); ?></h4>

	<p><?php echo ((isset($this->_rootref['L_COPPA_EXPLAIN'])) ? $this->_rootref['L_COPPA_EXPLAIN'] : ((isset($user->lang['COPPA_EXPLAIN'])) ? $user->lang['COPPA_EXPLAIN'] : '{ COPPA_EXPLAIN }')); ?></p>
<?php } ?>

	<span class="corners-bottom"><span></span></span></div>
</div>

<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>

	<fieldset class="submit-buttons">
		<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?>
		<input type="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" name="reset" class="button2" />&nbsp;
		<input type="submit" name="submit" id ="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" class="button1" />
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>

	<span class="corners-bottom"><span></span></span></div>
</div>
</form>

<?php $this->_tpl_include('overall_footer.html'); ?>
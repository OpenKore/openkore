<form id="user_profile" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_USER_PROFILE'])) ? $this->_rootref['L_USER_PROFILE'] : ((isset($user->lang['USER_PROFILE'])) ? $user->lang['USER_PROFILE'] : '{ USER_PROFILE }')); ?></legend>
	<dl>
		<dt><label for="icq"><?php echo ((isset($this->_rootref['L_UCP_ICQ'])) ? $this->_rootref['L_UCP_ICQ'] : ((isset($user->lang['UCP_ICQ'])) ? $user->lang['UCP_ICQ'] : '{ UCP_ICQ }')); ?>:</label></dt>
		<dd><input type="text" id="icq" name="icq" value="<?php echo (isset($this->_rootref['ICQ'])) ? $this->_rootref['ICQ'] : ''; ?>" /></dd>
	</dl>
	<dl>
		<dt><label for="aim"><?php echo ((isset($this->_rootref['L_UCP_AIM'])) ? $this->_rootref['L_UCP_AIM'] : ((isset($user->lang['UCP_AIM'])) ? $user->lang['UCP_AIM'] : '{ UCP_AIM }')); ?>:</label></dt>
		<dd><input type="text" id="aim" name="aim" value="<?php echo (isset($this->_rootref['AIM'])) ? $this->_rootref['AIM'] : ''; ?>" /></dd>
	</dl>
	<dl>
		<dt><label for="msn"><?php echo ((isset($this->_rootref['L_UCP_MSNM'])) ? $this->_rootref['L_UCP_MSNM'] : ((isset($user->lang['UCP_MSNM'])) ? $user->lang['UCP_MSNM'] : '{ UCP_MSNM }')); ?>:</label></dt>
		<dd><input type="text" id="msn" name="msn" value="<?php echo (isset($this->_rootref['MSN'])) ? $this->_rootref['MSN'] : ''; ?>" /></dd>
	</dl>
	<dl>
		<dt><label for="yim"><?php echo ((isset($this->_rootref['L_UCP_YIM'])) ? $this->_rootref['L_UCP_YIM'] : ((isset($user->lang['UCP_YIM'])) ? $user->lang['UCP_YIM'] : '{ UCP_YIM }')); ?>:</label></dt>
		<dd><input type="text" id="yim" name="yim" value="<?php echo (isset($this->_rootref['YIM'])) ? $this->_rootref['YIM'] : ''; ?>" /></dd>
	</dl>
	<dl>
		<dt><label for="jabber"><?php echo ((isset($this->_rootref['L_UCP_JABBER'])) ? $this->_rootref['L_UCP_JABBER'] : ((isset($user->lang['UCP_JABBER'])) ? $user->lang['UCP_JABBER'] : '{ UCP_JABBER }')); ?>:</label></dt>
		<dd><input type="text" id="jabber" name="jabber" value="<?php echo (isset($this->_rootref['JABBER'])) ? $this->_rootref['JABBER'] : ''; ?>" /></dd>
	</dl>
	<dl>
		<dt><label for="website"><?php echo ((isset($this->_rootref['L_WEBSITE'])) ? $this->_rootref['L_WEBSITE'] : ((isset($user->lang['WEBSITE'])) ? $user->lang['WEBSITE'] : '{ WEBSITE }')); ?>:</label></dt>
		<dd><input type="text" id="website" name="website" value="<?php echo (isset($this->_rootref['WEBSITE'])) ? $this->_rootref['WEBSITE'] : ''; ?>" /></dd>
	</dl>
	<dl>
		<dt><label for="location"><?php echo ((isset($this->_rootref['L_LOCATION'])) ? $this->_rootref['L_LOCATION'] : ((isset($user->lang['LOCATION'])) ? $user->lang['LOCATION'] : '{ LOCATION }')); ?>:</label></dt>
		<dd><input type="text" id="location" name="location" value="<?php echo (isset($this->_rootref['LOCATION'])) ? $this->_rootref['LOCATION'] : ''; ?>" /></dd>
	</dl>
	<dl>
		<dt><label for="occupation"><?php echo ((isset($this->_rootref['L_OCCUPATION'])) ? $this->_rootref['L_OCCUPATION'] : ((isset($user->lang['OCCUPATION'])) ? $user->lang['OCCUPATION'] : '{ OCCUPATION }')); ?>:</label></dt>
		<dd><textarea id="occupation" name="occupation" rows="3" cols="30"><?php echo (isset($this->_rootref['OCCUPATION'])) ? $this->_rootref['OCCUPATION'] : ''; ?></textarea></dd>
	</dl>
	<dl>
		<dt><label for="interests"><?php echo ((isset($this->_rootref['L_INTERESTS'])) ? $this->_rootref['L_INTERESTS'] : ((isset($user->lang['INTERESTS'])) ? $user->lang['INTERESTS'] : '{ INTERESTS }')); ?>:</label></dt>
		<dd><textarea id="interests" name="interests" rows="3" cols="30"><?php echo (isset($this->_rootref['INTERESTS'])) ? $this->_rootref['INTERESTS'] : ''; ?></textarea></dd>
	</dl>
	<dl> 
		<dt><label for="birthday"><?php echo ((isset($this->_rootref['L_BIRTHDAY'])) ? $this->_rootref['L_BIRTHDAY'] : ((isset($user->lang['BIRTHDAY'])) ? $user->lang['BIRTHDAY'] : '{ BIRTHDAY }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_BIRTHDAY_EXPLAIN'])) ? $this->_rootref['L_BIRTHDAY_EXPLAIN'] : ((isset($user->lang['BIRTHDAY_EXPLAIN'])) ? $user->lang['BIRTHDAY_EXPLAIN'] : '{ BIRTHDAY_EXPLAIN }')); ?></span></dt>
		<dd><?php echo ((isset($this->_rootref['L_DAY'])) ? $this->_rootref['L_DAY'] : ((isset($user->lang['DAY'])) ? $user->lang['DAY'] : '{ DAY }')); ?>: <select id="birthday" name="bday_day"><?php echo (isset($this->_rootref['S_BIRTHDAY_DAY_OPTIONS'])) ? $this->_rootref['S_BIRTHDAY_DAY_OPTIONS'] : ''; ?></select> <?php echo ((isset($this->_rootref['L_MONTH'])) ? $this->_rootref['L_MONTH'] : ((isset($user->lang['MONTH'])) ? $user->lang['MONTH'] : '{ MONTH }')); ?>: <select name="bday_month"><?php echo (isset($this->_rootref['S_BIRTHDAY_MONTH_OPTIONS'])) ? $this->_rootref['S_BIRTHDAY_MONTH_OPTIONS'] : ''; ?></select> <?php echo ((isset($this->_rootref['L_YEAR'])) ? $this->_rootref['L_YEAR'] : ((isset($user->lang['YEAR'])) ? $user->lang['YEAR'] : '{ YEAR }')); ?>: <select name="bday_year"><?php echo (isset($this->_rootref['S_BIRTHDAY_YEAR_OPTIONS'])) ? $this->_rootref['S_BIRTHDAY_YEAR_OPTIONS'] : ''; ?></select></dd>
	</dl>
	</fieldset>

	<?php if (sizeof($this->_tpldata['profile_fields'])) {  ?>
		<fieldset>
			<legend><?php echo ((isset($this->_rootref['L_USER_CUSTOM_PROFILE_FIELDS'])) ? $this->_rootref['L_USER_CUSTOM_PROFILE_FIELDS'] : ((isset($user->lang['USER_CUSTOM_PROFILE_FIELDS'])) ? $user->lang['USER_CUSTOM_PROFILE_FIELDS'] : '{ USER_CUSTOM_PROFILE_FIELDS }')); ?></legend>
		<?php $_profile_fields_count = (isset($this->_tpldata['profile_fields'])) ? sizeof($this->_tpldata['profile_fields']) : 0;if ($_profile_fields_count) {for ($_profile_fields_i = 0; $_profile_fields_i < $_profile_fields_count; ++$_profile_fields_i){$_profile_fields_val = &$this->_tpldata['profile_fields'][$_profile_fields_i]; ?>
		<dl> 
			<dt><label<?php if ($_profile_fields_val['FIELD_ID']) {  ?> for="<?php echo $_profile_fields_val['FIELD_ID']; ?>"<?php } ?>><?php echo $_profile_fields_val['LANG_NAME']; ?>:</label><?php if ($_profile_fields_val['LANG_EXPLAIN']) {  ?><br /><span><?php echo $_profile_fields_val['LANG_EXPLAIN']; ?></span><?php } ?></dt>
			<dd><?php echo $_profile_fields_val['FIELD']; ?></dd>
			<?php if ($_profile_fields_val['ERROR']) {  ?>
				<dd><span class="small" style="color: red;"><?php echo $_profile_fields_val['ERROR']; ?></span></dd>
			<?php } ?>
		</dl>
		<?php }} ?>
		</fieldset>
	<?php } ?>

	<fieldset class="quick">
		<input class="button1" type="submit" name="update" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
	</form>
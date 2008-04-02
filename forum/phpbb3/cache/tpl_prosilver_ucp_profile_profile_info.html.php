<?php $this->_tpl_include('ucp_header.html'); ?>

<form id="ucp" method="post" action="<?php echo (isset($this->_rootref['S_UCP_ACTION'])) ? $this->_rootref['S_UCP_ACTION'] : ''; ?>"<?php echo (isset($this->_rootref['S_FORM_ENCTYPE'])) ? $this->_rootref['S_FORM_ENCTYPE'] : ''; ?>>

<h2><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></h2>

<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>
	<p><?php echo ((isset($this->_rootref['L_PROFILE_INFO_NOTICE'])) ? $this->_rootref['L_PROFILE_INFO_NOTICE'] : ((isset($user->lang['PROFILE_INFO_NOTICE'])) ? $user->lang['PROFILE_INFO_NOTICE'] : '{ PROFILE_INFO_NOTICE }')); ?></p>

	<fieldset>
	<?php if ($this->_rootref['ERROR']) {  ?><p class="error"><?php echo (isset($this->_rootref['ERROR'])) ? $this->_rootref['ERROR'] : ''; ?></p><?php } ?>
	<dl>
		<dt><label for="icq"><?php echo ((isset($this->_rootref['L_UCP_ICQ'])) ? $this->_rootref['L_UCP_ICQ'] : ((isset($user->lang['UCP_ICQ'])) ? $user->lang['UCP_ICQ'] : '{ UCP_ICQ }')); ?>:</label></dt>
		<dd><input type="text" name="icq" id="icq" maxlength="15" value="<?php echo (isset($this->_rootref['ICQ'])) ? $this->_rootref['ICQ'] : ''; ?>" class="inputbox" /></dd>
	</dl>
	<dl>
		<dt><label for="aim"><?php echo ((isset($this->_rootref['L_UCP_AIM'])) ? $this->_rootref['L_UCP_AIM'] : ((isset($user->lang['UCP_AIM'])) ? $user->lang['UCP_AIM'] : '{ UCP_AIM }')); ?>:</label></dt>
		<dd><input type="text" name="aim" id="aim" maxlength="255" value="<?php echo (isset($this->_rootref['AIM'])) ? $this->_rootref['AIM'] : ''; ?>" class="inputbox" /></dd>
	</dl>
	<dl>
		<dt><label for="msn"><?php echo ((isset($this->_rootref['L_UCP_MSNM'])) ? $this->_rootref['L_UCP_MSNM'] : ((isset($user->lang['UCP_MSNM'])) ? $user->lang['UCP_MSNM'] : '{ UCP_MSNM }')); ?>:</label></dt>
		<dd><input type="text" name="msn" id="msn" maxlength="255" value="<?php echo (isset($this->_rootref['MSN'])) ? $this->_rootref['MSN'] : ''; ?>" class="inputbox" /></dd>
	</dl>
	<dl>
		<dt><label for="yim"><?php echo ((isset($this->_rootref['L_UCP_YIM'])) ? $this->_rootref['L_UCP_YIM'] : ((isset($user->lang['UCP_YIM'])) ? $user->lang['UCP_YIM'] : '{ UCP_YIM }')); ?>:</label></dt>
		<dd><input type="text" name="yim" id="yim" maxlength="255" value="<?php echo (isset($this->_rootref['YIM'])) ? $this->_rootref['YIM'] : ''; ?>" class="inputbox" /></dd>
	</dl>
	<dl>
		<dt><label for="jabber"><?php echo ((isset($this->_rootref['L_UCP_JABBER'])) ? $this->_rootref['L_UCP_JABBER'] : ((isset($user->lang['UCP_JABBER'])) ? $user->lang['UCP_JABBER'] : '{ UCP_JABBER }')); ?>:</label></dt>
		<dd><input type="text" name="jabber" id="jabber" maxlength="255" value="<?php echo (isset($this->_rootref['JABBER'])) ? $this->_rootref['JABBER'] : ''; ?>" class="inputbox" /></dd>
	</dl>
	<dl>
		<dt><label for="website"><?php echo ((isset($this->_rootref['L_WEBSITE'])) ? $this->_rootref['L_WEBSITE'] : ((isset($user->lang['WEBSITE'])) ? $user->lang['WEBSITE'] : '{ WEBSITE }')); ?>:</label></dt>
		<dd><input type="text" name="website" id="website" maxlength="255" value="<?php echo (isset($this->_rootref['WEBSITE'])) ? $this->_rootref['WEBSITE'] : ''; ?>" class="inputbox" /></dd>
	</dl>
	<dl>
		<dt><label for="location"><?php echo ((isset($this->_rootref['L_LOCATION'])) ? $this->_rootref['L_LOCATION'] : ((isset($user->lang['LOCATION'])) ? $user->lang['LOCATION'] : '{ LOCATION }')); ?>:</label></dt>
		<dd><input type="text" name="location" id="location" maxlength="255" value="<?php echo (isset($this->_rootref['LOCATION'])) ? $this->_rootref['LOCATION'] : ''; ?>" class="inputbox" /></dd>
	</dl>
	<dl>
		<dt><label for="occupation"><?php echo ((isset($this->_rootref['L_OCCUPATION'])) ? $this->_rootref['L_OCCUPATION'] : ((isset($user->lang['OCCUPATION'])) ? $user->lang['OCCUPATION'] : '{ OCCUPATION }')); ?>:</label></dt>
		<dd><textarea name="occupation" id="occupation" class="inputbox" rows="3" cols="30"><?php echo (isset($this->_rootref['OCCUPATION'])) ? $this->_rootref['OCCUPATION'] : ''; ?></textarea></dd>
	</dl>
	<dl>
		<dt><label for="interests"><?php echo ((isset($this->_rootref['L_INTERESTS'])) ? $this->_rootref['L_INTERESTS'] : ((isset($user->lang['INTERESTS'])) ? $user->lang['INTERESTS'] : '{ INTERESTS }')); ?>:</label></dt>
		<dd><textarea name="interests" id="interests" class="inputbox" rows="3" cols="30"><?php echo (isset($this->_rootref['INTERESTS'])) ? $this->_rootref['INTERESTS'] : ''; ?></textarea></dd>
	</dl>
	<?php if ($this->_rootref['S_BIRTHDAYS_ENABLED']) {  ?>
		<dl>
			<dt><label for="bday_day"><?php echo ((isset($this->_rootref['L_BIRTHDAY'])) ? $this->_rootref['L_BIRTHDAY'] : ((isset($user->lang['BIRTHDAY'])) ? $user->lang['BIRTHDAY'] : '{ BIRTHDAY }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_BIRTHDAY_EXPLAIN'])) ? $this->_rootref['L_BIRTHDAY_EXPLAIN'] : ((isset($user->lang['BIRTHDAY_EXPLAIN'])) ? $user->lang['BIRTHDAY_EXPLAIN'] : '{ BIRTHDAY_EXPLAIN }')); ?></span></dt>
			<dd>
				<label for="bday_day"><?php echo ((isset($this->_rootref['L_DAY'])) ? $this->_rootref['L_DAY'] : ((isset($user->lang['DAY'])) ? $user->lang['DAY'] : '{ DAY }')); ?>: <select name="bday_day" id="bday_day" style="width: 4em;"><?php echo (isset($this->_rootref['S_BIRTHDAY_DAY_OPTIONS'])) ? $this->_rootref['S_BIRTHDAY_DAY_OPTIONS'] : ''; ?></select></label> 
				<label for="bday_month"><?php echo ((isset($this->_rootref['L_MONTH'])) ? $this->_rootref['L_MONTH'] : ((isset($user->lang['MONTH'])) ? $user->lang['MONTH'] : '{ MONTH }')); ?>: <select name="bday_month" id="bday_month" style="width: 4em;"><?php echo (isset($this->_rootref['S_BIRTHDAY_MONTH_OPTIONS'])) ? $this->_rootref['S_BIRTHDAY_MONTH_OPTIONS'] : ''; ?></select></label> 
				<label for="bday_year"><?php echo ((isset($this->_rootref['L_YEAR'])) ? $this->_rootref['L_YEAR'] : ((isset($user->lang['YEAR'])) ? $user->lang['YEAR'] : '{ YEAR }')); ?>: <select name="bday_year" id="bday_year" style="width: 6em;"><?php echo (isset($this->_rootref['S_BIRTHDAY_YEAR_OPTIONS'])) ? $this->_rootref['S_BIRTHDAY_YEAR_OPTIONS'] : ''; ?></select></label>
			</dd>
		</dl>
	<?php } $_profile_fields_count = (isset($this->_tpldata['profile_fields'])) ? sizeof($this->_tpldata['profile_fields']) : 0;if ($_profile_fields_count) {for ($_profile_fields_i = 0; $_profile_fields_i < $_profile_fields_count; ++$_profile_fields_i){$_profile_fields_val = &$this->_tpldata['profile_fields'][$_profile_fields_i]; ?>
		<dl>
			<dt><label<?php if ($_profile_fields_val['FIELD_ID']) {  ?> for="<?php echo $_profile_fields_val['FIELD_ID']; ?>"<?php } ?>><?php echo $_profile_fields_val['LANG_NAME']; ?>:<?php if ($_profile_fields_val['S_REQUIRED']) {  ?> *<?php } ?></label>
			<?php if ($_profile_fields_val['LANG_EXPLAIN']) {  ?><br /><span><?php echo $_profile_fields_val['LANG_EXPLAIN']; ?></span><?php } ?></dt>
			<?php if ($_profile_fields_val['ERROR']) {  ?><dd class="error"><?php echo $_profile_fields_val['ERROR']; ?></dd><?php } ?>
			<dd><?php echo $_profile_fields_val['FIELD']; ?></dd>
		</dl>
	<?php }} ?>
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
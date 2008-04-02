<?php $this->_tpl_include('ucp_header.html'); ?>

<table class="tablebg" width="100%" cellspacing="1">
<tr>
	<th colspan="2" valign="middle"><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></th>
</tr>
<?php if ($this->_rootref['ERROR']) {  ?>
	<tr>
		<td class="row3" colspan="2" align="center"><span class="gensmall error"><?php echo (isset($this->_rootref['ERROR'])) ? $this->_rootref['ERROR'] : ''; ?></span></td>
	</tr>
<?php } ?>
<tr> 
	<td class="row1" colspan="2"><span class="gensmall"><?php echo ((isset($this->_rootref['L_PROFILE_INFO_NOTICE'])) ? $this->_rootref['L_PROFILE_INFO_NOTICE'] : ((isset($user->lang['PROFILE_INFO_NOTICE'])) ? $user->lang['PROFILE_INFO_NOTICE'] : '{ PROFILE_INFO_NOTICE }')); ?></span></td>
</tr>
<tr> 
	<td class="row1" width="35%"><b class="genmed"><?php echo ((isset($this->_rootref['L_UCP_ICQ'])) ? $this->_rootref['L_UCP_ICQ'] : ((isset($user->lang['UCP_ICQ'])) ? $user->lang['UCP_ICQ'] : '{ UCP_ICQ }')); ?>: </b></td>
	<td class="row2"><input class="post" type="text" name="icq" size="30" maxlength="15" value="<?php echo (isset($this->_rootref['ICQ'])) ? $this->_rootref['ICQ'] : ''; ?>" /></td>
</tr>
<tr> 
	<td class="row1" width="35%"><b class="genmed"><?php echo ((isset($this->_rootref['L_UCP_AIM'])) ? $this->_rootref['L_UCP_AIM'] : ((isset($user->lang['UCP_AIM'])) ? $user->lang['UCP_AIM'] : '{ UCP_AIM }')); ?>: </b></td>
	<td class="row2"><input class="post" type="text" name="aim" size="30" maxlength="255" value="<?php echo (isset($this->_rootref['AIM'])) ? $this->_rootref['AIM'] : ''; ?>" /></td>
</tr>
<tr> 
	<td class="row1" width="35%"><b class="genmed"><?php echo ((isset($this->_rootref['L_UCP_MSNM'])) ? $this->_rootref['L_UCP_MSNM'] : ((isset($user->lang['UCP_MSNM'])) ? $user->lang['UCP_MSNM'] : '{ UCP_MSNM }')); ?>: </b></td>
	<td class="row2"><input class="post" type="text" name="msn" size="30" maxlength="255" value="<?php echo (isset($this->_rootref['MSN'])) ? $this->_rootref['MSN'] : ''; ?>" /></td>
</tr>
<tr> 
	<td class="row1" width="35%"><b class="genmed"><?php echo ((isset($this->_rootref['L_UCP_YIM'])) ? $this->_rootref['L_UCP_YIM'] : ((isset($user->lang['UCP_YIM'])) ? $user->lang['UCP_YIM'] : '{ UCP_YIM }')); ?>: </b></td>
	<td class="row2"><input class="post" type="text" name="yim" size="30" maxlength="255" value="<?php echo (isset($this->_rootref['YIM'])) ? $this->_rootref['YIM'] : ''; ?>" /></td>
</tr>
<tr> 
	<td class="row1" width="35%"><b class="genmed"><?php echo ((isset($this->_rootref['L_UCP_JABBER'])) ? $this->_rootref['L_UCP_JABBER'] : ((isset($user->lang['UCP_JABBER'])) ? $user->lang['UCP_JABBER'] : '{ UCP_JABBER }')); ?>: </b></td>
	<td class="row2"><input class="post" type="text" name="jabber" size="30" maxlength="255" value="<?php echo (isset($this->_rootref['JABBER'])) ? $this->_rootref['JABBER'] : ''; ?>" /></td>
</tr>
<tr> 
	<td class="row1" width="35%"><b class="genmed"><?php echo ((isset($this->_rootref['L_WEBSITE'])) ? $this->_rootref['L_WEBSITE'] : ((isset($user->lang['WEBSITE'])) ? $user->lang['WEBSITE'] : '{ WEBSITE }')); ?>: </b></td>
	<td class="row2"><input class="post" type="text" name="website" size="30" maxlength="255" value="<?php echo (isset($this->_rootref['WEBSITE'])) ? $this->_rootref['WEBSITE'] : ''; ?>" /></td>
</tr>
<tr> 
	<td class="row1" width="35%"><b class="genmed"><?php echo ((isset($this->_rootref['L_LOCATION'])) ? $this->_rootref['L_LOCATION'] : ((isset($user->lang['LOCATION'])) ? $user->lang['LOCATION'] : '{ LOCATION }')); ?>: </b></td>
	<td class="row2"><input class="post" type="text" name="location" size="30" maxlength="100" value="<?php echo (isset($this->_rootref['LOCATION'])) ? $this->_rootref['LOCATION'] : ''; ?>" /></td>
</tr>
<tr> 
	<td class="row1" width="35%"><b class="genmed"><?php echo ((isset($this->_rootref['L_OCCUPATION'])) ? $this->_rootref['L_OCCUPATION'] : ((isset($user->lang['OCCUPATION'])) ? $user->lang['OCCUPATION'] : '{ OCCUPATION }')); ?>: </b></td>
	<td class="row2"><textarea class="post" name="occupation" rows="3" cols="30"><?php echo (isset($this->_rootref['OCCUPATION'])) ? $this->_rootref['OCCUPATION'] : ''; ?></textarea></td>
</tr>
<tr> 
	<td class="row1" width="35%"><b class="genmed"><?php echo ((isset($this->_rootref['L_INTERESTS'])) ? $this->_rootref['L_INTERESTS'] : ((isset($user->lang['INTERESTS'])) ? $user->lang['INTERESTS'] : '{ INTERESTS }')); ?>: </b></td>
	<td class="row2"><textarea class="post" name="interests" rows="3" cols="30"><?php echo (isset($this->_rootref['INTERESTS'])) ? $this->_rootref['INTERESTS'] : ''; ?></textarea></td>
</tr>
<?php if ($this->_rootref['S_BIRTHDAYS_ENABLED']) {  ?>
	<tr> 
		<td class="row1" width="35%"><b class="genmed"><?php echo ((isset($this->_rootref['L_BIRTHDAY'])) ? $this->_rootref['L_BIRTHDAY'] : ((isset($user->lang['BIRTHDAY'])) ? $user->lang['BIRTHDAY'] : '{ BIRTHDAY }')); ?>: </b><br /><span class="gensmall"><?php echo ((isset($this->_rootref['L_BIRTHDAY_EXPLAIN'])) ? $this->_rootref['L_BIRTHDAY_EXPLAIN'] : ((isset($user->lang['BIRTHDAY_EXPLAIN'])) ? $user->lang['BIRTHDAY_EXPLAIN'] : '{ BIRTHDAY_EXPLAIN }')); ?></span></td>
		<td class="row2"><span class="genmed"><?php echo ((isset($this->_rootref['L_DAY'])) ? $this->_rootref['L_DAY'] : ((isset($user->lang['DAY'])) ? $user->lang['DAY'] : '{ DAY }')); ?>:</span> <select name="bday_day"><?php echo (isset($this->_rootref['S_BIRTHDAY_DAY_OPTIONS'])) ? $this->_rootref['S_BIRTHDAY_DAY_OPTIONS'] : ''; ?></select> <span class="genmed"><?php echo ((isset($this->_rootref['L_MONTH'])) ? $this->_rootref['L_MONTH'] : ((isset($user->lang['MONTH'])) ? $user->lang['MONTH'] : '{ MONTH }')); ?>:</span> <select name="bday_month"><?php echo (isset($this->_rootref['S_BIRTHDAY_MONTH_OPTIONS'])) ? $this->_rootref['S_BIRTHDAY_MONTH_OPTIONS'] : ''; ?></select> <span class="genmed"><?php echo ((isset($this->_rootref['L_YEAR'])) ? $this->_rootref['L_YEAR'] : ((isset($user->lang['YEAR'])) ? $user->lang['YEAR'] : '{ YEAR }')); ?>:</span> <select name="bday_year"><?php echo (isset($this->_rootref['S_BIRTHDAY_YEAR_OPTIONS'])) ? $this->_rootref['S_BIRTHDAY_YEAR_OPTIONS'] : ''; ?></select></td>
	</tr>
<?php } $_profile_fields_count = (isset($this->_tpldata['profile_fields'])) ? sizeof($this->_tpldata['profile_fields']) : 0;if ($_profile_fields_count) {for ($_profile_fields_i = 0; $_profile_fields_i < $_profile_fields_count; ++$_profile_fields_i){$_profile_fields_val = &$this->_tpldata['profile_fields'][$_profile_fields_i]; ?>
	<tr> 
		<td class="row1" width="35%">
			<b class="genmed"><?php echo $_profile_fields_val['LANG_NAME']; ?>: </b>
			<?php if ($_profile_fields_val['S_REQUIRED']) {  ?><b>*</b><?php } if ($_profile_fields_val['LANG_EXPLAIN']) {  ?><br /><span class="gensmall"><?php echo $_profile_fields_val['LANG_EXPLAIN']; ?></span><?php } ?>
		</td>
		<td class="row2"><?php echo $_profile_fields_val['FIELD']; if ($_profile_fields_val['ERROR']) {  ?><br /><span class="gensmall error"><?php echo $_profile_fields_val['ERROR']; ?></span><?php } ?></td>
	</tr>
<?php }} ?>
<tr>
	<td class="cat" colspan="2" align="center"><?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?><input class="btnmain" type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />&nbsp;&nbsp;<input class="btnlite" type="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" name="reset" /></td>
</tr>
</table>

<?php $this->_tpl_include('ucp_footer.html'); ?>
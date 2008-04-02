<?php $this->_tpl_include('ucp_header.html'); ?>

<form id="ucp" method="post" action="<?php echo (isset($this->_rootref['S_UCP_ACTION'])) ? $this->_rootref['S_UCP_ACTION'] : ''; ?>"<?php echo (isset($this->_rootref['S_FORM_ENCTYPE'])) ? $this->_rootref['S_FORM_ENCTYPE'] : ''; ?>>

<h2><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></h2>

<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>

	<fieldset>
	<?php if ($this->_rootref['ERROR']) {  ?><p class="error"><?php echo (isset($this->_rootref['ERROR'])) ? $this->_rootref['ERROR'] : ''; ?></p><?php } ?>
	<dl>
		<dt><label for="viewemail0"><?php echo ((isset($this->_rootref['L_SHOW_EMAIL'])) ? $this->_rootref['L_SHOW_EMAIL'] : ((isset($user->lang['SHOW_EMAIL'])) ? $user->lang['SHOW_EMAIL'] : '{ SHOW_EMAIL }')); ?>:</label></dt>
		<dd>
			<label for="viewemail1"><input type="radio" name="viewemail" id="viewemail1" value="1"<?php if ($this->_rootref['S_VIEW_EMAIL']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label> 
			<label for="viewemail0"><input type="radio" name="viewemail" id="viewemail0" value="0"<?php if (! $this->_rootref['S_VIEW_EMAIL']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label>
		</dd>
	</dl>
	<dl>
		<dt><label for="massemail1"><?php echo ((isset($this->_rootref['L_ADMIN_EMAIL'])) ? $this->_rootref['L_ADMIN_EMAIL'] : ((isset($user->lang['ADMIN_EMAIL'])) ? $user->lang['ADMIN_EMAIL'] : '{ ADMIN_EMAIL }')); ?>:</label></dt>
		<dd>
			<label for="massemail1"><input type="radio" name="massemail" id="massemail1" value="1"<?php if ($this->_rootref['S_MASS_EMAIL']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label> 
			<label for="massemail0"><input type="radio" name="massemail" id="massemail0" value="0"<?php if (! $this->_rootref['S_MASS_EMAIL']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label>
		</dd>
	</dl>
	<dl>
		<dt><label for="allowpm1"><?php echo ((isset($this->_rootref['L_ALLOW_PM'])) ? $this->_rootref['L_ALLOW_PM'] : ((isset($user->lang['ALLOW_PM'])) ? $user->lang['ALLOW_PM'] : '{ ALLOW_PM }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_ALLOW_PM_EXPLAIN'])) ? $this->_rootref['L_ALLOW_PM_EXPLAIN'] : ((isset($user->lang['ALLOW_PM_EXPLAIN'])) ? $user->lang['ALLOW_PM_EXPLAIN'] : '{ ALLOW_PM_EXPLAIN }')); ?></span></dt>
		<dd>
			<label for="allowpm1"><input type="radio" name="allowpm" id="allowpm1" value="1"<?php if ($this->_rootref['S_ALLOW_PM']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label> 
			<label for="allowpm0"><input type="radio" name="allowpm" id="allowpm0" value="0"<?php if (! $this->_rootref['S_ALLOW_PM']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label>
		</dd>
	</dl>
	<?php if ($this->_rootref['S_CAN_HIDE_ONLINE']) {  ?>
		<dl>
			<dt><label for="hideonline0"><?php echo ((isset($this->_rootref['L_HIDE_ONLINE'])) ? $this->_rootref['L_HIDE_ONLINE'] : ((isset($user->lang['HIDE_ONLINE'])) ? $user->lang['HIDE_ONLINE'] : '{ HIDE_ONLINE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_HIDE_ONLINE_EXPLAIN'])) ? $this->_rootref['L_HIDE_ONLINE_EXPLAIN'] : ((isset($user->lang['HIDE_ONLINE_EXPLAIN'])) ? $user->lang['HIDE_ONLINE_EXPLAIN'] : '{ HIDE_ONLINE_EXPLAIN }')); ?></span></dt>
			<dd>
				<label for="hideonline1"><input type="radio" name="hideonline" id="hideonline1" value="1"<?php if ($this->_rootref['S_HIDE_ONLINE']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label> 
				<label for="hideonline0"><input type="radio" name="hideonline" id="hideonline0" value="0"<?php if (! $this->_rootref['S_HIDE_ONLINE']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label>
			</dd>
		</dl>
	<?php } if ($this->_rootref['S_SELECT_NOTIFY']) {  ?>
		<dl>
			<dt><label for="notifymethod0"><?php echo ((isset($this->_rootref['L_NOTIFY_METHOD'])) ? $this->_rootref['L_NOTIFY_METHOD'] : ((isset($user->lang['NOTIFY_METHOD'])) ? $user->lang['NOTIFY_METHOD'] : '{ NOTIFY_METHOD }')); ?>:</label></dt>
			<dd>
				<label for="notifymethod0"><input type="radio" name="notifymethod" id="notifymethod0" value="0"<?php if ($this->_rootref['S_NOTIFY_EMAIL']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NOTIFY_METHOD_EMAIL'])) ? $this->_rootref['L_NOTIFY_METHOD_EMAIL'] : ((isset($user->lang['NOTIFY_METHOD_EMAIL'])) ? $user->lang['NOTIFY_METHOD_EMAIL'] : '{ NOTIFY_METHOD_EMAIL }')); ?></label> 
				<label for="notifymethod1"><input type="radio" name="notifymethod" id="notifymethod1" value="1"<?php if ($this->_rootref['S_NOTIFY_IM']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NOTIFY_METHOD_IM'])) ? $this->_rootref['L_NOTIFY_METHOD_IM'] : ((isset($user->lang['NOTIFY_METHOD_IM'])) ? $user->lang['NOTIFY_METHOD_IM'] : '{ NOTIFY_METHOD_IM }')); ?></label> 
				<label for="notifymethod2"><input type="radio" name="notifymethod" id="notifymethod2" value="2"<?php if ($this->_rootref['S_NOTIFY_BOTH']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NOTIFY_METHOD_BOTH'])) ? $this->_rootref['L_NOTIFY_METHOD_BOTH'] : ((isset($user->lang['NOTIFY_METHOD_BOTH'])) ? $user->lang['NOTIFY_METHOD_BOTH'] : '{ NOTIFY_METHOD_BOTH }')); ?></label>
			</dd>
		</dl>
	<?php } ?>
	<dl>
		<dt><label for="notifypm1"><?php echo ((isset($this->_rootref['L_NOTIFY_ON_PM'])) ? $this->_rootref['L_NOTIFY_ON_PM'] : ((isset($user->lang['NOTIFY_ON_PM'])) ? $user->lang['NOTIFY_ON_PM'] : '{ NOTIFY_ON_PM }')); ?>:</label></dt>
		<dd>
			<label for="notifypm1"><input type="radio" name="notifypm" id="notifypm1" value="1"<?php if ($this->_rootref['S_NOTIFY_PM']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label> 
			<label for="notifypm0"><input type="radio" name="notifypm" id="notifypm0" value="0"<?php if (! $this->_rootref['S_NOTIFY_PM']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label>
		</dd>
	</dl>
	<dl>
		<dt><label for="popuppm0"><?php echo ((isset($this->_rootref['L_POPUP_ON_PM'])) ? $this->_rootref['L_POPUP_ON_PM'] : ((isset($user->lang['POPUP_ON_PM'])) ? $user->lang['POPUP_ON_PM'] : '{ POPUP_ON_PM }')); ?>:</label></dt>
		<dd>
			<label for="popuppm1"><input type="radio" name="popuppm" id="popuppm1" value="1"<?php if ($this->_rootref['S_POPUP_PM']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label> 
			<label for="popuppm0"><input type="radio" name="popuppm" id="popuppm0" value="0"<?php if (! $this->_rootref['S_POPUP_PM']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label>
		</dd>
	</dl>
	<dl>
		<dt><label for="lang"><?php echo ((isset($this->_rootref['L_BOARD_LANGUAGE'])) ? $this->_rootref['L_BOARD_LANGUAGE'] : ((isset($user->lang['BOARD_LANGUAGE'])) ? $user->lang['BOARD_LANGUAGE'] : '{ BOARD_LANGUAGE }')); ?>:</label></dt>
		<dd><select name="lang" id="lang"><?php echo (isset($this->_rootref['S_LANG_OPTIONS'])) ? $this->_rootref['S_LANG_OPTIONS'] : ''; ?></select></dd>
	</dl>
	<?php if ($this->_rootref['S_STYLE_OPTIONS']) {  ?>
		<dl>
			<dt><label for="style"><?php echo ((isset($this->_rootref['L_BOARD_STYLE'])) ? $this->_rootref['L_BOARD_STYLE'] : ((isset($user->lang['BOARD_STYLE'])) ? $user->lang['BOARD_STYLE'] : '{ BOARD_STYLE }')); ?>:</label></dt>
			<dd><select name="style" id="style"><?php echo (isset($this->_rootref['S_STYLE_OPTIONS'])) ? $this->_rootref['S_STYLE_OPTIONS'] : ''; ?></select></dd>
		</dl>
	<?php } ?>
	<dl>
		<dt><label for="timezone"><?php echo ((isset($this->_rootref['L_BOARD_TIMEZONE'])) ? $this->_rootref['L_BOARD_TIMEZONE'] : ((isset($user->lang['BOARD_TIMEZONE'])) ? $user->lang['BOARD_TIMEZONE'] : '{ BOARD_TIMEZONE }')); ?>:</label></dt>
		<dd><select name="tz" id="timezone" class="autowidth"><?php echo (isset($this->_rootref['S_TZ_OPTIONS'])) ? $this->_rootref['S_TZ_OPTIONS'] : ''; ?></select></dd>
	</dl>
	<dl>
		<dt><label for="dst1"><?php echo ((isset($this->_rootref['L_BOARD_DST'])) ? $this->_rootref['L_BOARD_DST'] : ((isset($user->lang['BOARD_DST'])) ? $user->lang['BOARD_DST'] : '{ BOARD_DST }')); ?>:</label></dt>
		<dd>
			<label for="dst1"><input type="radio" name="dst" id="dst1" value="1"<?php if ($this->_rootref['S_DST']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label> 
			<label for="dst0"><input type="radio" name="dst" id="dst0" value="0"<?php if (! $this->_rootref['S_DST']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label>
		</dd>
	</dl>
	<dl>
		<dt><label for="dateformat"><?php echo ((isset($this->_rootref['L_BOARD_DATE_FORMAT'])) ? $this->_rootref['L_BOARD_DATE_FORMAT'] : ((isset($user->lang['BOARD_DATE_FORMAT'])) ? $user->lang['BOARD_DATE_FORMAT'] : '{ BOARD_DATE_FORMAT }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_BOARD_DATE_FORMAT_EXPLAIN'])) ? $this->_rootref['L_BOARD_DATE_FORMAT_EXPLAIN'] : ((isset($user->lang['BOARD_DATE_FORMAT_EXPLAIN'])) ? $user->lang['BOARD_DATE_FORMAT_EXPLAIN'] : '{ BOARD_DATE_FORMAT_EXPLAIN }')); ?></span></dt>
		<dd>
			<select name="dateoptions" id="dateoptions" onchange="if(this.value=='custom'){dE('custom_date',1);}else{dE('custom_date',-1);} if (this.value == 'custom') { document.getElementById('dateformat').value = default_dateformat; } else { document.getElementById('dateformat').value = this.value; }">
				<?php echo (isset($this->_rootref['S_DATEFORMAT_OPTIONS'])) ? $this->_rootref['S_DATEFORMAT_OPTIONS'] : ''; ?>
			</select>
		</dd>
		<dd id="custom_date" style="display:none;"><input type="text" name="dateformat" id="dateformat" value="<?php echo (isset($this->_rootref['DATE_FORMAT'])) ? $this->_rootref['DATE_FORMAT'] : ''; ?>" maxlength="30" class="inputbox narrow" style="margin-top: 3px;" /></dd>
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

<script type="text/javascript">
// <![CDATA[
	var date_format = '<?php echo (isset($this->_rootref['A_DATE_FORMAT'])) ? $this->_rootref['A_DATE_FORMAT'] : ''; ?>';
	var default_dateformat = '<?php echo (isset($this->_rootref['A_DEFAULT_DATEFORMAT'])) ? $this->_rootref['A_DEFAULT_DATEFORMAT'] : ''; ?>';

	function customDates()
	{
		var e = document.getElementById('dateoptions');
	
		e.selectedIndex = e.length - 1;
	
		// Loop and match date_format in menu
		for (var i = 0; i < e.length; i++)
		{
			if (e.options[i].value == date_format)
			{
				e.selectedIndex = i;
				break;
			}
		}
	
		// Show/hide custom field
		if (e.selectedIndex == e.length - 1)
		{
			dE('custom_date',1);
		}
		else
		{
			dE('custom_date',-1);
		}
	}

	customDates();
// ]]>
</script>

<?php $this->_tpl_include('ucp_footer.html'); ?>
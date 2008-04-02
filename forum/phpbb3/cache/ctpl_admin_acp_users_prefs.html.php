<script type="text/javascript">
// <![CDATA[
	var default_dateformat = '<?php echo (isset($this->_rootref['A_DEFAULT_DATEFORMAT'])) ? $this->_rootref['A_DEFAULT_DATEFORMAT'] : ''; ?>';
// ]]>
</script>

	<form id="user_prefs" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_UCP_PREFS_PERSONAL'])) ? $this->_rootref['L_UCP_PREFS_PERSONAL'] : ((isset($user->lang['UCP_PREFS_PERSONAL'])) ? $user->lang['UCP_PREFS_PERSONAL'] : '{ UCP_PREFS_PERSONAL }')); ?></legend>
	<dl> 
		<dt><label for="viewemail"><?php echo ((isset($this->_rootref['L_SHOW_EMAIL'])) ? $this->_rootref['L_SHOW_EMAIL'] : ((isset($user->lang['SHOW_EMAIL'])) ? $user->lang['SHOW_EMAIL'] : '{ SHOW_EMAIL }')); ?>:</label></dt>
		<dd><label><input type="radio" class="radio" name="viewemail" value="1"<?php if ($this->_rootref['VIEW_EMAIL']) {  ?> id="viewemail" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input type="radio" class="radio" name="viewemail" value="0"<?php if (! $this->_rootref['VIEW_EMAIL']) {  ?> id="viewemail" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<dl> 
		<dt><label for="massemail"><?php echo ((isset($this->_rootref['L_ADMIN_EMAIL'])) ? $this->_rootref['L_ADMIN_EMAIL'] : ((isset($user->lang['ADMIN_EMAIL'])) ? $user->lang['ADMIN_EMAIL'] : '{ ADMIN_EMAIL }')); ?>:</label></dt>
		<dd><label><input type="radio" class="radio" name="massemail" value="1"<?php if ($this->_rootref['MASS_EMAIL']) {  ?> id="massemail" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input type="radio" class="radio" name="massemail" value="0"<?php if (! $this->_rootref['MASS_EMAIL']) {  ?> id="massemail" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<dl> 
		<dt><label for="allowpm"><?php echo ((isset($this->_rootref['L_ALLOW_PM'])) ? $this->_rootref['L_ALLOW_PM'] : ((isset($user->lang['ALLOW_PM'])) ? $user->lang['ALLOW_PM'] : '{ ALLOW_PM }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_ALLOW_PM_EXPLAIN'])) ? $this->_rootref['L_ALLOW_PM_EXPLAIN'] : ((isset($user->lang['ALLOW_PM_EXPLAIN'])) ? $user->lang['ALLOW_PM_EXPLAIN'] : '{ ALLOW_PM_EXPLAIN }')); ?></span></dt>
		<dd><label><input type="radio" class="radio" name="allowpm" value="1"<?php if ($this->_rootref['ALLOW_PM']) {  ?> id="allowpm" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input type="radio" class="radio" name="allowpm" value="0"<?php if (! $this->_rootref['ALLOW_PM']) {  ?> id="allowpm" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<dl> 
		<dt><label for="hideonline"><?php echo ((isset($this->_rootref['L_HIDE_ONLINE'])) ? $this->_rootref['L_HIDE_ONLINE'] : ((isset($user->lang['HIDE_ONLINE'])) ? $user->lang['HIDE_ONLINE'] : '{ HIDE_ONLINE }')); ?>:</label></dt>
		<dd><label><input type="radio" class="radio" name="hideonline" value="1"<?php if ($this->_rootref['HIDE_ONLINE']) {  ?> id="hideonline" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input type="radio" class="radio" name="hideonline" value="0"<?php if (! $this->_rootref['HIDE_ONLINE']) {  ?> id="hideonline" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<dl> 
		<dt><label for="notifymethod"><?php echo ((isset($this->_rootref['L_NOTIFY_METHOD'])) ? $this->_rootref['L_NOTIFY_METHOD'] : ((isset($user->lang['NOTIFY_METHOD'])) ? $user->lang['NOTIFY_METHOD'] : '{ NOTIFY_METHOD }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_NOTIFY_METHOD_EXPLAIN'])) ? $this->_rootref['L_NOTIFY_METHOD_EXPLAIN'] : ((isset($user->lang['NOTIFY_METHOD_EXPLAIN'])) ? $user->lang['NOTIFY_METHOD_EXPLAIN'] : '{ NOTIFY_METHOD_EXPLAIN }')); ?></span></dt>
		<dd><label><input type="radio" class="radio" name="notifymethod" value="0"<?php if ($this->_rootref['NOTIFY_EMAIL']) {  ?> id="notifymethod" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NOTIFY_METHOD_EMAIL'])) ? $this->_rootref['L_NOTIFY_METHOD_EMAIL'] : ((isset($user->lang['NOTIFY_METHOD_EMAIL'])) ? $user->lang['NOTIFY_METHOD_EMAIL'] : '{ NOTIFY_METHOD_EMAIL }')); ?></label>
			<label><input type="radio" class="radio" name="notifymethod" value="1"<?php if ($this->_rootref['NOTIFY_IM']) {  ?> id="notifymethod" checked="checked"<?php } if ($this->_rootref['S_JABBER_DISABLED']) {  ?> disabled="disabled"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NOTIFY_METHOD_IM'])) ? $this->_rootref['L_NOTIFY_METHOD_IM'] : ((isset($user->lang['NOTIFY_METHOD_IM'])) ? $user->lang['NOTIFY_METHOD_IM'] : '{ NOTIFY_METHOD_IM }')); ?></label>
			<label><input type="radio" class="radio" name="notifymethod" value="2"<?php if ($this->_rootref['NOTIFY_BOTH']) {  ?> id="notifymethod" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NOTIFY_METHOD_BOTH'])) ? $this->_rootref['L_NOTIFY_METHOD_BOTH'] : ((isset($user->lang['NOTIFY_METHOD_BOTH'])) ? $user->lang['NOTIFY_METHOD_BOTH'] : '{ NOTIFY_METHOD_BOTH }')); ?></label></dd>
	</dl>
	<dl> 
		<dt><label for="notifypm"><?php echo ((isset($this->_rootref['L_NOTIFY_ON_PM'])) ? $this->_rootref['L_NOTIFY_ON_PM'] : ((isset($user->lang['NOTIFY_ON_PM'])) ? $user->lang['NOTIFY_ON_PM'] : '{ NOTIFY_ON_PM }')); ?>:</label></dt>
		<dd><label><input type="radio" class="radio" name="notifypm" value="1"<?php if ($this->_rootref['NOTIFY_PM']) {  ?> id="notifypm" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input type="radio" class="radio" name="notifypm" value="0"<?php if (! $this->_rootref['NOTIFY_PM']) {  ?> id="notifypm" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<dl> 
		<dt><label for="popuppm"><?php echo ((isset($this->_rootref['L_POPUP_ON_PM'])) ? $this->_rootref['L_POPUP_ON_PM'] : ((isset($user->lang['POPUP_ON_PM'])) ? $user->lang['POPUP_ON_PM'] : '{ POPUP_ON_PM }')); ?>:</label></dt>
		<dd><label><input type="radio" class="radio" name="popuppm" value="1"<?php if ($this->_rootref['POPUP_PM']) {  ?> id="popuppm" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input type="radio" class="radio" name="popuppm" value="0"<?php if (! $this->_rootref['POPUP_PM']) {  ?> id="popuppm" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<dl> 
		<dt><label for="lang"><?php echo ((isset($this->_rootref['L_BOARD_LANGUAGE'])) ? $this->_rootref['L_BOARD_LANGUAGE'] : ((isset($user->lang['BOARD_LANGUAGE'])) ? $user->lang['BOARD_LANGUAGE'] : '{ BOARD_LANGUAGE }')); ?>:</label></dt>
		<dd><select id="lang" name="lang"><?php echo (isset($this->_rootref['S_LANG_OPTIONS'])) ? $this->_rootref['S_LANG_OPTIONS'] : ''; ?></select></dd>
	</dl>
	<dl> 
		<dt><label for="style"><?php echo ((isset($this->_rootref['L_BOARD_STYLE'])) ? $this->_rootref['L_BOARD_STYLE'] : ((isset($user->lang['BOARD_STYLE'])) ? $user->lang['BOARD_STYLE'] : '{ BOARD_STYLE }')); ?>:</label></dt>
		<dd><select id="style" name="style"><?php echo (isset($this->_rootref['S_STYLE_OPTIONS'])) ? $this->_rootref['S_STYLE_OPTIONS'] : ''; ?></select></dd>
	</dl>
	<dl> 
		<dt><label for="tz"><?php echo ((isset($this->_rootref['L_BOARD_TIMEZONE'])) ? $this->_rootref['L_BOARD_TIMEZONE'] : ((isset($user->lang['BOARD_TIMEZONE'])) ? $user->lang['BOARD_TIMEZONE'] : '{ BOARD_TIMEZONE }')); ?>:</label></dt>
		<dd><select id="tz" name="tz" style="width: 100%;"><?php echo (isset($this->_rootref['S_TZ_OPTIONS'])) ? $this->_rootref['S_TZ_OPTIONS'] : ''; ?></select></dd>
	</dl>
	<dl> 
		<dt><label for="dst"><?php echo ((isset($this->_rootref['L_BOARD_DST'])) ? $this->_rootref['L_BOARD_DST'] : ((isset($user->lang['BOARD_DST'])) ? $user->lang['BOARD_DST'] : '{ BOARD_DST }')); ?>:</label></dt>
		<dd><label><input type="radio" class="radio" name="dst" value="1"<?php if ($this->_rootref['DST']) {  ?> id="dst" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input type="radio" class="radio" name="dst" value="0"<?php if (! $this->_rootref['DST']) {  ?> id="dst" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<dl> 
		<dt><label for="dateoptions"><?php echo ((isset($this->_rootref['L_BOARD_DATE_FORMAT'])) ? $this->_rootref['L_BOARD_DATE_FORMAT'] : ((isset($user->lang['BOARD_DATE_FORMAT'])) ? $user->lang['BOARD_DATE_FORMAT'] : '{ BOARD_DATE_FORMAT }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_BOARD_DATE_FORMAT_EXPLAIN'])) ? $this->_rootref['L_BOARD_DATE_FORMAT_EXPLAIN'] : ((isset($user->lang['BOARD_DATE_FORMAT_EXPLAIN'])) ? $user->lang['BOARD_DATE_FORMAT_EXPLAIN'] : '{ BOARD_DATE_FORMAT_EXPLAIN }')); ?></span></dt>
		<dd><select name="dateoptions" id="dateoptions" onchange="if(this.value=='custom'){dE('custom_date',1);}else{dE('custom_date',-1);} if (this.value == 'custom') { document.getElementById('dateformat').value = default_dateformat; } else { document.getElementById('dateformat').value = this.value; }"><?php echo (isset($this->_rootref['S_DATEFORMAT_OPTIONS'])) ? $this->_rootref['S_DATEFORMAT_OPTIONS'] : ''; ?></select></dd>
		<dd><div id="custom_date"<?php if (! $this->_rootref['S_CUSTOM_DATEFORMAT']) {  ?> style="display:none;"<?php } ?>><input type="text" name="dateformat" id="dateformat" value="<?php echo (isset($this->_rootref['DATE_FORMAT'])) ? $this->_rootref['DATE_FORMAT'] : ''; ?>" maxlength="30" /></div></dd>
	</dl>
	</fieldset>

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_UCP_PREFS_POST'])) ? $this->_rootref['L_UCP_PREFS_POST'] : ((isset($user->lang['UCP_PREFS_POST'])) ? $user->lang['UCP_PREFS_POST'] : '{ UCP_PREFS_POST }')); ?></legend>
	<dl> 
		<dt><label for="bbcode"><?php echo ((isset($this->_rootref['L_DEFAULT_BBCODE'])) ? $this->_rootref['L_DEFAULT_BBCODE'] : ((isset($user->lang['DEFAULT_BBCODE'])) ? $user->lang['DEFAULT_BBCODE'] : '{ DEFAULT_BBCODE }')); ?>:</label></dt>
		<dd><label><input type="radio" class="radio" name="bbcode" value="1"<?php if ($this->_rootref['BBCODE']) {  ?> id="bbcode" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input type="radio" class="radio" name="bbcode" value="0"<?php if (! $this->_rootref['BBCODE']) {  ?> id="bbcode" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<dl> 
		<dt><label for="smilies"><?php echo ((isset($this->_rootref['L_DEFAULT_SMILIES'])) ? $this->_rootref['L_DEFAULT_SMILIES'] : ((isset($user->lang['DEFAULT_SMILIES'])) ? $user->lang['DEFAULT_SMILIES'] : '{ DEFAULT_SMILIES }')); ?>:</label></dt>
		<dd><label><input type="radio" class="radio" name="smilies" value="1"<?php if ($this->_rootref['SMILIES']) {  ?> id="smilies" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input type="radio" class="radio" name="smilies" value="0"<?php if (! $this->_rootref['SMILIES']) {  ?> id="smilies" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<dl> 
		<dt><label for="sig"><?php echo ((isset($this->_rootref['L_DEFAULT_ADD_SIG'])) ? $this->_rootref['L_DEFAULT_ADD_SIG'] : ((isset($user->lang['DEFAULT_ADD_SIG'])) ? $user->lang['DEFAULT_ADD_SIG'] : '{ DEFAULT_ADD_SIG }')); ?>:</label></dt>
		<dd><label><input type="radio" class="radio" name="sig" value="1"<?php if ($this->_rootref['ATTACH_SIG']) {  ?> id="sig" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input type="radio" class="radio" name="sig" value="0"<?php if (! $this->_rootref['ATTACH_SIG']) {  ?> id="sig" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<dl> 
		<dt><label for="notify"><?php echo ((isset($this->_rootref['L_DEFAULT_NOTIFY'])) ? $this->_rootref['L_DEFAULT_NOTIFY'] : ((isset($user->lang['DEFAULT_NOTIFY'])) ? $user->lang['DEFAULT_NOTIFY'] : '{ DEFAULT_NOTIFY }')); ?>:</label></dt>
		<dd><label><input type="radio" class="radio" name="notify" value="1"<?php if ($this->_rootref['NOTIFY']) {  ?> id="notify" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input type="radio" class="radio" name="notify" value="0"<?php if (! $this->_rootref['NOTIFY']) {  ?> id="notify" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	</fieldset>

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_UCP_PREFS_VIEW'])) ? $this->_rootref['L_UCP_PREFS_VIEW'] : ((isset($user->lang['UCP_PREFS_VIEW'])) ? $user->lang['UCP_PREFS_VIEW'] : '{ UCP_PREFS_VIEW }')); ?></legend>
	<dl> 
		<dt><label for="view_images"><?php echo ((isset($this->_rootref['L_VIEW_IMAGES'])) ? $this->_rootref['L_VIEW_IMAGES'] : ((isset($user->lang['VIEW_IMAGES'])) ? $user->lang['VIEW_IMAGES'] : '{ VIEW_IMAGES }')); ?>:</label></dt>
		<dd><label><input type="radio" class="radio" name="view_images" value="1"<?php if ($this->_rootref['VIEW_IMAGES']) {  ?> id="view_images" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input type="radio" class="radio" name="view_images" value="0"<?php if (! $this->_rootref['VIEW_IMAGES']) {  ?> id="view_images" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<dl> 
		<dt><label for="view_flash"><?php echo ((isset($this->_rootref['L_VIEW_FLASH'])) ? $this->_rootref['L_VIEW_FLASH'] : ((isset($user->lang['VIEW_FLASH'])) ? $user->lang['VIEW_FLASH'] : '{ VIEW_FLASH }')); ?>:</label></dt>
		<dd><label><input type="radio" class="radio" name="view_flash" value="1"<?php if ($this->_rootref['VIEW_FLASH']) {  ?> id="view_flash" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input type="radio" class="radio" name="view_flash" value="0"<?php if (! $this->_rootref['VIEW_FLASH']) {  ?> id="view_flash" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<dl> 
		<dt><label for="view_smilies"><?php echo ((isset($this->_rootref['L_VIEW_SMILIES'])) ? $this->_rootref['L_VIEW_SMILIES'] : ((isset($user->lang['VIEW_SMILIES'])) ? $user->lang['VIEW_SMILIES'] : '{ VIEW_SMILIES }')); ?>:</label></dt>
		<dd><label><input type="radio" class="radio" name="view_smilies" value="1"<?php if ($this->_rootref['VIEW_SMILIES']) {  ?> id="view_smilies" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input type="radio" class="radio" name="view_smilies" value="0"<?php if (! $this->_rootref['VIEW_SMILIES']) {  ?> id="view_smilies" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<dl> 
		<dt><label for="view_sigs"><?php echo ((isset($this->_rootref['L_VIEW_SIGS'])) ? $this->_rootref['L_VIEW_SIGS'] : ((isset($user->lang['VIEW_SIGS'])) ? $user->lang['VIEW_SIGS'] : '{ VIEW_SIGS }')); ?>:</label></dt>
		<dd><label><input type="radio" class="radio" name="view_sigs" value="1"<?php if ($this->_rootref['VIEW_SIGS']) {  ?> id="view_sigs" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input type="radio" class="radio" name="view_sigs" value="0"<?php if (! $this->_rootref['VIEW_SIGS']) {  ?> id="view_sigss" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<dl> 
		<dt><label for="view_avatars"><?php echo ((isset($this->_rootref['L_VIEW_AVATARS'])) ? $this->_rootref['L_VIEW_AVATARS'] : ((isset($user->lang['VIEW_AVATARS'])) ? $user->lang['VIEW_AVATARS'] : '{ VIEW_AVATARS }')); ?>:</label></dt>
		<dd><label><input type="radio" class="radio" name="view_avatars" value="1"<?php if ($this->_rootref['VIEW_AVATARS']) {  ?> id="view_avatars" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input type="radio" class="radio" name="view_avatars" value="0"<?php if (! $this->_rootref['VIEW_AVATARS']) {  ?> id="view_avatars" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<dl> 
		<dt><label for="view_wordcensor"><?php echo ((isset($this->_rootref['L_DISABLE_CENSORS'])) ? $this->_rootref['L_DISABLE_CENSORS'] : ((isset($user->lang['DISABLE_CENSORS'])) ? $user->lang['DISABLE_CENSORS'] : '{ DISABLE_CENSORS }')); ?>:</label></dt>
		<dd><label><input type="radio" class="radio" name="view_wordcensor" value="1"<?php if ($this->_rootref['VIEW_WORDCENSOR']) {  ?> id="view_wordcensor" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input type="radio" class="radio" name="view_wordcensor" value="0"<?php if (! $this->_rootref['VIEW_WORDCENSOR']) {  ?> id="view_wordcensor" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<dl> 
		<dt><label><?php echo ((isset($this->_rootref['L_VIEW_TOPICS_DAYS'])) ? $this->_rootref['L_VIEW_TOPICS_DAYS'] : ((isset($user->lang['VIEW_TOPICS_DAYS'])) ? $user->lang['VIEW_TOPICS_DAYS'] : '{ VIEW_TOPICS_DAYS }')); ?>:</label></dt>
		<dd><?php echo (isset($this->_rootref['S_TOPIC_SORT_DAYS'])) ? $this->_rootref['S_TOPIC_SORT_DAYS'] : ''; ?></dd>
	</dl>
	<dl> 
		<dt><label><?php echo ((isset($this->_rootref['L_VIEW_TOPICS_KEY'])) ? $this->_rootref['L_VIEW_TOPICS_KEY'] : ((isset($user->lang['VIEW_TOPICS_KEY'])) ? $user->lang['VIEW_TOPICS_KEY'] : '{ VIEW_TOPICS_KEY }')); ?>:</label></dt>
		<dd><?php echo (isset($this->_rootref['S_TOPIC_SORT_KEY'])) ? $this->_rootref['S_TOPIC_SORT_KEY'] : ''; ?></dd>
	</dl>
	<dl> 
		<dt><label><?php echo ((isset($this->_rootref['L_VIEW_TOPICS_DIR'])) ? $this->_rootref['L_VIEW_TOPICS_DIR'] : ((isset($user->lang['VIEW_TOPICS_DIR'])) ? $user->lang['VIEW_TOPICS_DIR'] : '{ VIEW_TOPICS_DIR }')); ?>:</label></dt>
		<dd><?php echo (isset($this->_rootref['S_TOPIC_SORT_DIR'])) ? $this->_rootref['S_TOPIC_SORT_DIR'] : ''; ?></dd>
	</dl>
	<dl> 
		<dt><label><?php echo ((isset($this->_rootref['L_VIEW_POSTS_DAYS'])) ? $this->_rootref['L_VIEW_POSTS_DAYS'] : ((isset($user->lang['VIEW_POSTS_DAYS'])) ? $user->lang['VIEW_POSTS_DAYS'] : '{ VIEW_POSTS_DAYS }')); ?>:</label></dt>
		<dd><?php echo (isset($this->_rootref['S_POST_SORT_DAYS'])) ? $this->_rootref['S_POST_SORT_DAYS'] : ''; ?></dd>
	</dl>
	<dl> 
		<dt><label><?php echo ((isset($this->_rootref['L_VIEW_POSTS_KEY'])) ? $this->_rootref['L_VIEW_POSTS_KEY'] : ((isset($user->lang['VIEW_POSTS_KEY'])) ? $user->lang['VIEW_POSTS_KEY'] : '{ VIEW_POSTS_KEY }')); ?>:</label></dt>
		<dd><?php echo (isset($this->_rootref['S_POST_SORT_KEY'])) ? $this->_rootref['S_POST_SORT_KEY'] : ''; ?></dd>
	</dl>
	<dl> 
		<dt><label><?php echo ((isset($this->_rootref['L_VIEW_POSTS_DIR'])) ? $this->_rootref['L_VIEW_POSTS_DIR'] : ((isset($user->lang['VIEW_POSTS_DIR'])) ? $user->lang['VIEW_POSTS_DIR'] : '{ VIEW_POSTS_DIR }')); ?>:</label></dt>
		<dd><?php echo (isset($this->_rootref['S_POST_SORT_DIR'])) ? $this->_rootref['S_POST_SORT_DIR'] : ''; ?></dd>
	</dl>
	</fieldset>

	<fieldset class="quick">
		<input class="button1" type="submit" name="update" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>

	</form>
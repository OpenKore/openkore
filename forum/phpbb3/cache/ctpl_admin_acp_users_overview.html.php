<form id="user_overview" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

<fieldset>
	<legend><?php echo ((isset($this->_rootref['L_ACP_USER_OVERVIEW'])) ? $this->_rootref['L_ACP_USER_OVERVIEW'] : ((isset($user->lang['ACP_USER_OVERVIEW'])) ? $user->lang['ACP_USER_OVERVIEW'] : '{ ACP_USER_OVERVIEW }')); ?></legend>
<dl>
	<dt><label for="user"><?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_NAME_CHARS_EXPLAIN'])) ? $this->_rootref['L_NAME_CHARS_EXPLAIN'] : ((isset($user->lang['NAME_CHARS_EXPLAIN'])) ? $user->lang['NAME_CHARS_EXPLAIN'] : '{ NAME_CHARS_EXPLAIN }')); ?></span></dt>
	<dd><input type="text" id="user" name="user" value="<?php echo (isset($this->_rootref['USER'])) ? $this->_rootref['USER'] : ''; ?>" /></dd>
	<?php if ($this->_rootref['U_SWITCH_PERMISSIONS']) {  ?><dd>[ <a href="<?php echo (isset($this->_rootref['U_SWITCH_PERMISSIONS'])) ? $this->_rootref['U_SWITCH_PERMISSIONS'] : ''; ?>"><?php echo ((isset($this->_rootref['L_USE_PERMISSIONS'])) ? $this->_rootref['L_USE_PERMISSIONS'] : ((isset($user->lang['USE_PERMISSIONS'])) ? $user->lang['USE_PERMISSIONS'] : '{ USE_PERMISSIONS }')); ?></a> ]</dd><?php } ?>
</dl>
<?php if ($this->_rootref['S_USER_INACTIVE']) {  ?>
<dl>
	<dt><label><?php echo ((isset($this->_rootref['L_USER_IS_INACTIVE'])) ? $this->_rootref['L_USER_IS_INACTIVE'] : ((isset($user->lang['USER_IS_INACTIVE'])) ? $user->lang['USER_IS_INACTIVE'] : '{ USER_IS_INACTIVE }')); ?>:</label></dt>
	<dd><strong><?php echo (isset($this->_rootref['USER_INACTIVE_REASON'])) ? $this->_rootref['USER_INACTIVE_REASON'] : ''; ?></strong></dd>
</dl>
<?php } ?>
<dl>
	<dt><label><?php echo ((isset($this->_rootref['L_REGISTERED'])) ? $this->_rootref['L_REGISTERED'] : ((isset($user->lang['REGISTERED'])) ? $user->lang['REGISTERED'] : '{ REGISTERED }')); ?>:</label></dt>
	<dd><strong><?php echo (isset($this->_rootref['USER_REGISTERED'])) ? $this->_rootref['USER_REGISTERED'] : ''; ?></strong></dd>
</dl>
<?php if ($this->_rootref['S_USER_IP']) {  ?>
<dl>
	<dt><label><?php echo ((isset($this->_rootref['L_REGISTERED_IP'])) ? $this->_rootref['L_REGISTERED_IP'] : ((isset($user->lang['REGISTERED_IP'])) ? $user->lang['REGISTERED_IP'] : '{ REGISTERED_IP }')); ?>:</label></dt>
	<dd><a href="<?php echo (isset($this->_rootref['U_SHOW_IP'])) ? $this->_rootref['U_SHOW_IP'] : ''; ?>"><?php echo (isset($this->_rootref['REGISTERED_IP'])) ? $this->_rootref['REGISTERED_IP'] : ''; ?></a></dd>
	<dd>[ <a href="<?php echo (isset($this->_rootref['U_WHOIS'])) ? $this->_rootref['U_WHOIS'] : ''; ?>" onclick="popup(this.href, 700, 500, '_whois'); return false;"><?php echo ((isset($this->_rootref['L_WHOIS'])) ? $this->_rootref['L_WHOIS'] : ((isset($user->lang['WHOIS'])) ? $user->lang['WHOIS'] : '{ WHOIS }')); ?></a> ]</dd>
</dl>
<?php } ?>
<dl>
	<dt><label><?php echo ((isset($this->_rootref['L_LAST_ACTIVE'])) ? $this->_rootref['L_LAST_ACTIVE'] : ((isset($user->lang['LAST_ACTIVE'])) ? $user->lang['LAST_ACTIVE'] : '{ LAST_ACTIVE }')); ?>:</label></dt>
	<dd><strong><?php echo (isset($this->_rootref['USER_LASTACTIVE'])) ? $this->_rootref['USER_LASTACTIVE'] : ''; ?></strong></dd>
</dl>
<dl>
	<dt><label><?php echo ((isset($this->_rootref['L_POSTS'])) ? $this->_rootref['L_POSTS'] : ((isset($user->lang['POSTS'])) ? $user->lang['POSTS'] : '{ POSTS }')); ?>:</label></dt>
	<dd><strong><?php echo (isset($this->_rootref['USER_POSTS'])) ? $this->_rootref['USER_POSTS'] : ''; ?></strong></dd>
</dl>
<dl>
	<dt><label><?php echo ((isset($this->_rootref['L_WARNINGS'])) ? $this->_rootref['L_WARNINGS'] : ((isset($user->lang['WARNINGS'])) ? $user->lang['WARNINGS'] : '{ WARNINGS }')); ?>:</label></dt>
	<dd><strong><?php echo (isset($this->_rootref['USER_WARNINGS'])) ? $this->_rootref['USER_WARNINGS'] : ''; ?></strong></dd>
</dl>
<dl>
	<dt><label for="user_founder"><?php echo ((isset($this->_rootref['L_FOUNDER'])) ? $this->_rootref['L_FOUNDER'] : ((isset($user->lang['FOUNDER'])) ? $user->lang['FOUNDER'] : '{ FOUNDER }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_FOUNDER_EXPLAIN'])) ? $this->_rootref['L_FOUNDER_EXPLAIN'] : ((isset($user->lang['FOUNDER_EXPLAIN'])) ? $user->lang['FOUNDER_EXPLAIN'] : '{ FOUNDER_EXPLAIN }')); ?></span></dt>
	<dd><label><input type="radio" class="radio" name="user_founder" value="1"<?php if ($this->_rootref['S_USER_FOUNDER']) {  ?> id="user_founder" checked="checked"<?php } if (! $this->_rootref['S_FOUNDER']) {  ?> disabled="disabled"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
		<label><input type="radio" class="radio" name="user_founder" value="0"<?php if (! $this->_rootref['S_USER_FOUNDER']) {  ?> id="user_founder" checked="checked"<?php } if (! $this->_rootref['S_FOUNDER']) {  ?> disabled="disabled"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
</dl>
<dl>
	<dt><label for="user_email"><?php echo ((isset($this->_rootref['L_EMAIL'])) ? $this->_rootref['L_EMAIL'] : ((isset($user->lang['EMAIL'])) ? $user->lang['EMAIL'] : '{ EMAIL }')); ?>:</label></dt>
	<dd><input class="text medium" type="text" id="user_email" name="user_email" value="<?php echo (isset($this->_rootref['USER_EMAIL'])) ? $this->_rootref['USER_EMAIL'] : ''; ?>" /></dd>
</dl>
<dl>
	<dt><label for="email_confirm"><?php echo ((isset($this->_rootref['L_CONFIRM_EMAIL'])) ? $this->_rootref['L_CONFIRM_EMAIL'] : ((isset($user->lang['CONFIRM_EMAIL'])) ? $user->lang['CONFIRM_EMAIL'] : '{ CONFIRM_EMAIL }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_CONFIRM_EMAIL_EXPLAIN'])) ? $this->_rootref['L_CONFIRM_EMAIL_EXPLAIN'] : ((isset($user->lang['CONFIRM_EMAIL_EXPLAIN'])) ? $user->lang['CONFIRM_EMAIL_EXPLAIN'] : '{ CONFIRM_EMAIL_EXPLAIN }')); ?></span></dt>
	<dd><input class="text medium" type="text" id="email_confirm" name="email_confirm" value="" /></dd>
</dl>
<dl>
	<dt><label for="new_password"><?php echo ((isset($this->_rootref['L_NEW_PASSWORD'])) ? $this->_rootref['L_NEW_PASSWORD'] : ((isset($user->lang['NEW_PASSWORD'])) ? $user->lang['NEW_PASSWORD'] : '{ NEW_PASSWORD }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_CHANGE_PASSWORD_EXPLAIN'])) ? $this->_rootref['L_CHANGE_PASSWORD_EXPLAIN'] : ((isset($user->lang['CHANGE_PASSWORD_EXPLAIN'])) ? $user->lang['CHANGE_PASSWORD_EXPLAIN'] : '{ CHANGE_PASSWORD_EXPLAIN }')); ?></span></dt>
	<dd><input type="password" id="new_password" name="new_password" value="" /></dd>
</dl>
<dl>
	<dt><label for="password_confirm"><?php echo ((isset($this->_rootref['L_CONFIRM_PASSWORD'])) ? $this->_rootref['L_CONFIRM_PASSWORD'] : ((isset($user->lang['CONFIRM_PASSWORD'])) ? $user->lang['CONFIRM_PASSWORD'] : '{ CONFIRM_PASSWORD }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_CONFIRM_PASSWORD_EXPLAIN'])) ? $this->_rootref['L_CONFIRM_PASSWORD_EXPLAIN'] : ((isset($user->lang['CONFIRM_PASSWORD_EXPLAIN'])) ? $user->lang['CONFIRM_PASSWORD_EXPLAIN'] : '{ CONFIRM_PASSWORD_EXPLAIN }')); ?></span></dt>
	<dd><input type="password" id="password_confirm" name="password_confirm" value="" /></dd>
</dl>

<p class="quick">
	<input class="button1" type="submit" name="update" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />
	<input type="hidden" name="action" value="" />
	<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
</p>

</fieldset>
</form>

<?php if (! $this->_rootref['S_USER_FOUNDER'] || $this->_rootref['S_FOUNDER']) {  ?>

	<script type="text/javascript">
	// <![CDATA[

		function display_reason(option)
		{
			if (option != 'banuser' && option != 'banemail' && option != 'banip')
			{
				dE('reasons', -1);
				return;
			}

			dE('reasons', 1);

			element = document.getElementById('user_quick_tools').ban_reason;

			if (element.value && element.value != '<?php echo ((isset($this->_rootref['LA_USER_ADMIN_BAN_NAME_REASON'])) ? $this->_rootref['LA_USER_ADMIN_BAN_NAME_REASON'] : ((isset($this->_rootref['L_USER_ADMIN_BAN_NAME_REASON'])) ? addslashes($this->_rootref['L_USER_ADMIN_BAN_NAME_REASON']) : ((isset($user->lang['USER_ADMIN_BAN_NAME_REASON'])) ? addslashes($user->lang['USER_ADMIN_BAN_NAME_REASON']) : '{ USER_ADMIN_BAN_NAME_REASON }'))); ?>' && element.value != '<?php echo ((isset($this->_rootref['LA_USER_ADMIN_BAN_EMAIL_REASON'])) ? $this->_rootref['LA_USER_ADMIN_BAN_EMAIL_REASON'] : ((isset($this->_rootref['L_USER_ADMIN_BAN_EMAIL_REASON'])) ? addslashes($this->_rootref['L_USER_ADMIN_BAN_EMAIL_REASON']) : ((isset($user->lang['USER_ADMIN_BAN_EMAIL_REASON'])) ? addslashes($user->lang['USER_ADMIN_BAN_EMAIL_REASON']) : '{ USER_ADMIN_BAN_EMAIL_REASON }'))); ?>' && element.value != '<?php echo ((isset($this->_rootref['LA_USER_ADMIN_BAN_IP_REASON'])) ? $this->_rootref['LA_USER_ADMIN_BAN_IP_REASON'] : ((isset($this->_rootref['L_USER_ADMIN_BAN_IP_REASON'])) ? addslashes($this->_rootref['L_USER_ADMIN_BAN_IP_REASON']) : ((isset($user->lang['USER_ADMIN_BAN_IP_REASON'])) ? addslashes($user->lang['USER_ADMIN_BAN_IP_REASON']) : '{ USER_ADMIN_BAN_IP_REASON }'))); ?>')
			{
				return;
			}

			if (option == 'banuser')
			{
				element.value = '<?php echo ((isset($this->_rootref['LA_USER_ADMIN_BAN_NAME_REASON'])) ? $this->_rootref['LA_USER_ADMIN_BAN_NAME_REASON'] : ((isset($this->_rootref['L_USER_ADMIN_BAN_NAME_REASON'])) ? addslashes($this->_rootref['L_USER_ADMIN_BAN_NAME_REASON']) : ((isset($user->lang['USER_ADMIN_BAN_NAME_REASON'])) ? addslashes($user->lang['USER_ADMIN_BAN_NAME_REASON']) : '{ USER_ADMIN_BAN_NAME_REASON }'))); ?>';
			}
			else if (option == 'banemail')
			{
				element.value = '<?php echo ((isset($this->_rootref['LA_USER_ADMIN_BAN_EMAIL_REASON'])) ? $this->_rootref['LA_USER_ADMIN_BAN_EMAIL_REASON'] : ((isset($this->_rootref['L_USER_ADMIN_BAN_EMAIL_REASON'])) ? addslashes($this->_rootref['L_USER_ADMIN_BAN_EMAIL_REASON']) : ((isset($user->lang['USER_ADMIN_BAN_EMAIL_REASON'])) ? addslashes($user->lang['USER_ADMIN_BAN_EMAIL_REASON']) : '{ USER_ADMIN_BAN_EMAIL_REASON }'))); ?>';
			}
			else if (option == 'banip')
			{
				element.value = '<?php echo ((isset($this->_rootref['LA_USER_ADMIN_BAN_IP_REASON'])) ? $this->_rootref['LA_USER_ADMIN_BAN_IP_REASON'] : ((isset($this->_rootref['L_USER_ADMIN_BAN_IP_REASON'])) ? addslashes($this->_rootref['L_USER_ADMIN_BAN_IP_REASON']) : ((isset($user->lang['USER_ADMIN_BAN_IP_REASON'])) ? addslashes($user->lang['USER_ADMIN_BAN_IP_REASON']) : '{ USER_ADMIN_BAN_IP_REASON }'))); ?>';
			}
		}

	// ]]>
	</script>

	<form id="user_quick_tools" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_USER_TOOLS'])) ? $this->_rootref['L_USER_TOOLS'] : ((isset($user->lang['USER_TOOLS'])) ? $user->lang['USER_TOOLS'] : '{ USER_TOOLS }')); ?></legend>
	<dl>
		<dt><label for="quicktools"><?php echo ((isset($this->_rootref['L_QUICK_TOOLS'])) ? $this->_rootref['L_QUICK_TOOLS'] : ((isset($user->lang['QUICK_TOOLS'])) ? $user->lang['QUICK_TOOLS'] : '{ QUICK_TOOLS }')); ?>:</label></dt>
		<dd><select id="quicktools" name="action" onchange="display_reason(this.options[this.selectedIndex].value);"><?php echo (isset($this->_rootref['S_ACTION_OPTIONS'])) ? $this->_rootref['S_ACTION_OPTIONS'] : ''; ?></select></dd>
	</dl>
	<div style="display: none;" id="reasons">
		<dl>
			<dt><label for="ban_reason"><?php echo ((isset($this->_rootref['L_BAN_REASON'])) ? $this->_rootref['L_BAN_REASON'] : ((isset($user->lang['BAN_REASON'])) ? $user->lang['BAN_REASON'] : '{ BAN_REASON }')); ?>:</label></dt>
			<dd><input name="ban_reason" type="text" class="text medium" maxlength="3000" id="ban_reason" /></dd>
		</dl>
		<dl>
			<dt><label for="ban_give_reason"><?php echo ((isset($this->_rootref['L_BAN_GIVE_REASON'])) ? $this->_rootref['L_BAN_GIVE_REASON'] : ((isset($user->lang['BAN_GIVE_REASON'])) ? $user->lang['BAN_GIVE_REASON'] : '{ BAN_GIVE_REASON }')); ?>:</label></dt>
			<dd><input name="ban_give_reason" type="text" class="text medium" maxlength="3000" id="ban_give_reason" /></dd>
		</dl>
	</div>
		<?php if (! $this->_rootref['S_OWN_ACCOUNT']) {  ?>
			<dl>
				<dt><label for="delete_user"><?php echo ((isset($this->_rootref['L_DELETE_USER'])) ? $this->_rootref['L_DELETE_USER'] : ((isset($user->lang['DELETE_USER'])) ? $user->lang['DELETE_USER'] : '{ DELETE_USER }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_DELETE_USER_EXPLAIN'])) ? $this->_rootref['L_DELETE_USER_EXPLAIN'] : ((isset($user->lang['DELETE_USER_EXPLAIN'])) ? $user->lang['DELETE_USER_EXPLAIN'] : '{ DELETE_USER_EXPLAIN }')); ?></span></dt>
				<dd><input type="checkbox" class="radio" name="delete" value="1" /></dd>
				<dd><select id="delete_user" name="delete_type"><option value="retain"><?php echo ((isset($this->_rootref['L_RETAIN_POSTS'])) ? $this->_rootref['L_RETAIN_POSTS'] : ((isset($user->lang['RETAIN_POSTS'])) ? $user->lang['RETAIN_POSTS'] : '{ RETAIN_POSTS }')); ?></option><option value="remove"><?php echo ((isset($this->_rootref['L_DELETE_POSTS'])) ? $this->_rootref['L_DELETE_POSTS'] : ((isset($user->lang['DELETE_POSTS'])) ? $user->lang['DELETE_POSTS'] : '{ DELETE_POSTS }')); ?></option></select></dd>
			</dl>
		<?php } ?>

	<p class="quick">
		<input class="button1" type="submit" name="update" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</p>

	</fieldset>
	
	</form>

<?php } ?>
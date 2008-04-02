<?php $this->_tpl_include('overall_header.html'); ?>

<a name="maincontent"></a>

<?php if ($this->_rootref['U_BACK']) {  ?>
	<a href="<?php echo (isset($this->_rootref['U_BACK'])) ? $this->_rootref['U_BACK'] : ''; ?>" style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>;">&laquo; <?php echo ((isset($this->_rootref['L_BACK'])) ? $this->_rootref['L_BACK'] : ((isset($user->lang['BACK'])) ? $user->lang['BACK'] : '{ BACK }')); ?></a>
<?php } ?>

<h1><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></h1>

<p><?php echo ((isset($this->_rootref['L_TITLE_EXPLAIN'])) ? $this->_rootref['L_TITLE_EXPLAIN'] : ((isset($user->lang['TITLE_EXPLAIN'])) ? $user->lang['TITLE_EXPLAIN'] : '{ TITLE_EXPLAIN }')); ?></p>

<?php if ($this->_rootref['S_WARNING']) {  ?>
	<div class="errorbox">
		<h3><?php echo ((isset($this->_rootref['L_WARNING'])) ? $this->_rootref['L_WARNING'] : ((isset($user->lang['WARNING'])) ? $user->lang['WARNING'] : '{ WARNING }')); ?></h3>
		<p><?php echo (isset($this->_rootref['WARNING_MSG'])) ? $this->_rootref['WARNING_MSG'] : ''; ?></p>
	</div>
<?php } if ($this->_rootref['S_NOTIFY']) {  ?>
	<div class="successbox">
		<h3><?php echo ((isset($this->_rootref['L_NOTIFY'])) ? $this->_rootref['L_NOTIFY'] : ((isset($user->lang['NOTIFY'])) ? $user->lang['NOTIFY'] : '{ NOTIFY }')); ?></h3>
		<p><?php echo (isset($this->_rootref['NOTIFY_MSG'])) ? $this->_rootref['NOTIFY_MSG'] : ''; ?></p>
	</div>
<?php } if ($this->_rootref['S_UPLOADING_FILES']) {  ?>
	<h2><?php echo ((isset($this->_rootref['L_UPLOADING_FILES'])) ? $this->_rootref['L_UPLOADING_FILES'] : ((isset($user->lang['UPLOADING_FILES'])) ? $user->lang['UPLOADING_FILES'] : '{ UPLOADING_FILES }')); ?></h2>

	<?php $_upload_count = (isset($this->_tpldata['upload'])) ? sizeof($this->_tpldata['upload']) : 0;if ($_upload_count) {for ($_upload_i = 0; $_upload_i < $_upload_count; ++$_upload_i){$_upload_val = &$this->_tpldata['upload'][$_upload_i]; ?>
		:: <?php echo $_upload_val['FILE_INFO']; ?><br />
		<?php if ($_upload_val['S_DENIED']) {  ?><span class="error"><?php echo $_upload_val['DENIED']; ?></span><?php } else if ($_upload_val['ERROR_MSG']) {  ?><span class="error"><?php echo $_upload_val['ERROR_MSG']; ?></span><?php } else { ?><span class="success"><?php echo ((isset($this->_rootref['L_SUCCESSFULLY_UPLOADED'])) ? $this->_rootref['L_SUCCESSFULLY_UPLOADED'] : ((isset($user->lang['SUCCESSFULLY_UPLOADED'])) ? $user->lang['SUCCESSFULLY_UPLOADED'] : '{ SUCCESSFULLY_UPLOADED }')); ?></span><?php } ?>
		<br /><br />
	<?php }} } if ($this->_rootref['S_ATTACHMENT_SETTINGS']) {  if (! $this->_rootref['S_THUMBNAIL_SUPPORT']) {  ?>
		<div class="errorbox">
			<p><?php echo ((isset($this->_rootref['L_NO_THUMBNAIL_SUPPORT'])) ? $this->_rootref['L_NO_THUMBNAIL_SUPPORT'] : ((isset($user->lang['NO_THUMBNAIL_SUPPORT'])) ? $user->lang['NO_THUMBNAIL_SUPPORT'] : '{ NO_THUMBNAIL_SUPPORT }')); ?></p>
		</div>
	<?php } ?>

	<form id="attachsettings" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">
	<?php $_options_count = (isset($this->_tpldata['options'])) ? sizeof($this->_tpldata['options']) : 0;if ($_options_count) {for ($_options_i = 0; $_options_i < $_options_count; ++$_options_i){$_options_val = &$this->_tpldata['options'][$_options_i]; if ($_options_val['S_LEGEND']) {  if (! $_options_val['S_FIRST_ROW']) {  ?>
				</fieldset>
			<?php } ?>
			<fieldset>
				<legend><?php echo $_options_val['LEGEND']; ?></legend>
		<?php } else { ?>

			<dl>
				<dt><label for="<?php echo $_options_val['KEY']; ?>"><?php echo $_options_val['TITLE']; ?>:</label><?php if ($_options_val['S_EXPLAIN']) {  ?><br /><span><?php echo $_options_val['TITLE_EXPLAIN']; ?></span><?php } ?></dt>
				<dd><?php echo $_options_val['CONTENT']; ?></dd>
			</dl>

		<?php } }} ?>
	</fieldset>

	<fieldset class="submit-buttons">
		<legend><?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?></legend>
		<input class="button1" type="submit" id="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />&nbsp;
		<input class="button2" type="reset" id="reset" name="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" />
	</fieldset>

	<?php if (! $this->_rootref['S_SECURE_DOWNLOADS']) {  ?>
		<div class="errorbox">
			<p><?php echo ((isset($this->_rootref['L_SECURE_DOWNLOAD_NOTICE'])) ? $this->_rootref['L_SECURE_DOWNLOAD_NOTICE'] : ((isset($user->lang['SECURE_DOWNLOAD_NOTICE'])) ? $user->lang['SECURE_DOWNLOAD_NOTICE'] : '{ SECURE_DOWNLOAD_NOTICE }')); ?></p>
		</div>
	<?php } ?>

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_SECURE_TITLE'])) ? $this->_rootref['L_SECURE_TITLE'] : ((isset($user->lang['SECURE_TITLE'])) ? $user->lang['SECURE_TITLE'] : '{ SECURE_TITLE }')); ?></legend>
		<p><?php echo ((isset($this->_rootref['L_DOWNLOAD_ADD_IPS_EXPLAIN'])) ? $this->_rootref['L_DOWNLOAD_ADD_IPS_EXPLAIN'] : ((isset($user->lang['DOWNLOAD_ADD_IPS_EXPLAIN'])) ? $user->lang['DOWNLOAD_ADD_IPS_EXPLAIN'] : '{ DOWNLOAD_ADD_IPS_EXPLAIN }')); ?></p>
	<dl>
		<dt><label for="ip_hostname"><?php echo ((isset($this->_rootref['L_IP_HOSTNAME'])) ? $this->_rootref['L_IP_HOSTNAME'] : ((isset($user->lang['IP_HOSTNAME'])) ? $user->lang['IP_HOSTNAME'] : '{ IP_HOSTNAME }')); ?>:</label></dt>
		<dd><textarea id="ip_hostname" cols="40" rows="3" name="ips"></textarea></dd>
	</dl>
	<dl>
		<dt><label for="exclude"><?php echo ((isset($this->_rootref['L_IP_EXCLUDE'])) ? $this->_rootref['L_IP_EXCLUDE'] : ((isset($user->lang['IP_EXCLUDE'])) ? $user->lang['IP_EXCLUDE'] : '{ IP_EXCLUDE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_EXCLUDE_ENTERED_IP'])) ? $this->_rootref['L_EXCLUDE_ENTERED_IP'] : ((isset($user->lang['EXCLUDE_ENTERED_IP'])) ? $user->lang['EXCLUDE_ENTERED_IP'] : '{ EXCLUDE_ENTERED_IP }')); ?></span></dt>
		<dd><label><input type="radio" id="exclude" name="ipexclude" value="1" class="radio" /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input type="radio" name="ipexclude" value="0" checked="checked" class="radio" /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>

	<p class="quick">
		<input class="button1" type="submit" id="securesubmit" name="securesubmit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />
	</p>
	</fieldset>

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_REMOVE_IPS'])) ? $this->_rootref['L_REMOVE_IPS'] : ((isset($user->lang['REMOVE_IPS'])) ? $user->lang['REMOVE_IPS'] : '{ REMOVE_IPS }')); ?></legend>
	<?php if ($this->_rootref['S_DEFINED_IPS']) {  ?>
			<p><?php echo ((isset($this->_rootref['L_DOWNLOAD_REMOVE_IPS_EXPLAIN'])) ? $this->_rootref['L_DOWNLOAD_REMOVE_IPS_EXPLAIN'] : ((isset($user->lang['DOWNLOAD_REMOVE_IPS_EXPLAIN'])) ? $user->lang['DOWNLOAD_REMOVE_IPS_EXPLAIN'] : '{ DOWNLOAD_REMOVE_IPS_EXPLAIN }')); ?></p>
		<dl>
			<dt><label for="remove_ip_hostname"><?php echo ((isset($this->_rootref['L_IP_HOSTNAME'])) ? $this->_rootref['L_IP_HOSTNAME'] : ((isset($user->lang['IP_HOSTNAME'])) ? $user->lang['IP_HOSTNAME'] : '{ IP_HOSTNAME }')); ?>:</label></dt>
			<dd><select name="unip[]" id="remove_ip_hostname" multiple="multiple" size="10"><?php echo (isset($this->_rootref['DEFINED_IPS'])) ? $this->_rootref['DEFINED_IPS'] : ''; ?></select></dd>
		</dl>

		<p class="quick">
			<input class="button1" type="submit" id="unsecuresubmit" name="unsecuresubmit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />
		</p>
		</fieldset>

	<?php } else { ?>
		<p><?php echo ((isset($this->_rootref['L_NO_IPS_DEFINED'])) ? $this->_rootref['L_NO_IPS_DEFINED'] : ((isset($user->lang['NO_IPS_DEFINED'])) ? $user->lang['NO_IPS_DEFINED'] : '{ NO_IPS_DEFINED }')); ?></p>
	<?php } ?>
	<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
	</form>

<?php } else if ($this->_rootref['S_EXTENSION_GROUPS']) {  if ($this->_rootref['S_EDIT_GROUP']) {  ?>
		<script type="text/javascript" defer="defer">
		// <![CDATA[
			function update_image(newimage)
			{
				if (newimage == 'no_image')
				{
					document.image_upload_icon.src = "<?php echo (isset($this->_rootref['PHPBB_ROOT_PATH'])) ? $this->_rootref['PHPBB_ROOT_PATH'] : ''; ?>images/spacer.gif";
				}
				else
				{
					document.image_upload_icon.src = "<?php echo (isset($this->_rootref['PHPBB_ROOT_PATH'])) ? $this->_rootref['PHPBB_ROOT_PATH'] : ''; echo (isset($this->_rootref['IMG_PATH'])) ? $this->_rootref['IMG_PATH'] : ''; ?>/" + newimage;
				}
			}

			function show_extensions(elem)
			{
				var str = '';

				for (i = 0; i < elem.length; i++)
				{
					var element = elem.options[i];
					if (element.selected)
					{
						if (str)
						{
							str = str + ', ';
						}

						str = str + element.innerHTML;
					}
				}

				if (document.all)
				{
					document.all.ext.innerText = str;
				}
				else if (document.getElementById('ext').textContent)
				{
					document.getElementById('ext').textContent = str;
				}
				else if (document.getElementById('ext').firstChild.nodeValue)
				{
					document.getElementById('ext').firstChild.nodeValue = str;
				}
			}

		// ]]>
		</script>

		<form id="extgroups" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">
		<fieldset>
			<input type="hidden" name="action" value="<?php echo (isset($this->_rootref['ACTION'])) ? $this->_rootref['ACTION'] : ''; ?>" />
			<input type="hidden" name="g" value="<?php echo (isset($this->_rootref['GROUP_ID'])) ? $this->_rootref['GROUP_ID'] : ''; ?>" />

			<legend><?php echo ((isset($this->_rootref['L_LEGEND'])) ? $this->_rootref['L_LEGEND'] : ((isset($user->lang['LEGEND'])) ? $user->lang['LEGEND'] : '{ LEGEND }')); ?></legend>
		<dl>
			<dt><label for="group_name"><?php echo ((isset($this->_rootref['L_GROUP_NAME'])) ? $this->_rootref['L_GROUP_NAME'] : ((isset($user->lang['GROUP_NAME'])) ? $user->lang['GROUP_NAME'] : '{ GROUP_NAME }')); ?>:</label></dt>
			<dd><input type="text" id="group_name" size="20" maxlength="100" name="group_name" value="<?php echo (isset($this->_rootref['GROUP_NAME'])) ? $this->_rootref['GROUP_NAME'] : ''; ?>" /></dd>
		</dl>
		<dl>
			<dt><label for="category"><?php echo ((isset($this->_rootref['L_SPECIAL_CATEGORY'])) ? $this->_rootref['L_SPECIAL_CATEGORY'] : ((isset($user->lang['SPECIAL_CATEGORY'])) ? $user->lang['SPECIAL_CATEGORY'] : '{ SPECIAL_CATEGORY }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_SPECIAL_CATEGORY_EXPLAIN'])) ? $this->_rootref['L_SPECIAL_CATEGORY_EXPLAIN'] : ((isset($user->lang['SPECIAL_CATEGORY_EXPLAIN'])) ? $user->lang['SPECIAL_CATEGORY_EXPLAIN'] : '{ SPECIAL_CATEGORY_EXPLAIN }')); ?></span></dt>
			<dd><?php echo (isset($this->_rootref['S_CATEGORY_SELECT'])) ? $this->_rootref['S_CATEGORY_SELECT'] : ''; ?></dd>
		</dl>
		<dl>
			<dt><label for="allowed"><?php echo ((isset($this->_rootref['L_ALLOWED'])) ? $this->_rootref['L_ALLOWED'] : ((isset($user->lang['ALLOWED'])) ? $user->lang['ALLOWED'] : '{ ALLOWED }')); ?>:</label></dt>
			<dd><input type="checkbox" class="radio" id="allowed" name="allow_group" value="1"<?php if ($this->_rootref['ALLOW_GROUP']) {  ?> checked="checked"<?php } ?> /></dd>
		</dl>
		<dl>
			<dt><label for="allow_in_pm"><?php echo ((isset($this->_rootref['L_ALLOW_IN_PM'])) ? $this->_rootref['L_ALLOW_IN_PM'] : ((isset($user->lang['ALLOW_IN_PM'])) ? $user->lang['ALLOW_IN_PM'] : '{ ALLOW_IN_PM }')); ?>:</label></dt>
			<dd><input type="checkbox" class="radio" id="allow_in_pm" name="allow_in_pm" value="1"<?php if ($this->_rootref['ALLOW_IN_PM']) {  ?> checked="checked"<?php } ?> /></dd>
		</dl>
		<dl>
			<dt><label for="upload_icon"><?php echo ((isset($this->_rootref['L_UPLOAD_ICON'])) ? $this->_rootref['L_UPLOAD_ICON'] : ((isset($user->lang['UPLOAD_ICON'])) ? $user->lang['UPLOAD_ICON'] : '{ UPLOAD_ICON }')); ?>:</label></dt>
			<dd><select name="upload_icon" id="upload_icon" onchange="update_image(this.options[selectedIndex].value);">
					<option value="no_image"<?php if ($this->_rootref['S_NO_IMAGE']) {  ?> selected="selected"<?php } ?>><?php echo ((isset($this->_rootref['L_NO_IMAGE'])) ? $this->_rootref['L_NO_IMAGE'] : ((isset($user->lang['NO_IMAGE'])) ? $user->lang['NO_IMAGE'] : '{ NO_IMAGE }')); ?></option><?php echo (isset($this->_rootref['S_FILENAME_LIST'])) ? $this->_rootref['S_FILENAME_LIST'] : ''; ?>
			</select></dd>
			<dd>&nbsp;<img <?php if ($this->_rootref['S_NO_IMAGE']) {  ?>src="<?php echo (isset($this->_rootref['PHPBB_ROOT_PATH'])) ? $this->_rootref['PHPBB_ROOT_PATH'] : ''; ?>images/spacer.gif"<?php } else { ?>src="<?php echo (isset($this->_rootref['UPLOAD_ICON_SRC'])) ? $this->_rootref['UPLOAD_ICON_SRC'] : ''; ?>"<?php } ?> name="image_upload_icon" alt="" title="" />&nbsp;</dd>
		</dl>
		<dl>
			<dt><label for="extgroup_filesize"><?php echo ((isset($this->_rootref['L_MAX_EXTGROUP_FILESIZE'])) ? $this->_rootref['L_MAX_EXTGROUP_FILESIZE'] : ((isset($user->lang['MAX_EXTGROUP_FILESIZE'])) ? $user->lang['MAX_EXTGROUP_FILESIZE'] : '{ MAX_EXTGROUP_FILESIZE }')); ?>:</label></dt>
			<dd><input type="text" id="extgroup_filesize" size="3" maxlength="15" name="max_filesize" value="<?php echo (isset($this->_rootref['EXTGROUP_FILESIZE'])) ? $this->_rootref['EXTGROUP_FILESIZE'] : ''; ?>" /> <select name="size_select"><?php echo (isset($this->_rootref['S_EXT_GROUP_SIZE_OPTIONS'])) ? $this->_rootref['S_EXT_GROUP_SIZE_OPTIONS'] : ''; ?></select></dd>
		</dl>
		<dl>
			<dt><label for="assigned_extensions"><?php echo ((isset($this->_rootref['L_ASSIGNED_EXTENSIONS'])) ? $this->_rootref['L_ASSIGNED_EXTENSIONS'] : ((isset($user->lang['ASSIGNED_EXTENSIONS'])) ? $user->lang['ASSIGNED_EXTENSIONS'] : '{ ASSIGNED_EXTENSIONS }')); ?>:</label></dt>
			<dd><div id="ext"><?php echo (isset($this->_rootref['ASSIGNED_EXTENSIONS'])) ? $this->_rootref['ASSIGNED_EXTENSIONS'] : ''; ?></div> <span>[<a href="<?php echo (isset($this->_rootref['U_EXTENSIONS'])) ? $this->_rootref['U_EXTENSIONS'] : ''; ?>"><?php echo ((isset($this->_rootref['L_GO_TO_EXTENSIONS'])) ? $this->_rootref['L_GO_TO_EXTENSIONS'] : ((isset($user->lang['GO_TO_EXTENSIONS'])) ? $user->lang['GO_TO_EXTENSIONS'] : '{ GO_TO_EXTENSIONS }')); ?></a> ]</span></dd>
			<dd><select name="extensions[]" id="assigned_extensions" class="narrow" onchange="show_extensions(this);" multiple="multiple" size="8"><?php echo (isset($this->_rootref['S_EXTENSION_OPTIONS'])) ? $this->_rootref['S_EXTENSION_OPTIONS'] : ''; ?></select></dd>
		</dl>
		<dl>
			<dt><label for="allowed_forums"><?php echo ((isset($this->_rootref['L_ALLOWED_FORUMS'])) ? $this->_rootref['L_ALLOWED_FORUMS'] : ((isset($user->lang['ALLOWED_FORUMS'])) ? $user->lang['ALLOWED_FORUMS'] : '{ ALLOWED_FORUMS }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_ALLOWED_FORUMS_EXPLAIN'])) ? $this->_rootref['L_ALLOWED_FORUMS_EXPLAIN'] : ((isset($user->lang['ALLOWED_FORUMS_EXPLAIN'])) ? $user->lang['ALLOWED_FORUMS_EXPLAIN'] : '{ ALLOWED_FORUMS_EXPLAIN }')); ?></span></dt>
			<dd><label><input type="radio" id="allowed_forums" class="radio" name="forum_select" value="0"<?php if (! $this->_rootref['S_FORUM_IDS']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_ALLOW_ALL_FORUMS'])) ? $this->_rootref['L_ALLOW_ALL_FORUMS'] : ((isset($user->lang['ALLOW_ALL_FORUMS'])) ? $user->lang['ALLOW_ALL_FORUMS'] : '{ ALLOW_ALL_FORUMS }')); ?></label>
				<label><input type="radio" class="radio" name="forum_select" value="1"<?php if ($this->_rootref['S_FORUM_IDS']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_ALLOW_SELECTED_FORUMS'])) ? $this->_rootref['L_ALLOW_SELECTED_FORUMS'] : ((isset($user->lang['ALLOW_SELECTED_FORUMS'])) ? $user->lang['ALLOW_SELECTED_FORUMS'] : '{ ALLOW_SELECTED_FORUMS }')); ?></label></dd>
			<dd><select name="allowed_forums[]" multiple="multiple" size="8"><?php echo (isset($this->_rootref['S_FORUM_ID_OPTIONS'])) ? $this->_rootref['S_FORUM_ID_OPTIONS'] : ''; ?></select></dd>
		</dl>

		<p class="submit-buttons">
			<input class="button1" type="submit" id="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />&nbsp;
			<input class="button2" type="reset" id="reset" name="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" />
		</p>
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
		</fieldset>

		</form>
	<?php } else { ?>

		<form id="extgroups" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">
		<fieldset class="tabulated">
		<legend><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></legend>

		<table cellspacing="1">
			<col class="row1" /><col class="row1" /><col class="row2" />
		<thead>
		<tr>
			<th><?php echo ((isset($this->_rootref['L_EXTENSION_GROUP'])) ? $this->_rootref['L_EXTENSION_GROUP'] : ((isset($user->lang['EXTENSION_GROUP'])) ? $user->lang['EXTENSION_GROUP'] : '{ EXTENSION_GROUP }')); ?></th>
			<th><?php echo ((isset($this->_rootref['L_SPECIAL_CATEGORY'])) ? $this->_rootref['L_SPECIAL_CATEGORY'] : ((isset($user->lang['SPECIAL_CATEGORY'])) ? $user->lang['SPECIAL_CATEGORY'] : '{ SPECIAL_CATEGORY }')); ?></th>
			<th><?php echo ((isset($this->_rootref['L_OPTIONS'])) ? $this->_rootref['L_OPTIONS'] : ((isset($user->lang['OPTIONS'])) ? $user->lang['OPTIONS'] : '{ OPTIONS }')); ?></th>
		</tr>
		</thead>
		<tbody>
		<?php $_groups_count = (isset($this->_tpldata['groups'])) ? sizeof($this->_tpldata['groups']) : 0;if ($_groups_count) {for ($_groups_i = 0; $_groups_i < $_groups_count; ++$_groups_i){$_groups_val = &$this->_tpldata['groups'][$_groups_i]; if ($_groups_val['S_ADD_SPACER'] && ! $_groups_val['S_FIRST_ROW']) {  ?>
			<tr>
				<td class="spacer" colspan="3">&nbsp;</td>
			</tr>
			<?php } ?>
			<tr>
				<td><strong><?php echo $_groups_val['GROUP_NAME']; ?></strong>
					<?php if ($_groups_val['S_GROUP_ALLOWED'] && ! $_groups_val['S_ALLOWED_IN_PM']) {  ?><br /><span>&raquo; <?php echo ((isset($this->_rootref['L_NOT_ALLOWED_IN_PM'])) ? $this->_rootref['L_NOT_ALLOWED_IN_PM'] : ((isset($user->lang['NOT_ALLOWED_IN_PM'])) ? $user->lang['NOT_ALLOWED_IN_PM'] : '{ NOT_ALLOWED_IN_PM }')); ?></span>
					<?php } else if ($_groups_val['S_ALLOWED_IN_PM'] && ! $_groups_val['S_GROUP_ALLOWED']) {  ?><br /><span>&raquo; <?php echo ((isset($this->_rootref['L_ONLY_ALLOWED_IN_PM'])) ? $this->_rootref['L_ONLY_ALLOWED_IN_PM'] : ((isset($user->lang['ONLY_ALLOWED_IN_PM'])) ? $user->lang['ONLY_ALLOWED_IN_PM'] : '{ ONLY_ALLOWED_IN_PM }')); ?></span>
					<?php } else if (! $_groups_val['S_GROUP_ALLOWED'] && ! $_groups_val['S_ALLOWED_IN_PM']) {  ?><br /><span>&raquo; <?php echo ((isset($this->_rootref['L_NOT_ALLOWED_IN_PM_POST'])) ? $this->_rootref['L_NOT_ALLOWED_IN_PM_POST'] : ((isset($user->lang['NOT_ALLOWED_IN_PM_POST'])) ? $user->lang['NOT_ALLOWED_IN_PM_POST'] : '{ NOT_ALLOWED_IN_PM_POST }')); ?></span>
					<?php } else { ?><br /><span>&raquo; <?php echo ((isset($this->_rootref['L_ALLOWED_IN_PM_POST'])) ? $this->_rootref['L_ALLOWED_IN_PM_POST'] : ((isset($user->lang['ALLOWED_IN_PM_POST'])) ? $user->lang['ALLOWED_IN_PM_POST'] : '{ ALLOWED_IN_PM_POST }')); ?></span><?php } ?>
				</td>
				<td><?php echo $_groups_val['CATEGORY']; ?></td>
				<td align="center" valign="middle" style="white-space: nowrap;">&nbsp;<a href="<?php echo $_groups_val['U_EDIT']; ?>"><?php echo (isset($this->_rootref['ICON_EDIT'])) ? $this->_rootref['ICON_EDIT'] : ''; ?></a>&nbsp;&nbsp;<a href="<?php echo $_groups_val['U_DELETE']; ?>"><?php echo (isset($this->_rootref['ICON_DELETE'])) ? $this->_rootref['ICON_DELETE'] : ''; ?></a>&nbsp;</td>
			</tr>
		<?php }} ?>
		</tbody>
		</table>
		<p class="quick">
				<?php echo ((isset($this->_rootref['L_CREATE_GROUP'])) ? $this->_rootref['L_CREATE_GROUP'] : ((isset($user->lang['CREATE_GROUP'])) ? $user->lang['CREATE_GROUP'] : '{ CREATE_GROUP }')); ?>: <input type="text" name="group_name" maxlength="30" />
				<input class="button2" name="add" type="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />
		</p>
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
		</fieldset>
		</form>

	<?php } } else if ($this->_rootref['S_EXTENSIONS']) {  ?>

	<form id="add_ext" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">
	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_ADD_EXTENSION'])) ? $this->_rootref['L_ADD_EXTENSION'] : ((isset($user->lang['ADD_EXTENSION'])) ? $user->lang['ADD_EXTENSION'] : '{ ADD_EXTENSION }')); ?></legend>
	<dl>
		<dt><label for="add_extension"><?php echo ((isset($this->_rootref['L_EXTENSION'])) ? $this->_rootref['L_EXTENSION'] : ((isset($user->lang['EXTENSION'])) ? $user->lang['EXTENSION'] : '{ EXTENSION }')); ?></label></dt>
		<dd><input type="text" id="add_extension" size="20" maxlength="100" name="add_extension" value="<?php echo (isset($this->_rootref['ADD_EXTENSION'])) ? $this->_rootref['ADD_EXTENSION'] : ''; ?>" /></dd>
	</dl>
	<dl>
		<dt><label for="extension_group"><?php echo ((isset($this->_rootref['L_EXTENSION_GROUP'])) ? $this->_rootref['L_EXTENSION_GROUP'] : ((isset($user->lang['EXTENSION_GROUP'])) ? $user->lang['EXTENSION_GROUP'] : '{ EXTENSION_GROUP }')); ?></label></dt>
		<dd><?php echo (isset($this->_rootref['GROUP_SELECT_OPTIONS'])) ? $this->_rootref['GROUP_SELECT_OPTIONS'] : ''; ?></dd>
	</dl>

	<p class="quick">
		<input type="submit" id="add_extension_check" name="add_extension_check" class="button2" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />
	</p>
	<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
	</form>

	<br />

	<form id="change_ext" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

	<fieldset class="tabulated">
	<legend><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></legend>

	<table cellspacing="1">
		<col class="row1" /><col class="row1" /><col class="row2" />
	<thead>
	<tr>
		<th><?php echo ((isset($this->_rootref['L_EXTENSION'])) ? $this->_rootref['L_EXTENSION'] : ((isset($user->lang['EXTENSION'])) ? $user->lang['EXTENSION'] : '{ EXTENSION }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_EXTENSION_GROUP'])) ? $this->_rootref['L_EXTENSION_GROUP'] : ((isset($user->lang['EXTENSION_GROUP'])) ? $user->lang['EXTENSION_GROUP'] : '{ EXTENSION_GROUP }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_DELETE'])) ? $this->_rootref['L_DELETE'] : ((isset($user->lang['DELETE'])) ? $user->lang['DELETE'] : '{ DELETE }')); ?></th>
	</tr>
	</thead>
	<tbody>
	<?php $_extensions_count = (isset($this->_tpldata['extensions'])) ? sizeof($this->_tpldata['extensions']) : 0;if ($_extensions_count) {for ($_extensions_i = 0; $_extensions_i < $_extensions_count; ++$_extensions_i){$_extensions_val = &$this->_tpldata['extensions'][$_extensions_i]; if ($_extensions_val['S_SPACER']) {  ?>
		<tr>
			<td class="spacer" colspan="3">&nbsp;</td>
		</tr>
		<?php } ?>
		<tr>
			<td><strong><?php echo $_extensions_val['EXTENSION']; ?></strong></td>
			<td><?php echo $_extensions_val['GROUP_OPTIONS']; ?></td>
			<td><input type="checkbox" class="radio" name="extension_id_list[]" value="<?php echo $_extensions_val['EXTENSION_ID']; ?>" /><input type="hidden" name="extension_change_list[]" value="<?php echo $_extensions_val['EXTENSION_ID']; ?>" /></td>
		</tr>
	<?php }} ?>
	</tbody>
	</table>

	<p class="submit-buttons">
		<input class="button1" type="submit" id="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />&nbsp;
		<input class="button2" type="reset" id="reset" name="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" />
	</p>
	<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
	</form>

<?php } else if ($this->_rootref['S_ORPHAN']) {  ?>

	<form id="orphan" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

	<fieldset class="tabulated">
	<legend><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></legend>

	<table cellspacing="1">
	<thead>
	<tr>
		<th><?php echo ((isset($this->_rootref['L_FILENAME'])) ? $this->_rootref['L_FILENAME'] : ((isset($user->lang['FILENAME'])) ? $user->lang['FILENAME'] : '{ FILENAME }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_FILEDATE'])) ? $this->_rootref['L_FILEDATE'] : ((isset($user->lang['FILEDATE'])) ? $user->lang['FILEDATE'] : '{ FILEDATE }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_FILESIZE'])) ? $this->_rootref['L_FILESIZE'] : ((isset($user->lang['FILESIZE'])) ? $user->lang['FILESIZE'] : '{ FILESIZE }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_ATTACH_POST_ID'])) ? $this->_rootref['L_ATTACH_POST_ID'] : ((isset($user->lang['ATTACH_POST_ID'])) ? $user->lang['ATTACH_POST_ID'] : '{ ATTACH_POST_ID }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_ATTACH_TO_POST'])) ? $this->_rootref['L_ATTACH_TO_POST'] : ((isset($user->lang['ATTACH_TO_POST'])) ? $user->lang['ATTACH_TO_POST'] : '{ ATTACH_TO_POST }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_DELETE'])) ? $this->_rootref['L_DELETE'] : ((isset($user->lang['DELETE'])) ? $user->lang['DELETE'] : '{ DELETE }')); ?></th>
	</tr>
	</thead>
	<tbody>
	<?php $_orphan_count = (isset($this->_tpldata['orphan'])) ? sizeof($this->_tpldata['orphan']) : 0;if ($_orphan_count) {for ($_orphan_i = 0; $_orphan_i < $_orphan_count; ++$_orphan_i){$_orphan_val = &$this->_tpldata['orphan'][$_orphan_i]; if (!($_orphan_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>
			<td><a href="<?php echo $_orphan_val['U_FILE']; ?>"><?php echo $_orphan_val['REAL_FILENAME']; ?></a></td>
			<td><?php echo $_orphan_val['FILETIME']; ?></td>
			<td><?php echo $_orphan_val['FILESIZE']; ?></td>
			<td><strong><?php echo ((isset($this->_rootref['L_ATTACH_ID'])) ? $this->_rootref['L_ATTACH_ID'] : ((isset($user->lang['ATTACH_ID'])) ? $user->lang['ATTACH_ID'] : '{ ATTACH_ID }')); ?>: </strong><input type="text" name="post_id[<?php echo $_orphan_val['ATTACH_ID']; ?>]" size="7" maxlength="10" value="<?php echo $_orphan_val['POST_ID']; ?>" /></td>
			<td><input type="checkbox" class="radio" name="add[<?php echo $_orphan_val['ATTACH_ID']; ?>]" /></td>
			<td><input type="checkbox" class="radio" name="delete[<?php echo $_orphan_val['ATTACH_ID']; ?>]" /></td>
		</tr>
	<?php }} ?>
	<tr class="row4">
		<td colspan="4">&nbsp;</td>
		<td class="small"><a href="#" onclick="marklist('orphan', 'add', true); return false;"><?php echo ((isset($this->_rootref['L_MARK_ALL'])) ? $this->_rootref['L_MARK_ALL'] : ((isset($user->lang['MARK_ALL'])) ? $user->lang['MARK_ALL'] : '{ MARK_ALL }')); ?></a> :: <a href="#" onclick="marklist('orphan', 'add', false); return false;"><?php echo ((isset($this->_rootref['L_UNMARK_ALL'])) ? $this->_rootref['L_UNMARK_ALL'] : ((isset($user->lang['UNMARK_ALL'])) ? $user->lang['UNMARK_ALL'] : '{ UNMARK_ALL }')); ?></a></td>
		<td class="small"><a href="#" onclick="marklist('orphan', 'delete', true); return false;"><?php echo ((isset($this->_rootref['L_MARK_ALL'])) ? $this->_rootref['L_MARK_ALL'] : ((isset($user->lang['MARK_ALL'])) ? $user->lang['MARK_ALL'] : '{ MARK_ALL }')); ?></a> :: <a href="#" onclick="marklist('orphan', 'delete', false); return false;"><?php echo ((isset($this->_rootref['L_UNMARK_ALL'])) ? $this->_rootref['L_UNMARK_ALL'] : ((isset($user->lang['UNMARK_ALL'])) ? $user->lang['UNMARK_ALL'] : '{ UNMARK_ALL }')); ?></a></td>
	</tr>
	</tbody>
	</table>

	<br />

	<p class="submit-buttons">
		<input class="button1" type="submit" id="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />&nbsp;
		<input class="button2" type="reset" id="reset" name="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" />
	</p>
	<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
	</form>

<?php } $this->_tpl_include('overall_footer.html'); ?>
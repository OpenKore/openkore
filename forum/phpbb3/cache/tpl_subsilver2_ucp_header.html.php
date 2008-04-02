<?php $this->_tpl_include('overall_header.html'); if ($this->_rootref['S_SHOW_PM_BOX'] && $this->_rootref['S_POST_ACTION']) {  ?>
	<form action="<?php echo (isset($this->_rootref['S_POST_ACTION'])) ? $this->_rootref['S_POST_ACTION'] : ''; ?>" method="post" name="postform"<?php echo (isset($this->_rootref['S_FORM_ENCTYPE'])) ? $this->_rootref['S_FORM_ENCTYPE'] : ''; ?>>
<?php } ?>
<table width="100%" cellspacing="0" cellpadding="0" border="0">
<tr>
	<td width="20%" valign="top">

<?php if ($this->_rootref['S_SHOW_PM_BOX'] && $this->_rootref['S_POST_ACTION']) {  ?>
	<table class="tablebg" width="100%" cellspacing="1">
	<tr>
		<th><?php echo ((isset($this->_rootref['L_PM_TO'])) ? $this->_rootref['L_PM_TO'] : ((isset($user->lang['PM_TO'])) ? $user->lang['PM_TO'] : '{ PM_TO }')); ?></th>
	</tr>
	<?php if (! $this->_rootref['S_ALLOW_MASS_PM']) {  ?>
	<tr>
		<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?>:</b><br />[ <a href="<?php echo (isset($this->_rootref['U_FIND_USERNAME'])) ? $this->_rootref['U_FIND_USERNAME'] : ''; ?>" onclick="find_username(this.href); return false;"><?php echo ((isset($this->_rootref['L_FIND_USERNAME'])) ? $this->_rootref['L_FIND_USERNAME'] : ((isset($user->lang['FIND_USERNAME'])) ? $user->lang['FIND_USERNAME'] : '{ FIND_USERNAME }')); ?></a> ]</td>
	</tr>
	
	<tr>
		<td class="row2"><input class="post" type="text" name="username_list" size="20" value="" />&nbsp;<input class="post" type="submit" name="add_to" value="<?php echo ((isset($this->_rootref['L_ADD'])) ? $this->_rootref['L_ADD'] : ((isset($user->lang['ADD'])) ? $user->lang['ADD'] : '{ ADD }')); ?>" /></td>
	</tr>
	<?php } else { ?>
		<tr>
			<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_USERNAMES'])) ? $this->_rootref['L_USERNAMES'] : ((isset($user->lang['USERNAMES'])) ? $user->lang['USERNAMES'] : '{ USERNAMES }')); ?>:</b></td>
		</tr>
		<tr>
			<td class="row2"><textarea name="username_list" rows="5" cols="22"></textarea><br />
				[ <a href="<?php echo (isset($this->_rootref['U_FIND_USERNAME'])) ? $this->_rootref['U_FIND_USERNAME'] : ''; ?>" onclick="find_username(this.href); return false;"><?php echo ((isset($this->_rootref['L_FIND_USERNAME'])) ? $this->_rootref['L_FIND_USERNAME'] : ((isset($user->lang['FIND_USERNAME'])) ? $user->lang['FIND_USERNAME'] : '{ FIND_USERNAME }')); ?></a> ]
			</td>
		</tr>
	<?php } if ($this->_rootref['S_GROUP_OPTIONS']) {  ?>
		<tr>
			<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_USERGROUPS'])) ? $this->_rootref['L_USERGROUPS'] : ((isset($user->lang['USERGROUPS'])) ? $user->lang['USERGROUPS'] : '{ USERGROUPS }')); ?>:</b></td>
		</tr>
		<tr>
			<td class="row2"><select name="group_list[]" multiple="true" size="5" style="width:150px"><?php echo (isset($this->_rootref['S_GROUP_OPTIONS'])) ? $this->_rootref['S_GROUP_OPTIONS'] : ''; ?></select></td>
		</tr>
	<?php } if ($this->_rootref['S_ALLOW_MASS_PM']) {  ?>
		<tr>
			<td class="row1"><div style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>;">&nbsp;<input class="post" type="submit" name="add_bcc" value="<?php echo ((isset($this->_rootref['L_ADD_BCC'])) ? $this->_rootref['L_ADD_BCC'] : ((isset($user->lang['ADD_BCC'])) ? $user->lang['ADD_BCC'] : '{ ADD_BCC }')); ?>" />&nbsp;</div><div style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>;">&nbsp;<input class="post" type="submit" name="add_to" value="<?php echo ((isset($this->_rootref['L_ADD_TO'])) ? $this->_rootref['L_ADD_TO'] : ((isset($user->lang['ADD_TO'])) ? $user->lang['ADD_TO'] : '{ ADD_TO }')); ?>" />&nbsp;</div></td>
		</tr>
	<?php } ?>
	</table>
	<div style="padding: 2px;"></div>
<?php } ?>

<table class="tablebg" width="100%" cellspacing="1">
<tr>
	<th><?php echo ((isset($this->_rootref['L_OPTIONS'])) ? $this->_rootref['L_OPTIONS'] : ((isset($user->lang['OPTIONS'])) ? $user->lang['OPTIONS'] : '{ OPTIONS }')); ?></th>
</tr>

<?php $_l_block1_count = (isset($this->_tpldata['l_block1'])) ? sizeof($this->_tpldata['l_block1']) : 0;if ($_l_block1_count) {for ($_l_block1_i = 0; $_l_block1_i < $_l_block1_count; ++$_l_block1_i){$_l_block1_val = &$this->_tpldata['l_block1'][$_l_block1_i]; ?>
	<tr>
		<?php if ($_l_block1_val['S_SELECTED']) {  ?>
			<td class="row1"><b class="nav"><?php echo $_l_block1_val['L_TITLE']; ?></b>

			<?php if ($this->_rootref['S_PRIVMSGS']) {  ?><!-- the ! at the beginning of the loop name forces the loop to be not a nested one of l_block1 (it gets parsed separately) --><?php $_folder_count = (isset($this->_tpldata['folder'])) ? sizeof($this->_tpldata['folder']) : 0;if ($_folder_count) {for ($_folder_i = 0; $_folder_i < $_folder_count; ++$_folder_i){$_folder_val = &$this->_tpldata['folder'][$_folder_i]; if ($_folder_val['S_FIRST_ROW']) {  ?>
						<ul class="nav" style="margin: 0; padding: 0; list-style-type: none; line-height: 175%;">
					<?php } if ($_folder_val['S_CUR_FOLDER']) {  ?>
						<li class="row2" style="padding: 1px 0;">&#187; <a href="<?php echo $_folder_val['U_FOLDER']; ?>"><?php echo $_folder_val['FOLDER_NAME']; if ($_folder_val['S_UNREAD_MESSAGES']) {  ?> (<?php echo $_folder_val['UNREAD_MESSAGES']; ?>)<?php } ?></a></li>
					<?php } else { ?>
						<li>&#187; <a href="<?php echo $_folder_val['U_FOLDER']; ?>"><?php echo $_folder_val['FOLDER_NAME']; if ($_folder_val['S_UNREAD_MESSAGES']) {  ?> (<?php echo $_folder_val['UNREAD_MESSAGES']; ?>)<?php } ?></a></li>
					<?php } if ($_folder_val['S_LAST_ROW']) {  ?>
						</ul>
						<hr />
					<?php } }} } ?>

			<ul class="nav" style="margin: 0; padding: 0; list-style-type: none; line-height: 175%;">
			<?php $_l_block2_count = (isset($_l_block1_val['l_block2'])) ? sizeof($_l_block1_val['l_block2']) : 0;if ($_l_block2_count) {for ($_l_block2_i = 0; $_l_block2_i < $_l_block2_count; ++$_l_block2_i){$_l_block2_val = &$_l_block1_val['l_block2'][$_l_block2_i]; ?>
				<li>&#187; <?php if ($_l_block2_val['S_SELECTED']) {  ?><b><?php echo $_l_block2_val['L_TITLE']; ?></b><?php } else { ?><a href="<?php echo $_l_block2_val['U_TITLE']; ?>"><?php echo $_l_block2_val['L_TITLE']; ?></a><?php } ?></li>
			<?php }} ?>
			</ul>
		<?php } else { ?>
			<td class="row2" nowrap="nowrap" onmouseover="this.className='row1'" onmouseout="this.className='row2'" onclick="location.href=this.firstChild.href;"><a class="nav" href="<?php echo $_l_block1_val['U_TITLE']; ?>"><?php echo $_l_block1_val['L_TITLE']; ?></a>
		<?php } ?>
		</td>
	</tr>
<?php }} ?>
</table>

<div style="padding: 2px;"></div>

<?php if ($this->_rootref['S_SHOW_COLOUR_LEGEND']) {  ?>
	<table class="tablebg" width="100%" cellspacing="1" cellpadding="0">
	<tr>
		<th colspan="2"><?php echo ((isset($this->_rootref['L_MESSAGE_COLOURS'])) ? $this->_rootref['L_MESSAGE_COLOURS'] : ((isset($user->lang['MESSAGE_COLOURS'])) ? $user->lang['MESSAGE_COLOURS'] : '{ MESSAGE_COLOURS }')); ?></th>
	</tr>
	<?php $_pm_colour_info_count = (isset($this->_tpldata['pm_colour_info'])) ? sizeof($this->_tpldata['pm_colour_info']) : 0;if ($_pm_colour_info_count) {for ($_pm_colour_info_i = 0; $_pm_colour_info_i < $_pm_colour_info_count; ++$_pm_colour_info_i){$_pm_colour_info_val = &$this->_tpldata['pm_colour_info'][$_pm_colour_info_i]; ?>
		<tr>
			<?php if (! $_pm_colour_info_val['IMG']) {  ?>
				<td class="row1 <?php echo $_pm_colour_info_val['CLASS']; ?>" width="5"><img src="images/spacer.gif" width="5" alt="<?php echo $_pm_colour_info_val['LANG']; ?>" /></td>
			<?php } else { ?>
				<td class="row1" width="25" align="center"><?php echo $_pm_colour_info_val['IMG']; ?></td>
			<?php } ?>
			<td class="row1"><span class="genmed"><?php echo $_pm_colour_info_val['LANG']; ?></span></td>
		</tr>
	<?php }} ?>
	</table>

	<div style="padding: 2px;"></div>
<?php } if ($this->_rootref['S_ZEBRA_ENABLED'] && $this->_rootref['S_ZEBRA_FRIENDS_ENABLED']) {  ?>
	<table class="tablebg" width="100%" cellspacing="1">
	<tr>
		<th><?php echo ((isset($this->_rootref['L_FRIENDS'])) ? $this->_rootref['L_FRIENDS'] : ((isset($user->lang['FRIENDS'])) ? $user->lang['FRIENDS'] : '{ FRIENDS }')); ?></th>
	</tr>
	<tr>
		<td class="row1" align="center">
		
			<b class="genmed" style="color:green"><?php echo ((isset($this->_rootref['L_FRIENDS_ONLINE'])) ? $this->_rootref['L_FRIENDS_ONLINE'] : ((isset($user->lang['FRIENDS_ONLINE'])) ? $user->lang['FRIENDS_ONLINE'] : '{ FRIENDS_ONLINE }')); ?></b>

			<ul class="nav" style="margin: 0; padding: 0; list-style-type: none; line-height: 175%;">
			<?php $_friends_online_count = (isset($this->_tpldata['friends_online'])) ? sizeof($this->_tpldata['friends_online']) : 0;if ($_friends_online_count) {for ($_friends_online_i = 0; $_friends_online_i < $_friends_online_count; ++$_friends_online_i){$_friends_online_val = &$this->_tpldata['friends_online'][$_friends_online_i]; ?>
				<li><?php echo $_friends_online_val['USERNAME_FULL']; ?>
				<?php if ($this->_rootref['S_SHOW_PM_BOX']) {  ?>
					&nbsp;[ <input class="post" style="font-size: 90%;" type="submit" name="add_to[<?php echo $_friends_online_val['USER_ID']; ?>]" value="<?php echo ((isset($this->_rootref['L_ADD'])) ? $this->_rootref['L_ADD'] : ((isset($user->lang['ADD'])) ? $user->lang['ADD'] : '{ ADD }')); ?>" /> ]
				<?php } ?>
				</li>
			<?php }} else { ?>
				<li><?php echo ((isset($this->_rootref['L_NO_FRIENDS_ONLINE'])) ? $this->_rootref['L_NO_FRIENDS_ONLINE'] : ((isset($user->lang['NO_FRIENDS_ONLINE'])) ? $user->lang['NO_FRIENDS_ONLINE'] : '{ NO_FRIENDS_ONLINE }')); ?></li>
			<?php } ?>
			</ul>

			<hr />

			<b class="genmed" style="color:red"><?php echo ((isset($this->_rootref['L_FRIENDS_OFFLINE'])) ? $this->_rootref['L_FRIENDS_OFFLINE'] : ((isset($user->lang['FRIENDS_OFFLINE'])) ? $user->lang['FRIENDS_OFFLINE'] : '{ FRIENDS_OFFLINE }')); ?></b>

			<ul class="nav" style="margin: 0; padding: 0; list-style-type: none; line-height: 175%;">
			<?php $_friends_offline_count = (isset($this->_tpldata['friends_offline'])) ? sizeof($this->_tpldata['friends_offline']) : 0;if ($_friends_offline_count) {for ($_friends_offline_i = 0; $_friends_offline_i < $_friends_offline_count; ++$_friends_offline_i){$_friends_offline_val = &$this->_tpldata['friends_offline'][$_friends_offline_i]; ?>
				<li><?php echo $_friends_offline_val['USERNAME_FULL']; ?>
				<?php if ($this->_rootref['S_SHOW_PM_BOX']) {  ?>
					&nbsp;[ <input class="post" style="font-size: 90%;" type="submit" name="add_to[<?php echo $_friends_offline_val['USER_ID']; ?>]" value="<?php echo ((isset($this->_rootref['L_ADD'])) ? $this->_rootref['L_ADD'] : ((isset($user->lang['ADD'])) ? $user->lang['ADD'] : '{ ADD }')); ?>" /> ]
				<?php } ?>
				</li>
			<?php }} else { ?>
				<li><?php echo ((isset($this->_rootref['L_NO_FRIENDS_OFFLINE'])) ? $this->_rootref['L_NO_FRIENDS_OFFLINE'] : ((isset($user->lang['NO_FRIENDS_OFFLINE'])) ? $user->lang['NO_FRIENDS_OFFLINE'] : '{ NO_FRIENDS_OFFLINE }')); ?></li>
			<?php } ?>
			</ul>

		</td>
	</tr>
	</table>
<?php } ?>

</td>
<td><img src="images/spacer.gif" width="4" alt="" /></td>
<td width="80%" valign="top"><?php if (! $this->_rootref['S_PRIVMSGS'] || $this->_rootref['S_SHOW_DRAFTS']) {  ?><form name="ucp" id="ucp" method="post" action="<?php echo (isset($this->_rootref['S_UCP_ACTION'])) ? $this->_rootref['S_UCP_ACTION'] : ''; ?>"<?php echo (isset($this->_rootref['S_FORM_ENCTYPE'])) ? $this->_rootref['S_FORM_ENCTYPE'] : ''; ?>><?php } ?>
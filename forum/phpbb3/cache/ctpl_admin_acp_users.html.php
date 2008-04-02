<?php $this->_tpl_include('overall_header.html'); ?>

<a name="maincontent"></a>

<?php if ($this->_rootref['S_SELECT_USER']) {  ?>

	<h1><?php echo ((isset($this->_rootref['L_USER_ADMIN'])) ? $this->_rootref['L_USER_ADMIN'] : ((isset($user->lang['USER_ADMIN'])) ? $user->lang['USER_ADMIN'] : '{ USER_ADMIN }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_USER_ADMIN_EXPLAIN'])) ? $this->_rootref['L_USER_ADMIN_EXPLAIN'] : ((isset($user->lang['USER_ADMIN_EXPLAIN'])) ? $user->lang['USER_ADMIN_EXPLAIN'] : '{ USER_ADMIN_EXPLAIN }')); ?></p>

	<form id="select_user" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_SELECT_USER'])) ? $this->_rootref['L_SELECT_USER'] : ((isset($user->lang['SELECT_USER'])) ? $user->lang['SELECT_USER'] : '{ SELECT_USER }')); ?></legend>
	<dl>
		<dt><label for="username"><?php echo ((isset($this->_rootref['L_FIND_USERNAME'])) ? $this->_rootref['L_FIND_USERNAME'] : ((isset($user->lang['FIND_USERNAME'])) ? $user->lang['FIND_USERNAME'] : '{ FIND_USERNAME }')); ?>:</label></dt>
		<dd><input class="text medium" type="text" id="username" name="username" /></dd>
		<dd>[ <a href="<?php echo (isset($this->_rootref['U_FIND_USERNAME'])) ? $this->_rootref['U_FIND_USERNAME'] : ''; ?>" onclick="find_username(this.href); return false;"><?php echo ((isset($this->_rootref['L_FIND_USERNAME'])) ? $this->_rootref['L_FIND_USERNAME'] : ((isset($user->lang['FIND_USERNAME'])) ? $user->lang['FIND_USERNAME'] : '{ FIND_USERNAME }')); ?></a> ]</dd>
		<dd class="full" style="text-align: left;"><label><input type="checkbox" class="radio" id="anonymous" name="u" value="<?php echo (isset($this->_rootref['ANONYMOUS_USER_ID'])) ? $this->_rootref['ANONYMOUS_USER_ID'] : ''; ?>" /> <?php echo ((isset($this->_rootref['L_SELECT_ANONYMOUS'])) ? $this->_rootref['L_SELECT_ANONYMOUS'] : ((isset($user->lang['SELECT_ANONYMOUS'])) ? $user->lang['SELECT_ANONYMOUS'] : '{ SELECT_ANONYMOUS }')); ?></label></dd>
	</dl>

	<p class="quick">
		<input type="submit" name="submituser" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" class="button1" />
	</p>
	</fieldset>

	</form>

<?php } else if ($this->_rootref['S_SELECT_FORUM']) {  ?>

	<a href="<?php echo (isset($this->_rootref['U_BACK'])) ? $this->_rootref['U_BACK'] : ''; ?>" style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>;">&laquo; <?php echo ((isset($this->_rootref['L_BACK'])) ? $this->_rootref['L_BACK'] : ((isset($user->lang['BACK'])) ? $user->lang['BACK'] : '{ BACK }')); ?></a>

	<h1><?php echo ((isset($this->_rootref['L_USER_ADMIN'])) ? $this->_rootref['L_USER_ADMIN'] : ((isset($user->lang['USER_ADMIN'])) ? $user->lang['USER_ADMIN'] : '{ USER_ADMIN }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_USER_ADMIN_EXPLAIN'])) ? $this->_rootref['L_USER_ADMIN_EXPLAIN'] : ((isset($user->lang['USER_ADMIN_EXPLAIN'])) ? $user->lang['USER_ADMIN_EXPLAIN'] : '{ USER_ADMIN_EXPLAIN }')); ?></p>

	<form id="select_forum" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_USER_ADMIN_MOVE_POSTS'])) ? $this->_rootref['L_USER_ADMIN_MOVE_POSTS'] : ((isset($user->lang['USER_ADMIN_MOVE_POSTS'])) ? $user->lang['USER_ADMIN_MOVE_POSTS'] : '{ USER_ADMIN_MOVE_POSTS }')); ?></legend>
	<dl>
		<dt><label for="new_forum"><?php echo ((isset($this->_rootref['L_USER_ADMIN_MOVE_POSTS'])) ? $this->_rootref['L_USER_ADMIN_MOVE_POSTS'] : ((isset($user->lang['USER_ADMIN_MOVE_POSTS'])) ? $user->lang['USER_ADMIN_MOVE_POSTS'] : '{ USER_ADMIN_MOVE_POSTS }')); ?></label><br /><span><?php echo ((isset($this->_rootref['L_MOVE_POSTS_EXPLAIN'])) ? $this->_rootref['L_MOVE_POSTS_EXPLAIN'] : ((isset($user->lang['MOVE_POSTS_EXPLAIN'])) ? $user->lang['MOVE_POSTS_EXPLAIN'] : '{ MOVE_POSTS_EXPLAIN }')); ?></span></dt>
		<dd><select id="new_forum" name="new_f"><?php echo (isset($this->_rootref['S_FORUM_OPTIONS'])) ? $this->_rootref['S_FORUM_OPTIONS'] : ''; ?></select></dd>
	</dl>
	</fieldset>

	<fieldset class="quick">
		<input type="submit" name="update" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" class="button1" />
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
	</form>

<?php } else { ?>

	<a href="<?php echo (isset($this->_rootref['U_BACK'])) ? $this->_rootref['U_BACK'] : ''; ?>" style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>;">&laquo; <?php echo ((isset($this->_rootref['L_BACK'])) ? $this->_rootref['L_BACK'] : ((isset($user->lang['BACK'])) ? $user->lang['BACK'] : '{ BACK }')); ?></a>

	<h1><?php echo ((isset($this->_rootref['L_USER_ADMIN'])) ? $this->_rootref['L_USER_ADMIN'] : ((isset($user->lang['USER_ADMIN'])) ? $user->lang['USER_ADMIN'] : '{ USER_ADMIN }')); ?> :: <?php echo (isset($this->_rootref['MANAGED_USERNAME'])) ? $this->_rootref['MANAGED_USERNAME'] : ''; ?></h1>

	<p><?php echo ((isset($this->_rootref['L_USER_ADMIN_EXPLAIN'])) ? $this->_rootref['L_USER_ADMIN_EXPLAIN'] : ((isset($user->lang['USER_ADMIN_EXPLAIN'])) ? $user->lang['USER_ADMIN_EXPLAIN'] : '{ USER_ADMIN_EXPLAIN }')); ?></p>

	<?php if ($this->_rootref['S_ERROR']) {  ?>
		<div class="errorbox">
			<h3><?php echo ((isset($this->_rootref['L_WARNING'])) ? $this->_rootref['L_WARNING'] : ((isset($user->lang['WARNING'])) ? $user->lang['WARNING'] : '{ WARNING }')); ?></h3>
			<p><?php echo (isset($this->_rootref['ERROR_MSG'])) ? $this->_rootref['ERROR_MSG'] : ''; ?></p>
		</div>
	<?php } ?>

	<form id="mode_select" method="post" action="<?php echo (isset($this->_rootref['U_MODE_SELECT'])) ? $this->_rootref['U_MODE_SELECT'] : ''; ?>">

	<fieldset class="quick">
		<?php echo ((isset($this->_rootref['L_SELECT_FORM'])) ? $this->_rootref['L_SELECT_FORM'] : ((isset($user->lang['SELECT_FORM'])) ? $user->lang['SELECT_FORM'] : '{ SELECT_FORM }')); ?>: <select name="mode" onchange="if (this.options[this.selectedIndex].value != '') this.form.submit();"><?php echo (isset($this->_rootref['S_FORM_OPTIONS'])) ? $this->_rootref['S_FORM_OPTIONS'] : ''; ?></select> <input class="button2" type="submit" value="<?php echo ((isset($this->_rootref['L_GO'])) ? $this->_rootref['L_GO'] : ((isset($user->lang['GO'])) ? $user->lang['GO'] : '{ GO }')); ?>" />
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
	</form>

<?php } if ($this->_rootref['S_OVERVIEW']) {  $this->_tpl_include('acp_users_overview.html'); } else if ($this->_rootref['S_FEEDBACK']) {  $this->_tpl_include('acp_users_feedback.html'); } else if ($this->_rootref['S_PROFILE']) {  $this->_tpl_include('acp_users_profile.html'); } else if ($this->_rootref['S_PREFS']) {  $this->_tpl_include('acp_users_prefs.html'); } else if ($this->_rootref['S_AVATAR']) {  $this->_tpl_include('acp_users_avatar.html'); } else if ($this->_rootref['S_RANK']) {  ?>

	<form id="user_prefs" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_ACP_USER_RANK'])) ? $this->_rootref['L_ACP_USER_RANK'] : ((isset($user->lang['ACP_USER_RANK'])) ? $user->lang['ACP_USER_RANK'] : '{ ACP_USER_RANK }')); ?></legend>
	<dl>
		<dt><label for="user_rank"><?php echo ((isset($this->_rootref['L_USER_RANK'])) ? $this->_rootref['L_USER_RANK'] : ((isset($user->lang['USER_RANK'])) ? $user->lang['USER_RANK'] : '{ USER_RANK }')); ?>:</label></dt>
		<dd><select name="user_rank" id="user_rank"><?php echo (isset($this->_rootref['S_RANK_OPTIONS'])) ? $this->_rootref['S_RANK_OPTIONS'] : ''; ?></select></dd>
	</dl>
	</fieldset>

	<fieldset class="quick">
		<input class="button1" type="submit" name="update" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
	</form>

<?php } else if ($this->_rootref['S_SIGNATURE']) {  $this->_tpl_include('acp_users_signature.html'); } else if ($this->_rootref['S_GROUPS']) {  ?>

	<form id="user_groups" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

	<table cellspacing="1">
	<tbody>
	<?php $_group_count = (isset($this->_tpldata['group'])) ? sizeof($this->_tpldata['group']) : 0;if ($_group_count) {for ($_group_i = 0; $_group_i < $_group_count; ++$_group_i){$_group_val = &$this->_tpldata['group'][$_group_i]; if ($_group_val['S_NEW_GROUP_TYPE']) {  ?>
		<tr>
			<td class="row3" colspan="4"><strong><?php echo $_group_val['GROUP_TYPE']; ?></strong></td>
		</tr>
		<?php } else { if (!($_group_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>
				<td><a href="<?php echo $_group_val['U_EDIT_GROUP']; ?>"><?php echo $_group_val['GROUP_NAME']; ?></a></td>
				<td><?php if ($_group_val['S_NO_DEFAULT']) {  ?><a href="<?php echo $_group_val['U_DEFAULT']; ?>"><?php echo ((isset($this->_rootref['L_GROUP_DEFAULT'])) ? $this->_rootref['L_GROUP_DEFAULT'] : ((isset($user->lang['GROUP_DEFAULT'])) ? $user->lang['GROUP_DEFAULT'] : '{ GROUP_DEFAULT }')); ?></a><?php } else { ?><strong><?php echo ((isset($this->_rootref['L_GROUP_DEFAULT'])) ? $this->_rootref['L_GROUP_DEFAULT'] : ((isset($user->lang['GROUP_DEFAULT'])) ? $user->lang['GROUP_DEFAULT'] : '{ GROUP_DEFAULT }')); ?></strong><?php } ?></td>
				<td><?php if (! $_group_val['S_SPECIAL_GROUP']) {  ?><a href="<?php echo $_group_val['U_DEMOTE_PROMOTE']; ?>"><?php echo $_group_val['L_DEMOTE_PROMOTE']; ?></a><?php } else { ?>&nbsp;<?php } ?></td>
				<td><a href="<?php echo $_group_val['U_DELETE']; ?>"><?php echo ((isset($this->_rootref['L_GROUP_DELETE'])) ? $this->_rootref['L_GROUP_DELETE'] : ((isset($user->lang['GROUP_DELETE'])) ? $user->lang['GROUP_DELETE'] : '{ GROUP_DELETE }')); ?></a></td>
			</tr>
		<?php } }} ?>
	</tbody>
	</table>

	<?php if ($this->_rootref['S_GROUP_OPTIONS']) {  ?>
		<fieldset class="quick">
			<?php echo ((isset($this->_rootref['L_USER_GROUP_ADD'])) ? $this->_rootref['L_USER_GROUP_ADD'] : ((isset($user->lang['USER_GROUP_ADD'])) ? $user->lang['USER_GROUP_ADD'] : '{ USER_GROUP_ADD }')); ?>: <select name="g"><?php echo (isset($this->_rootref['S_GROUP_OPTIONS'])) ? $this->_rootref['S_GROUP_OPTIONS'] : ''; ?></select> <input class="button1" type="submit" name="update" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />
			<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
		</fieldset>
	<?php } ?>
	</form>

<?php } else if ($this->_rootref['S_ATTACHMENTS']) {  ?>

	<form id="user_attachments" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">


	<?php if ($this->_rootref['PAGINATION']) {  ?>
	<div class="pagination">
		<a href="#" onclick="jumpto(); return false;" title="<?php echo ((isset($this->_rootref['L_JUMP_TO_PAGE'])) ? $this->_rootref['L_JUMP_TO_PAGE'] : ((isset($user->lang['JUMP_TO_PAGE'])) ? $user->lang['JUMP_TO_PAGE'] : '{ JUMP_TO_PAGE }')); ?>"><?php echo (isset($this->_rootref['S_ON_PAGE'])) ? $this->_rootref['S_ON_PAGE'] : ''; ?></a> &bull; <span><?php echo (isset($this->_rootref['PAGINATION'])) ? $this->_rootref['PAGINATION'] : ''; ?></span>
	</div>
	<?php } if (sizeof($this->_tpldata['attach'])) {  ?>
	<table cellspacing="1">
	<thead>
	<tr>
		<th><?php echo ((isset($this->_rootref['L_FILENAME'])) ? $this->_rootref['L_FILENAME'] : ((isset($user->lang['FILENAME'])) ? $user->lang['FILENAME'] : '{ FILENAME }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_POST_TIME'])) ? $this->_rootref['L_POST_TIME'] : ((isset($user->lang['POST_TIME'])) ? $user->lang['POST_TIME'] : '{ POST_TIME }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_FILESIZE'])) ? $this->_rootref['L_FILESIZE'] : ((isset($user->lang['FILESIZE'])) ? $user->lang['FILESIZE'] : '{ FILESIZE }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_DOWNLOADS'])) ? $this->_rootref['L_DOWNLOADS'] : ((isset($user->lang['DOWNLOADS'])) ? $user->lang['DOWNLOADS'] : '{ DOWNLOADS }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_MARK'])) ? $this->_rootref['L_MARK'] : ((isset($user->lang['MARK'])) ? $user->lang['MARK'] : '{ MARK }')); ?></th>
	</tr>
	</thead>
	<tbody>
	<?php $_attach_count = (isset($this->_tpldata['attach'])) ? sizeof($this->_tpldata['attach']) : 0;if ($_attach_count) {for ($_attach_i = 0; $_attach_i < $_attach_count; ++$_attach_i){$_attach_val = &$this->_tpldata['attach'][$_attach_i]; if (!($_attach_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>
		<td><a href="<?php echo $_attach_val['U_DOWNLOAD']; ?>"><?php echo $_attach_val['REAL_FILENAME']; ?></a><br /><span class="small"><?php if ($_attach_val['S_IN_MESSAGE']) {  ?><strong><?php echo ((isset($this->_rootref['L_PM'])) ? $this->_rootref['L_PM'] : ((isset($user->lang['PM'])) ? $user->lang['PM'] : '{ PM }')); ?>: </strong><?php } else { ?><strong><?php echo ((isset($this->_rootref['L_POST'])) ? $this->_rootref['L_POST'] : ((isset($user->lang['POST'])) ? $user->lang['POST'] : '{ POST }')); ?>: </strong><?php } ?><a href="<?php echo $_attach_val['U_VIEW_TOPIC']; ?>"><?php echo $_attach_val['TOPIC_TITLE']; ?></a></span></td>
		<td style="text-align: center"><?php echo $_attach_val['POST_TIME']; ?></td>
		<td style="text-align: center"><?php echo $_attach_val['SIZE']; ?></td>
		<td style="text-align: center"><?php echo $_attach_val['DOWNLOAD_COUNT']; ?></td>
		<td style="text-align: center"><input type="checkbox" class="radio" name="mark[]" value="<?php echo $_attach_val['ATTACH_ID']; ?>" /></td>
	</tr>
	<?php }} ?>
	</tbody>
	</table>
	<?php } else { ?>
	<div class="errorbox">
		<p><?php echo ((isset($this->_rootref['L_USER_NO_ATTACHMENTS'])) ? $this->_rootref['L_USER_NO_ATTACHMENTS'] : ((isset($user->lang['USER_NO_ATTACHMENTS'])) ? $user->lang['USER_NO_ATTACHMENTS'] : '{ USER_NO_ATTACHMENTS }')); ?></p>
	</div>
	<?php } ?>
	<fieldset class="display-options">
		<?php echo ((isset($this->_rootref['L_SORT_BY'])) ? $this->_rootref['L_SORT_BY'] : ((isset($user->lang['SORT_BY'])) ? $user->lang['SORT_BY'] : '{ SORT_BY }')); ?>: <select name="sk"><?php echo (isset($this->_rootref['S_SORT_KEY'])) ? $this->_rootref['S_SORT_KEY'] : ''; ?></select> <select name="sd"><?php echo (isset($this->_rootref['S_SORT_DIR'])) ? $this->_rootref['S_SORT_DIR'] : ''; ?></select>
		<input class="button2" type="submit" value="<?php echo ((isset($this->_rootref['L_GO'])) ? $this->_rootref['L_GO'] : ((isset($user->lang['GO'])) ? $user->lang['GO'] : '{ GO }')); ?>" name="sort" />
	</fieldset>
	<hr />
	<?php if ($this->_rootref['PAGINATION']) {  ?>
	<div class="pagination">
		<a href="#" onclick="jumpto(); return false;" title="<?php echo ((isset($this->_rootref['L_JUMP_TO_PAGE'])) ? $this->_rootref['L_JUMP_TO_PAGE'] : ((isset($user->lang['JUMP_TO_PAGE'])) ? $user->lang['JUMP_TO_PAGE'] : '{ JUMP_TO_PAGE }')); ?>"><?php echo (isset($this->_rootref['S_ON_PAGE'])) ? $this->_rootref['S_ON_PAGE'] : ''; ?></a> &bull; <span><?php echo (isset($this->_rootref['PAGINATION'])) ? $this->_rootref['PAGINATION'] : ''; ?></span>
	</div>
	<?php } ?>
	
	<fieldset class="quick">
		<input class="button2" type="submit" name="delmarked" value="<?php echo ((isset($this->_rootref['L_DELETE_MARKED'])) ? $this->_rootref['L_DELETE_MARKED'] : ((isset($user->lang['DELETE_MARKED'])) ? $user->lang['DELETE_MARKED'] : '{ DELETE_MARKED }')); ?>" />
		<p class="small"><a href="#" onclick="marklist('user_attachments', 'mark', true);"><?php echo ((isset($this->_rootref['L_MARK_ALL'])) ? $this->_rootref['L_MARK_ALL'] : ((isset($user->lang['MARK_ALL'])) ? $user->lang['MARK_ALL'] : '{ MARK_ALL }')); ?></a> &bull; <a href="#" onclick="marklist('user_attachments', 'mark', false);"><?php echo ((isset($this->_rootref['L_UNMARK_ALL'])) ? $this->_rootref['L_UNMARK_ALL'] : ((isset($user->lang['UNMARK_ALL'])) ? $user->lang['UNMARK_ALL'] : '{ UNMARK_ALL }')); ?></a></p>
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
	</form>

<?php } else if ($this->_rootref['S_PERMISSIONS']) {  ?>

	<div style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>;">
		<a href="<?php echo (isset($this->_rootref['U_USER_PERMISSIONS'])) ? $this->_rootref['U_USER_PERMISSIONS'] : ''; ?>">&raquo; <?php echo ((isset($this->_rootref['L_SET_USERS_PERMISSIONS'])) ? $this->_rootref['L_SET_USERS_PERMISSIONS'] : ((isset($user->lang['SET_USERS_PERMISSIONS'])) ? $user->lang['SET_USERS_PERMISSIONS'] : '{ SET_USERS_PERMISSIONS }')); ?></a><br />
		<a href="<?php echo (isset($this->_rootref['U_USER_FORUM_PERMISSIONS'])) ? $this->_rootref['U_USER_FORUM_PERMISSIONS'] : ''; ?>">&raquo; <?php echo ((isset($this->_rootref['L_SET_USERS_FORUM_PERMISSIONS'])) ? $this->_rootref['L_SET_USERS_FORUM_PERMISSIONS'] : ((isset($user->lang['SET_USERS_FORUM_PERMISSIONS'])) ? $user->lang['SET_USERS_FORUM_PERMISSIONS'] : '{ SET_USERS_FORUM_PERMISSIONS }')); ?></a>
	</div>

	<form id="select_forum" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

		<fieldset class="quick" style="text-align: left;">
			<?php echo ((isset($this->_rootref['L_SELECT_FORUM'])) ? $this->_rootref['L_SELECT_FORUM'] : ((isset($user->lang['SELECT_FORUM'])) ? $user->lang['SELECT_FORUM'] : '{ SELECT_FORUM }')); ?>: <select name="f"><?php echo (isset($this->_rootref['S_FORUM_OPTIONS'])) ? $this->_rootref['S_FORUM_OPTIONS'] : ''; ?></select> 
			<input class="button2" type="submit" value="<?php echo ((isset($this->_rootref['L_GO'])) ? $this->_rootref['L_GO'] : ((isset($user->lang['GO'])) ? $user->lang['GO'] : '{ GO }')); ?>" name="select" />
			<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
		</fieldset>
	</form>

	<div class="clearfix">&nbsp;</div>

	<?php $this->_tpl_include('permission_mask.html'); } $this->_tpl_include('overall_footer.html'); ?>
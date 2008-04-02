<?php $this->_tpl_include('overall_header.html'); ?>

<a name="maincontent"></a>

<?php if ($this->_rootref['S_INTRO']) {  ?>
	
	<h1><?php echo ((isset($this->_rootref['L_ACP_PERMISSIONS'])) ? $this->_rootref['L_ACP_PERMISSIONS'] : ((isset($user->lang['ACP_PERMISSIONS'])) ? $user->lang['ACP_PERMISSIONS'] : '{ ACP_PERMISSIONS }')); ?></h1>

	<?php echo ((isset($this->_rootref['L_ACP_PERMISSIONS_EXPLAIN'])) ? $this->_rootref['L_ACP_PERMISSIONS_EXPLAIN'] : ((isset($user->lang['ACP_PERMISSIONS_EXPLAIN'])) ? $user->lang['ACP_PERMISSIONS_EXPLAIN'] : '{ ACP_PERMISSIONS_EXPLAIN }')); ?>

<?php } if ($this->_rootref['S_SELECT_VICTIM']) {  ?>

	<h1><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_EXPLAIN'])) ? $this->_rootref['L_EXPLAIN'] : ((isset($user->lang['EXPLAIN'])) ? $user->lang['EXPLAIN'] : '{ EXPLAIN }')); ?></p>
	
	<?php if ($this->_rootref['S_FORUM_NAMES']) {  ?>
		<p><strong><?php echo ((isset($this->_rootref['L_FORUMS'])) ? $this->_rootref['L_FORUMS'] : ((isset($user->lang['FORUMS'])) ? $user->lang['FORUMS'] : '{ FORUMS }')); ?>:</strong> <?php echo (isset($this->_rootref['FORUM_NAMES'])) ? $this->_rootref['FORUM_NAMES'] : ''; ?></p>
	<?php } if ($this->_rootref['S_SELECT_FORUM']) {  ?>

		<form id="select_victim" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

		<fieldset>
			<legend><?php echo ((isset($this->_rootref['L_LOOK_UP_FORUM'])) ? $this->_rootref['L_LOOK_UP_FORUM'] : ((isset($user->lang['LOOK_UP_FORUM'])) ? $user->lang['LOOK_UP_FORUM'] : '{ LOOK_UP_FORUM }')); ?></legend>
			<?php if ($this->_rootref['S_FORUM_MULTIPLE']) {  ?><p><?php echo ((isset($this->_rootref['L_LOOK_UP_FORUMS_EXPLAIN'])) ? $this->_rootref['L_LOOK_UP_FORUMS_EXPLAIN'] : ((isset($user->lang['LOOK_UP_FORUMS_EXPLAIN'])) ? $user->lang['LOOK_UP_FORUMS_EXPLAIN'] : '{ LOOK_UP_FORUMS_EXPLAIN }')); ?></p><?php } ?>
		<dl>
			<dt><label for="forum"><?php echo ((isset($this->_rootref['L_LOOK_UP_FORUM'])) ? $this->_rootref['L_LOOK_UP_FORUM'] : ((isset($user->lang['LOOK_UP_FORUM'])) ? $user->lang['LOOK_UP_FORUM'] : '{ LOOK_UP_FORUM }')); ?>:</label></dt>
			<dd><select id="forum" name="forum_id[]"<?php if ($this->_rootref['S_FORUM_MULTIPLE']) {  ?> multiple="multiple"<?php } ?> size="10"><?php echo (isset($this->_rootref['S_FORUM_OPTIONS'])) ? $this->_rootref['S_FORUM_OPTIONS'] : ''; ?></select></dd>
			<?php if ($this->_rootref['S_FORUM_ALL']) {  ?><dd><label><input type="checkbox" class="radio" name="all_forums" value="1" /> <?php echo ((isset($this->_rootref['L_ALL_FORUMS'])) ? $this->_rootref['L_ALL_FORUMS'] : ((isset($user->lang['ALL_FORUMS'])) ? $user->lang['ALL_FORUMS'] : '{ ALL_FORUMS }')); ?></label></dd><?php } ?>
		</dl>

		<p class="quick">
			<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?>
			<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
			<input type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" class="button1" />
		</p>

		</fieldset>
		</form>

		<?php if ($this->_rootref['S_FORUM_MULTIPLE']) {  ?>

			<form id="select_subforum" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

			<fieldset>
				<legend><?php echo ((isset($this->_rootref['L_LOOK_UP_FORUM'])) ? $this->_rootref['L_LOOK_UP_FORUM'] : ((isset($user->lang['LOOK_UP_FORUM'])) ? $user->lang['LOOK_UP_FORUM'] : '{ LOOK_UP_FORUM }')); ?></legend>
				<p><?php echo ((isset($this->_rootref['L_SELECT_FORUM_SUBFORUM_EXPLAIN'])) ? $this->_rootref['L_SELECT_FORUM_SUBFORUM_EXPLAIN'] : ((isset($user->lang['SELECT_FORUM_SUBFORUM_EXPLAIN'])) ? $user->lang['SELECT_FORUM_SUBFORUM_EXPLAIN'] : '{ SELECT_FORUM_SUBFORUM_EXPLAIN }')); ?></p>
			<dl>
				<dt><label for="sforum"><?php echo ((isset($this->_rootref['L_LOOK_UP_FORUM'])) ? $this->_rootref['L_LOOK_UP_FORUM'] : ((isset($user->lang['LOOK_UP_FORUM'])) ? $user->lang['LOOK_UP_FORUM'] : '{ LOOK_UP_FORUM }')); ?>:</label></dt>
				<dd><select id="sforum" name="subforum_id"><?php echo (isset($this->_rootref['S_SUBFORUM_OPTIONS'])) ? $this->_rootref['S_SUBFORUM_OPTIONS'] : ''; ?></select></dd>
			</dl>

			<p class="quick">
				<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?>
				<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
				<input type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" class="button1" />
			</p>

			</fieldset>
			</form>
			
		<?php } } else if ($this->_rootref['S_SELECT_USER'] && $this->_rootref['S_CAN_SELECT_USER']) {  ?>

		<form id="select_victim" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

		<fieldset>
			<legend><?php echo ((isset($this->_rootref['L_LOOK_UP_USER'])) ? $this->_rootref['L_LOOK_UP_USER'] : ((isset($user->lang['LOOK_UP_USER'])) ? $user->lang['LOOK_UP_USER'] : '{ LOOK_UP_USER }')); ?></legend>
		<dl>
			<dt><label for="username"><?php echo ((isset($this->_rootref['L_FIND_USERNAME'])) ? $this->_rootref['L_FIND_USERNAME'] : ((isset($user->lang['FIND_USERNAME'])) ? $user->lang['FIND_USERNAME'] : '{ FIND_USERNAME }')); ?>:</label></dt>
			<dd><input class="text medium" type="text" id="username" name="username[]" /></dd>
			<dd>[ <a href="<?php echo (isset($this->_rootref['U_FIND_USERNAME'])) ? $this->_rootref['U_FIND_USERNAME'] : ''; ?>" onclick="find_username(this.href); return false;"><?php echo ((isset($this->_rootref['L_FIND_USERNAME'])) ? $this->_rootref['L_FIND_USERNAME'] : ((isset($user->lang['FIND_USERNAME'])) ? $user->lang['FIND_USERNAME'] : '{ FIND_USERNAME }')); ?></a> ]</dd>
			<dd class="full" style="text-align: left;"><label><input type="checkbox" class="radio" id="anonymous" name="user_id[]" value="<?php echo (isset($this->_rootref['ANONYMOUS_USER_ID'])) ? $this->_rootref['ANONYMOUS_USER_ID'] : ''; ?>" /> <?php echo ((isset($this->_rootref['L_SELECT_ANONYMOUS'])) ? $this->_rootref['L_SELECT_ANONYMOUS'] : ((isset($user->lang['SELECT_ANONYMOUS'])) ? $user->lang['SELECT_ANONYMOUS'] : '{ SELECT_ANONYMOUS }')); ?></label></dd>
		</dl>

		<p class="quick">
			<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?>
			<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
			<input type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" class="button1" />
		</p>
		</fieldset>
		</form>

	<?php } else if ($this->_rootref['S_SELECT_GROUP'] && $this->_rootref['S_CAN_SELECT_GROUP']) {  ?>

		<form id="select_victim" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

		<fieldset>
			<legend><?php echo ((isset($this->_rootref['L_LOOK_UP_GROUP'])) ? $this->_rootref['L_LOOK_UP_GROUP'] : ((isset($user->lang['LOOK_UP_GROUP'])) ? $user->lang['LOOK_UP_GROUP'] : '{ LOOK_UP_GROUP }')); ?></legend>
		<dl>
			<dt><label for="group"><?php echo ((isset($this->_rootref['L_LOOK_UP_GROUP'])) ? $this->_rootref['L_LOOK_UP_GROUP'] : ((isset($user->lang['LOOK_UP_GROUP'])) ? $user->lang['LOOK_UP_GROUP'] : '{ LOOK_UP_GROUP }')); ?>:</label></dt>
			<dd><select name="group_id[]" id="group"><?php echo (isset($this->_rootref['S_GROUP_OPTIONS'])) ? $this->_rootref['S_GROUP_OPTIONS'] : ''; ?></select></dd>
		</dl>

		<p class="quick">
			<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?>
			<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
			<input type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" class="button1" />
		</p>

		</fieldset>
		</form>

		<?php } else if ($this->_rootref['S_SELECT_USERGROUP']) {  ?>

		<div style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>; width: 48%;">

		<?php if ($this->_rootref['S_CAN_SELECT_USER']) {  ?>

			<h1><?php echo ((isset($this->_rootref['L_USERS'])) ? $this->_rootref['L_USERS'] : ((isset($user->lang['USERS'])) ? $user->lang['USERS'] : '{ USERS }')); ?></h1>

			<form id="users" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

			<fieldset>
				<legend><?php echo ((isset($this->_rootref['L_MANAGE_USERS'])) ? $this->_rootref['L_MANAGE_USERS'] : ((isset($user->lang['MANAGE_USERS'])) ? $user->lang['MANAGE_USERS'] : '{ MANAGE_USERS }')); ?></legend>
			<dl>
				<dd class="full"><select style="width: 100%;" name="user_id[]" multiple="multiple" size="5"><?php echo (isset($this->_rootref['S_DEFINED_USER_OPTIONS'])) ? $this->_rootref['S_DEFINED_USER_OPTIONS'] : ''; ?></select></dd>
				<?php if ($this->_rootref['S_ALLOW_ALL_SELECT']) {  ?><dd class="full" style="text-align: right;"><label><input type="checkbox" class="radio" name="all_users" value="1" /> <?php echo ((isset($this->_rootref['L_ALL_USERS'])) ? $this->_rootref['L_ALL_USERS'] : ((isset($user->lang['ALL_USERS'])) ? $user->lang['ALL_USERS'] : '{ ALL_USERS }')); ?></label></dd><?php } ?>
			</dl>
			</fieldset>
			
			<fieldset class="quick">
				<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?>
				<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
				<input type="submit" class="button2" name="action[delete]" value="<?php echo ((isset($this->_rootref['L_REMOVE_PERMISSIONS'])) ? $this->_rootref['L_REMOVE_PERMISSIONS'] : ((isset($user->lang['REMOVE_PERMISSIONS'])) ? $user->lang['REMOVE_PERMISSIONS'] : '{ REMOVE_PERMISSIONS }')); ?>" style="width: 46% !important;" /> &nbsp; <input class="button1" type="submit" name="submit_edit_options" value="<?php echo ((isset($this->_rootref['L_EDIT_PERMISSIONS'])) ? $this->_rootref['L_EDIT_PERMISSIONS'] : ((isset($user->lang['EDIT_PERMISSIONS'])) ? $user->lang['EDIT_PERMISSIONS'] : '{ EDIT_PERMISSIONS }')); ?>" style="width: 46% !important;" />
			</fieldset>
			</form>

			<form id="add_user" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

			<fieldset>
				<legend><?php echo ((isset($this->_rootref['L_ADD_USERS'])) ? $this->_rootref['L_ADD_USERS'] : ((isset($user->lang['ADD_USERS'])) ? $user->lang['ADD_USERS'] : '{ ADD_USERS }')); ?></legend>
				<p><?php echo ((isset($this->_rootref['L_USERNAMES_EXPLAIN'])) ? $this->_rootref['L_USERNAMES_EXPLAIN'] : ((isset($user->lang['USERNAMES_EXPLAIN'])) ? $user->lang['USERNAMES_EXPLAIN'] : '{ USERNAMES_EXPLAIN }')); ?></p>
			<dl>
				<dd class="full"><textarea id="username" name="usernames" rows="5" cols="5" style="width: 100%; height: 60px;"></textarea></dd>
				<dd class="full" style="text-align: left;"><div style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>;">[ <a href="<?php echo (isset($this->_rootref['U_FIND_USERNAME'])) ? $this->_rootref['U_FIND_USERNAME'] : ''; ?>" onclick="find_username(this.href); return false;"><?php echo ((isset($this->_rootref['L_FIND_USERNAME'])) ? $this->_rootref['L_FIND_USERNAME'] : ((isset($user->lang['FIND_USERNAME'])) ? $user->lang['FIND_USERNAME'] : '{ FIND_USERNAME }')); ?></a> ]</div><label><input type="checkbox" class="radio" id="anonymous" name="user_id[]" value="<?php echo (isset($this->_rootref['ANONYMOUS_USER_ID'])) ? $this->_rootref['ANONYMOUS_USER_ID'] : ''; ?>" /> <?php echo ((isset($this->_rootref['L_SELECT_ANONYMOUS'])) ? $this->_rootref['L_SELECT_ANONYMOUS'] : ((isset($user->lang['SELECT_ANONYMOUS'])) ? $user->lang['SELECT_ANONYMOUS'] : '{ SELECT_ANONYMOUS }')); ?></label></dd>
			</dl>
			</fieldset>

			<fieldset class="quick">
				<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?>
				<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
				<input class="button1" type="submit" name="submit_add_options" value="<?php echo ((isset($this->_rootref['L_ADD_PERMISSIONS'])) ? $this->_rootref['L_ADD_PERMISSIONS'] : ((isset($user->lang['ADD_PERMISSIONS'])) ? $user->lang['ADD_PERMISSIONS'] : '{ ADD_PERMISSIONS }')); ?>" />
			</fieldset>
			</form>

		<?php } ?>

		</div>

		<div style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>; width: 48%">
			
		<?php if ($this->_rootref['S_CAN_SELECT_GROUP']) {  ?>

			<h1><?php echo ((isset($this->_rootref['L_USERGROUPS'])) ? $this->_rootref['L_USERGROUPS'] : ((isset($user->lang['USERGROUPS'])) ? $user->lang['USERGROUPS'] : '{ USERGROUPS }')); ?></h1>

			<form id="groups" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

			<fieldset>
				<legend><?php echo ((isset($this->_rootref['L_MANAGE_GROUPS'])) ? $this->_rootref['L_MANAGE_GROUPS'] : ((isset($user->lang['MANAGE_GROUPS'])) ? $user->lang['MANAGE_GROUPS'] : '{ MANAGE_GROUPS }')); ?></legend>
			<dl>
				<dd class="full"><select style="width: 100%;" name="group_id[]" multiple="multiple" size="5"><?php echo (isset($this->_rootref['S_DEFINED_GROUP_OPTIONS'])) ? $this->_rootref['S_DEFINED_GROUP_OPTIONS'] : ''; ?></select></dd>
				<?php if ($this->_rootref['S_ALLOW_ALL_SELECT']) {  ?><dd class="full" style="text-align: right;"><label><input type="checkbox" class="radio" name="all_groups" value="1" /> <?php echo ((isset($this->_rootref['L_ALL_GROUPS'])) ? $this->_rootref['L_ALL_GROUPS'] : ((isset($user->lang['ALL_GROUPS'])) ? $user->lang['ALL_GROUPS'] : '{ ALL_GROUPS }')); ?></label></dd><?php } ?>
			</dl>
			</fieldset>
			
			<fieldset class="quick">
				<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?>
				<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
				<input class="button2" type="submit" name="action[delete]" value="<?php echo ((isset($this->_rootref['L_REMOVE_PERMISSIONS'])) ? $this->_rootref['L_REMOVE_PERMISSIONS'] : ((isset($user->lang['REMOVE_PERMISSIONS'])) ? $user->lang['REMOVE_PERMISSIONS'] : '{ REMOVE_PERMISSIONS }')); ?>" style="width: 46% !important;" /> &nbsp; <input class="button1" type="submit" name="submit_edit_options" value="<?php echo ((isset($this->_rootref['L_EDIT_PERMISSIONS'])) ? $this->_rootref['L_EDIT_PERMISSIONS'] : ((isset($user->lang['EDIT_PERMISSIONS'])) ? $user->lang['EDIT_PERMISSIONS'] : '{ EDIT_PERMISSIONS }')); ?>" style="width: 46% !important;" />
			</fieldset>
			</form>

			<form id="add_groups" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">
			
			<fieldset>
				<legend><?php echo ((isset($this->_rootref['L_ADD_GROUPS'])) ? $this->_rootref['L_ADD_GROUPS'] : ((isset($user->lang['ADD_GROUPS'])) ? $user->lang['ADD_GROUPS'] : '{ ADD_GROUPS }')); ?></legend>
			<dl>
				<dd class="full"><select name="group_id[]" style="width: 100%; height: 107px;" multiple="multiple"><?php echo (isset($this->_rootref['S_ADD_GROUP_OPTIONS'])) ? $this->_rootref['S_ADD_GROUP_OPTIONS'] : ''; ?></select></dd>
			</dl>
			</fieldset>

			<fieldset class="quick">
				<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?>
				<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
				<input type="submit" class="button1" name="submit_add_options" value="<?php echo ((isset($this->_rootref['L_ADD_PERMISSIONS'])) ? $this->_rootref['L_ADD_PERMISSIONS'] : ((isset($user->lang['ADD_PERMISSIONS'])) ? $user->lang['ADD_PERMISSIONS'] : '{ ADD_PERMISSIONS }')); ?>" />
			</fieldset>
			</form>

		<?php } ?>

		</div>

	<?php } else if ($this->_rootref['S_SELECT_USERGROUP_VIEW']) {  ?>

		<div style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>; width: 48%;">
		
			<h1><?php echo ((isset($this->_rootref['L_USERS'])) ? $this->_rootref['L_USERS'] : ((isset($user->lang['USERS'])) ? $user->lang['USERS'] : '{ USERS }')); ?></h1>

			<form id="users" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

			<fieldset>
				<legend><?php echo ((isset($this->_rootref['L_MANAGE_USERS'])) ? $this->_rootref['L_MANAGE_USERS'] : ((isset($user->lang['MANAGE_USERS'])) ? $user->lang['MANAGE_USERS'] : '{ MANAGE_USERS }')); ?></legend>
			<dl>
				<dd class="full"><select style="width: 100%;" name="user_id[]" multiple="multiple" size="5"><?php echo (isset($this->_rootref['S_DEFINED_USER_OPTIONS'])) ? $this->_rootref['S_DEFINED_USER_OPTIONS'] : ''; ?></select></dd>
			</dl>
			</fieldset>
			
			<fieldset class="quick">
				<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?>
				<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
				<input class="button1" type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_VIEW_PERMISSIONS'])) ? $this->_rootref['L_VIEW_PERMISSIONS'] : ((isset($user->lang['VIEW_PERMISSIONS'])) ? $user->lang['VIEW_PERMISSIONS'] : '{ VIEW_PERMISSIONS }')); ?>" />
			</fieldset>
			</form>

			<form id="add_user" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

			<fieldset>
				<legend><?php echo ((isset($this->_rootref['L_LOOK_UP_USER'])) ? $this->_rootref['L_LOOK_UP_USER'] : ((isset($user->lang['LOOK_UP_USER'])) ? $user->lang['LOOK_UP_USER'] : '{ LOOK_UP_USER }')); ?></legend>
			<dl>
				<dt><label for="username"><?php echo ((isset($this->_rootref['L_FIND_USERNAME'])) ? $this->_rootref['L_FIND_USERNAME'] : ((isset($user->lang['FIND_USERNAME'])) ? $user->lang['FIND_USERNAME'] : '{ FIND_USERNAME }')); ?>:</label></dt>
				<dd><input type="text" id="username" name="username[]" /></dd>
				<dd>[ <a href="<?php echo (isset($this->_rootref['U_FIND_USERNAME'])) ? $this->_rootref['U_FIND_USERNAME'] : ''; ?>" onclick="find_username(this.href); return false;"><?php echo ((isset($this->_rootref['L_FIND_USERNAME'])) ? $this->_rootref['L_FIND_USERNAME'] : ((isset($user->lang['FIND_USERNAME'])) ? $user->lang['FIND_USERNAME'] : '{ FIND_USERNAME }')); ?></a> ]</dd>
				<dd class="full" style="text-align: left;"><label><input type="checkbox" class="radio" id="anonymous" name="user_id[]" value="<?php echo (isset($this->_rootref['ANONYMOUS_USER_ID'])) ? $this->_rootref['ANONYMOUS_USER_ID'] : ''; ?>" /> <?php echo ((isset($this->_rootref['L_SELECT_ANONYMOUS'])) ? $this->_rootref['L_SELECT_ANONYMOUS'] : ((isset($user->lang['SELECT_ANONYMOUS'])) ? $user->lang['SELECT_ANONYMOUS'] : '{ SELECT_ANONYMOUS }')); ?></label></dd>
			</dl>
			</fieldset>

			<fieldset class="quick">
				<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?>
				<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
				<input type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_VIEW_PERMISSIONS'])) ? $this->_rootref['L_VIEW_PERMISSIONS'] : ((isset($user->lang['VIEW_PERMISSIONS'])) ? $user->lang['VIEW_PERMISSIONS'] : '{ VIEW_PERMISSIONS }')); ?>" class="button1" />
			</fieldset>
			</form>

		</div>

		<div style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>; width: 48%">
			
			<h1><?php echo ((isset($this->_rootref['L_USERGROUPS'])) ? $this->_rootref['L_USERGROUPS'] : ((isset($user->lang['USERGROUPS'])) ? $user->lang['USERGROUPS'] : '{ USERGROUPS }')); ?></h1>

			<form id="groups" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

			<fieldset>
				<legend><?php echo ((isset($this->_rootref['L_MANAGE_GROUPS'])) ? $this->_rootref['L_MANAGE_GROUPS'] : ((isset($user->lang['MANAGE_GROUPS'])) ? $user->lang['MANAGE_GROUPS'] : '{ MANAGE_GROUPS }')); ?></legend>
			<dl>
				<dd class="full"><select style="width: 100%;" name="group_id[]" multiple="multiple" size="5"><?php echo (isset($this->_rootref['S_DEFINED_GROUP_OPTIONS'])) ? $this->_rootref['S_DEFINED_GROUP_OPTIONS'] : ''; ?></select></dd>
			</dl>
			</fieldset>
			
			<fieldset class="quick">
				<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?>
				<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
				<input class="button1" type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_VIEW_PERMISSIONS'])) ? $this->_rootref['L_VIEW_PERMISSIONS'] : ((isset($user->lang['VIEW_PERMISSIONS'])) ? $user->lang['VIEW_PERMISSIONS'] : '{ VIEW_PERMISSIONS }')); ?>" />
			</fieldset>
			</form>

			<form id="group" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

			<fieldset>
				<legend><?php echo ((isset($this->_rootref['L_LOOK_UP_GROUP'])) ? $this->_rootref['L_LOOK_UP_GROUP'] : ((isset($user->lang['LOOK_UP_GROUP'])) ? $user->lang['LOOK_UP_GROUP'] : '{ LOOK_UP_GROUP }')); ?></legend>
			<dl>
				<dt><label for="group_select"><?php echo ((isset($this->_rootref['L_LOOK_UP_GROUP'])) ? $this->_rootref['L_LOOK_UP_GROUP'] : ((isset($user->lang['LOOK_UP_GROUP'])) ? $user->lang['LOOK_UP_GROUP'] : '{ LOOK_UP_GROUP }')); ?>:</label></dt>
				<dd><select name="group_id[]" id="group_select"><?php echo (isset($this->_rootref['S_ADD_GROUP_OPTIONS'])) ? $this->_rootref['S_ADD_GROUP_OPTIONS'] : ''; ?></select></dd>
				<dd>&nbsp;</dd>
			</dl>
			</fieldset>

			<fieldset class="quick">
				<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?>
				<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
				<input type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_VIEW_PERMISSIONS'])) ? $this->_rootref['L_VIEW_PERMISSIONS'] : ((isset($user->lang['VIEW_PERMISSIONS'])) ? $user->lang['VIEW_PERMISSIONS'] : '{ VIEW_PERMISSIONS }')); ?>" class="button1" />
			</fieldset>
			</form>

		</div>

	<?php } } if ($this->_rootref['S_VIEWING_PERMISSIONS']) {  ?>

	<h1><?php echo ((isset($this->_rootref['L_ACL_VIEW'])) ? $this->_rootref['L_ACL_VIEW'] : ((isset($user->lang['ACL_VIEW'])) ? $user->lang['ACL_VIEW'] : '{ ACL_VIEW }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_ACL_VIEW_EXPLAIN'])) ? $this->_rootref['L_ACL_VIEW_EXPLAIN'] : ((isset($user->lang['ACL_VIEW_EXPLAIN'])) ? $user->lang['ACL_VIEW_EXPLAIN'] : '{ ACL_VIEW_EXPLAIN }')); ?></p>

	<fieldset class="quick">
		<strong>&raquo; <?php echo ((isset($this->_rootref['L_PERMISSION_TYPE'])) ? $this->_rootref['L_PERMISSION_TYPE'] : ((isset($user->lang['PERMISSION_TYPE'])) ? $user->lang['PERMISSION_TYPE'] : '{ PERMISSION_TYPE }')); ?></strong>
	</fieldset>

	<?php $this->_tpl_include('permission_mask.html'); } if ($this->_rootref['S_SETTING_PERMISSIONS']) {  ?>

	<h1><?php echo ((isset($this->_rootref['L_ACL_SET'])) ? $this->_rootref['L_ACL_SET'] : ((isset($user->lang['ACL_SET'])) ? $user->lang['ACL_SET'] : '{ ACL_SET }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_ACL_SET_EXPLAIN'])) ? $this->_rootref['L_ACL_SET_EXPLAIN'] : ((isset($user->lang['ACL_SET_EXPLAIN'])) ? $user->lang['ACL_SET_EXPLAIN'] : '{ ACL_SET_EXPLAIN }')); ?></p>

	<br />

	<fieldset class="quick" style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>;">
		<strong>&raquo; <?php echo ((isset($this->_rootref['L_PERMISSION_TYPE'])) ? $this->_rootref['L_PERMISSION_TYPE'] : ((isset($user->lang['PERMISSION_TYPE'])) ? $user->lang['PERMISSION_TYPE'] : '{ PERMISSION_TYPE }')); ?></strong>
	</fieldset>

	<?php if ($this->_rootref['S_PERMISSION_DROPDOWN']) {  ?>
		<form id="pselect" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">
	
		<fieldset class="quick" style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>;">
			<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?>
			<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
			<?php echo ((isset($this->_rootref['L_SELECT_TYPE'])) ? $this->_rootref['L_SELECT_TYPE'] : ((isset($user->lang['SELECT_TYPE'])) ? $user->lang['SELECT_TYPE'] : '{ SELECT_TYPE }')); ?>: <select name="type"><?php echo (isset($this->_rootref['S_PERMISSION_DROPDOWN'])) ? $this->_rootref['S_PERMISSION_DROPDOWN'] : ''; ?></select> 

			<input class="button2" type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_GO'])) ? $this->_rootref['L_GO'] : ((isset($user->lang['GO'])) ? $user->lang['GO'] : '{ GO }')); ?>" />
		</fieldset>
		</form>
	<?php } ?>

	<br /><br />

	<!-- include tooltip file -->
	<script type="text/javascript" src="style/tooltip.js"></script>
	<script type="text/javascript">
	// <![CDATA[
		window.onload = function(){enable_tooltips_select('set-permissions', '<?php echo ((isset($this->_rootref['LA_ROLE_DESCRIPTION'])) ? $this->_rootref['LA_ROLE_DESCRIPTION'] : ((isset($this->_rootref['L_ROLE_DESCRIPTION'])) ? addslashes($this->_rootref['L_ROLE_DESCRIPTION']) : ((isset($user->lang['ROLE_DESCRIPTION'])) ? addslashes($user->lang['ROLE_DESCRIPTION']) : '{ ROLE_DESCRIPTION }'))); ?>', 'role')};
	// ]]>
	</script>

	<form id="set-permissions" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

	<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?>

	<?php $this->_tpl_include('permission_mask.html'); ?>

	<br /><br />

	<fieldset class="quick" style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>;">
		<input class="button1" type="submit" name="action[apply_all_permissions]" value="<?php echo ((isset($this->_rootref['L_APPLY_ALL_PERMISSIONS'])) ? $this->_rootref['L_APPLY_ALL_PERMISSIONS'] : ((isset($user->lang['APPLY_ALL_PERMISSIONS'])) ? $user->lang['APPLY_ALL_PERMISSIONS'] : '{ APPLY_ALL_PERMISSIONS }')); ?>" />
		<input class="button2" type="button" name="cancel" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" onclick="document.forms['set-permissions'].reset(); init_colours(active_pmask + active_fmask);" />
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>

	<br /><br />
	
	</form>

<?php } $this->_tpl_include('overall_footer.html'); ?>
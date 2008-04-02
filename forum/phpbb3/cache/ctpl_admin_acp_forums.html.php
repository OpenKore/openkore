<?php $this->_tpl_include('overall_header.html'); ?>

<a name="maincontent"></a>

<?php if ($this->_rootref['S_EDIT_FORUM']) {  ?>

	<script type="text/javascript">
	// <![CDATA[
		/**
		* Handle displaying/hiding several options based on the forum type
		*/
		function display_options(value)
		{
			<?php if (! $this->_rootref['S_ADD_ACTION'] && $this->_rootref['S_FORUM_ORIG_POST']) {  ?>
				if (value == <?php echo (isset($this->_rootref['FORUM_POST'])) ? $this->_rootref['FORUM_POST'] : ''; ?>)
				{
					dE('type_actions', -1);
				}
				else
				{
					dE('type_actions', 1);
				}
			<?php } if (! $this->_rootref['S_ADD_ACTION'] && $this->_rootref['S_FORUM_ORIG_CAT'] && $this->_rootref['S_HAS_SUBFORUMS']) {  ?>
				if (value == <?php echo (isset($this->_rootref['FORUM_LINK'])) ? $this->_rootref['FORUM_LINK'] : ''; ?>)
				{
					dE('cat_to_link_actions', 1);
				}
				else
				{
					dE('cat_to_link_actions', -1);
				}
			<?php } ?>

			if (value == <?php echo (isset($this->_rootref['FORUM_POST'])) ? $this->_rootref['FORUM_POST'] : ''; ?>)
			{
				dE('forum_post_options', 1);
				dE('forum_link_options', -1);
				dE('forum_rules_options', 1);
				dE('forum_cat_options', -1);
			}
			else if (value == <?php echo (isset($this->_rootref['FORUM_LINK'])) ? $this->_rootref['FORUM_LINK'] : ''; ?>)
			{
				dE('forum_post_options', -1);
				dE('forum_link_options', 1);
				dE('forum_rules_options', -1);
				dE('forum_cat_options', -1);
			}
			else if (value == <?php echo (isset($this->_rootref['FORUM_CAT'])) ? $this->_rootref['FORUM_CAT'] : ''; ?>)
			{
				dE('forum_post_options', -1);
				dE('forum_link_options', -1);
				dE('forum_rules_options', 1);
				dE('forum_cat_options', 1);
			}
		}

		/**
		* Init the wanted display functionality if javascript is enabled.
		* If javascript is not available, the user is still able to properly administrate.
		*/
		onload = function()
		{
			<?php if (! $this->_rootref['S_ADD_ACTION'] && $this->_rootref['S_FORUM_ORIG_POST']) {  if ($this->_rootref['S_FORUM_POST']) {  ?>
					dE('type_actions', -1);
				<?php } } if (! $this->_rootref['S_ADD_ACTION'] && $this->_rootref['S_FORUM_ORIG_CAT'] && $this->_rootref['S_HAS_SUBFORUMS']) {  if ($this->_rootref['S_FORUM_CAT']) {  ?>
					dE('cat_to_link_actions', -1);
				<?php } } if (! $this->_rootref['S_FORUM_POST']) {  ?>
				dE('forum_post_options', -1);
			<?php } if (! $this->_rootref['S_FORUM_CAT']) {  ?>
				dE('forum_cat_options', -1);
			<?php } if (! $this->_rootref['S_FORUM_LINK']) {  ?>
				dE('forum_link_options', -1);
			<?php } if ($this->_rootref['S_FORUM_LINK']) {  ?>
			dE('forum_rules_options', -1);
			<?php } ?>
		}

	// ]]>
	</script>

	<a href="<?php echo (isset($this->_rootref['U_BACK'])) ? $this->_rootref['U_BACK'] : ''; ?>" style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>;">&laquo; <?php echo ((isset($this->_rootref['L_BACK'])) ? $this->_rootref['L_BACK'] : ((isset($user->lang['BACK'])) ? $user->lang['BACK'] : '{ BACK }')); ?></a>

	<h1><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?> :: <?php echo (isset($this->_rootref['FORUM_NAME'])) ? $this->_rootref['FORUM_NAME'] : ''; ?></h1>

	<p><?php echo ((isset($this->_rootref['L_FORUM_EDIT_EXPLAIN'])) ? $this->_rootref['L_FORUM_EDIT_EXPLAIN'] : ((isset($user->lang['FORUM_EDIT_EXPLAIN'])) ? $user->lang['FORUM_EDIT_EXPLAIN'] : '{ FORUM_EDIT_EXPLAIN }')); ?></p>

	<?php if ($this->_rootref['S_ERROR']) {  ?>
		<div class="errorbox">
			<h3><?php echo ((isset($this->_rootref['L_WARNING'])) ? $this->_rootref['L_WARNING'] : ((isset($user->lang['WARNING'])) ? $user->lang['WARNING'] : '{ WARNING }')); ?></h3>
			<p><?php echo (isset($this->_rootref['ERROR_MSG'])) ? $this->_rootref['ERROR_MSG'] : ''; ?></p>
		</div>
	<?php } ?>

	<form id="forumedit" method="post" action="<?php echo (isset($this->_rootref['U_EDIT_ACTION'])) ? $this->_rootref['U_EDIT_ACTION'] : ''; ?>">

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_FORUM_SETTINGS'])) ? $this->_rootref['L_FORUM_SETTINGS'] : ((isset($user->lang['FORUM_SETTINGS'])) ? $user->lang['FORUM_SETTINGS'] : '{ FORUM_SETTINGS }')); ?></legend>
	<dl>
		<dt><label for="forum_type"><?php echo ((isset($this->_rootref['L_FORUM_TYPE'])) ? $this->_rootref['L_FORUM_TYPE'] : ((isset($user->lang['FORUM_TYPE'])) ? $user->lang['FORUM_TYPE'] : '{ FORUM_TYPE }')); ?>:</label></dt>
		<dd><select id="forum_type" name="forum_type" onchange="display_options(this.options[this.selectedIndex].value);"><?php echo (isset($this->_rootref['S_FORUM_TYPE_OPTIONS'])) ? $this->_rootref['S_FORUM_TYPE_OPTIONS'] : ''; ?></select></dd>
	</dl>
	<?php if (! $this->_rootref['S_ADD_ACTION'] && $this->_rootref['S_FORUM_ORIG_POST']) {  ?>
	<div id="type_actions">
		<dl>
			<dt><label for="type_action"><?php echo ((isset($this->_rootref['L_DECIDE_MOVE_DELETE_CONTENT'])) ? $this->_rootref['L_DECIDE_MOVE_DELETE_CONTENT'] : ((isset($user->lang['DECIDE_MOVE_DELETE_CONTENT'])) ? $user->lang['DECIDE_MOVE_DELETE_CONTENT'] : '{ DECIDE_MOVE_DELETE_CONTENT }')); ?>:</label></dt>
			<dd><label><input type="radio" class="radio" name="type_action" value="delete"<?php if (! $this->_rootref['S_MOVE_FORUM_OPTIONS']) {  ?> checked="checked" id="type_action"<?php } ?> /> <?php echo ((isset($this->_rootref['L_DELETE_ALL_POSTS'])) ? $this->_rootref['L_DELETE_ALL_POSTS'] : ((isset($user->lang['DELETE_ALL_POSTS'])) ? $user->lang['DELETE_ALL_POSTS'] : '{ DELETE_ALL_POSTS }')); ?></label></dd>
			<?php if ($this->_rootref['S_MOVE_FORUM_OPTIONS']) {  ?><dd><label><input type="radio" class="radio" name="type_action" id="type_action" value="move" checked="checked" /> <?php echo ((isset($this->_rootref['L_MOVE_POSTS_TO'])) ? $this->_rootref['L_MOVE_POSTS_TO'] : ((isset($user->lang['MOVE_POSTS_TO'])) ? $user->lang['MOVE_POSTS_TO'] : '{ MOVE_POSTS_TO }')); ?></label> <select name="to_forum_id"><?php echo (isset($this->_rootref['S_MOVE_FORUM_OPTIONS'])) ? $this->_rootref['S_MOVE_FORUM_OPTIONS'] : ''; ?></select></dd><?php } ?>
		</dl>
	</div>
	<?php } if (! $this->_rootref['S_ADD_ACTION'] && $this->_rootref['S_FORUM_ORIG_CAT'] && $this->_rootref['S_HAS_SUBFORUMS']) {  ?>
	<div id="cat_to_link_actions">
		<dl>
			<dt><label for="action_subforums"><?php echo ((isset($this->_rootref['L_DECIDE_MOVE_DELETE_SUBFORUMS'])) ? $this->_rootref['L_DECIDE_MOVE_DELETE_SUBFORUMS'] : ((isset($user->lang['DECIDE_MOVE_DELETE_SUBFORUMS'])) ? $user->lang['DECIDE_MOVE_DELETE_SUBFORUMS'] : '{ DECIDE_MOVE_DELETE_SUBFORUMS }')); ?>:</label></dt>
			<?php if ($this->_rootref['S_FORUMS_LIST']) {  ?>
				<dd><label><input type="radio" class="radio" id="action_subforums" name="action_subforums" value="move" checked="checked" /> <?php echo ((isset($this->_rootref['L_MOVE_SUBFORUMS_TO'])) ? $this->_rootref['L_MOVE_SUBFORUMS_TO'] : ((isset($user->lang['MOVE_SUBFORUMS_TO'])) ? $user->lang['MOVE_SUBFORUMS_TO'] : '{ MOVE_SUBFORUMS_TO }')); ?></label> <select name="subforums_to_id"><?php echo (isset($this->_rootref['S_FORUMS_LIST'])) ? $this->_rootref['S_FORUMS_LIST'] : ''; ?></select></dd>
			<?php } else { ?>
				<dd><label><input type="radio" class="radio" id="action_subforums" name="action_subforums" value="delete" checked="checked" /> <?php echo ((isset($this->_rootref['L_DELETE_SUBFORUMS'])) ? $this->_rootref['L_DELETE_SUBFORUMS'] : ((isset($user->lang['DELETE_SUBFORUMS'])) ? $user->lang['DELETE_SUBFORUMS'] : '{ DELETE_SUBFORUMS }')); ?></label></dd>
			<?php } ?>
		</dl>
	</div>
	<?php } ?>
	<dl>
		<dt><label for="parent"><?php echo ((isset($this->_rootref['L_FORUM_PARENT'])) ? $this->_rootref['L_FORUM_PARENT'] : ((isset($user->lang['FORUM_PARENT'])) ? $user->lang['FORUM_PARENT'] : '{ FORUM_PARENT }')); ?>:</label></dt>
		<dd><select id="parent" name="forum_parent_id"><option value="0"<?php if (! $this->_rootref['S_FORUM_PARENT_ID']) {  ?> selected="selected"<?php } ?>><?php echo ((isset($this->_rootref['L_NO_PARENT'])) ? $this->_rootref['L_NO_PARENT'] : ((isset($user->lang['NO_PARENT'])) ? $user->lang['NO_PARENT'] : '{ NO_PARENT }')); ?></option><?php echo (isset($this->_rootref['S_PARENT_OPTIONS'])) ? $this->_rootref['S_PARENT_OPTIONS'] : ''; ?></select></dd>
	</dl>
	<dl>
		<dt><label for="forum_name"><?php echo ((isset($this->_rootref['L_FORUM_NAME'])) ? $this->_rootref['L_FORUM_NAME'] : ((isset($user->lang['FORUM_NAME'])) ? $user->lang['FORUM_NAME'] : '{ FORUM_NAME }')); ?>:</label></dt>
		<dd><input class="text medium" type="text" id="forum_name" name="forum_name" value="<?php echo (isset($this->_rootref['FORUM_NAME'])) ? $this->_rootref['FORUM_NAME'] : ''; ?>" maxlength="255" /></dd>
	</dl>
	<dl>
		<dt><label for="forum_desc"><?php echo ((isset($this->_rootref['L_FORUM_DESC'])) ? $this->_rootref['L_FORUM_DESC'] : ((isset($user->lang['FORUM_DESC'])) ? $user->lang['FORUM_DESC'] : '{ FORUM_DESC }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_FORUM_DESC_EXPLAIN'])) ? $this->_rootref['L_FORUM_DESC_EXPLAIN'] : ((isset($user->lang['FORUM_DESC_EXPLAIN'])) ? $user->lang['FORUM_DESC_EXPLAIN'] : '{ FORUM_DESC_EXPLAIN }')); ?></span></dt>
		<dd><textarea id="forum_desc" name="forum_desc" rows="5" cols="45"><?php echo (isset($this->_rootref['FORUM_DESC'])) ? $this->_rootref['FORUM_DESC'] : ''; ?></textarea></dd>
		<dd><label><input type="checkbox" class="radio" name="desc_parse_bbcode"<?php if ($this->_rootref['S_DESC_BBCODE_CHECKED']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_PARSE_BBCODE'])) ? $this->_rootref['L_PARSE_BBCODE'] : ((isset($user->lang['PARSE_BBCODE'])) ? $user->lang['PARSE_BBCODE'] : '{ PARSE_BBCODE }')); ?></label>
			<label><input type="checkbox" class="radio" name="desc_parse_smilies"<?php if ($this->_rootref['S_DESC_SMILIES_CHECKED']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_PARSE_SMILIES'])) ? $this->_rootref['L_PARSE_SMILIES'] : ((isset($user->lang['PARSE_SMILIES'])) ? $user->lang['PARSE_SMILIES'] : '{ PARSE_SMILIES }')); ?></label>
			<label><input type="checkbox" class="radio" name="desc_parse_urls"<?php if ($this->_rootref['S_DESC_URLS_CHECKED']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_PARSE_URLS'])) ? $this->_rootref['L_PARSE_URLS'] : ((isset($user->lang['PARSE_URLS'])) ? $user->lang['PARSE_URLS'] : '{ PARSE_URLS }')); ?></label></dd>
	</dl>
	<dl>
		<dt><label for="forum_image"><?php echo ((isset($this->_rootref['L_FORUM_IMAGE'])) ? $this->_rootref['L_FORUM_IMAGE'] : ((isset($user->lang['FORUM_IMAGE'])) ? $user->lang['FORUM_IMAGE'] : '{ FORUM_IMAGE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_FORUM_IMAGE_EXPLAIN'])) ? $this->_rootref['L_FORUM_IMAGE_EXPLAIN'] : ((isset($user->lang['FORUM_IMAGE_EXPLAIN'])) ? $user->lang['FORUM_IMAGE_EXPLAIN'] : '{ FORUM_IMAGE_EXPLAIN }')); ?></span></dt>
		<dd><input class="text medium" type="text" id="forum_image" name="forum_image" value="<?php echo (isset($this->_rootref['FORUM_IMAGE'])) ? $this->_rootref['FORUM_IMAGE'] : ''; ?>" maxlength="255" /></dd>
		<?php if ($this->_rootref['FORUM_IMAGE_SRC']) {  ?>
			<dd><img src="<?php echo (isset($this->_rootref['FORUM_IMAGE_SRC'])) ? $this->_rootref['FORUM_IMAGE_SRC'] : ''; ?>" alt="<?php echo ((isset($this->_rootref['L_FORUM_IMAGE'])) ? $this->_rootref['L_FORUM_IMAGE'] : ((isset($user->lang['FORUM_IMAGE'])) ? $user->lang['FORUM_IMAGE'] : '{ FORUM_IMAGE }')); ?>" /></dd>
		<?php } ?>
	</dl>
	<dl>
		<dt><label for="forum_password"><?php echo ((isset($this->_rootref['L_FORUM_PASSWORD'])) ? $this->_rootref['L_FORUM_PASSWORD'] : ((isset($user->lang['FORUM_PASSWORD'])) ? $user->lang['FORUM_PASSWORD'] : '{ FORUM_PASSWORD }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_FORUM_PASSWORD_EXPLAIN'])) ? $this->_rootref['L_FORUM_PASSWORD_EXPLAIN'] : ((isset($user->lang['FORUM_PASSWORD_EXPLAIN'])) ? $user->lang['FORUM_PASSWORD_EXPLAIN'] : '{ FORUM_PASSWORD_EXPLAIN }')); ?></span></dt>
		<dd><input type="password" id="forum_password" name="forum_password" value="<?php if ($this->_rootref['S_FORUM_PASSWORD_SET']) {  ?>&#x20;&#x20;&#x20;&#x20;&#x20;&#x20;<?php } ?>" /></dd>
	</dl>
	<dl>
		<dt><label for="forum_password_confirm"><?php echo ((isset($this->_rootref['L_FORUM_PASSWORD_CONFIRM'])) ? $this->_rootref['L_FORUM_PASSWORD_CONFIRM'] : ((isset($user->lang['FORUM_PASSWORD_CONFIRM'])) ? $user->lang['FORUM_PASSWORD_CONFIRM'] : '{ FORUM_PASSWORD_CONFIRM }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_FORUM_PASSWORD_CONFIRM_EXPLAIN'])) ? $this->_rootref['L_FORUM_PASSWORD_CONFIRM_EXPLAIN'] : ((isset($user->lang['FORUM_PASSWORD_CONFIRM_EXPLAIN'])) ? $user->lang['FORUM_PASSWORD_CONFIRM_EXPLAIN'] : '{ FORUM_PASSWORD_CONFIRM_EXPLAIN }')); ?></span></dt>
		<dd><input type="password" id="forum_password_confirm" name="forum_password_confirm" value="<?php if ($this->_rootref['S_FORUM_PASSWORD_SET']) {  ?>&#x20;&#x20;&#x20;&#x20;&#x20;&#x20;<?php } ?>" /></dd>
	</dl>
	<?php if ($this->_rootref['S_FORUM_PASSWORD_SET']) {  ?>
	<dl>
		<dt><label for="forum_password_unset"><?php echo ((isset($this->_rootref['L_FORUM_PASSWORD_UNSET'])) ? $this->_rootref['L_FORUM_PASSWORD_UNSET'] : ((isset($user->lang['FORUM_PASSWORD_UNSET'])) ? $user->lang['FORUM_PASSWORD_UNSET'] : '{ FORUM_PASSWORD_UNSET }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_FORUM_PASSWORD_UNSET_EXPLAIN'])) ? $this->_rootref['L_FORUM_PASSWORD_UNSET_EXPLAIN'] : ((isset($user->lang['FORUM_PASSWORD_UNSET_EXPLAIN'])) ? $user->lang['FORUM_PASSWORD_UNSET_EXPLAIN'] : '{ FORUM_PASSWORD_UNSET_EXPLAIN }')); ?></span></dt>
		<dd><input id="forum_password_unset" name="forum_password_unset" type="checkbox" /></dd>
	</dl>
	<?php } ?>
	<dl>
		<dt><label for="forum_style"><?php echo ((isset($this->_rootref['L_FORUM_STYLE'])) ? $this->_rootref['L_FORUM_STYLE'] : ((isset($user->lang['FORUM_STYLE'])) ? $user->lang['FORUM_STYLE'] : '{ FORUM_STYLE }')); ?>:</label></dt>
		<dd><select id="forum_style" name="forum_style"><option value="0"><?php echo ((isset($this->_rootref['L_DEFAULT_STYLE'])) ? $this->_rootref['L_DEFAULT_STYLE'] : ((isset($user->lang['DEFAULT_STYLE'])) ? $user->lang['DEFAULT_STYLE'] : '{ DEFAULT_STYLE }')); ?></option><?php echo (isset($this->_rootref['S_STYLES_OPTIONS'])) ? $this->_rootref['S_STYLES_OPTIONS'] : ''; ?></select></dd>
	</dl>
	<?php if ($this->_rootref['S_CAN_COPY_PERMISSIONS']) {  ?>
		<dl>
			<dt><label for="forum_perm_from"><?php echo ((isset($this->_rootref['L_COPY_PERMISSIONS'])) ? $this->_rootref['L_COPY_PERMISSIONS'] : ((isset($user->lang['COPY_PERMISSIONS'])) ? $user->lang['COPY_PERMISSIONS'] : '{ COPY_PERMISSIONS }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_COPY_PERMISSIONS_EXPLAIN'])) ? $this->_rootref['L_COPY_PERMISSIONS_EXPLAIN'] : ((isset($user->lang['COPY_PERMISSIONS_EXPLAIN'])) ? $user->lang['COPY_PERMISSIONS_EXPLAIN'] : '{ COPY_PERMISSIONS_EXPLAIN }')); ?></span></dt>
			<dd><select id="forum_perm_from" name="forum_perm_from"><option value="0"><?php echo ((isset($this->_rootref['L_NO_PERMISSIONS'])) ? $this->_rootref['L_NO_PERMISSIONS'] : ((isset($user->lang['NO_PERMISSIONS'])) ? $user->lang['NO_PERMISSIONS'] : '{ NO_PERMISSIONS }')); ?></option><?php echo (isset($this->_rootref['S_FORUM_OPTIONS'])) ? $this->_rootref['S_FORUM_OPTIONS'] : ''; ?></select></dd>
		</dl>
	<?php } ?>
	</fieldset>

	<div id="forum_cat_options">
		<fieldset>
			<legend><?php echo ((isset($this->_rootref['L_GENERAL_FORUM_SETTINGS'])) ? $this->_rootref['L_GENERAL_FORUM_SETTINGS'] : ((isset($user->lang['GENERAL_FORUM_SETTINGS'])) ? $user->lang['GENERAL_FORUM_SETTINGS'] : '{ GENERAL_FORUM_SETTINGS }')); ?></legend>
		<dl>
			<dt><label for="display_active"><?php echo ((isset($this->_rootref['L_DISPLAY_ACTIVE_TOPICS'])) ? $this->_rootref['L_DISPLAY_ACTIVE_TOPICS'] : ((isset($user->lang['DISPLAY_ACTIVE_TOPICS'])) ? $user->lang['DISPLAY_ACTIVE_TOPICS'] : '{ DISPLAY_ACTIVE_TOPICS }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_DISPLAY_ACTIVE_TOPICS_EXPLAIN'])) ? $this->_rootref['L_DISPLAY_ACTIVE_TOPICS_EXPLAIN'] : ((isset($user->lang['DISPLAY_ACTIVE_TOPICS_EXPLAIN'])) ? $user->lang['DISPLAY_ACTIVE_TOPICS_EXPLAIN'] : '{ DISPLAY_ACTIVE_TOPICS_EXPLAIN }')); ?></span></dt>
			<dd><label><input type="radio" class="radio" name="display_active" value="1"<?php if ($this->_rootref['S_DISPLAY_ACTIVE_TOPICS']) {  ?> id="display_active" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
				<label><input type="radio" class="radio" name="display_active" value="0"<?php if (! $this->_rootref['S_DISPLAY_ACTIVE_TOPICS']) {  ?> id="display_active" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
		</dl>
		</fieldset>
	</div>

	<div id="forum_post_options">
		<fieldset>
			<legend><?php echo ((isset($this->_rootref['L_GENERAL_FORUM_SETTINGS'])) ? $this->_rootref['L_GENERAL_FORUM_SETTINGS'] : ((isset($user->lang['GENERAL_FORUM_SETTINGS'])) ? $user->lang['GENERAL_FORUM_SETTINGS'] : '{ GENERAL_FORUM_SETTINGS }')); ?></legend>
		<dl>
			<dt><label for="forum_status"><?php echo ((isset($this->_rootref['L_FORUM_STATUS'])) ? $this->_rootref['L_FORUM_STATUS'] : ((isset($user->lang['FORUM_STATUS'])) ? $user->lang['FORUM_STATUS'] : '{ FORUM_STATUS }')); ?>:</label></dt>
			<dd><select id="forum_status" name="forum_status"><?php echo (isset($this->_rootref['S_STATUS_OPTIONS'])) ? $this->_rootref['S_STATUS_OPTIONS'] : ''; ?></select></dd>
		</dl>
		<dl>
			<dt><label for="display_on_index"><?php echo ((isset($this->_rootref['L_LIST_INDEX'])) ? $this->_rootref['L_LIST_INDEX'] : ((isset($user->lang['LIST_INDEX'])) ? $user->lang['LIST_INDEX'] : '{ LIST_INDEX }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_LIST_INDEX_EXPLAIN'])) ? $this->_rootref['L_LIST_INDEX_EXPLAIN'] : ((isset($user->lang['LIST_INDEX_EXPLAIN'])) ? $user->lang['LIST_INDEX_EXPLAIN'] : '{ LIST_INDEX_EXPLAIN }')); ?></span></dt>
			<dd><label><input type="radio" class="radio" name="display_on_index" value="1"<?php if ($this->_rootref['S_DISPLAY_ON_INDEX']) {  ?> id="display_on_index" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
				<label><input type="radio" class="radio" name="display_on_index" value="0"<?php if (! $this->_rootref['S_DISPLAY_ON_INDEX']) {  ?> id="display_on_index" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
		</dl>
		<dl>
			<dt><label for="enable_post_review"><?php echo ((isset($this->_rootref['L_ENABLE_POST_REVIEW'])) ? $this->_rootref['L_ENABLE_POST_REVIEW'] : ((isset($user->lang['ENABLE_POST_REVIEW'])) ? $user->lang['ENABLE_POST_REVIEW'] : '{ ENABLE_POST_REVIEW }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_ENABLE_POST_REVIEW_EXPLAIN'])) ? $this->_rootref['L_ENABLE_POST_REVIEW_EXPLAIN'] : ((isset($user->lang['ENABLE_POST_REVIEW_EXPLAIN'])) ? $user->lang['ENABLE_POST_REVIEW_EXPLAIN'] : '{ ENABLE_POST_REVIEW_EXPLAIN }')); ?></span></dt>
			<dd><label><input type="radio" class="radio" name="enable_post_review" value="1"<?php if ($this->_rootref['S_ENABLE_POST_REVIEW']) {  ?> id="enable_post_review" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
				<label><input type="radio" class="radio" name="enable_post_review" value="0"<?php if (! $this->_rootref['S_ENABLE_POST_REVIEW']) {  ?> id="enable_post_review" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
		</dl>
		<dl>
			<dt><label for="enable_indexing"><?php echo ((isset($this->_rootref['L_ENABLE_INDEXING'])) ? $this->_rootref['L_ENABLE_INDEXING'] : ((isset($user->lang['ENABLE_INDEXING'])) ? $user->lang['ENABLE_INDEXING'] : '{ ENABLE_INDEXING }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_ENABLE_INDEXING_EXPLAIN'])) ? $this->_rootref['L_ENABLE_INDEXING_EXPLAIN'] : ((isset($user->lang['ENABLE_INDEXING_EXPLAIN'])) ? $user->lang['ENABLE_INDEXING_EXPLAIN'] : '{ ENABLE_INDEXING_EXPLAIN }')); ?></span></dt>
			<dd><label><input type="radio" class="radio" name="enable_indexing" value="1"<?php if ($this->_rootref['S_ENABLE_INDEXING']) {  ?> id="enable_indexing" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
				<label><input type="radio" class="radio" name="enable_indexing" value="0"<?php if (! $this->_rootref['S_ENABLE_INDEXING']) {  ?> id="enable_indexing" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
		</dl>
		<dl>
			<dt><label for="enable_icons"><?php echo ((isset($this->_rootref['L_ENABLE_TOPIC_ICONS'])) ? $this->_rootref['L_ENABLE_TOPIC_ICONS'] : ((isset($user->lang['ENABLE_TOPIC_ICONS'])) ? $user->lang['ENABLE_TOPIC_ICONS'] : '{ ENABLE_TOPIC_ICONS }')); ?>:</label></dt>
			<dd><label><input type="radio" class="radio" name="enable_icons" value="1"<?php if ($this->_rootref['S_TOPIC_ICONS']) {  ?> id="enable_icons" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
				<label><input type="radio" class="radio" name="enable_icons" value="0"<?php if (! $this->_rootref['S_TOPIC_ICONS']) {  ?> id="enable_icons" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
		</dl>
		<dl>
			<dt><label for="display_recent"><?php echo ((isset($this->_rootref['L_ENABLE_RECENT'])) ? $this->_rootref['L_ENABLE_RECENT'] : ((isset($user->lang['ENABLE_RECENT'])) ? $user->lang['ENABLE_RECENT'] : '{ ENABLE_RECENT }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_ENABLE_RECENT_EXPLAIN'])) ? $this->_rootref['L_ENABLE_RECENT_EXPLAIN'] : ((isset($user->lang['ENABLE_RECENT_EXPLAIN'])) ? $user->lang['ENABLE_RECENT_EXPLAIN'] : '{ ENABLE_RECENT_EXPLAIN }')); ?></span></dt>
			<dd><label><input type="radio" class="radio" name="display_recent" value="1"<?php if ($this->_rootref['S_DISPLAY_ACTIVE_TOPICS']) {  ?> id="display_recent" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
				<label><input type="radio" class="radio" name="display_recent" value="0"<?php if (! $this->_rootref['S_DISPLAY_ACTIVE_TOPICS']) {  ?> id="display_recent" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
		</dl>
		<dl>
			<dt><label for="topics_per_page"><?php echo ((isset($this->_rootref['L_FORUM_TOPICS_PAGE'])) ? $this->_rootref['L_FORUM_TOPICS_PAGE'] : ((isset($user->lang['FORUM_TOPICS_PAGE'])) ? $user->lang['FORUM_TOPICS_PAGE'] : '{ FORUM_TOPICS_PAGE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_FORUM_TOPICS_PAGE_EXPLAIN'])) ? $this->_rootref['L_FORUM_TOPICS_PAGE_EXPLAIN'] : ((isset($user->lang['FORUM_TOPICS_PAGE_EXPLAIN'])) ? $user->lang['FORUM_TOPICS_PAGE_EXPLAIN'] : '{ FORUM_TOPICS_PAGE_EXPLAIN }')); ?></span></dt>
			<dd><input type="text" id="topics_per_page" name="topics_per_page" value="<?php echo (isset($this->_rootref['TOPICS_PER_PAGE'])) ? $this->_rootref['TOPICS_PER_PAGE'] : ''; ?>" size="4" maxlength="4" /></dd>
		</dl>
		</fieldset>

		<fieldset>
			<legend><?php echo ((isset($this->_rootref['L_FORUM_PRUNE_SETTINGS'])) ? $this->_rootref['L_FORUM_PRUNE_SETTINGS'] : ((isset($user->lang['FORUM_PRUNE_SETTINGS'])) ? $user->lang['FORUM_PRUNE_SETTINGS'] : '{ FORUM_PRUNE_SETTINGS }')); ?></legend>
		<dl>
			<dt><label for="enable_prune"><?php echo ((isset($this->_rootref['L_FORUM_AUTO_PRUNE'])) ? $this->_rootref['L_FORUM_AUTO_PRUNE'] : ((isset($user->lang['FORUM_AUTO_PRUNE'])) ? $user->lang['FORUM_AUTO_PRUNE'] : '{ FORUM_AUTO_PRUNE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_FORUM_AUTO_PRUNE_EXPLAIN'])) ? $this->_rootref['L_FORUM_AUTO_PRUNE_EXPLAIN'] : ((isset($user->lang['FORUM_AUTO_PRUNE_EXPLAIN'])) ? $user->lang['FORUM_AUTO_PRUNE_EXPLAIN'] : '{ FORUM_AUTO_PRUNE_EXPLAIN }')); ?></span></dt>
			<dd><label><input type="radio" class="radio" name="enable_prune" value="1"<?php if ($this->_rootref['S_PRUNE_ENABLE']) {  ?> id="enable_prune" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
				<label><input type="radio" class="radio" name="enable_prune" value="0"<?php if (! $this->_rootref['S_PRUNE_ENABLE']) {  ?> id="enable_prune" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
		</dl>
		<dl>
			<dt><label for="prune_freq"><?php echo ((isset($this->_rootref['L_AUTO_PRUNE_FREQ'])) ? $this->_rootref['L_AUTO_PRUNE_FREQ'] : ((isset($user->lang['AUTO_PRUNE_FREQ'])) ? $user->lang['AUTO_PRUNE_FREQ'] : '{ AUTO_PRUNE_FREQ }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_AUTO_PRUNE_FREQ_EXPLAIN'])) ? $this->_rootref['L_AUTO_PRUNE_FREQ_EXPLAIN'] : ((isset($user->lang['AUTO_PRUNE_FREQ_EXPLAIN'])) ? $user->lang['AUTO_PRUNE_FREQ_EXPLAIN'] : '{ AUTO_PRUNE_FREQ_EXPLAIN }')); ?></span></dt>
			<dd><input type="text" id="prune_freq" name="prune_freq" value="<?php echo (isset($this->_rootref['PRUNE_FREQ'])) ? $this->_rootref['PRUNE_FREQ'] : ''; ?>" maxlength="4" size="4" /> <?php echo ((isset($this->_rootref['L_DAYS'])) ? $this->_rootref['L_DAYS'] : ((isset($user->lang['DAYS'])) ? $user->lang['DAYS'] : '{ DAYS }')); ?></dd>
		</dl>
		<dl>
			<dt><label for="prune_days"><?php echo ((isset($this->_rootref['L_AUTO_PRUNE_DAYS'])) ? $this->_rootref['L_AUTO_PRUNE_DAYS'] : ((isset($user->lang['AUTO_PRUNE_DAYS'])) ? $user->lang['AUTO_PRUNE_DAYS'] : '{ AUTO_PRUNE_DAYS }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_AUTO_PRUNE_DAYS_EXPLAIN'])) ? $this->_rootref['L_AUTO_PRUNE_DAYS_EXPLAIN'] : ((isset($user->lang['AUTO_PRUNE_DAYS_EXPLAIN'])) ? $user->lang['AUTO_PRUNE_DAYS_EXPLAIN'] : '{ AUTO_PRUNE_DAYS_EXPLAIN }')); ?></span></dt>
			<dd><input type="text" id="prune_days" name="prune_days" value="<?php echo (isset($this->_rootref['PRUNE_DAYS'])) ? $this->_rootref['PRUNE_DAYS'] : ''; ?>" maxlength="4" size="4" /> <?php echo ((isset($this->_rootref['L_DAYS'])) ? $this->_rootref['L_DAYS'] : ((isset($user->lang['DAYS'])) ? $user->lang['DAYS'] : '{ DAYS }')); ?></dd>
		</dl>
		<dl>
			<dt><label for="prune_viewed"><?php echo ((isset($this->_rootref['L_AUTO_PRUNE_VIEWED'])) ? $this->_rootref['L_AUTO_PRUNE_VIEWED'] : ((isset($user->lang['AUTO_PRUNE_VIEWED'])) ? $user->lang['AUTO_PRUNE_VIEWED'] : '{ AUTO_PRUNE_VIEWED }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_AUTO_PRUNE_VIEWED_EXPLAIN'])) ? $this->_rootref['L_AUTO_PRUNE_VIEWED_EXPLAIN'] : ((isset($user->lang['AUTO_PRUNE_VIEWED_EXPLAIN'])) ? $user->lang['AUTO_PRUNE_VIEWED_EXPLAIN'] : '{ AUTO_PRUNE_VIEWED_EXPLAIN }')); ?></span></dt>
			<dd><input type="text" id="prune_viewed" name="prune_viewed" value="<?php echo (isset($this->_rootref['PRUNE_VIEWED'])) ? $this->_rootref['PRUNE_VIEWED'] : ''; ?>" maxlength="4" size="4" /> <?php echo ((isset($this->_rootref['L_DAYS'])) ? $this->_rootref['L_DAYS'] : ((isset($user->lang['DAYS'])) ? $user->lang['DAYS'] : '{ DAYS }')); ?></dd>
		</dl>
		<dl>
			<dt><label for="prune_old_polls"><?php echo ((isset($this->_rootref['L_PRUNE_OLD_POLLS'])) ? $this->_rootref['L_PRUNE_OLD_POLLS'] : ((isset($user->lang['PRUNE_OLD_POLLS'])) ? $user->lang['PRUNE_OLD_POLLS'] : '{ PRUNE_OLD_POLLS }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_PRUNE_OLD_POLLS_EXPLAIN'])) ? $this->_rootref['L_PRUNE_OLD_POLLS_EXPLAIN'] : ((isset($user->lang['PRUNE_OLD_POLLS_EXPLAIN'])) ? $user->lang['PRUNE_OLD_POLLS_EXPLAIN'] : '{ PRUNE_OLD_POLLS_EXPLAIN }')); ?></span></dt>
			<dd><label><input type="radio" class="radio" name="prune_old_polls" value="1"<?php if ($this->_rootref['S_PRUNE_OLD_POLLS']) {  ?> id="prune_old_polls" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
				<label><input type="radio" class="radio" name="prune_old_polls" value="0"<?php if (! $this->_rootref['S_PRUNE_OLD_POLLS']) {  ?> id="prune_old_polls" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
		</dl>
		<dl>
			<dt><label for="prune_announce"><?php echo ((isset($this->_rootref['L_PRUNE_ANNOUNCEMENTS'])) ? $this->_rootref['L_PRUNE_ANNOUNCEMENTS'] : ((isset($user->lang['PRUNE_ANNOUNCEMENTS'])) ? $user->lang['PRUNE_ANNOUNCEMENTS'] : '{ PRUNE_ANNOUNCEMENTS }')); ?>:</label></dt>
			<dd><label><input type="radio" class="radio" name="prune_announce" value="1"<?php if ($this->_rootref['S_PRUNE_ANNOUNCE']) {  ?> id="prune_announce" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
				<label><input type="radio" class="radio" name="prune_announce" value="0"<?php if (! $this->_rootref['S_PRUNE_ANNOUNCE']) {  ?> id="prune_announce" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
		</dl>
		<dl>
			<dt><label for="prune_sticky"><?php echo ((isset($this->_rootref['L_PRUNE_STICKY'])) ? $this->_rootref['L_PRUNE_STICKY'] : ((isset($user->lang['PRUNE_STICKY'])) ? $user->lang['PRUNE_STICKY'] : '{ PRUNE_STICKY }')); ?>:</label></dt>
			<dd><label><input type="radio" class="radio" name="prune_sticky" value="1"<?php if ($this->_rootref['S_PRUNE_STICKY']) {  ?> id="prune_sticky" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
				<label><input type="radio" class="radio" name="prune_sticky" value="0"<?php if (! $this->_rootref['S_PRUNE_STICKY']) {  ?> id="prune_sticky" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
		</dl>
		</fieldset>
	</div>

	<div id="forum_link_options">
		<fieldset>
			<legend><?php echo ((isset($this->_rootref['L_GENERAL_FORUM_SETTINGS'])) ? $this->_rootref['L_GENERAL_FORUM_SETTINGS'] : ((isset($user->lang['GENERAL_FORUM_SETTINGS'])) ? $user->lang['GENERAL_FORUM_SETTINGS'] : '{ GENERAL_FORUM_SETTINGS }')); ?></legend>
		<dl>
			<dt><label for="link_display_on_index"><?php echo ((isset($this->_rootref['L_LIST_INDEX'])) ? $this->_rootref['L_LIST_INDEX'] : ((isset($user->lang['LIST_INDEX'])) ? $user->lang['LIST_INDEX'] : '{ LIST_INDEX }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_LIST_INDEX_EXPLAIN'])) ? $this->_rootref['L_LIST_INDEX_EXPLAIN'] : ((isset($user->lang['LIST_INDEX_EXPLAIN'])) ? $user->lang['LIST_INDEX_EXPLAIN'] : '{ LIST_INDEX_EXPLAIN }')); ?></span></dt>
			<dd><label><input type="radio" class="radio" name="link_display_on_index" value="1"<?php if ($this->_rootref['S_DISPLAY_ON_INDEX']) {  ?> id="link_display_on_index" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
				<label><input type="radio" class="radio" name="link_display_on_index" value="0"<?php if (! $this->_rootref['S_DISPLAY_ON_INDEX']) {  ?> id="link_display_on_index" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
		</dl>
		<dl>
			<dt><label for="forum_link"><?php echo ((isset($this->_rootref['L_FORUM_LINK'])) ? $this->_rootref['L_FORUM_LINK'] : ((isset($user->lang['FORUM_LINK'])) ? $user->lang['FORUM_LINK'] : '{ FORUM_LINK }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_FORUM_LINK_EXPLAIN'])) ? $this->_rootref['L_FORUM_LINK_EXPLAIN'] : ((isset($user->lang['FORUM_LINK_EXPLAIN'])) ? $user->lang['FORUM_LINK_EXPLAIN'] : '{ FORUM_LINK_EXPLAIN }')); ?></span></dt>
			<dd><input class="text medium" type="text" id="forum_link" name="forum_link" value="<?php echo (isset($this->_rootref['FORUM_DATA_LINK'])) ? $this->_rootref['FORUM_DATA_LINK'] : ''; ?>" maxlength="255" /></dd>
		</dl>
		<dl>
			<dt><label for="forum_link_track"><?php echo ((isset($this->_rootref['L_FORUM_LINK_TRACK'])) ? $this->_rootref['L_FORUM_LINK_TRACK'] : ((isset($user->lang['FORUM_LINK_TRACK'])) ? $user->lang['FORUM_LINK_TRACK'] : '{ FORUM_LINK_TRACK }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_FORUM_LINK_TRACK_EXPLAIN'])) ? $this->_rootref['L_FORUM_LINK_TRACK_EXPLAIN'] : ((isset($user->lang['FORUM_LINK_TRACK_EXPLAIN'])) ? $user->lang['FORUM_LINK_TRACK_EXPLAIN'] : '{ FORUM_LINK_TRACK_EXPLAIN }')); ?></span></dt>
			<dd><label><input type="radio" class="radio" name="forum_link_track" value="1"<?php if ($this->_rootref['S_FORUM_LINK_TRACK']) {  ?> id="forum_link_track" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
				<label><input type="radio" class="radio" name="forum_link_track" value="0"<?php if (! $this->_rootref['S_FORUM_LINK_TRACK']) {  ?> id="forum_link_track" checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
		</dl>
		</fieldset>
	</div>

	<div id="forum_rules_options">
		<fieldset>
			<legend><?php echo ((isset($this->_rootref['L_FORUM_RULES'])) ? $this->_rootref['L_FORUM_RULES'] : ((isset($user->lang['FORUM_RULES'])) ? $user->lang['FORUM_RULES'] : '{ FORUM_RULES }')); ?></legend>
		<dl>
			<dt><label for="forum_rules_link"><?php echo ((isset($this->_rootref['L_FORUM_RULES_LINK'])) ? $this->_rootref['L_FORUM_RULES_LINK'] : ((isset($user->lang['FORUM_RULES_LINK'])) ? $user->lang['FORUM_RULES_LINK'] : '{ FORUM_RULES_LINK }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_FORUM_RULES_LINK_EXPLAIN'])) ? $this->_rootref['L_FORUM_RULES_LINK_EXPLAIN'] : ((isset($user->lang['FORUM_RULES_LINK_EXPLAIN'])) ? $user->lang['FORUM_RULES_LINK_EXPLAIN'] : '{ FORUM_RULES_LINK_EXPLAIN }')); ?></span></dt>
			<dd><input class="text medium" type="text" id="forum_rules_link" name="forum_rules_link" value="<?php echo (isset($this->_rootref['FORUM_RULES_LINK'])) ? $this->_rootref['FORUM_RULES_LINK'] : ''; ?>" maxlength="255" /></dd>
		</dl>
	<?php if ($this->_rootref['FORUM_RULES_PREVIEW']) {  ?>
		<dl>
			<dt><label><?php echo ((isset($this->_rootref['L_FORUM_RULES_PREVIEW'])) ? $this->_rootref['L_FORUM_RULES_PREVIEW'] : ((isset($user->lang['FORUM_RULES_PREVIEW'])) ? $user->lang['FORUM_RULES_PREVIEW'] : '{ FORUM_RULES_PREVIEW }')); ?>:</label></dt>
			<dd><?php echo (isset($this->_rootref['FORUM_RULES_PREVIEW'])) ? $this->_rootref['FORUM_RULES_PREVIEW'] : ''; ?></dd>
		</dl>
	<?php } ?>
		<dl>
			<dt><label for="forum_rules"><?php echo ((isset($this->_rootref['L_FORUM_RULES'])) ? $this->_rootref['L_FORUM_RULES'] : ((isset($user->lang['FORUM_RULES'])) ? $user->lang['FORUM_RULES'] : '{ FORUM_RULES }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_FORUM_RULES_EXPLAIN'])) ? $this->_rootref['L_FORUM_RULES_EXPLAIN'] : ((isset($user->lang['FORUM_RULES_EXPLAIN'])) ? $user->lang['FORUM_RULES_EXPLAIN'] : '{ FORUM_RULES_EXPLAIN }')); ?></span></dt>
			<dd><textarea id="forum_rules" name="forum_rules" rows="4" cols="70"><?php echo (isset($this->_rootref['FORUM_RULES_PLAIN'])) ? $this->_rootref['FORUM_RULES_PLAIN'] : ''; ?></textarea></dd>
			<dd><label><input type="checkbox" class="radio" name="rules_parse_bbcode"<?php if ($this->_rootref['S_BBCODE_CHECKED']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_PARSE_BBCODE'])) ? $this->_rootref['L_PARSE_BBCODE'] : ((isset($user->lang['PARSE_BBCODE'])) ? $user->lang['PARSE_BBCODE'] : '{ PARSE_BBCODE }')); ?></label>
				<label><input type="checkbox" class="radio" name="rules_parse_smilies"<?php if ($this->_rootref['S_SMILIES_CHECKED']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_PARSE_SMILIES'])) ? $this->_rootref['L_PARSE_SMILIES'] : ((isset($user->lang['PARSE_SMILIES'])) ? $user->lang['PARSE_SMILIES'] : '{ PARSE_SMILIES }')); ?></label>
				<label><input type="checkbox" class="radio" name="rules_parse_urls"<?php if ($this->_rootref['S_URLS_CHECKED']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_PARSE_URLS'])) ? $this->_rootref['L_PARSE_URLS'] : ((isset($user->lang['PARSE_URLS'])) ? $user->lang['PARSE_URLS'] : '{ PARSE_URLS }')); ?></label></dd>
		</dl>
		</fieldset>
	</div>

	<fieldset class="submit-buttons">
		<legend><?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?></legend>
		<input class="button1" type="submit" id="submit" name="update" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />&nbsp;
		<input class="button2" type="reset" id="reset" name="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" />
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
	</form>

<?php } else if ($this->_rootref['S_DELETE_FORUM']) {  ?>

	<a href="<?php echo (isset($this->_rootref['U_BACK'])) ? $this->_rootref['U_BACK'] : ''; ?>" style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>;">&laquo; <?php echo ((isset($this->_rootref['L_BACK'])) ? $this->_rootref['L_BACK'] : ((isset($user->lang['BACK'])) ? $user->lang['BACK'] : '{ BACK }')); ?></a>

	<h1><?php echo ((isset($this->_rootref['L_FORUM_DELETE'])) ? $this->_rootref['L_FORUM_DELETE'] : ((isset($user->lang['FORUM_DELETE'])) ? $user->lang['FORUM_DELETE'] : '{ FORUM_DELETE }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_FORUM_DELETE_EXPLAIN'])) ? $this->_rootref['L_FORUM_DELETE_EXPLAIN'] : ((isset($user->lang['FORUM_DELETE_EXPLAIN'])) ? $user->lang['FORUM_DELETE_EXPLAIN'] : '{ FORUM_DELETE_EXPLAIN }')); ?></p>

	<?php if ($this->_rootref['S_ERROR']) {  ?>
		<div class="errorbox">
			<h3><?php echo ((isset($this->_rootref['L_WARNING'])) ? $this->_rootref['L_WARNING'] : ((isset($user->lang['WARNING'])) ? $user->lang['WARNING'] : '{ WARNING }')); ?></h3>
			<p><?php echo (isset($this->_rootref['ERROR_MSG'])) ? $this->_rootref['ERROR_MSG'] : ''; ?></p>
		</div>
	<?php } ?>

	<form id="acp_forum" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_FORUM_DELETE'])) ? $this->_rootref['L_FORUM_DELETE'] : ((isset($user->lang['FORUM_DELETE'])) ? $user->lang['FORUM_DELETE'] : '{ FORUM_DELETE }')); ?></legend>
	<dl>
		<dt><label><?php echo ((isset($this->_rootref['L_FORUM_NAME'])) ? $this->_rootref['L_FORUM_NAME'] : ((isset($user->lang['FORUM_NAME'])) ? $user->lang['FORUM_NAME'] : '{ FORUM_NAME }')); ?>:</label></dt>
		<dd><strong><?php echo (isset($this->_rootref['FORUM_NAME'])) ? $this->_rootref['FORUM_NAME'] : ''; ?></strong></dd>
	</dl>
	<?php if ($this->_rootref['S_FORUM_POST']) {  ?>
		<dl>
			<dt><label for="delete_action"><?php echo ((isset($this->_rootref['L_ACTION'])) ? $this->_rootref['L_ACTION'] : ((isset($user->lang['ACTION'])) ? $user->lang['ACTION'] : '{ ACTION }')); ?>:</label></dt>
			<dd><label><input type="radio" class="radio" id="delete_action" name="action_posts" value="delete" checked="checked" /> <?php echo ((isset($this->_rootref['L_DELETE_ALL_POSTS'])) ? $this->_rootref['L_DELETE_ALL_POSTS'] : ((isset($user->lang['DELETE_ALL_POSTS'])) ? $user->lang['DELETE_ALL_POSTS'] : '{ DELETE_ALL_POSTS }')); ?></label></dd>
			<?php if ($this->_rootref['S_MOVE_FORUM_OPTIONS']) {  ?>
				<dd><label><input type="radio" class="radio" name="action_posts" value="move" /> <?php echo ((isset($this->_rootref['L_MOVE_POSTS_TO'])) ? $this->_rootref['L_MOVE_POSTS_TO'] : ((isset($user->lang['MOVE_POSTS_TO'])) ? $user->lang['MOVE_POSTS_TO'] : '{ MOVE_POSTS_TO }')); ?></label> <select name="posts_to_id"><?php echo (isset($this->_rootref['S_MOVE_FORUM_OPTIONS'])) ? $this->_rootref['S_MOVE_FORUM_OPTIONS'] : ''; ?></select></dd>
			<?php } ?>
		</dl>
	<?php } if ($this->_rootref['S_HAS_SUBFORUMS']) {  ?>
		<dl>
			<dt><label for="sub_delete_action"><?php echo ((isset($this->_rootref['L_ACTION'])) ? $this->_rootref['L_ACTION'] : ((isset($user->lang['ACTION'])) ? $user->lang['ACTION'] : '{ ACTION }')); ?>:</label></dt>
			<dd><label><input type="radio" class="radio" id="sub_delete_action" name="action_subforums" value="delete" checked="checked" /> <?php echo ((isset($this->_rootref['L_DELETE_SUBFORUMS'])) ? $this->_rootref['L_DELETE_SUBFORUMS'] : ((isset($user->lang['DELETE_SUBFORUMS'])) ? $user->lang['DELETE_SUBFORUMS'] : '{ DELETE_SUBFORUMS }')); ?></label></dd>
			<?php if ($this->_rootref['S_FORUMS_LIST']) {  ?>
				<dd><label><input type="radio" class="radio" name="action_subforums" value="move" /> <?php echo ((isset($this->_rootref['L_MOVE_SUBFORUMS_TO'])) ? $this->_rootref['L_MOVE_SUBFORUMS_TO'] : ((isset($user->lang['MOVE_SUBFORUMS_TO'])) ? $user->lang['MOVE_SUBFORUMS_TO'] : '{ MOVE_SUBFORUMS_TO }')); ?></label> <select name="subforums_to_id"><?php echo (isset($this->_rootref['S_FORUMS_LIST'])) ? $this->_rootref['S_FORUMS_LIST'] : ''; ?></select></dd>
			<?php } ?>
		</dl>
	<?php } ?>

	<p class="quick">
		<input class="button1" type="submit" name="update" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />
	</p>
	<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
	</form>

<?php } else if ($this->_rootref['S_CONTINUE_SYNC']) {  ?>

	<script type="text/javascript">
	// <![CDATA[
		var close_waitscreen = 0;
		// no scrollbars...
		popup('<?php echo (isset($this->_rootref['UA_PROGRESS_BAR'])) ? $this->_rootref['UA_PROGRESS_BAR'] : ''; ?>', 400, 240, '_sync');
	// ]]>
	</script>

	<h1><?php echo ((isset($this->_rootref['L_FORUM_ADMIN'])) ? $this->_rootref['L_FORUM_ADMIN'] : ((isset($user->lang['FORUM_ADMIN'])) ? $user->lang['FORUM_ADMIN'] : '{ FORUM_ADMIN }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_FORUM_ADMIN_EXPLAIN'])) ? $this->_rootref['L_FORUM_ADMIN_EXPLAIN'] : ((isset($user->lang['FORUM_ADMIN_EXPLAIN'])) ? $user->lang['FORUM_ADMIN_EXPLAIN'] : '{ FORUM_ADMIN_EXPLAIN }')); ?></p>

	<p><?php echo ((isset($this->_rootref['L_PROGRESS_EXPLAIN'])) ? $this->_rootref['L_PROGRESS_EXPLAIN'] : ((isset($user->lang['PROGRESS_EXPLAIN'])) ? $user->lang['PROGRESS_EXPLAIN'] : '{ PROGRESS_EXPLAIN }')); ?></p>

<?php } else { ?>

	<script type="text/javascript">
	// <![CDATA[
		/**
		* Popup search progress bar
		*/
		function popup_progress_bar()
		{
			var close_waitscreen = 0;
			// no scrollbars...
			popup('<?php echo (isset($this->_rootref['UA_PROGRESS_BAR'])) ? $this->_rootref['UA_PROGRESS_BAR'] : ''; ?>', 400, 240, '_sync');
		}
	// ]]>
	</script>

	<h1><?php echo ((isset($this->_rootref['L_FORUM_ADMIN'])) ? $this->_rootref['L_FORUM_ADMIN'] : ((isset($user->lang['FORUM_ADMIN'])) ? $user->lang['FORUM_ADMIN'] : '{ FORUM_ADMIN }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_FORUM_ADMIN_EXPLAIN'])) ? $this->_rootref['L_FORUM_ADMIN_EXPLAIN'] : ((isset($user->lang['FORUM_ADMIN_EXPLAIN'])) ? $user->lang['FORUM_ADMIN_EXPLAIN'] : '{ FORUM_ADMIN_EXPLAIN }')); ?></p>

	<?php if ($this->_rootref['ERROR_MSG']) {  ?>
		<div class="errorbox">
			<h3><?php echo ((isset($this->_rootref['L_WARNING'])) ? $this->_rootref['L_WARNING'] : ((isset($user->lang['WARNING'])) ? $user->lang['WARNING'] : '{ WARNING }')); ?></h3>
			<p><?php echo (isset($this->_rootref['ERROR_MSG'])) ? $this->_rootref['ERROR_MSG'] : ''; ?></p>
		</div>
	<?php } if ($this->_rootref['S_RESYNCED']) {  ?>
		<script type="text/javascript">
		// <![CDATA[
			var close_waitscreen = 1;
		// ]]>
		</script>

		<div class="successbox">
			<h3><?php echo ((isset($this->_rootref['L_NOTIFY'])) ? $this->_rootref['L_NOTIFY'] : ((isset($user->lang['NOTIFY'])) ? $user->lang['NOTIFY'] : '{ NOTIFY }')); ?></h3>
			<p><?php echo ((isset($this->_rootref['L_FORUM_RESYNCED'])) ? $this->_rootref['L_FORUM_RESYNCED'] : ((isset($user->lang['FORUM_RESYNCED'])) ? $user->lang['FORUM_RESYNCED'] : '{ FORUM_RESYNCED }')); ?></p>
		</div>
	<?php } ?>

	<p><strong><?php echo (isset($this->_rootref['NAVIGATION'])) ? $this->_rootref['NAVIGATION'] : ''; if ($this->_rootref['S_NO_FORUMS']) {  ?> [<a href="<?php echo (isset($this->_rootref['U_EDIT'])) ? $this->_rootref['U_EDIT'] : ''; ?>"><?php echo ((isset($this->_rootref['L_EDIT'])) ? $this->_rootref['L_EDIT'] : ((isset($user->lang['EDIT'])) ? $user->lang['EDIT'] : '{ EDIT }')); ?></a> | <a href="<?php echo (isset($this->_rootref['U_DELETE'])) ? $this->_rootref['U_DELETE'] : ''; ?>"><?php echo ((isset($this->_rootref['L_DELETE'])) ? $this->_rootref['L_DELETE'] : ((isset($user->lang['DELETE'])) ? $user->lang['DELETE'] : '{ DELETE }')); ?></a><?php if (! $this->_rootref['S_LINK']) {  ?> | <a href="<?php echo (isset($this->_rootref['U_SYNC'])) ? $this->_rootref['U_SYNC'] : ''; ?>"><?php echo ((isset($this->_rootref['L_RESYNC'])) ? $this->_rootref['L_RESYNC'] : ((isset($user->lang['RESYNC'])) ? $user->lang['RESYNC'] : '{ RESYNC }')); ?></a><?php } ?>]<?php } ?></strong></p>

	<?php if (sizeof($this->_tpldata['forums'])) {  ?>
		<table cellspacing="1">
			<col class="row1" /><col class="row1" /><col class="row2" />
		<tbody>
		<?php $_forums_count = (isset($this->_tpldata['forums'])) ? sizeof($this->_tpldata['forums']) : 0;if ($_forums_count) {for ($_forums_i = 0; $_forums_i < $_forums_count; ++$_forums_i){$_forums_val = &$this->_tpldata['forums'][$_forums_i]; ?>
			<tr>
				<td style="width: 5%; text-align: center;"><?php echo $_forums_val['FOLDER_IMAGE']; ?></td>
				<td>
					<?php if ($_forums_val['FORUM_IMAGE']) {  ?><div style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>; margin-right: 5px;"><?php echo $_forums_val['FORUM_IMAGE']; ?></div><?php } ?>
					<strong><?php if ($_forums_val['S_FORUM_LINK']) {  echo $_forums_val['FORUM_NAME']; } else { ?><a href="<?php echo $_forums_val['U_FORUM']; ?>"><?php echo $_forums_val['FORUM_NAME']; ?></a><?php } ?></strong>
					<?php if ($_forums_val['FORUM_DESCRIPTION']) {  ?><br /><span><?php echo $_forums_val['FORUM_DESCRIPTION']; ?></span><?php } if ($_forums_val['S_FORUM_POST']) {  ?><br /><br /><span><?php echo ((isset($this->_rootref['L_TOPICS'])) ? $this->_rootref['L_TOPICS'] : ((isset($user->lang['TOPICS'])) ? $user->lang['TOPICS'] : '{ TOPICS }')); ?>: <strong><?php echo $_forums_val['FORUM_TOPICS']; ?></strong> / <?php echo ((isset($this->_rootref['L_POSTS'])) ? $this->_rootref['L_POSTS'] : ((isset($user->lang['POSTS'])) ? $user->lang['POSTS'] : '{ POSTS }')); ?>: <b><?php echo $_forums_val['FORUM_POSTS']; ?></b></span><?php } ?>
				</td>
				<td style="vertical-align: top; width: 100px; text-align: right; white-space: nowrap;">
					<?php if ($_forums_val['S_FIRST_ROW'] && ! $_forums_val['S_LAST_ROW']) {  ?>
						<?php echo (isset($this->_rootref['ICON_MOVE_UP_DISABLED'])) ? $this->_rootref['ICON_MOVE_UP_DISABLED'] : ''; ?>
						<a href="<?php echo $_forums_val['U_MOVE_DOWN']; ?>"><?php echo (isset($this->_rootref['ICON_MOVE_DOWN'])) ? $this->_rootref['ICON_MOVE_DOWN'] : ''; ?></a>
					<?php } else if (! $_forums_val['S_FIRST_ROW'] && ! $_forums_val['S_LAST_ROW']) {  ?>
						<a href="<?php echo $_forums_val['U_MOVE_UP']; ?>"><?php echo (isset($this->_rootref['ICON_MOVE_UP'])) ? $this->_rootref['ICON_MOVE_UP'] : ''; ?></a>
						<a href="<?php echo $_forums_val['U_MOVE_DOWN']; ?>"><?php echo (isset($this->_rootref['ICON_MOVE_DOWN'])) ? $this->_rootref['ICON_MOVE_DOWN'] : ''; ?></a>
					<?php } else if ($_forums_val['S_LAST_ROW'] && ! $_forums_val['S_FIRST_ROW']) {  ?>
						<a href="<?php echo $_forums_val['U_MOVE_UP']; ?>"><?php echo (isset($this->_rootref['ICON_MOVE_UP'])) ? $this->_rootref['ICON_MOVE_UP'] : ''; ?></a>
						<?php echo (isset($this->_rootref['ICON_MOVE_DOWN_DISABLED'])) ? $this->_rootref['ICON_MOVE_DOWN_DISABLED'] : ''; ?>
					<?php } else { ?>
						<?php echo (isset($this->_rootref['ICON_MOVE_UP_DISABLED'])) ? $this->_rootref['ICON_MOVE_UP_DISABLED'] : ''; ?>
						<?php echo (isset($this->_rootref['ICON_MOVE_DOWN_DISABLED'])) ? $this->_rootref['ICON_MOVE_DOWN_DISABLED'] : ''; ?>
					<?php } ?>
					<a href="<?php echo $_forums_val['U_EDIT']; ?>"><?php echo (isset($this->_rootref['ICON_EDIT'])) ? $this->_rootref['ICON_EDIT'] : ''; ?></a>
					<?php if (! $_forums_val['S_FORUM_LINK']) {  ?>
						<a href="<?php echo $_forums_val['U_SYNC']; ?>" onclick="popup_progress_bar();"><?php echo (isset($this->_rootref['ICON_SYNC'])) ? $this->_rootref['ICON_SYNC'] : ''; ?></a>
					<?php } else { ?>
						<?php echo (isset($this->_rootref['ICON_SYNC_DISABLED'])) ? $this->_rootref['ICON_SYNC_DISABLED'] : ''; ?>
					<?php } ?>
					<a href="<?php echo $_forums_val['U_DELETE']; ?>"><?php echo (isset($this->_rootref['ICON_DELETE'])) ? $this->_rootref['ICON_DELETE'] : ''; ?></a>
				</td>
			</tr>
		<?php }} ?>
		</tbody>
		</table>
	<?php } ?>

	<form id="fselect" method="post" action="<?php echo (isset($this->_rootref['U_SEL_ACTION'])) ? $this->_rootref['U_SEL_ACTION'] : ''; ?>">

	<fieldset class="quick">
		<?php echo ((isset($this->_rootref['L_SELECT_FORUM'])) ? $this->_rootref['L_SELECT_FORUM'] : ((isset($user->lang['SELECT_FORUM'])) ? $user->lang['SELECT_FORUM'] : '{ SELECT_FORUM }')); ?>: <select name="parent_id" onchange="if(this.options[this.selectedIndex].value != -1){ this.form.submit(); }"><?php echo (isset($this->_rootref['FORUM_BOX'])) ? $this->_rootref['FORUM_BOX'] : ''; ?></select>

		<input class="button2" type="submit" value="<?php echo ((isset($this->_rootref['L_GO'])) ? $this->_rootref['L_GO'] : ((isset($user->lang['GO'])) ? $user->lang['GO'] : '{ GO }')); ?>" />
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
	</form>

	<form id="forums" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

	<fieldset class="quick">
		<input type="hidden" name="action" value="add" />

		<input type="text" name="forum_name" value="" maxlength="255" />
		<input class="button2" name="addforum" type="submit" value="<?php echo ((isset($this->_rootref['L_CREATE_FORUM'])) ? $this->_rootref['L_CREATE_FORUM'] : ((isset($user->lang['CREATE_FORUM'])) ? $user->lang['CREATE_FORUM'] : '{ CREATE_FORUM }')); ?>" />
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
	</form>

<?php } $this->_tpl_include('overall_footer.html'); ?>
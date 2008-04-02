<?php $this->_tpl_include('mcp_header.html'); $this->_tpldata['DEFINE']['.']['CUSTOM_FIELDSET_CLASS'] = 'forum-selection2'; $this->_tpl_include('jumpbox.html'); ?>

<h2><a href="<?php echo (isset($this->_rootref['U_VIEW_FORUM'])) ? $this->_rootref['U_VIEW_FORUM'] : ''; ?>"><?php echo ((isset($this->_rootref['L_FORUM'])) ? $this->_rootref['L_FORUM'] : ((isset($user->lang['FORUM'])) ? $user->lang['FORUM'] : '{ FORUM }')); ?>: <?php echo (isset($this->_rootref['FORUM_NAME'])) ? $this->_rootref['FORUM_NAME'] : ''; ?></a></h2>

<form method="post" id="mcp" action="<?php echo (isset($this->_rootref['S_MCP_ACTION'])) ? $this->_rootref['S_MCP_ACTION'] : ''; ?>">

<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>

	<?php if ($this->_rootref['PAGINATION'] || $this->_rootref['TOTAL_TOPICS']) {  ?>
		<ul class="linklist">
			<li class="rightside pagination">
				<?php if ($this->_rootref['TOTAL_TOPICS']) {  ?> <?php echo (isset($this->_rootref['TOTAL_TOPICS'])) ? $this->_rootref['TOTAL_TOPICS'] : ''; } if ($this->_rootref['PAGE_NUMBER']) {  if ($this->_rootref['PAGINATION']) {  ?> &bull; <a href="#" onclick="jumpto(); return false;" title="<?php echo ((isset($this->_rootref['L_JUMP_TO_PAGE'])) ? $this->_rootref['L_JUMP_TO_PAGE'] : ((isset($user->lang['JUMP_TO_PAGE'])) ? $user->lang['JUMP_TO_PAGE'] : '{ JUMP_TO_PAGE }')); ?>"><?php echo (isset($this->_rootref['PAGE_NUMBER'])) ? $this->_rootref['PAGE_NUMBER'] : ''; ?></a> &bull; <span><?php echo (isset($this->_rootref['PAGINATION'])) ? $this->_rootref['PAGINATION'] : ''; ?></span><?php } else { ?> &bull; <?php echo (isset($this->_rootref['PAGE_NUMBER'])) ? $this->_rootref['PAGE_NUMBER'] : ''; } } ?>
			</li>
		</ul>
	<?php } if (sizeof($this->_tpldata['topicrow'])) {  ?>
		<ul class="topiclist">
			<li class="header">
				<dl class="icon">
					<dt><?php echo ((isset($this->_rootref['L_TOPICS'])) ? $this->_rootref['L_TOPICS'] : ((isset($user->lang['TOPICS'])) ? $user->lang['TOPICS'] : '{ TOPICS }')); ?></dt>
					<dd class="posts"><?php echo ((isset($this->_rootref['L_REPLIES'])) ? $this->_rootref['L_REPLIES'] : ((isset($user->lang['REPLIES'])) ? $user->lang['REPLIES'] : '{ REPLIES }')); ?></dd>
					<dd class="lastpost"><span><?php echo ((isset($this->_rootref['L_LAST_POST'])) ? $this->_rootref['L_LAST_POST'] : ((isset($user->lang['LAST_POST'])) ? $user->lang['LAST_POST'] : '{ LAST_POST }')); ?></span></dd>
					<dd class="mark"><?php echo ((isset($this->_rootref['L_MARK'])) ? $this->_rootref['L_MARK'] : ((isset($user->lang['MARK'])) ? $user->lang['MARK'] : '{ MARK }')); ?></dd>
				</dl>
			</li>
		</ul>
		<ul class="topiclist cplist">

		<?php $_topicrow_count = (isset($this->_tpldata['topicrow'])) ? sizeof($this->_tpldata['topicrow']) : 0;if ($_topicrow_count) {for ($_topicrow_i = 0; $_topicrow_i < $_topicrow_count; ++$_topicrow_i){$_topicrow_val = &$this->_tpldata['topicrow'][$_topicrow_i]; ?>
		<li class="row<?php if (($_topicrow_val['S_ROW_COUNT'] & 1)  ) {  ?> bg1<?php } else { ?> bg2<?php } if ($_topicrow_val['S_TOPIC_REPORTED']) {  ?> reported<?php } ?>">
			<dl class="icon" style="background-image: url(<?php echo $_topicrow_val['TOPIC_FOLDER_IMG_SRC']; ?>); background-repeat: no-repeat;">
				<dt <?php if ($_topicrow_val['TOPIC_ICON_IMG'] && $this->_rootref['S_TOPIC_ICONS']) {  ?>style="background-image: url(<?php echo (isset($this->_rootref['T_ICONS_PATH'])) ? $this->_rootref['T_ICONS_PATH'] : ''; echo $_topicrow_val['TOPIC_ICON_IMG']; ?>); background-repeat: no-repeat;"<?php } ?>>
					<?php if ($_topicrow_val['S_SELECT_TOPIC']) {  ?><a href="<?php echo $_topicrow_val['U_SELECT_TOPIC']; ?>" class="topictitle">[ <?php echo ((isset($this->_rootref['L_SELECT_MERGE'])) ? $this->_rootref['L_SELECT_MERGE'] : ((isset($user->lang['SELECT_MERGE'])) ? $user->lang['SELECT_MERGE'] : '{ SELECT_MERGE }')); ?> ]</a>&nbsp;&nbsp; <?php } ?> 
					<a href="<?php echo $_topicrow_val['U_VIEW_TOPIC']; ?>" class="topictitle"><?php echo $_topicrow_val['TOPIC_TITLE']; ?></a>
					<?php if ($_topicrow_val['S_TOPIC_UNAPPROVED'] || $_topicrow_val['S_POSTS_UNAPPROVED']) {  ?><a href="<?php echo $_topicrow_val['U_MCP_QUEUE']; ?>"><?php echo $_topicrow_val['UNAPPROVED_IMG']; ?></a> <?php } if ($_topicrow_val['S_TOPIC_REPORTED']) {  ?><a href="<?php echo $_topicrow_val['U_MCP_REPORT']; ?>"><?php echo (isset($this->_rootref['REPORTED_IMG'])) ? $this->_rootref['REPORTED_IMG'] : ''; ?></a><?php } if ($_topicrow_val['S_MOVED_TOPIC'] && $this->_rootref['S_CAN_DELETE']) {  ?>&nbsp;<a href="<?php echo $_topicrow_val['U_DELETE_TOPIC']; ?>" class="topictitle">[ <?php echo ((isset($this->_rootref['L_DELETE_SHADOW_TOPIC'])) ? $this->_rootref['L_DELETE_SHADOW_TOPIC'] : ((isset($user->lang['DELETE_SHADOW_TOPIC'])) ? $user->lang['DELETE_SHADOW_TOPIC'] : '{ DELETE_SHADOW_TOPIC }')); ?> ]</a><?php } ?>
					<br />
					<?php if ($_topicrow_val['PAGINATION']) {  ?><strong class="pagination"><span><?php echo $_topicrow_val['PAGINATION']; ?></span></strong><?php } if ($_topicrow_val['ATTACH_ICON_IMG']) {  echo $_topicrow_val['ATTACH_ICON_IMG']; ?> <?php } echo ((isset($this->_rootref['L_POST_BY_AUTHOR'])) ? $this->_rootref['L_POST_BY_AUTHOR'] : ((isset($user->lang['POST_BY_AUTHOR'])) ? $user->lang['POST_BY_AUTHOR'] : '{ POST_BY_AUTHOR }')); ?> <?php echo $_topicrow_val['TOPIC_AUTHOR_FULL']; ?> <?php echo ((isset($this->_rootref['L_POSTED_ON_DATE'])) ? $this->_rootref['L_POSTED_ON_DATE'] : ((isset($user->lang['POSTED_ON_DATE'])) ? $user->lang['POSTED_ON_DATE'] : '{ POSTED_ON_DATE }')); ?> <?php echo $_topicrow_val['FIRST_POST_TIME']; ?> </dt>
				<dd class="posts"><?php echo $_topicrow_val['REPLIES']; ?> <dfn><?php echo ((isset($this->_rootref['L_REPLIES'])) ? $this->_rootref['L_REPLIES'] : ((isset($user->lang['REPLIES'])) ? $user->lang['REPLIES'] : '{ REPLIES }')); ?></dfn></dd>
				<dd class="lastpost"><span><dfn><?php echo ((isset($this->_rootref['L_LAST_POST'])) ? $this->_rootref['L_LAST_POST'] : ((isset($user->lang['LAST_POST'])) ? $user->lang['LAST_POST'] : '{ LAST_POST }')); ?> </dfn><?php echo ((isset($this->_rootref['L_POST_BY_AUTHOR'])) ? $this->_rootref['L_POST_BY_AUTHOR'] : ((isset($user->lang['POST_BY_AUTHOR'])) ? $user->lang['POST_BY_AUTHOR'] : '{ POST_BY_AUTHOR }')); ?> <?php echo $_topicrow_val['LAST_POST_AUTHOR_FULL']; ?> <?php echo ((isset($this->_rootref['L_POSTED_ON_DATE'])) ? $this->_rootref['L_POSTED_ON_DATE'] : ((isset($user->lang['POSTED_ON_DATE'])) ? $user->lang['POSTED_ON_DATE'] : '{ POSTED_ON_DATE }')); ?><br /><?php echo $_topicrow_val['LAST_POST_TIME']; ?></span>
				</dd>
				<dd class="mark">
					<?php if (! $_topicrow_val['S_MOVED_TOPIC']) {  ?><input type="checkbox" name="topic_id_list[]" value="<?php echo $_topicrow_val['TOPIC_ID']; ?>"<?php if ($_topicrow_val['S_TOPIC_CHECKED']) {  ?> checked="checked"<?php } ?> /><?php } else { ?>&nbsp;<?php } ?>
				</dd>
			</dl>
		</li>
		<?php }} ?>
		</ul>
	<?php } else { ?>
		<ul class="topiclist">
			<li><p class="notopics"><?php echo ((isset($this->_rootref['L_NO_TOPICS'])) ? $this->_rootref['L_NO_TOPICS'] : ((isset($user->lang['NO_TOPICS'])) ? $user->lang['NO_TOPICS'] : '{ NO_TOPICS }')); ?></p></li>
		</ul>
	<?php } ?>

	<fieldset class="display-options">
		<?php if ($this->_rootref['NEXT_PAGE']) {  ?><a href="<?php echo (isset($this->_rootref['NEXT_PAGE'])) ? $this->_rootref['NEXT_PAGE'] : ''; ?>" class="right-box <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>"><?php echo ((isset($this->_rootref['L_NEXT'])) ? $this->_rootref['L_NEXT'] : ((isset($user->lang['NEXT'])) ? $user->lang['NEXT'] : '{ NEXT }')); ?></a><?php } if ($this->_rootref['PREVIOUS_PAGE']) {  ?><a href="<?php echo (isset($this->_rootref['PREVIOUS_PAGE'])) ? $this->_rootref['PREVIOUS_PAGE'] : ''; ?>" class="left-box <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>"><?php echo ((isset($this->_rootref['L_PREVIOUS'])) ? $this->_rootref['L_PREVIOUS'] : ((isset($user->lang['PREVIOUS'])) ? $user->lang['PREVIOUS'] : '{ PREVIOUS }')); ?></a><?php } ?>	
		<label><?php echo ((isset($this->_rootref['L_DISPLAY_TOPICS'])) ? $this->_rootref['L_DISPLAY_TOPICS'] : ((isset($user->lang['DISPLAY_TOPICS'])) ? $user->lang['DISPLAY_TOPICS'] : '{ DISPLAY_TOPICS }')); ?>: <?php echo (isset($this->_rootref['S_SELECT_SORT_DAYS'])) ? $this->_rootref['S_SELECT_SORT_DAYS'] : ''; ?></label> 
		<label><?php echo ((isset($this->_rootref['L_SORT_BY'])) ? $this->_rootref['L_SORT_BY'] : ((isset($user->lang['SORT_BY'])) ? $user->lang['SORT_BY'] : '{ SORT_BY }')); ?> <?php echo (isset($this->_rootref['S_SELECT_SORT_KEY'])) ? $this->_rootref['S_SELECT_SORT_KEY'] : ''; ?></label> 
		<label><?php echo (isset($this->_rootref['S_SELECT_SORT_DIR'])) ? $this->_rootref['S_SELECT_SORT_DIR'] : ''; ?> <input type="submit" name="sort" value="<?php echo ((isset($this->_rootref['L_GO'])) ? $this->_rootref['L_GO'] : ((isset($user->lang['GO'])) ? $user->lang['GO'] : '{ GO }')); ?>" class="button2" /></label>
	</fieldset>

	<hr />

	<?php if ($this->_rootref['PAGINATION'] || $this->_rootref['TOTAL_TOPICS']) {  ?>
		<ul class="linklist">
			<li class="rightside pagination">
				<?php if ($this->_rootref['TOTAL_TOPICS']) {  ?> <?php echo (isset($this->_rootref['TOTAL_TOPICS'])) ? $this->_rootref['TOTAL_TOPICS'] : ''; } if ($this->_rootref['PAGE_NUMBER']) {  if ($this->_rootref['PAGINATION']) {  ?> &bull; <a href="#" onclick="jumpto(); return false;" title="<?php echo ((isset($this->_rootref['L_JUMP_TO_PAGE'])) ? $this->_rootref['L_JUMP_TO_PAGE'] : ((isset($user->lang['JUMP_TO_PAGE'])) ? $user->lang['JUMP_TO_PAGE'] : '{ JUMP_TO_PAGE }')); ?>"><?php echo (isset($this->_rootref['PAGE_NUMBER'])) ? $this->_rootref['PAGE_NUMBER'] : ''; ?></a> &bull; <span><?php echo (isset($this->_rootref['PAGINATION'])) ? $this->_rootref['PAGINATION'] : ''; ?></span><?php } else { ?> &bull; <?php echo (isset($this->_rootref['PAGE_NUMBER'])) ? $this->_rootref['PAGE_NUMBER'] : ''; } } ?>
			</li>
		</ul>
	<?php } ?>

	<span class="corners-bottom"><span></span></span></div>
</div>

<fieldset class="display-actions">
	<select name="action">
		<option value="" selected="selected"><?php echo ((isset($this->_rootref['L_SELECT_ACTION'])) ? $this->_rootref['L_SELECT_ACTION'] : ((isset($user->lang['SELECT_ACTION'])) ? $user->lang['SELECT_ACTION'] : '{ SELECT_ACTION }')); ?></option>
		<?php if ($this->_rootref['S_CAN_DELETE']) {  ?><option value="delete_topic"><?php echo ((isset($this->_rootref['L_DELETE'])) ? $this->_rootref['L_DELETE'] : ((isset($user->lang['DELETE'])) ? $user->lang['DELETE'] : '{ DELETE }')); ?></option><?php } if ($this->_rootref['S_CAN_MERGE']) {  ?><option value="merge_topics"><?php echo ((isset($this->_rootref['L_MERGE'])) ? $this->_rootref['L_MERGE'] : ((isset($user->lang['MERGE'])) ? $user->lang['MERGE'] : '{ MERGE }')); ?></option><?php } if ($this->_rootref['S_CAN_MOVE']) {  ?><option value="move"><?php echo ((isset($this->_rootref['L_MOVE'])) ? $this->_rootref['L_MOVE'] : ((isset($user->lang['MOVE'])) ? $user->lang['MOVE'] : '{ MOVE }')); ?></option><?php } if ($this->_rootref['S_CAN_FORK']) {  ?><option value="fork"><?php echo ((isset($this->_rootref['L_FORK'])) ? $this->_rootref['L_FORK'] : ((isset($user->lang['FORK'])) ? $user->lang['FORK'] : '{ FORK }')); ?></option><?php } if ($this->_rootref['S_CAN_LOCK']) {  ?><option value="lock"><?php echo ((isset($this->_rootref['L_LOCK'])) ? $this->_rootref['L_LOCK'] : ((isset($user->lang['LOCK'])) ? $user->lang['LOCK'] : '{ LOCK }')); ?></option><option value="unlock"><?php echo ((isset($this->_rootref['L_UNLOCK'])) ? $this->_rootref['L_UNLOCK'] : ((isset($user->lang['UNLOCK'])) ? $user->lang['UNLOCK'] : '{ UNLOCK }')); ?></option><?php } if ($this->_rootref['S_CAN_SYNC']) {  ?><option value="resync"><?php echo ((isset($this->_rootref['L_RESYNC'])) ? $this->_rootref['L_RESYNC'] : ((isset($user->lang['RESYNC'])) ? $user->lang['RESYNC'] : '{ RESYNC }')); ?></option><?php } if ($this->_rootref['S_CAN_MAKE_NORMAL']) {  ?><option value="make_normal"><?php echo ((isset($this->_rootref['L_MAKE_NORMAL'])) ? $this->_rootref['L_MAKE_NORMAL'] : ((isset($user->lang['MAKE_NORMAL'])) ? $user->lang['MAKE_NORMAL'] : '{ MAKE_NORMAL }')); ?></option><?php } if ($this->_rootref['S_CAN_MAKE_STICKY']) {  ?><option value="make_sticky"><?php echo ((isset($this->_rootref['L_MAKE_STICKY'])) ? $this->_rootref['L_MAKE_STICKY'] : ((isset($user->lang['MAKE_STICKY'])) ? $user->lang['MAKE_STICKY'] : '{ MAKE_STICKY }')); ?></option><?php } if ($this->_rootref['S_CAN_MAKE_ANNOUNCE']) {  ?>
			<option value="make_announce"><?php echo ((isset($this->_rootref['L_MAKE_ANNOUNCE'])) ? $this->_rootref['L_MAKE_ANNOUNCE'] : ((isset($user->lang['MAKE_ANNOUNCE'])) ? $user->lang['MAKE_ANNOUNCE'] : '{ MAKE_ANNOUNCE }')); ?></option>
			<option value="make_global"><?php echo ((isset($this->_rootref['L_MAKE_GLOBAL'])) ? $this->_rootref['L_MAKE_GLOBAL'] : ((isset($user->lang['MAKE_GLOBAL'])) ? $user->lang['MAKE_GLOBAL'] : '{ MAKE_GLOBAL }')); ?></option>
		<?php } ?>
	</select>
	<input class="button2" type="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />
	<div><a href="#" onclick="marklist('mcp', 'topic_id_list', true); return false;"><?php echo ((isset($this->_rootref['L_MARK_ALL'])) ? $this->_rootref['L_MARK_ALL'] : ((isset($user->lang['MARK_ALL'])) ? $user->lang['MARK_ALL'] : '{ MARK_ALL }')); ?></a> :: <a href="#" onclick="marklist('mcp', 'topic_id_list', false); return false;"><?php echo ((isset($this->_rootref['L_UNMARK_ALL'])) ? $this->_rootref['L_UNMARK_ALL'] : ((isset($user->lang['UNMARK_ALL'])) ? $user->lang['UNMARK_ALL'] : '{ UNMARK_ALL }')); ?></a></div>
	<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
</fieldset>
</form>

<?php $this->_tpl_include('mcp_footer.html'); ?>
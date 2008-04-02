<?php $this->_tpl_include('ucp_header.html'); ?>

<form id="ucp" method="post" action="<?php echo (isset($this->_rootref['S_UCP_ACTION'])) ? $this->_rootref['S_UCP_ACTION'] : ''; ?>"<?php echo (isset($this->_rootref['S_FORM_ENCTYPE'])) ? $this->_rootref['S_FORM_ENCTYPE'] : ''; ?>>

<h2><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></h2>

<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>
	
	<p><?php echo ((isset($this->_rootref['L_BOOKMARKS_EXPLAIN'])) ? $this->_rootref['L_BOOKMARKS_EXPLAIN'] : ((isset($user->lang['BOOKMARKS_EXPLAIN'])) ? $user->lang['BOOKMARKS_EXPLAIN'] : '{ BOOKMARKS_EXPLAIN }')); ?></p>
	
<?php if ($this->_rootref['S_NO_DISPLAY_BOOKMARKS']) {  ?>
	<p class="error"><?php echo ((isset($this->_rootref['L_BOOKMARKS_DISABLED'])) ? $this->_rootref['L_BOOKMARKS_DISABLED'] : ((isset($user->lang['BOOKMARKS_DISABLED'])) ? $user->lang['BOOKMARKS_DISABLED'] : '{ BOOKMARKS_DISABLED }')); ?></p>
<?php } else { if (sizeof($this->_tpldata['topicrow'])) {  ?>
	<ul class="topiclist">
		<li class="header">
			<dl class="icon">
				<dt><?php echo ((isset($this->_rootref['L_BOOKMARKS'])) ? $this->_rootref['L_BOOKMARKS'] : ((isset($user->lang['BOOKMARKS'])) ? $user->lang['BOOKMARKS'] : '{ BOOKMARKS }')); ?></dt>
				<dd class="lastpost"><span><?php echo ((isset($this->_rootref['L_LAST_POST'])) ? $this->_rootref['L_LAST_POST'] : ((isset($user->lang['LAST_POST'])) ? $user->lang['LAST_POST'] : '{ LAST_POST }')); ?></span></dd>
			</dl>
		</li>
	</ul>
	<ul class="topiclist cplist">

	<?php $_topicrow_count = (isset($this->_tpldata['topicrow'])) ? sizeof($this->_tpldata['topicrow']) : 0;if ($_topicrow_count) {for ($_topicrow_i = 0; $_topicrow_i < $_topicrow_count; ++$_topicrow_i){$_topicrow_val = &$this->_tpldata['topicrow'][$_topicrow_i]; ?>
		<li class="row<?php if ($_topicrow_val['S_TOPIC_REPORTED']) {  ?> reported<?php } else if (($_topicrow_val['S_ROW_COUNT'] & 1)  ) {  ?> bg1<?php } else { ?> bg2<?php } ?>">
			<?php if ($_topicrow_val['S_DELETED_TOPIC']) {  ?>
				<dl><dt><strong><?php echo ((isset($this->_rootref['L_DELETED_TOPIC'])) ? $this->_rootref['L_DELETED_TOPIC'] : ((isset($user->lang['DELETED_TOPIC'])) ? $user->lang['DELETED_TOPIC'] : '{ DELETED_TOPIC }')); ?></strong></dt>
				<dd class="mark"><input type="checkbox" name="t[<?php echo $_topicrow_val['TOPIC_ID']; ?>]" id="t<?php echo $_topicrow_val['TOPIC_ID']; ?>" /></dd>
				</dl>
			<?php } else { ?>
			<dl class="icon" style="background-image: url(<?php echo $_topicrow_val['TOPIC_FOLDER_IMG_SRC']; ?>); background-repeat: no-repeat;">
				<dt style="<?php if ($_topicrow_val['TOPIC_ICON_IMG']) {  ?>background-image: url(<?php echo (isset($this->_rootref['T_ICONS_PATH'])) ? $this->_rootref['T_ICONS_PATH'] : ''; echo $_topicrow_val['TOPIC_ICON_IMG']; ?>); background-repeat: no-repeat;<?php } ?>" title="<?php echo $_topicrow_val['TOPIC_FOLDER_IMG_ALT']; ?>">
					<?php if ($_topicrow_val['S_UNREAD_TOPIC']) {  ?><a href="<?php echo $_topicrow_val['U_NEWEST_POST']; ?>"><?php echo (isset($this->_rootref['NEWEST_POST_IMG'])) ? $this->_rootref['NEWEST_POST_IMG'] : ''; ?></a> <?php } ?><a href="<?php echo $_topicrow_val['U_VIEW_TOPIC']; ?>" class="topictitle"><?php echo $_topicrow_val['TOPIC_TITLE']; ?></a>
					<?php if ($_topicrow_val['S_TOPIC_UNAPPROVED'] || $_topicrow_val['S_POSTS_UNAPPROVED']) {  ?><a href="<?php echo $_topicrow_val['U_MCP_QUEUE']; ?>"><?php echo $_topicrow_val['UNAPPROVED_IMG']; ?></a> <?php } if ($_topicrow_val['S_TOPIC_REPORTED']) {  ?><a href="<?php echo $_topicrow_val['U_MCP_REPORT']; ?>"><?php echo (isset($this->_rootref['REPORTED_IMG'])) ? $this->_rootref['REPORTED_IMG'] : ''; ?></a><?php } ?><br />
					<?php if ($_topicrow_val['PAGINATION']) {  ?><strong class="pagination"><span><?php echo $_topicrow_val['PAGINATION']; ?></span></strong><?php } if ($_topicrow_val['ATTACH_ICON_IMG']) {  echo $_topicrow_val['ATTACH_ICON_IMG']; ?> <?php } echo ((isset($this->_rootref['L_POST_BY_AUTHOR'])) ? $this->_rootref['L_POST_BY_AUTHOR'] : ((isset($user->lang['POST_BY_AUTHOR'])) ? $user->lang['POST_BY_AUTHOR'] : '{ POST_BY_AUTHOR }')); ?> <?php echo $_topicrow_val['TOPIC_AUTHOR_FULL']; ?> <?php echo ((isset($this->_rootref['L_POSTED_ON_DATE'])) ? $this->_rootref['L_POSTED_ON_DATE'] : ((isset($user->lang['POSTED_ON_DATE'])) ? $user->lang['POSTED_ON_DATE'] : '{ POSTED_ON_DATE }')); ?> <?php echo $_topicrow_val['FIRST_POST_TIME']; ?> 
				</dt>
				<dd class="lastpost"><span><dfn><?php echo ((isset($this->_rootref['L_LAST_POST'])) ? $this->_rootref['L_LAST_POST'] : ((isset($user->lang['LAST_POST'])) ? $user->lang['LAST_POST'] : '{ LAST_POST }')); ?> </dfn><?php echo ((isset($this->_rootref['L_POST_BY_AUTHOR'])) ? $this->_rootref['L_POST_BY_AUTHOR'] : ((isset($user->lang['POST_BY_AUTHOR'])) ? $user->lang['POST_BY_AUTHOR'] : '{ POST_BY_AUTHOR }')); ?> <?php echo $_topicrow_val['LAST_POST_AUTHOR_FULL']; ?>
					<a href="<?php echo $_topicrow_val['U_LAST_POST']; ?>"><?php echo (isset($this->_rootref['LAST_POST_IMG'])) ? $this->_rootref['LAST_POST_IMG'] : ''; ?></a> <br /><?php echo ((isset($this->_rootref['L_POSTED_ON_DATE'])) ? $this->_rootref['L_POSTED_ON_DATE'] : ((isset($user->lang['POSTED_ON_DATE'])) ? $user->lang['POSTED_ON_DATE'] : '{ POSTED_ON_DATE }')); ?> <?php echo $_topicrow_val['LAST_POST_TIME']; ?></span>
				</dd>
				<dd class="mark"><input type="checkbox" name="t[<?php echo $_topicrow_val['TOPIC_ID']; ?>]" id="t<?php echo $_topicrow_val['TOPIC_ID']; ?>" /></dd>
			</dl>
			<?php } ?>
		</li>
	<?php }} ?>
	</ul>
	<ul class="linklist">
		<li class="rightside pagination">
			<?php if ($this->_rootref['TOTAL_TOPICS']) {  ?> <?php echo (isset($this->_rootref['TOTAL_TOPICS'])) ? $this->_rootref['TOTAL_TOPICS'] : ''; ?> <?php } if ($this->_rootref['PAGE_NUMBER']) {  if ($this->_rootref['PAGINATION']) {  ?> &bull; <a href="#" onclick="jumpto(); return false;" title="<?php echo ((isset($this->_rootref['L_JUMP_TO_PAGE'])) ? $this->_rootref['L_JUMP_TO_PAGE'] : ((isset($user->lang['JUMP_TO_PAGE'])) ? $user->lang['JUMP_TO_PAGE'] : '{ JUMP_TO_PAGE }')); ?>"><?php echo (isset($this->_rootref['PAGE_NUMBER'])) ? $this->_rootref['PAGE_NUMBER'] : ''; ?></a> &bull; <span><?php echo (isset($this->_rootref['PAGINATION'])) ? $this->_rootref['PAGINATION'] : ''; ?></span><?php } else { ?> &bull; <?php echo (isset($this->_rootref['PAGE_NUMBER'])) ? $this->_rootref['PAGE_NUMBER'] : ''; } } ?>
		</li>
	</ul>
<?php } else { ?>
	<p><strong><?php echo ((isset($this->_rootref['L_NO_BOOKMARKS'])) ? $this->_rootref['L_NO_BOOKMARKS'] : ((isset($user->lang['NO_BOOKMARKS'])) ? $user->lang['NO_BOOKMARKS'] : '{ NO_BOOKMARKS }')); ?></strong></p>
<?php } } ?>

	<span class="corners-bottom"><span></span></span></div>
</div>

<?php if (sizeof($this->_tpldata['topicrow']) && ! $this->_rootref['S_NO_DISPLAY_BOOKMARKS']) {  ?>
	<fieldset class="display-actions">		
		<input type="submit" name="unbookmark" value="<?php echo ((isset($this->_rootref['L_REMOVE_BOOKMARK_MARKED'])) ? $this->_rootref['L_REMOVE_BOOKMARK_MARKED'] : ((isset($user->lang['REMOVE_BOOKMARK_MARKED'])) ? $user->lang['REMOVE_BOOKMARK_MARKED'] : '{ REMOVE_BOOKMARK_MARKED }')); ?>" class="button2" />
		<div><a href="#" onclick="marklist('ucp', '', true); return false;"><?php echo ((isset($this->_rootref['L_MARK_ALL'])) ? $this->_rootref['L_MARK_ALL'] : ((isset($user->lang['MARK_ALL'])) ? $user->lang['MARK_ALL'] : '{ MARK_ALL }')); ?></a> &bull; <a href="#" onclick="marklist('ucp', '', false); return false;"><?php echo ((isset($this->_rootref['L_UNMARK_ALL'])) ? $this->_rootref['L_UNMARK_ALL'] : ((isset($user->lang['UNMARK_ALL'])) ? $user->lang['UNMARK_ALL'] : '{ UNMARK_ALL }')); ?></a></div>
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
<?php } ?>
</form>

<?php $this->_tpl_include('ucp_footer.html'); ?>
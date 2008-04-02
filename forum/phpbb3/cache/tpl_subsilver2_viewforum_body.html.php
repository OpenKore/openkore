<?php $this->_tpl_include('overall_header.html'); if ($this->_rootref['S_FORUM_RULES']) {  ?>
	<div class="forumrules">
		<?php if ($this->_rootref['U_FORUM_RULES']) {  ?>
			<h3><?php echo ((isset($this->_rootref['L_FORUM_RULES'])) ? $this->_rootref['L_FORUM_RULES'] : ((isset($user->lang['FORUM_RULES'])) ? $user->lang['FORUM_RULES'] : '{ FORUM_RULES }')); ?></h3><br />
			<a href="<?php echo (isset($this->_rootref['U_FORUM_RULES'])) ? $this->_rootref['U_FORUM_RULES'] : ''; ?>"><b><?php echo ((isset($this->_rootref['L_FORUM_RULES_LINK'])) ? $this->_rootref['L_FORUM_RULES_LINK'] : ((isset($user->lang['FORUM_RULES_LINK'])) ? $user->lang['FORUM_RULES_LINK'] : '{ FORUM_RULES_LINK }')); ?></b></a>
		<?php } else { ?>
			<h3><?php echo ((isset($this->_rootref['L_FORUM_RULES'])) ? $this->_rootref['L_FORUM_RULES'] : ((isset($user->lang['FORUM_RULES'])) ? $user->lang['FORUM_RULES'] : '{ FORUM_RULES }')); ?></h3><br />
			<?php echo (isset($this->_rootref['FORUM_RULES'])) ? $this->_rootref['FORUM_RULES'] : ''; ?>
		<?php } ?>
	</div>

	<br clear="all" />
<?php } if ($this->_rootref['S_DISPLAY_ACTIVE']) {  ?>
	<table class="tablebg" width="100%" cellspacing="1">
	<tr>
		<td class="cat" colspan="<?php if ($this->_rootref['S_TOPIC_ICONS']) {  ?>7<?php } else { ?>6<?php } ?>"><span class="nav"><?php echo ((isset($this->_rootref['L_ACTIVE_TOPICS'])) ? $this->_rootref['L_ACTIVE_TOPICS'] : ((isset($user->lang['ACTIVE_TOPICS'])) ? $user->lang['ACTIVE_TOPICS'] : '{ ACTIVE_TOPICS }')); ?></span></td>
	</tr>

	<tr>
		<?php if ($this->_rootref['S_TOPIC_ICONS']) {  ?>
			<th colspan="3">&nbsp;<?php echo ((isset($this->_rootref['L_TOPICS'])) ? $this->_rootref['L_TOPICS'] : ((isset($user->lang['TOPICS'])) ? $user->lang['TOPICS'] : '{ TOPICS }')); ?>&nbsp;</th>
		<?php } else { ?>
			<th colspan="2">&nbsp;<?php echo ((isset($this->_rootref['L_TOPICS'])) ? $this->_rootref['L_TOPICS'] : ((isset($user->lang['TOPICS'])) ? $user->lang['TOPICS'] : '{ TOPICS }')); ?>&nbsp;</th>
		<?php } ?>
		<th>&nbsp;<?php echo ((isset($this->_rootref['L_AUTHOR'])) ? $this->_rootref['L_AUTHOR'] : ((isset($user->lang['AUTHOR'])) ? $user->lang['AUTHOR'] : '{ AUTHOR }')); ?>&nbsp;</th>
		<th>&nbsp;<?php echo ((isset($this->_rootref['L_REPLIES'])) ? $this->_rootref['L_REPLIES'] : ((isset($user->lang['REPLIES'])) ? $user->lang['REPLIES'] : '{ REPLIES }')); ?>&nbsp;</th>
		<th>&nbsp;<?php echo ((isset($this->_rootref['L_VIEWS'])) ? $this->_rootref['L_VIEWS'] : ((isset($user->lang['VIEWS'])) ? $user->lang['VIEWS'] : '{ VIEWS }')); ?>&nbsp;</th>
		<th>&nbsp;<?php echo ((isset($this->_rootref['L_LAST_POST'])) ? $this->_rootref['L_LAST_POST'] : ((isset($user->lang['LAST_POST'])) ? $user->lang['LAST_POST'] : '{ LAST_POST }')); ?>&nbsp;</th>
	</tr>

	<?php $_topicrow_count = (isset($this->_tpldata['topicrow'])) ? sizeof($this->_tpldata['topicrow']) : 0;if ($_topicrow_count) {for ($_topicrow_i = 0; $_topicrow_i < $_topicrow_count; ++$_topicrow_i){$_topicrow_val = &$this->_tpldata['topicrow'][$_topicrow_i]; ?>

		<tr>
			<td class="row1" width="25" align="center"><?php echo $_topicrow_val['TOPIC_FOLDER_IMG']; ?></td>
			<?php if ($this->_rootref['S_TOPIC_ICONS']) {  ?>
				<td class="row1" width="25" align="center"><?php if ($_topicrow_val['TOPIC_ICON_IMG']) {  ?><img src="<?php echo (isset($this->_rootref['T_ICONS_PATH'])) ? $this->_rootref['T_ICONS_PATH'] : ''; echo $_topicrow_val['TOPIC_ICON_IMG']; ?>" width="<?php echo $_topicrow_val['TOPIC_ICON_IMG_WIDTH']; ?>" height="<?php echo $_topicrow_val['TOPIC_ICON_IMG_HEIGHT']; ?>" alt="" title="" /><?php } ?></td>
			<?php } ?>
			<td class="row1">
				<?php if ($_topicrow_val['S_UNREAD_TOPIC']) {  ?><a href="<?php echo $_topicrow_val['U_NEWEST_POST']; ?>"><?php echo (isset($this->_rootref['NEWEST_POST_IMG'])) ? $this->_rootref['NEWEST_POST_IMG'] : ''; ?></a><?php } ?>
				<?php echo $_topicrow_val['ATTACH_ICON_IMG']; ?> <?php if ($_topicrow_val['S_HAS_POLL'] || $_topicrow_val['S_TOPIC_MOVED']) {  ?><b><?php echo $_topicrow_val['TOPIC_TYPE']; ?></b> <?php } ?><a title="<?php echo ((isset($this->_rootref['L_POSTED'])) ? $this->_rootref['L_POSTED'] : ((isset($user->lang['POSTED'])) ? $user->lang['POSTED'] : '{ POSTED }')); ?>: <?php echo $_topicrow_val['FIRST_POST_TIME']; ?>" href="<?php echo $_topicrow_val['U_VIEW_TOPIC']; ?>"class="topictitle"><?php echo $_topicrow_val['TOPIC_TITLE']; ?></a>
				<?php if ($_topicrow_val['S_TOPIC_UNAPPROVED'] || $_topicrow_val['S_POSTS_UNAPPROVED']) {  ?>
					<a href="<?php echo $_topicrow_val['U_MCP_QUEUE']; ?>"><?php echo (isset($this->_rootref['UNAPPROVED_IMG'])) ? $this->_rootref['UNAPPROVED_IMG'] : ''; ?></a>&nbsp;
				<?php } if ($_topicrow_val['S_TOPIC_REPORTED']) {  ?>
					<a href="<?php echo $_topicrow_val['U_MCP_REPORT']; ?>"><?php echo (isset($this->_rootref['REPORTED_IMG'])) ? $this->_rootref['REPORTED_IMG'] : ''; ?></a>&nbsp;
				<?php } if ($_topicrow_val['PAGINATION']) {  ?>
					<p class="gensmall"> [ <?php echo (isset($this->_rootref['GOTO_PAGE_IMG'])) ? $this->_rootref['GOTO_PAGE_IMG'] : ''; echo ((isset($this->_rootref['L_GOTO_PAGE'])) ? $this->_rootref['L_GOTO_PAGE'] : ((isset($user->lang['GOTO_PAGE'])) ? $user->lang['GOTO_PAGE'] : '{ GOTO_PAGE }')); ?>: <?php echo $_topicrow_val['PAGINATION']; ?> ] </p>
				<?php } ?>
			</td>
			<td class="row2" width="130" align="center"><p class="topicauthor"><?php echo $_topicrow_val['TOPIC_AUTHOR_FULL']; ?></p></td>
			<td class="row1" width="50" align="center"><p class="topicdetails"><?php echo $_topicrow_val['REPLIES']; ?></p></td>
			<td class="row2" width="50" align="center"><p class="topicdetails"><?php echo $_topicrow_val['VIEWS']; ?></p></td>
			<td class="row1" width="140" align="center">
				<p class="topicdetails" style="white-space: nowrap;"><?php echo $_topicrow_val['LAST_POST_TIME']; ?></p>
				<p class="topicdetails"><?php echo $_topicrow_val['LAST_POST_AUTHOR_FULL']; ?>
					<a href="<?php echo $_topicrow_val['U_LAST_POST']; ?>"><?php echo (isset($this->_rootref['LAST_POST_IMG'])) ? $this->_rootref['LAST_POST_IMG'] : ''; ?></a>
				</p>
			</td>
		</tr>

	<?php }} else { ?>

		<tr>
			<?php if ($this->_rootref['S_TOPIC_ICONS']) {  ?>
				<td class="row1" colspan="7" height="30" align="center" valign="middle"><span class="gen"><?php if (! $this->_rootref['S_SORT_DAYS']) {  echo ((isset($this->_rootref['L_NO_TOPICS'])) ? $this->_rootref['L_NO_TOPICS'] : ((isset($user->lang['NO_TOPICS'])) ? $user->lang['NO_TOPICS'] : '{ NO_TOPICS }')); } else { echo ((isset($this->_rootref['L_NO_TOPICS_TIME_FRAME'])) ? $this->_rootref['L_NO_TOPICS_TIME_FRAME'] : ((isset($user->lang['NO_TOPICS_TIME_FRAME'])) ? $user->lang['NO_TOPICS_TIME_FRAME'] : '{ NO_TOPICS_TIME_FRAME }')); } ?></span></td>
			<?php } else { ?>
				<td class="row1" colspan="6" height="30" align="center" valign="middle"><span class="gen"><?php if (! $this->_rootref['S_SORT_DAYS']) {  echo ((isset($this->_rootref['L_NO_TOPICS'])) ? $this->_rootref['L_NO_TOPICS'] : ((isset($user->lang['NO_TOPICS'])) ? $user->lang['NO_TOPICS'] : '{ NO_TOPICS }')); } else { echo ((isset($this->_rootref['L_NO_TOPICS_TIME_FRAME'])) ? $this->_rootref['L_NO_TOPICS_TIME_FRAME'] : ((isset($user->lang['NO_TOPICS_TIME_FRAME'])) ? $user->lang['NO_TOPICS_TIME_FRAME'] : '{ NO_TOPICS_TIME_FRAME }')); } ?></span></td>
			<?php } ?>
		</tr>
	<?php } ?>

	<tr align="center">
		<td class="cat" colspan="<?php if ($this->_rootref['S_TOPIC_ICONS']) {  ?>7<?php } else { ?>6<?php } ?>">&nbsp;</td>
	</tr>
	</table>

	<br clear="all" />
<?php } if ($this->_rootref['S_HAS_SUBFORUM']) {  $this->_tpl_include('forumlist_body.html'); ?>
	<br clear="all" />
<?php } if ($this->_rootref['S_IS_POSTABLE'] || $this->_rootref['S_NO_READ_ACCESS']) {  ?>
	<div id="pageheader">
		<h2><a class="titles" href="<?php echo (isset($this->_rootref['U_VIEW_FORUM'])) ? $this->_rootref['U_VIEW_FORUM'] : ''; ?>"><?php echo (isset($this->_rootref['FORUM_NAME'])) ? $this->_rootref['FORUM_NAME'] : ''; ?></a></h2>

		<?php if ($this->_rootref['MODERATORS']) {  ?>
			<p class="moderators"><?php if ($this->_rootref['S_SINGLE_MODERATOR']) {  echo ((isset($this->_rootref['L_MODERATOR'])) ? $this->_rootref['L_MODERATOR'] : ((isset($user->lang['MODERATOR'])) ? $user->lang['MODERATOR'] : '{ MODERATOR }')); } else { echo ((isset($this->_rootref['L_MODERATORS'])) ? $this->_rootref['L_MODERATORS'] : ((isset($user->lang['MODERATORS'])) ? $user->lang['MODERATORS'] : '{ MODERATORS }')); } ?>: <?php echo (isset($this->_rootref['MODERATORS'])) ? $this->_rootref['MODERATORS'] : ''; ?></p>
		<?php } if ($this->_rootref['U_MCP']) {  ?>
			<p class="linkmcp">[ <a href="<?php echo (isset($this->_rootref['U_MCP'])) ? $this->_rootref['U_MCP'] : ''; ?>"><?php echo ((isset($this->_rootref['L_MCP'])) ? $this->_rootref['L_MCP'] : ((isset($user->lang['MCP'])) ? $user->lang['MCP'] : '{ MCP }')); ?></a> ]</p>
		<?php } ?>
	</div>

	<br clear="all" /><br />
<?php } ?>

<div id="pagecontent">

<?php if ($this->_rootref['S_NO_READ_ACCESS']) {  ?>
	<table class="tablebg" width="100%" cellspacing="1">
	<tr>
		<td class="row1" height="30" align="center" valign="middle"><span class="gen"><?php echo ((isset($this->_rootref['L_NO_READ_ACCESS'])) ? $this->_rootref['L_NO_READ_ACCESS'] : ((isset($user->lang['NO_READ_ACCESS'])) ? $user->lang['NO_READ_ACCESS'] : '{ NO_READ_ACCESS }')); ?></span></td>
	</tr>
	</table>

	<?php if (! $this->_rootref['S_USER_LOGGED_IN']) {  ?>

		<br /><br />

		<form method="post" action="<?php echo (isset($this->_rootref['S_LOGIN_ACTION'])) ? $this->_rootref['S_LOGIN_ACTION'] : ''; ?>">

		<table class="tablebg" width="100%" cellspacing="1">
		<tr>
			<td class="cat"><h4><a href="<?php echo (isset($this->_rootref['U_LOGIN_LOGOUT'])) ? $this->_rootref['U_LOGIN_LOGOUT'] : ''; ?>"><?php echo ((isset($this->_rootref['L_LOGIN_LOGOUT'])) ? $this->_rootref['L_LOGIN_LOGOUT'] : ((isset($user->lang['LOGIN_LOGOUT'])) ? $user->lang['LOGIN_LOGOUT'] : '{ LOGIN_LOGOUT }')); ?></a></h4></td>
		</tr>
		<tr>
			<td class="row1" align="center"><span class="genmed"><?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?>:</span> <input class="post" type="text" name="username" size="10" />&nbsp; <span class="genmed"><?php echo ((isset($this->_rootref['L_PASSWORD'])) ? $this->_rootref['L_PASSWORD'] : ((isset($user->lang['PASSWORD'])) ? $user->lang['PASSWORD'] : '{ PASSWORD }')); ?>:</span> <input class="post" type="password" name="password" size="10" /><?php if ($this->_rootref['S_AUTOLOGIN_ENABLED']) {  ?>&nbsp; <span class="gensmall"><?php echo ((isset($this->_rootref['L_LOG_ME_IN'])) ? $this->_rootref['L_LOG_ME_IN'] : ((isset($user->lang['LOG_ME_IN'])) ? $user->lang['LOG_ME_IN'] : '{ LOG_ME_IN }')); ?></span> <input type="checkbox" class="radio" name="autologin" /><?php } ?>&nbsp; <input type="submit" class="btnmain" name="login" value="<?php echo ((isset($this->_rootref['L_LOGIN'])) ? $this->_rootref['L_LOGIN'] : ((isset($user->lang['LOGIN'])) ? $user->lang['LOGIN'] : '{ LOGIN }')); ?>" /></td>
		</tr>
		</table>
		
		</form>

	<?php } ?>

	<br clear="all" />
<?php } if ($this->_rootref['S_DISPLAY_POST_INFO'] || $this->_rootref['TOTAL_TOPICS']) {  ?>
		<table width="100%" cellspacing="1">
		<tr>
			<?php if ($this->_rootref['S_DISPLAY_POST_INFO'] && ! $this->_rootref['S_IS_BOT']) {  ?>
				<td align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>" valign="middle"><a href="<?php echo (isset($this->_rootref['U_POST_NEW_TOPIC'])) ? $this->_rootref['U_POST_NEW_TOPIC'] : ''; ?>"><?php echo (isset($this->_rootref['POST_IMG'])) ? $this->_rootref['POST_IMG'] : ''; ?></a></td>
			<?php } if ($this->_rootref['TOTAL_TOPICS']) {  ?>
				<td class="nav" valign="middle" nowrap="nowrap">&nbsp;<?php echo (isset($this->_rootref['PAGE_NUMBER'])) ? $this->_rootref['PAGE_NUMBER'] : ''; ?><br /></td>
				<td class="gensmall" nowrap="nowrap">&nbsp;[ <?php echo (isset($this->_rootref['TOTAL_TOPICS'])) ? $this->_rootref['TOTAL_TOPICS'] : ''; ?> ]&nbsp;</td>
				<td class="gensmall" width="100%" align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>" nowrap="nowrap"><?php $this->_tpl_include('pagination.html'); ?></td>
			<?php } ?>
		</tr>
		</table>
	<?php } if (! $this->_rootref['S_DISPLAY_ACTIVE'] && ( $this->_rootref['S_IS_POSTABLE'] || sizeof($this->_tpldata['topicrow']) )) {  ?>
		<table class="tablebg" width="100%" cellspacing="1">
		<tr>
			<td class="cat" colspan="<?php if ($this->_rootref['S_TOPIC_ICONS']) {  ?>7<?php } else { ?>6<?php } ?>">
				<table width="100%" cellspacing="0">
				<tr class="nav">
					<td valign="middle">&nbsp;<?php if ($this->_rootref['S_WATCH_FORUM_LINK'] && ! $this->_rootref['S_IS_BOT']) {  ?><a href="<?php echo (isset($this->_rootref['S_WATCH_FORUM_LINK'])) ? $this->_rootref['S_WATCH_FORUM_LINK'] : ''; ?>"><?php echo (isset($this->_rootref['S_WATCH_FORUM_TITLE'])) ? $this->_rootref['S_WATCH_FORUM_TITLE'] : ''; ?></a><?php } ?></td>
					<td align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>" valign="middle"><?php if (! $this->_rootref['S_IS_BOT'] && $this->_rootref['U_MARK_TOPICS']) {  ?><a href="<?php echo (isset($this->_rootref['U_MARK_TOPICS'])) ? $this->_rootref['U_MARK_TOPICS'] : ''; ?>"><?php echo ((isset($this->_rootref['L_MARK_TOPICS_READ'])) ? $this->_rootref['L_MARK_TOPICS_READ'] : ((isset($user->lang['MARK_TOPICS_READ'])) ? $user->lang['MARK_TOPICS_READ'] : '{ MARK_TOPICS_READ }')); ?></a><?php } ?>&nbsp;</td>
				</tr>
				</table>
			</td>
		</tr>

		<tr>
			<?php if ($this->_rootref['S_TOPIC_ICONS']) {  ?>
				<th colspan="3">&nbsp;<?php echo ((isset($this->_rootref['L_TOPICS'])) ? $this->_rootref['L_TOPICS'] : ((isset($user->lang['TOPICS'])) ? $user->lang['TOPICS'] : '{ TOPICS }')); ?>&nbsp;</th>
			<?php } else { ?>
				<th colspan="2">&nbsp;<?php echo ((isset($this->_rootref['L_TOPICS'])) ? $this->_rootref['L_TOPICS'] : ((isset($user->lang['TOPICS'])) ? $user->lang['TOPICS'] : '{ TOPICS }')); ?>&nbsp;</th>
			<?php } ?>
			<th>&nbsp;<?php echo ((isset($this->_rootref['L_AUTHOR'])) ? $this->_rootref['L_AUTHOR'] : ((isset($user->lang['AUTHOR'])) ? $user->lang['AUTHOR'] : '{ AUTHOR }')); ?>&nbsp;</th>
			<th>&nbsp;<?php echo ((isset($this->_rootref['L_REPLIES'])) ? $this->_rootref['L_REPLIES'] : ((isset($user->lang['REPLIES'])) ? $user->lang['REPLIES'] : '{ REPLIES }')); ?>&nbsp;</th>
			<th>&nbsp;<?php echo ((isset($this->_rootref['L_VIEWS'])) ? $this->_rootref['L_VIEWS'] : ((isset($user->lang['VIEWS'])) ? $user->lang['VIEWS'] : '{ VIEWS }')); ?>&nbsp;</th>
			<th>&nbsp;<?php echo ((isset($this->_rootref['L_LAST_POST'])) ? $this->_rootref['L_LAST_POST'] : ((isset($user->lang['LAST_POST'])) ? $user->lang['LAST_POST'] : '{ LAST_POST }')); ?>&nbsp;</th>
		</tr>

		<?php $_topicrow_count = (isset($this->_tpldata['topicrow'])) ? sizeof($this->_tpldata['topicrow']) : 0;if ($_topicrow_count) {for ($_topicrow_i = 0; $_topicrow_i < $_topicrow_count; ++$_topicrow_i){$_topicrow_val = &$this->_tpldata['topicrow'][$_topicrow_i]; if ($_topicrow_val['S_TOPIC_TYPE_SWITCH'] == 1) {  ?>
				<tr>
					<td class="row3" colspan="<?php if ($this->_rootref['S_TOPIC_ICONS']) {  ?>7<?php } else { ?>6<?php } ?>"><b class="gensmall"><?php echo ((isset($this->_rootref['L_ANNOUNCEMENTS'])) ? $this->_rootref['L_ANNOUNCEMENTS'] : ((isset($user->lang['ANNOUNCEMENTS'])) ? $user->lang['ANNOUNCEMENTS'] : '{ ANNOUNCEMENTS }')); ?></b></td>
				</tr>
			<?php } else if ($_topicrow_val['S_TOPIC_TYPE_SWITCH'] == 0) {  ?>
				<tr>
					<td class="row3" colspan="<?php if ($this->_rootref['S_TOPIC_ICONS']) {  ?>7<?php } else { ?>6<?php } ?>"><b class="gensmall"><?php echo ((isset($this->_rootref['L_TOPICS'])) ? $this->_rootref['L_TOPICS'] : ((isset($user->lang['TOPICS'])) ? $user->lang['TOPICS'] : '{ TOPICS }')); ?></b></td>
				</tr>
			<?php } ?>

			<tr>
				<td class="row1" width="25" align="center"><?php echo $_topicrow_val['TOPIC_FOLDER_IMG']; ?></td>
				<?php if ($this->_rootref['S_TOPIC_ICONS']) {  ?>
					<td class="row1" width="25" align="center"><?php if ($_topicrow_val['TOPIC_ICON_IMG']) {  ?><img src="<?php echo (isset($this->_rootref['T_ICONS_PATH'])) ? $this->_rootref['T_ICONS_PATH'] : ''; echo $_topicrow_val['TOPIC_ICON_IMG']; ?>" width="<?php echo $_topicrow_val['TOPIC_ICON_IMG_WIDTH']; ?>" height="<?php echo $_topicrow_val['TOPIC_ICON_IMG_HEIGHT']; ?>" alt="" title="" /><?php } ?></td>
				<?php } ?>
				<td class="row1">
					<?php if ($_topicrow_val['S_UNREAD_TOPIC']) {  ?><a href="<?php echo $_topicrow_val['U_NEWEST_POST']; ?>"><?php echo (isset($this->_rootref['NEWEST_POST_IMG'])) ? $this->_rootref['NEWEST_POST_IMG'] : ''; ?></a><?php } ?>
					<?php echo $_topicrow_val['ATTACH_ICON_IMG']; ?> <?php if ($_topicrow_val['S_HAS_POLL'] || $_topicrow_val['S_TOPIC_MOVED']) {  ?><b><?php echo $_topicrow_val['TOPIC_TYPE']; ?></b> <?php } ?><a title="<?php echo ((isset($this->_rootref['L_POSTED'])) ? $this->_rootref['L_POSTED'] : ((isset($user->lang['POSTED'])) ? $user->lang['POSTED'] : '{ POSTED }')); ?>: <?php echo $_topicrow_val['FIRST_POST_TIME']; ?>" href="<?php echo $_topicrow_val['U_VIEW_TOPIC']; ?>" class="topictitle"><?php echo $_topicrow_val['TOPIC_TITLE']; ?></a>
					<?php if ($_topicrow_val['S_TOPIC_UNAPPROVED'] || $_topicrow_val['S_POSTS_UNAPPROVED']) {  ?>
						<a href="<?php echo $_topicrow_val['U_MCP_QUEUE']; ?>"><?php echo $_topicrow_val['UNAPPROVED_IMG']; ?></a>&nbsp;
					<?php } if ($_topicrow_val['S_TOPIC_REPORTED']) {  ?>
						<a href="<?php echo $_topicrow_val['U_MCP_REPORT']; ?>"><?php echo (isset($this->_rootref['REPORTED_IMG'])) ? $this->_rootref['REPORTED_IMG'] : ''; ?></a>&nbsp;
					<?php } if ($_topicrow_val['PAGINATION']) {  ?>
						<p class="gensmall"> [ <?php echo (isset($this->_rootref['GOTO_PAGE_IMG'])) ? $this->_rootref['GOTO_PAGE_IMG'] : ''; echo ((isset($this->_rootref['L_GOTO_PAGE'])) ? $this->_rootref['L_GOTO_PAGE'] : ((isset($user->lang['GOTO_PAGE'])) ? $user->lang['GOTO_PAGE'] : '{ GOTO_PAGE }')); ?>: <?php echo $_topicrow_val['PAGINATION']; ?> ] </p>
					<?php } ?>
				</td>
				<td class="row2" width="130" align="center"><p class="topicauthor"><?php echo $_topicrow_val['TOPIC_AUTHOR_FULL']; ?></p></td>
				<td class="row1" width="50" align="center"><p class="topicdetails"><?php echo $_topicrow_val['REPLIES']; ?></p></td>
				<td class="row2" width="50" align="center"><p class="topicdetails"><?php echo $_topicrow_val['VIEWS']; ?></p></td>
				<td class="row1" width="140" align="center">
					<p class="topicdetails" style="white-space: nowrap;"><?php echo $_topicrow_val['LAST_POST_TIME']; ?></p>
					<p class="topicdetails"><?php echo $_topicrow_val['LAST_POST_AUTHOR_FULL']; ?>
						<a href="<?php echo $_topicrow_val['U_LAST_POST']; ?>"><?php echo (isset($this->_rootref['LAST_POST_IMG'])) ? $this->_rootref['LAST_POST_IMG'] : ''; ?></a>
					</p>
				</td>
			</tr>

		<?php }} else { if ($this->_rootref['S_IS_POSTABLE']) {  ?>
			<tr>
				<?php if ($this->_rootref['S_TOPIC_ICONS']) {  ?>
					<td class="row1" colspan="7" height="30" align="center" valign="middle"><span class="gen"><?php if (! $this->_rootref['S_SORT_DAYS']) {  echo ((isset($this->_rootref['L_NO_TOPICS'])) ? $this->_rootref['L_NO_TOPICS'] : ((isset($user->lang['NO_TOPICS'])) ? $user->lang['NO_TOPICS'] : '{ NO_TOPICS }')); } else { echo ((isset($this->_rootref['L_NO_TOPICS_TIME_FRAME'])) ? $this->_rootref['L_NO_TOPICS_TIME_FRAME'] : ((isset($user->lang['NO_TOPICS_TIME_FRAME'])) ? $user->lang['NO_TOPICS_TIME_FRAME'] : '{ NO_TOPICS_TIME_FRAME }')); } ?></span></td>
				<?php } else { ?>
					<td class="row1" colspan="6" height="30" align="center" valign="middle"><span class="gen"><?php if (! $this->_rootref['S_SORT_DAYS']) {  echo ((isset($this->_rootref['L_NO_TOPICS'])) ? $this->_rootref['L_NO_TOPICS'] : ((isset($user->lang['NO_TOPICS'])) ? $user->lang['NO_TOPICS'] : '{ NO_TOPICS }')); } else { echo ((isset($this->_rootref['L_NO_TOPICS_TIME_FRAME'])) ? $this->_rootref['L_NO_TOPICS_TIME_FRAME'] : ((isset($user->lang['NO_TOPICS_TIME_FRAME'])) ? $user->lang['NO_TOPICS_TIME_FRAME'] : '{ NO_TOPICS_TIME_FRAME }')); } ?></span></td>
				<?php } ?>
			</tr>
			<?php } } ?>

		<tr align="center">
			<?php if ($this->_rootref['S_TOPIC_ICONS']) {  ?>
				<td class="cat" colspan="7">
			<?php } else { ?>
				<td class="cat" colspan="6">
			<?php } ?>
					<form method="post" action="<?php echo (isset($this->_rootref['S_FORUM_ACTION'])) ? $this->_rootref['S_FORUM_ACTION'] : ''; ?>"><span class="gensmall"><?php echo ((isset($this->_rootref['L_DISPLAY_TOPICS'])) ? $this->_rootref['L_DISPLAY_TOPICS'] : ((isset($user->lang['DISPLAY_TOPICS'])) ? $user->lang['DISPLAY_TOPICS'] : '{ DISPLAY_TOPICS }')); ?>:</span>&nbsp;<?php echo (isset($this->_rootref['S_SELECT_SORT_DAYS'])) ? $this->_rootref['S_SELECT_SORT_DAYS'] : ''; ?>&nbsp;<span class="gensmall"><?php echo ((isset($this->_rootref['L_SORT_BY'])) ? $this->_rootref['L_SORT_BY'] : ((isset($user->lang['SORT_BY'])) ? $user->lang['SORT_BY'] : '{ SORT_BY }')); ?></span> <?php echo (isset($this->_rootref['S_SELECT_SORT_KEY'])) ? $this->_rootref['S_SELECT_SORT_KEY'] : ''; ?> <?php echo (isset($this->_rootref['S_SELECT_SORT_DIR'])) ? $this->_rootref['S_SELECT_SORT_DIR'] : ''; ?>&nbsp;<input class="btnlite" type="submit" name="sort" value="<?php echo ((isset($this->_rootref['L_GO'])) ? $this->_rootref['L_GO'] : ((isset($user->lang['GO'])) ? $user->lang['GO'] : '{ GO }')); ?>" /></form>
				</td>
		</tr>
		</table>
	<?php } if ($this->_rootref['S_DISPLAY_POST_INFO'] || $this->_rootref['TOTAL_TOPICS']) {  ?>
		<table width="100%" cellspacing="1">
		<tr>
			<?php if ($this->_rootref['S_DISPLAY_POST_INFO'] && ! $this->_rootref['S_IS_BOT']) {  ?>
				<td align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>" valign="middle"><a href="<?php echo (isset($this->_rootref['U_POST_NEW_TOPIC'])) ? $this->_rootref['U_POST_NEW_TOPIC'] : ''; ?>"><?php echo (isset($this->_rootref['POST_IMG'])) ? $this->_rootref['POST_IMG'] : ''; ?></a></td>
			<?php } if ($this->_rootref['TOTAL_TOPICS']) {  ?>
				<td class="nav" valign="middle" nowrap="nowrap">&nbsp;<?php echo (isset($this->_rootref['PAGE_NUMBER'])) ? $this->_rootref['PAGE_NUMBER'] : ''; ?><br /></td>
				<td class="gensmall" nowrap="nowrap">&nbsp;[ <?php echo (isset($this->_rootref['TOTAL_TOPICS'])) ? $this->_rootref['TOTAL_TOPICS'] : ''; ?> ]&nbsp;</td>
				<td class="gensmall" width="100%" align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>" nowrap="nowrap"><?php $this->_tpl_include('pagination.html'); ?></td>
			<?php } ?>
		</tr>
		</table>
	<?php } ?>

		<br clear="all" />
</div>

<?php $this->_tpl_include('breadcrumbs.html'); if ($this->_rootref['S_DISPLAY_ONLINE_LIST']) {  ?>
	<br clear="all" />

	<table class="tablebg" width="100%" cellspacing="1">
	<tr>
		<td class="cat"><h4><?php echo ((isset($this->_rootref['L_WHO_IS_ONLINE'])) ? $this->_rootref['L_WHO_IS_ONLINE'] : ((isset($user->lang['WHO_IS_ONLINE'])) ? $user->lang['WHO_IS_ONLINE'] : '{ WHO_IS_ONLINE }')); ?></h4></td>
	</tr>
	<tr>
		<td class="row1"><p class="gensmall"><?php echo (isset($this->_rootref['LOGGED_IN_USER_LIST'])) ? $this->_rootref['LOGGED_IN_USER_LIST'] : ''; ?></p></td>
	</tr>
	</table>
<?php } if ($this->_rootref['S_DISPLAY_POST_INFO']) {  ?>
	<br clear="all" />

	<table width="100%" cellspacing="0">
	<tr>
		<td align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>" valign="top">
			<table cellspacing="3" cellpadding="0" border="0">
			<tr>
				<td width="20" style="text-align: center;"><?php echo (isset($this->_rootref['FOLDER_NEW_IMG'])) ? $this->_rootref['FOLDER_NEW_IMG'] : ''; ?></td>
				<td class="gensmall"><?php echo ((isset($this->_rootref['L_NEW_POSTS'])) ? $this->_rootref['L_NEW_POSTS'] : ((isset($user->lang['NEW_POSTS'])) ? $user->lang['NEW_POSTS'] : '{ NEW_POSTS }')); ?></td>
				<td>&nbsp;&nbsp;</td>
				<td width="20" style="text-align: center;"><?php echo (isset($this->_rootref['FOLDER_IMG'])) ? $this->_rootref['FOLDER_IMG'] : ''; ?></td>
				<td class="gensmall"><?php echo ((isset($this->_rootref['L_NO_NEW_POSTS'])) ? $this->_rootref['L_NO_NEW_POSTS'] : ((isset($user->lang['NO_NEW_POSTS'])) ? $user->lang['NO_NEW_POSTS'] : '{ NO_NEW_POSTS }')); ?></td>
				<td>&nbsp;&nbsp;</td>
				<td width="20" style="text-align: center;"><?php echo (isset($this->_rootref['FOLDER_ANNOUNCE_IMG'])) ? $this->_rootref['FOLDER_ANNOUNCE_IMG'] : ''; ?></td>
				<td class="gensmall"><?php echo ((isset($this->_rootref['L_ICON_ANNOUNCEMENT'])) ? $this->_rootref['L_ICON_ANNOUNCEMENT'] : ((isset($user->lang['ICON_ANNOUNCEMENT'])) ? $user->lang['ICON_ANNOUNCEMENT'] : '{ ICON_ANNOUNCEMENT }')); ?></td>
			</tr>
			<tr>
				<td style="text-align: center;"><?php echo (isset($this->_rootref['FOLDER_HOT_NEW_IMG'])) ? $this->_rootref['FOLDER_HOT_NEW_IMG'] : ''; ?></td>
				<td class="gensmall"><?php echo ((isset($this->_rootref['L_NEW_POSTS_HOT'])) ? $this->_rootref['L_NEW_POSTS_HOT'] : ((isset($user->lang['NEW_POSTS_HOT'])) ? $user->lang['NEW_POSTS_HOT'] : '{ NEW_POSTS_HOT }')); ?></td>
				<td>&nbsp;&nbsp;</td>
				<td style="text-align: center;"><?php echo (isset($this->_rootref['FOLDER_HOT_IMG'])) ? $this->_rootref['FOLDER_HOT_IMG'] : ''; ?></td>
				<td class="gensmall"><?php echo ((isset($this->_rootref['L_NO_NEW_POSTS_HOT'])) ? $this->_rootref['L_NO_NEW_POSTS_HOT'] : ((isset($user->lang['NO_NEW_POSTS_HOT'])) ? $user->lang['NO_NEW_POSTS_HOT'] : '{ NO_NEW_POSTS_HOT }')); ?></td>
				<td>&nbsp;&nbsp;</td>
				<td style="text-align: center;"><?php echo (isset($this->_rootref['FOLDER_STICKY_IMG'])) ? $this->_rootref['FOLDER_STICKY_IMG'] : ''; ?></td>
				<td class="gensmall"><?php echo ((isset($this->_rootref['L_ICON_STICKY'])) ? $this->_rootref['L_ICON_STICKY'] : ((isset($user->lang['ICON_STICKY'])) ? $user->lang['ICON_STICKY'] : '{ ICON_STICKY }')); ?></td>			
			</tr>
			<tr>
				<td style="text-align: center;"><?php echo (isset($this->_rootref['FOLDER_LOCKED_NEW_IMG'])) ? $this->_rootref['FOLDER_LOCKED_NEW_IMG'] : ''; ?></td>
				<td class="gensmall"><?php echo ((isset($this->_rootref['L_NEW_POSTS_LOCKED'])) ? $this->_rootref['L_NEW_POSTS_LOCKED'] : ((isset($user->lang['NEW_POSTS_LOCKED'])) ? $user->lang['NEW_POSTS_LOCKED'] : '{ NEW_POSTS_LOCKED }')); ?></td>
				<td>&nbsp;&nbsp;</td>
				<td style="text-align: center;"><?php echo (isset($this->_rootref['FOLDER_LOCKED_IMG'])) ? $this->_rootref['FOLDER_LOCKED_IMG'] : ''; ?></td>
				<td class="gensmall"><?php echo ((isset($this->_rootref['L_NO_NEW_POSTS_LOCKED'])) ? $this->_rootref['L_NO_NEW_POSTS_LOCKED'] : ((isset($user->lang['NO_NEW_POSTS_LOCKED'])) ? $user->lang['NO_NEW_POSTS_LOCKED'] : '{ NO_NEW_POSTS_LOCKED }')); ?></td>
				<td>&nbsp;&nbsp;</td>
				<td style="text-align: center;"><?php echo (isset($this->_rootref['FOLDER_MOVED_IMG'])) ? $this->_rootref['FOLDER_MOVED_IMG'] : ''; ?></td>
				<td class="gensmall"><?php echo ((isset($this->_rootref['L_TOPIC_MOVED'])) ? $this->_rootref['L_TOPIC_MOVED'] : ((isset($user->lang['TOPIC_MOVED'])) ? $user->lang['TOPIC_MOVED'] : '{ TOPIC_MOVED }')); ?></td>
			</tr>
			</table>
		</td>
		<td align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>"><span class="gensmall"><?php $_rules_count = (isset($this->_tpldata['rules'])) ? sizeof($this->_tpldata['rules']) : 0;if ($_rules_count) {for ($_rules_i = 0; $_rules_i < $_rules_count; ++$_rules_i){$_rules_val = &$this->_tpldata['rules'][$_rules_i]; echo $_rules_val['RULE']; ?><br /><?php }} ?></span></td>
	</tr>
	</table>
<?php } ?>

<br clear="all" />

<table width="100%" cellspacing="0">
<tr>
	<td><?php if ($this->_rootref['S_DISPLAY_SEARCHBOX']) {  $this->_tpl_include('searchbox.html'); } ?></td>
	<td align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>"><?php $this->_tpl_include('jumpbox.html'); ?></td>
</tr>
</table>

<?php $this->_tpl_include('overall_footer.html'); ?>
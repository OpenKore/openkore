<?php $this->_tpl_include('overall_header.html'); ?>

<form method="post" action="<?php echo (isset($this->_rootref['S_SEARCH_ACTION'])) ? $this->_rootref['S_SEARCH_ACTION'] : ''; ?>">

<table width="100%" cellspacing="1">
<tr>
	<td colspan="2"><span class="titles"><?php if ($this->_rootref['SEARCH_TITLE']) {  echo (isset($this->_rootref['SEARCH_TITLE'])) ? $this->_rootref['SEARCH_TITLE'] : ''; } else { echo (isset($this->_rootref['SEARCH_MATCHES'])) ? $this->_rootref['SEARCH_MATCHES'] : ''; } ?></span><br /></td>
</tr>
<tr>
	<td class="genmed"><?php if ($this->_rootref['SEARCH_TOPIC']) {  echo ((isset($this->_rootref['L_SEARCHED_TOPIC'])) ? $this->_rootref['L_SEARCHED_TOPIC'] : ((isset($user->lang['SEARCHED_TOPIC'])) ? $user->lang['SEARCHED_TOPIC'] : '{ SEARCHED_TOPIC }')); ?>: <a href="<?php echo (isset($this->_rootref['U_SEARCH_TOPIC'])) ? $this->_rootref['U_SEARCH_TOPIC'] : ''; ?>"><b><?php echo (isset($this->_rootref['SEARCH_TOPIC'])) ? $this->_rootref['SEARCH_TOPIC'] : ''; ?></b></a><br /><?php } if ($this->_rootref['SEARCH_WORDS']) {  echo ((isset($this->_rootref['L_SEARCHED_FOR'])) ? $this->_rootref['L_SEARCHED_FOR'] : ((isset($user->lang['SEARCHED_FOR'])) ? $user->lang['SEARCHED_FOR'] : '{ SEARCHED_FOR }')); ?>: <a href="<?php echo (isset($this->_rootref['U_SEARCH_WORDS'])) ? $this->_rootref['U_SEARCH_WORDS'] : ''; ?>"><b><?php echo (isset($this->_rootref['SEARCH_WORDS'])) ? $this->_rootref['SEARCH_WORDS'] : ''; ?></b></a><?php } if ($this->_rootref['IGNORED_WORDS']) {  ?> <?php echo ((isset($this->_rootref['L_IGNORED_TERMS'])) ? $this->_rootref['L_IGNORED_TERMS'] : ((isset($user->lang['IGNORED_TERMS'])) ? $user->lang['IGNORED_TERMS'] : '{ IGNORED_TERMS }')); ?>: <b><?php echo (isset($this->_rootref['IGNORED_WORDS'])) ? $this->_rootref['IGNORED_WORDS'] : ''; ?></b><?php } ?></td>
	<td align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>"><?php if ($this->_rootref['SEARCH_IN_RESULTS']) {  ?><span class="genmed"><?php echo ((isset($this->_rootref['L_SEARCH_IN_RESULTS'])) ? $this->_rootref['L_SEARCH_IN_RESULTS'] : ((isset($user->lang['SEARCH_IN_RESULTS'])) ? $user->lang['SEARCH_IN_RESULTS'] : '{ SEARCH_IN_RESULTS }')); ?>: </span><input type="text" name="add_keywords" value="" /> <input class="btnlite" type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_GO'])) ? $this->_rootref['L_GO'] : ((isset($user->lang['GO'])) ? $user->lang['GO'] : '{ GO }')); ?>" /><?php } ?></td>
</tr>
</table>

<br clear="all" />

<?php if ($this->_rootref['S_SHOW_TOPICS']) {  ?>

	<table class="tablebg" width="100%" cellspacing="1">
	<tr>
		<th width="4%" nowrap="nowrap">&nbsp;</th>
		<th colspan="2" nowrap="nowrap">&nbsp;<?php echo ((isset($this->_rootref['L_TOPICS'])) ? $this->_rootref['L_TOPICS'] : ((isset($user->lang['TOPICS'])) ? $user->lang['TOPICS'] : '{ TOPICS }')); ?>&nbsp;</th>
		<th nowrap="nowrap">&nbsp;<?php echo ((isset($this->_rootref['L_AUTHOR'])) ? $this->_rootref['L_AUTHOR'] : ((isset($user->lang['AUTHOR'])) ? $user->lang['AUTHOR'] : '{ AUTHOR }')); ?>&nbsp;</th>
		<th nowrap="nowrap">&nbsp;<?php echo ((isset($this->_rootref['L_REPLIES'])) ? $this->_rootref['L_REPLIES'] : ((isset($user->lang['REPLIES'])) ? $user->lang['REPLIES'] : '{ REPLIES }')); ?>&nbsp;</th>
		<th nowrap="nowrap">&nbsp;<?php echo ((isset($this->_rootref['L_VIEWS'])) ? $this->_rootref['L_VIEWS'] : ((isset($user->lang['VIEWS'])) ? $user->lang['VIEWS'] : '{ VIEWS }')); ?>&nbsp;</th>
		<th nowrap="nowrap">&nbsp;<?php echo ((isset($this->_rootref['L_LAST_POST'])) ? $this->_rootref['L_LAST_POST'] : ((isset($user->lang['LAST_POST'])) ? $user->lang['LAST_POST'] : '{ LAST_POST }')); ?>&nbsp;</th>
	</tr>
	<?php $_searchresults_count = (isset($this->_tpldata['searchresults'])) ? sizeof($this->_tpldata['searchresults']) : 0;if ($_searchresults_count) {for ($_searchresults_i = 0; $_searchresults_i < $_searchresults_count; ++$_searchresults_i){$_searchresults_val = &$this->_tpldata['searchresults'][$_searchresults_i]; ?>
		<tr valign="middle">
			<td class="row1" width="25" align="center"><?php echo $_searchresults_val['TOPIC_FOLDER_IMG']; ?></td>
			<td class="row1" width="25" align="center">
			<?php if ($_searchresults_val['TOPIC_ICON_IMG']) {  ?>
				<img src="<?php echo (isset($this->_rootref['T_ICONS_PATH'])) ? $this->_rootref['T_ICONS_PATH'] : ''; echo $_searchresults_val['TOPIC_ICON_IMG']; ?>" width="<?php echo $_searchresults_val['TOPIC_ICON_IMG_WIDTH']; ?>" height="<?php echo $_searchresults_val['TOPIC_ICON_IMG_HEIGHT']; ?>" alt="" title="" />
			<?php } ?>
			</td>
			<td class="row1">
				<?php if ($_searchresults_val['S_UNREAD_TOPIC']) {  ?><a href="<?php echo $_searchresults_val['U_NEWEST_POST']; ?>"><?php echo (isset($this->_rootref['NEWEST_POST_IMG'])) ? $this->_rootref['NEWEST_POST_IMG'] : ''; ?></a><?php } ?>
				<?php echo $_topicrow_val['ATTACH_ICON_IMG']; ?> <a href="<?php echo $_searchresults_val['U_VIEW_TOPIC']; ?>" class="topictitle"><?php echo $_searchresults_val['TOPIC_TITLE']; ?></a>
				<?php if ($_searchresults_val['S_TOPIC_UNAPPROVED'] || $_searchresults_val['S_POSTS_UNAPPROVED']) {  ?>
					<a href="<?php echo $_searchresults_val['U_MCP_QUEUE']; ?>"><?php echo $_searchresults_val['UNAPPROVED_IMG']; ?></a>&nbsp;
				<?php } if ($_searchresults_val['S_TOPIC_REPORTED']) {  ?>
					<a href="<?php echo $_searchresults_val['U_MCP_REPORT']; ?>"><?php echo (isset($this->_rootref['REPORTED_IMG'])) ? $this->_rootref['REPORTED_IMG'] : ''; ?></a>&nbsp;
				<?php } if ($_searchresults_val['PAGINATION']) {  ?>
					<p class="gensmall"> [ <?php echo (isset($this->_rootref['GOTO_PAGE_IMG'])) ? $this->_rootref['GOTO_PAGE_IMG'] : ''; echo ((isset($this->_rootref['L_GOTO_PAGE'])) ? $this->_rootref['L_GOTO_PAGE'] : ((isset($user->lang['GOTO_PAGE'])) ? $user->lang['GOTO_PAGE'] : '{ GOTO_PAGE }')); ?>: <?php echo $_searchresults_val['PAGINATION']; ?> ] </p>
				<?php } if ($_searchresults_val['S_TOPIC_GLOBAL']) {  ?>
					<p class="gensmall"><?php echo ((isset($this->_rootref['L_GLOBAL'])) ? $this->_rootref['L_GLOBAL'] : ((isset($user->lang['GLOBAL'])) ? $user->lang['GLOBAL'] : '{ GLOBAL }')); ?></p>
				<?php } else { ?>
					<p class="gensmall"><?php echo ((isset($this->_rootref['L_IN'])) ? $this->_rootref['L_IN'] : ((isset($user->lang['IN'])) ? $user->lang['IN'] : '{ IN }')); ?> <a href="<?php echo $_searchresults_val['U_VIEW_FORUM']; ?>"><?php echo $_searchresults_val['FORUM_TITLE']; ?></a></p>
				<?php } ?>
			</td>
			<td class="row2" width="100" align="center"><p class="topicauthor"><?php echo $_searchresults_val['TOPIC_AUTHOR_FULL']; ?></p></td>
			<td class="row1" width="50" align="center"><p class="topicdetails"><?php echo $_searchresults_val['TOPIC_REPLIES']; ?></p></td>
			<td class="row2" width="50" align="center"><p class="topicdetails"><?php echo $_searchresults_val['TOPIC_VIEWS']; ?></p></td>
			<td class="row1" width="120" align="center">
				<p class="topicdetails"><?php echo $_searchresults_val['LAST_POST_TIME']; ?></p>
				<p class="topicdetails"><?php echo $_searchresults_val['LAST_POST_AUTHOR_FULL']; ?>
					<a href="<?php echo $_searchresults_val['U_LAST_POST']; ?>"><?php echo (isset($this->_rootref['LAST_POST_IMG'])) ? $this->_rootref['LAST_POST_IMG'] : ''; ?></a>
				</p>
			</td>
		</tr>
	<?php }} else { ?>
		<tr valign="middle">
			<td colspan="7" class="row3" align="center"><?php echo ((isset($this->_rootref['L_NO_SEARCH_RESULTS'])) ? $this->_rootref['L_NO_SEARCH_RESULTS'] : ((isset($user->lang['NO_SEARCH_RESULTS'])) ? $user->lang['NO_SEARCH_RESULTS'] : '{ NO_SEARCH_RESULTS }')); ?></td>
		</tr>
	<?php } ?>
	<tr>
		<td class="cat" colspan="7" valign="middle" align="center"><?php if ($this->_rootref['S_SELECT_SORT_DAYS'] || $this->_rootref['S_SELECT_SORT_KEY']) {  ?><span class="gensmall"><?php echo ((isset($this->_rootref['L_DISPLAY_POSTS'])) ? $this->_rootref['L_DISPLAY_POSTS'] : ((isset($user->lang['DISPLAY_POSTS'])) ? $user->lang['DISPLAY_POSTS'] : '{ DISPLAY_POSTS }')); ?>:</span> <?php echo (isset($this->_rootref['S_SELECT_SORT_DAYS'])) ? $this->_rootref['S_SELECT_SORT_DAYS'] : ''; if ($this->_rootref['S_SELECT_SORT_KEY']) {  ?>&nbsp;<span class="gensmall"><?php echo ((isset($this->_rootref['L_SORT_BY'])) ? $this->_rootref['L_SORT_BY'] : ((isset($user->lang['SORT_BY'])) ? $user->lang['SORT_BY'] : '{ SORT_BY }')); ?>:</span> <?php echo (isset($this->_rootref['S_SELECT_SORT_KEY'])) ? $this->_rootref['S_SELECT_SORT_KEY'] : ''; ?> <?php echo (isset($this->_rootref['S_SELECT_SORT_DIR'])) ? $this->_rootref['S_SELECT_SORT_DIR'] : ''; } ?>&nbsp;<input class="btnlite" type="submit" value="<?php echo ((isset($this->_rootref['L_GO'])) ? $this->_rootref['L_GO'] : ((isset($user->lang['GO'])) ? $user->lang['GO'] : '{ GO }')); ?>" name="sort" /><?php } ?></td>
	</tr>
	</table>

<?php } else { ?>

	<table class="tablebg" width="100%" cellspacing="1">
	<tr>
		<th width="150" nowrap="nowrap"><?php echo ((isset($this->_rootref['L_AUTHOR'])) ? $this->_rootref['L_AUTHOR'] : ((isset($user->lang['AUTHOR'])) ? $user->lang['AUTHOR'] : '{ AUTHOR }')); ?></th>
		<th width="100%" nowrap="nowrap"><?php echo ((isset($this->_rootref['L_MESSAGE'])) ? $this->_rootref['L_MESSAGE'] : ((isset($user->lang['MESSAGE'])) ? $user->lang['MESSAGE'] : '{ MESSAGE }')); ?></th>
	</tr>

	<?php $_searchresults_count = (isset($this->_tpldata['searchresults'])) ? sizeof($this->_tpldata['searchresults']) : 0;if ($_searchresults_count) {for ($_searchresults_i = 0; $_searchresults_i < $_searchresults_count; ++$_searchresults_i){$_searchresults_val = &$this->_tpldata['searchresults'][$_searchresults_i]; ?>
		<tr class="row2">
		<?php if ($_searchresults_val['S_IGNORE_POST']) {  ?>
			<td class="gensmall" colspan="2" height="25" align="center"><?php echo $_searchresults_val['L_IGNORE_POST']; ?></td>
		<?php } else { ?>
				<td colspan="2" height="25"><p class="topictitle"><a name="p<?php echo $_searchresults_val['POST_ID']; ?>" id="p<?php echo $_searchresults_val['POST_ID']; ?>"></a>&nbsp;<?php if ($_searchresults_val['FORUM_TITLE']) {  echo ((isset($this->_rootref['L_FORUM'])) ? $this->_rootref['L_FORUM'] : ((isset($user->lang['FORUM'])) ? $user->lang['FORUM'] : '{ FORUM }')); ?>: <a href="<?php echo $_searchresults_val['U_VIEW_FORUM']; ?>"><?php echo $_searchresults_val['FORUM_TITLE']; ?></a><?php } else { echo ((isset($this->_rootref['L_GLOBAL'])) ? $this->_rootref['L_GLOBAL'] : ((isset($user->lang['GLOBAL'])) ? $user->lang['GLOBAL'] : '{ GLOBAL }')); } ?> &nbsp; <?php echo ((isset($this->_rootref['L_TOPIC'])) ? $this->_rootref['L_TOPIC'] : ((isset($user->lang['TOPIC'])) ? $user->lang['TOPIC'] : '{ TOPIC }')); ?>: <a href="<?php echo $_searchresults_val['U_VIEW_TOPIC']; ?>"><?php echo $_searchresults_val['TOPIC_TITLE']; ?></a> </p></td>
			</tr>
			<tr class="row1">
				<td width="150" align="center" valign="middle"><b class="postauthor"><?php echo $_searchresults_val['POST_AUTHOR_FULL']; ?></b></td>
				<td height="25">
					<table width="100%" cellspacing="0" cellpadding="0" border="0">
					<tr>
						<td class="gensmall">
							<div style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>;">
							<?php if ($_searchresults_val['POST_SUBJECT'] != "") {  ?>
								&nbsp;<b><?php echo ((isset($this->_rootref['L_POST_SUBJECT'])) ? $this->_rootref['L_POST_SUBJECT'] : ((isset($user->lang['POST_SUBJECT'])) ? $user->lang['POST_SUBJECT'] : '{ POST_SUBJECT }')); ?>:</b> <a href="<?php echo $_searchresults_val['U_VIEW_POST']; ?>"><?php echo $_searchresults_val['POST_SUBJECT']; ?></a> 
							<?php } else { ?>
								[ <a href="<?php echo $_searchresults_val['U_VIEW_POST']; ?>"><?php echo ((isset($this->_rootref['L_JUMP_TO_POST'])) ? $this->_rootref['L_JUMP_TO_POST'] : ((isset($user->lang['JUMP_TO_POST'])) ? $user->lang['JUMP_TO_POST'] : '{ JUMP_TO_POST }')); ?></a> ]
							<?php } ?>
							</div>
							<div style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>;"><b><?php echo ((isset($this->_rootref['L_POSTED'])) ? $this->_rootref['L_POSTED'] : ((isset($user->lang['POSTED'])) ? $user->lang['POSTED'] : '{ POSTED }')); ?>:</b> <?php echo $_searchresults_val['POST_DATE']; ?>&nbsp;</div>
						</td>
					</tr>
					</table>
				</td>
			</tr>
			<tr class="row1">
				<td width="150" align="center" valign="top"><br /><span class="postdetails"><?php echo ((isset($this->_rootref['L_REPLIES'])) ? $this->_rootref['L_REPLIES'] : ((isset($user->lang['REPLIES'])) ? $user->lang['REPLIES'] : '{ REPLIES }')); ?>: <b><?php echo $_searchresults_val['TOPIC_REPLIES']; ?></b><br /><?php echo ((isset($this->_rootref['L_VIEWS'])) ? $this->_rootref['L_VIEWS'] : ((isset($user->lang['VIEWS'])) ? $user->lang['VIEWS'] : '{ VIEWS }')); ?>: <b><?php echo $_searchresults_val['TOPIC_VIEWS']; ?></b></span><br /><br /></td>
				<td valign="top">
					<table width="100%" cellspacing="5">
					<tr>
						<td class="postbody"><?php echo $_searchresults_val['MESSAGE']; ?></td>
					</tr>
					</table>
				</td>
			</tr>
		<?php } ?>
		<tr>
			<td class="spacer" colspan="2"><img src="images/spacer.gif" height="1" alt="" /></td>
		</tr>
	<?php }} else { ?>
		<tr valign="middle">
			<td colspan="2" class="row3" align="center"><?php echo ((isset($this->_rootref['L_NO_SEARCH_RESULTS'])) ? $this->_rootref['L_NO_SEARCH_RESULTS'] : ((isset($user->lang['NO_SEARCH_RESULTS'])) ? $user->lang['NO_SEARCH_RESULTS'] : '{ NO_SEARCH_RESULTS }')); ?></td>
		</tr>
	<?php } ?>
	<tr>
		<td class="cat" colspan="2" align="center"><?php if ($this->_rootref['S_SELECT_SORT_KEY']) {  ?><span class="gensmall"><?php echo ((isset($this->_rootref['L_SORT_BY'])) ? $this->_rootref['L_SORT_BY'] : ((isset($user->lang['SORT_BY'])) ? $user->lang['SORT_BY'] : '{ SORT_BY }')); ?>:</span> <?php echo (isset($this->_rootref['S_SELECT_SORT_KEY'])) ? $this->_rootref['S_SELECT_SORT_KEY'] : ''; ?> <?php echo (isset($this->_rootref['S_SELECT_SORT_DIR'])) ? $this->_rootref['S_SELECT_SORT_DIR'] : ''; ?>&nbsp;<input class="btnlite" type="submit" name="sort" value="<?php echo ((isset($this->_rootref['L_GO'])) ? $this->_rootref['L_GO'] : ((isset($user->lang['GO'])) ? $user->lang['GO'] : '{ GO }')); ?>" /><?php } ?></td>
	</tr>
	</table>
<?php } ?>

</form>

<div class="gensmall" style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>;"><span class="nav"><?php echo (isset($this->_rootref['PAGE_NUMBER'])) ? $this->_rootref['PAGE_NUMBER'] : ''; ?></span> [ <?php echo (isset($this->_rootref['SEARCH_MATCHES'])) ? $this->_rootref['SEARCH_MATCHES'] : ''; ?> ]</div>
<div class="nav" style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>;"><?php $this->_tpl_include('pagination.html'); ?></div>

<br clear="all" /><br />

<?php $this->_tpl_include('breadcrumbs.html'); ?>

<br clear="all" />

<div align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>"><?php $this->_tpl_include('jumpbox.html'); ?></div>

<?php $this->_tpl_include('overall_footer.html'); ?>
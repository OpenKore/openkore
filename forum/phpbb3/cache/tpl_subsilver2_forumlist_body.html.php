<table class="tablebg" cellspacing="1" width="100%">
<tr>
	<td class="cat" colspan="5" align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>"><?php if (! $this->_rootref['S_IS_BOT'] && $this->_rootref['U_MARK_FORUMS']) {  ?><a class="nav" href="<?php echo (isset($this->_rootref['U_MARK_FORUMS'])) ? $this->_rootref['U_MARK_FORUMS'] : ''; ?>"><?php echo ((isset($this->_rootref['L_MARK_FORUMS_READ'])) ? $this->_rootref['L_MARK_FORUMS_READ'] : ((isset($user->lang['MARK_FORUMS_READ'])) ? $user->lang['MARK_FORUMS_READ'] : '{ MARK_FORUMS_READ }')); ?></a><?php } ?>&nbsp;</td>
</tr>
<tr>
	<th colspan="2">&nbsp;<?php echo ((isset($this->_rootref['L_FORUM'])) ? $this->_rootref['L_FORUM'] : ((isset($user->lang['FORUM'])) ? $user->lang['FORUM'] : '{ FORUM }')); ?>&nbsp;</th>
	<th width="50">&nbsp;<?php echo ((isset($this->_rootref['L_TOPICS'])) ? $this->_rootref['L_TOPICS'] : ((isset($user->lang['TOPICS'])) ? $user->lang['TOPICS'] : '{ TOPICS }')); ?>&nbsp;</th>
	<th width="50">&nbsp;<?php echo ((isset($this->_rootref['L_POSTS'])) ? $this->_rootref['L_POSTS'] : ((isset($user->lang['POSTS'])) ? $user->lang['POSTS'] : '{ POSTS }')); ?>&nbsp;</th>
	<th>&nbsp;<?php echo ((isset($this->_rootref['L_LAST_POST'])) ? $this->_rootref['L_LAST_POST'] : ((isset($user->lang['LAST_POST'])) ? $user->lang['LAST_POST'] : '{ LAST_POST }')); ?>&nbsp;</th>
</tr>
<?php $_forumrow_count = (isset($this->_tpldata['forumrow'])) ? sizeof($this->_tpldata['forumrow']) : 0;if ($_forumrow_count) {for ($_forumrow_i = 0; $_forumrow_i < $_forumrow_count; ++$_forumrow_i){$_forumrow_val = &$this->_tpldata['forumrow'][$_forumrow_i]; if ($_forumrow_val['S_IS_CAT']) {  ?>
		<tr>
			<td class="cat" colspan="2"><h4><a href="<?php echo $_forumrow_val['U_VIEWFORUM']; ?>"><?php echo $_forumrow_val['FORUM_NAME']; ?></a></h4></td>
			<td class="catdiv" colspan="3">&nbsp;</td>
		</tr>
	<?php } else if ($_forumrow_val['S_IS_LINK']) {  ?>
		<tr>
			<td class="row1" width="50" align="center"><?php echo $_forumrow_val['FORUM_FOLDER_IMG']; ?></td>
			<td class="row1">
				<?php if ($_forumrow_val['FORUM_IMAGE']) {  ?>
					<div style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>; margin-<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>: 5px;"><?php echo $_forumrow_val['FORUM_IMAGE']; ?></div><div style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>;">
				<?php } ?>
				<a class="forumlink" href="<?php echo $_forumrow_val['U_VIEWFORUM']; ?>"><?php echo $_forumrow_val['FORUM_NAME']; ?></a>
				<p class="forumdesc"><?php echo $_forumrow_val['FORUM_DESC']; ?></p>
				<?php if ($_forumrow_val['FORUM_IMAGE']) {  ?></div><?php } ?>
			</td>
			<?php if ($_forumrow_val['CLICKS']) {  ?>
				<td class="row2" colspan="3" align="center"><span class="genmed"><?php echo ((isset($this->_rootref['L_REDIRECTS'])) ? $this->_rootref['L_REDIRECTS'] : ((isset($user->lang['REDIRECTS'])) ? $user->lang['REDIRECTS'] : '{ REDIRECTS }')); ?>: <?php echo $_forumrow_val['CLICKS']; ?></span></td>
			<?php } else { ?>
				<td class="row2" colspan="3" align="center">&nbsp;</td>
			<?php } ?>
		</tr>
	<?php } else { if ($_forumrow_val['S_NO_CAT']) {  ?>
			<tr>
				<td class="cat" colspan="2"><h4><?php echo ((isset($this->_rootref['L_FORUM'])) ? $this->_rootref['L_FORUM'] : ((isset($user->lang['FORUM'])) ? $user->lang['FORUM'] : '{ FORUM }')); ?></h4></td>
				<td class="catdiv" colspan="3">&nbsp;</td>
			</tr>
		<?php } ?>
		<tr>
			<td class="row1" width="50" align="center"><?php echo $_forumrow_val['FORUM_FOLDER_IMG']; ?></td>
			<td class="row1" width="100%">
				<?php if ($_forumrow_val['FORUM_IMAGE']) {  ?>
					<div style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>; margin-<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>: 5px;"><?php echo $_forumrow_val['FORUM_IMAGE']; ?></div><div style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>;">
				<?php } ?>
				<a class="forumlink" href="<?php echo $_forumrow_val['U_VIEWFORUM']; ?>"><?php echo $_forumrow_val['FORUM_NAME']; ?></a>
				<p class="forumdesc"><?php echo $_forumrow_val['FORUM_DESC']; ?></p>
				<?php if ($_forumrow_val['MODERATORS']) {  ?>
					<p class="forumdesc"><strong><?php echo $_forumrow_val['L_MODERATOR_STR']; ?>:</strong> <?php echo $_forumrow_val['MODERATORS']; ?></p>
				<?php } if ($_forumrow_val['SUBFORUMS']) {  ?>
					<p class="forumdesc"><strong><?php echo $_forumrow_val['L_SUBFORUM_STR']; ?></strong> <?php echo $_forumrow_val['SUBFORUMS']; ?></p>
				<?php } if ($_forumrow_val['FORUM_IMAGE']) {  ?></div><?php } ?>
			</td>
			<td class="row2" align="center"><p class="topicdetails"><?php echo $_forumrow_val['TOPICS']; ?></p></td>
			<td class="row2" align="center"><p class="topicdetails"><?php echo $_forumrow_val['POSTS']; ?></p></td>
			<td class="row2" align="center" nowrap="nowrap">
				<?php if ($_forumrow_val['LAST_POST_TIME']) {  ?>
					<p class="topicdetails"><?php echo $_forumrow_val['LAST_POST_TIME']; ?></p>
					<p class="topicdetails"><?php echo $_forumrow_val['LAST_POSTER_FULL']; ?>
						<a href="<?php echo $_forumrow_val['U_LAST_POST']; ?>"><?php echo (isset($this->_rootref['LAST_POST_IMG'])) ? $this->_rootref['LAST_POST_IMG'] : ''; ?></a>
					</p>
				<?php } else { ?>
					<p class="topicdetails"><?php echo ((isset($this->_rootref['L_NO_POSTS'])) ? $this->_rootref['L_NO_POSTS'] : ((isset($user->lang['NO_POSTS'])) ? $user->lang['NO_POSTS'] : '{ NO_POSTS }')); ?></p>
				<?php } ?>
			</td>
		</tr>
	<?php } }} else { ?>
	<tr>
		<td class="row1" colspan="5" align="center"><p class="gensmall"><?php echo ((isset($this->_rootref['L_NO_FORUMS'])) ? $this->_rootref['L_NO_FORUMS'] : ((isset($user->lang['NO_FORUMS'])) ? $user->lang['NO_FORUMS'] : '{ NO_FORUMS }')); ?></p></td>
	</tr>
<?php } ?>
</table>
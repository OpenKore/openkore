<?php $this->_tpl_include('ucp_header.html'); ?>

<table class="tablebg" width="100%" cellspacing="1">
<tr>
	<th colspan="3"><?php echo ((isset($this->_rootref['L_UCP'])) ? $this->_rootref['L_UCP'] : ((isset($user->lang['UCP'])) ? $user->lang['UCP'] : '{ UCP }')); ?></th>
</tr>
<tr>
	<td class="row1" colspan="3" align="center"><p class="genmed"><?php echo ((isset($this->_rootref['L_UCP_WELCOME'])) ? $this->_rootref['L_UCP_WELCOME'] : ((isset($user->lang['UCP_WELCOME'])) ? $user->lang['UCP_WELCOME'] : '{ UCP_WELCOME }')); ?></p></td>
</tr>
<tr>
	<th colspan="3"><?php echo ((isset($this->_rootref['L_IMPORTANT_NEWS'])) ? $this->_rootref['L_IMPORTANT_NEWS'] : ((isset($user->lang['IMPORTANT_NEWS'])) ? $user->lang['IMPORTANT_NEWS'] : '{ IMPORTANT_NEWS }')); ?></th>
</tr>

<?php $_topicrow_count = (isset($this->_tpldata['topicrow'])) ? sizeof($this->_tpldata['topicrow']) : 0;if ($_topicrow_count) {for ($_topicrow_i = 0; $_topicrow_i < $_topicrow_count; ++$_topicrow_i){$_topicrow_val = &$this->_tpldata['topicrow'][$_topicrow_i]; if (!($_topicrow_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>
		<td class="row1" width="25" align="center"><?php echo $_topicrow_val['TOPIC_FOLDER_IMG']; ?></td>
		<td class="row1" width="100%">
			<p class="topictitle"><?php if ($_topicrow_val['S_UNREAD']) {  ?><a href="<?php echo $_topicrow_val['U_NEWEST_POST']; ?>"><?php echo (isset($this->_rootref['NEWEST_POST_IMG'])) ? $this->_rootref['NEWEST_POST_IMG'] : ''; ?></a> <?php } echo $_topicrow_val['ATTACH_ICON_IMG']; ?> <a href="<?php echo $_topicrow_val['U_VIEW_TOPIC']; ?>"><?php echo $_topicrow_val['TOPIC_TITLE']; ?></a></p><p class="gensmall"><?php echo $_topicrow_val['GOTO_PAGE']; ?></p>
		</td>
		<td class="row1" width="120" align="center" nowrap="nowrap">
			<p class="topicdetails"><?php echo $_topicrow_val['LAST_POST_TIME']; ?></p>
			<p class="topicdetails"><?php echo $_topicrow_val['LAST_POST_AUTHOR_FULL']; ?>
				<a href="<?php echo $_topicrow_val['U_LAST_POST']; ?>"><?php echo (isset($this->_rootref['LAST_POST_IMG'])) ? $this->_rootref['LAST_POST_IMG'] : ''; ?></a>
			</p>
		</td>
	</tr>
<?php }} else { ?>
	<tr class="row1">
		<td align="center" colspan="3"><b class="gen"><?php echo ((isset($this->_rootref['L_NO_IMPORTANT_NEWS'])) ? $this->_rootref['L_NO_IMPORTANT_NEWS'] : ((isset($user->lang['NO_IMPORTANT_NEWS'])) ? $user->lang['NO_IMPORTANT_NEWS'] : '{ NO_IMPORTANT_NEWS }')); ?></b></td>
	</tr>
<?php } ?>

<tr>
	<th colspan="3"><?php echo ((isset($this->_rootref['L_YOUR_DETAILS'])) ? $this->_rootref['L_YOUR_DETAILS'] : ((isset($user->lang['YOUR_DETAILS'])) ? $user->lang['YOUR_DETAILS'] : '{ YOUR_DETAILS }')); ?></th>
</tr>
<tr>
	<td class="row1" colspan="3">
		<table width="100%" cellspacing="1" cellpadding="4">
		<tr> 
			<td align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>" valign="top" nowrap="nowrap"><b class="genmed"><?php echo ((isset($this->_rootref['L_JOINED'])) ? $this->_rootref['L_JOINED'] : ((isset($user->lang['JOINED'])) ? $user->lang['JOINED'] : '{ JOINED }')); ?>: </b></td>
			<td width="100%"><b class="gen"><?php echo (isset($this->_rootref['JOINED'])) ? $this->_rootref['JOINED'] : ''; ?></b></td>
		</tr>
		<tr> 
			<td align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>" valign="top" nowrap="nowrap"><b class="genmed"><?php echo ((isset($this->_rootref['L_TOTAL_POSTS'])) ? $this->_rootref['L_TOTAL_POSTS'] : ((isset($user->lang['TOTAL_POSTS'])) ? $user->lang['TOTAL_POSTS'] : '{ TOTAL_POSTS }')); ?>: </b></td>
			<td><?php if ($this->_rootref['POSTS_PCT']) {  ?><b class="gen"><?php echo (isset($this->_rootref['POSTS'])) ? $this->_rootref['POSTS'] : ''; ?></b><br /><span class="genmed">[<?php echo (isset($this->_rootref['POSTS_PCT'])) ? $this->_rootref['POSTS_PCT'] : ''; ?> / <?php echo (isset($this->_rootref['POSTS_DAY'])) ? $this->_rootref['POSTS_DAY'] : ''; ?>]<br /><a href="<?php echo (isset($this->_rootref['U_SEARCH_SELF'])) ? $this->_rootref['U_SEARCH_SELF'] : ''; ?>"><?php echo ((isset($this->_rootref['L_SEARCH_YOUR_POSTS'])) ? $this->_rootref['L_SEARCH_YOUR_POSTS'] : ((isset($user->lang['SEARCH_YOUR_POSTS'])) ? $user->lang['SEARCH_YOUR_POSTS'] : '{ SEARCH_YOUR_POSTS }')); ?></a></span><?php } else { ?><b class="gen"><?php echo (isset($this->_rootref['POSTS'])) ? $this->_rootref['POSTS'] : ''; ?><b><?php } ?></td>
		</tr>
		<?php if ($this->_rootref['S_SHOW_ACTIVITY']) {  ?>
			<tr>
				<td align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>" valign="top" nowrap="nowrap"><b class="genmed"><?php echo ((isset($this->_rootref['L_ACTIVE_IN_FORUM'])) ? $this->_rootref['L_ACTIVE_IN_FORUM'] : ((isset($user->lang['ACTIVE_IN_FORUM'])) ? $user->lang['ACTIVE_IN_FORUM'] : '{ ACTIVE_IN_FORUM }')); ?>: </b></td>
				<td><?php if ($this->_rootref['ACTIVE_FORUM']) {  ?><b><a class="gen" href="<?php echo (isset($this->_rootref['U_ACTIVE_FORUM'])) ? $this->_rootref['U_ACTIVE_FORUM'] : ''; ?>"><?php echo (isset($this->_rootref['ACTIVE_FORUM'])) ? $this->_rootref['ACTIVE_FORUM'] : ''; ?></a></b><br /><span class="genmed">[ <?php echo (isset($this->_rootref['ACTIVE_FORUM_POSTS'])) ? $this->_rootref['ACTIVE_FORUM_POSTS'] : ''; ?> / <?php echo (isset($this->_rootref['ACTIVE_FORUM_PCT'])) ? $this->_rootref['ACTIVE_FORUM_PCT'] : ''; ?> ]</span><?php } else { ?><span class="gen">-</span><?php } ?></td>
			</tr>
			<tr>
				<td align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>" valign="top" nowrap="nowrap"><b class="genmed"><?php echo ((isset($this->_rootref['L_ACTIVE_IN_TOPIC'])) ? $this->_rootref['L_ACTIVE_IN_TOPIC'] : ((isset($user->lang['ACTIVE_IN_TOPIC'])) ? $user->lang['ACTIVE_IN_TOPIC'] : '{ ACTIVE_IN_TOPIC }')); ?>: </b></td>
				<td><?php if ($this->_rootref['ACTIVE_TOPIC']) {  ?><b><a class="gen" href="<?php echo (isset($this->_rootref['U_ACTIVE_TOPIC'])) ? $this->_rootref['U_ACTIVE_TOPIC'] : ''; ?>"><?php echo (isset($this->_rootref['ACTIVE_TOPIC'])) ? $this->_rootref['ACTIVE_TOPIC'] : ''; ?></a></b><br /><span class="genmed">[ <?php echo (isset($this->_rootref['ACTIVE_TOPIC_POSTS'])) ? $this->_rootref['ACTIVE_TOPIC_POSTS'] : ''; ?> / <?php echo (isset($this->_rootref['ACTIVE_TOPIC_PCT'])) ? $this->_rootref['ACTIVE_TOPIC_PCT'] : ''; ?> ]</span><?php } else { ?><span class="gen">-</span><?php } ?></td>
			</tr>
		<?php } if ($this->_rootref['WARNINGS']) {  ?>
			<tr>
				<td align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>" valign="middle" nowrap="nowrap"><b class="genmed"><?php echo ((isset($this->_rootref['L_YOUR_WARNINGS'])) ? $this->_rootref['L_YOUR_WARNINGS'] : ((isset($user->lang['YOUR_WARNINGS'])) ? $user->lang['YOUR_WARNINGS'] : '{ YOUR_WARNINGS }')); ?>: </b></td>
				<td class="genmed"><?php echo (isset($this->_rootref['WARNING_IMG'])) ? $this->_rootref['WARNING_IMG'] : ''; ?> [ <b><?php echo (isset($this->_rootref['WARNINGS'])) ? $this->_rootref['WARNINGS'] : ''; ?></b> ]</td>
			</tr>
		<?php } ?>
		</table>
	</td>
</tr>
<tr>
	<td class="cat" colspan="3">&nbsp;</td>
</tr>
</table>

<?php $this->_tpl_include('ucp_footer.html'); ?>
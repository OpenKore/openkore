<?php if ($this->_rootref['S_IN_SEARCH_POPUP']) {  $this->_tpl_include('simple_header.html'); } else { $this->_tpl_include('overall_header.html'); } if ($this->_rootref['S_SEARCH_USER']) {  $this->_tpl_include('memberlist_search.html'); } if ($this->_rootref['S_SHOW_GROUP']) {  $this->_tpl_include('memberlist_group.html'); } if (! $this->_rootref['S_SHOW_GROUP']) {  ?>
	<form method="post" name="charsearch" action="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>">
		<table width="100%" cellspacing="1">
		<tr>
			<td align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>"><span class="genmed"><?php echo ((isset($this->_rootref['L_USERNAME_BEGINS_WITH'])) ? $this->_rootref['L_USERNAME_BEGINS_WITH'] : ((isset($user->lang['USERNAME_BEGINS_WITH'])) ? $user->lang['USERNAME_BEGINS_WITH'] : '{ USERNAME_BEGINS_WITH }')); ?>: </span><select name="first_char" onchange="this.form.submit();"><?php echo (isset($this->_rootref['S_CHAR_OPTIONS'])) ? $this->_rootref['S_CHAR_OPTIONS'] : ''; ?></select>&nbsp;<input type="submit" name="char" value="<?php echo ((isset($this->_rootref['L_DISPLAY'])) ? $this->_rootref['L_DISPLAY'] : ((isset($user->lang['DISPLAY'])) ? $user->lang['DISPLAY'] : '{ DISPLAY }')); ?>" class="btnlite" /></td>
	<?php if ($this->_rootref['U_FIND_MEMBER'] && ! $this->_rootref['S_SEARCH_USER']) {  ?>
			<td class="genmed" align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>"><a href="<?php echo (isset($this->_rootref['U_FIND_MEMBER'])) ? $this->_rootref['U_FIND_MEMBER'] : ''; ?>"><?php echo ((isset($this->_rootref['L_FIND_USERNAME'])) ? $this->_rootref['L_FIND_USERNAME'] : ((isset($user->lang['FIND_USERNAME'])) ? $user->lang['FIND_USERNAME'] : '{ FIND_USERNAME }')); ?></a></td>
	<?php } else if ($this->_rootref['S_SEARCH_USER'] && $this->_rootref['U_HIDE_FIND_MEMBER'] && ! $this->_rootref['S_IN_SEARCH_POPUP']) {  ?>
			<td class="genmed" align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>"><a href="<?php echo (isset($this->_rootref['U_HIDE_FIND_MEMBER'])) ? $this->_rootref['U_HIDE_FIND_MEMBER'] : ''; ?>"><?php echo ((isset($this->_rootref['L_HIDE_MEMBER_SEARCH'])) ? $this->_rootref['L_HIDE_MEMBER_SEARCH'] : ((isset($user->lang['HIDE_MEMBER_SEARCH'])) ? $user->lang['HIDE_MEMBER_SEARCH'] : '{ HIDE_MEMBER_SEARCH }')); ?></a></td>
	<?php } ?>
		</tr>
		</table>
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</form>
<?php } if ($this->_rootref['S_IN_SEARCH_POPUP']) {  ?>
	<form method="post" name="results" action="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>" onsubmit="insert_marked(this.user);return false">
<?php } else { ?>
	<form method="post" action="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>">
<?php } ?>
<table class="tablebg" width="100%" cellspacing="1">
<tr>
	<th nowrap="nowrap">#</th>
	<th nowrap="nowrap" width="25%" align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>"><a href="<?php echo (isset($this->_rootref['U_SORT_USERNAME'])) ? $this->_rootref['U_SORT_USERNAME'] : ''; ?>"><?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?></a></th>
	<th nowrap="nowrap" width="15%"><a href="<?php echo (isset($this->_rootref['U_SORT_JOINED'])) ? $this->_rootref['U_SORT_JOINED'] : ''; ?>"><?php echo ((isset($this->_rootref['L_JOINED'])) ? $this->_rootref['L_JOINED'] : ((isset($user->lang['JOINED'])) ? $user->lang['JOINED'] : '{ JOINED }')); ?></a></th>
	<th nowrap="nowrap" width="10%"><a href="<?php echo (isset($this->_rootref['U_SORT_POSTS'])) ? $this->_rootref['U_SORT_POSTS'] : ''; ?>"><?php echo ((isset($this->_rootref['L_POSTS'])) ? $this->_rootref['L_POSTS'] : ((isset($user->lang['POSTS'])) ? $user->lang['POSTS'] : '{ POSTS }')); ?></a></th>
	<th nowrap="nowrap" width="15%"><a href="<?php echo (isset($this->_rootref['U_SORT_RANK'])) ? $this->_rootref['U_SORT_RANK'] : ''; ?>"><?php echo ((isset($this->_rootref['L_RANK'])) ? $this->_rootref['L_RANK'] : ((isset($user->lang['RANK'])) ? $user->lang['RANK'] : '{ RANK }')); ?></a></th>
	<th nowrap="nowrap" width="11%"><?php echo ((isset($this->_rootref['L_SEND_MESSAGE'])) ? $this->_rootref['L_SEND_MESSAGE'] : ((isset($user->lang['SEND_MESSAGE'])) ? $user->lang['SEND_MESSAGE'] : '{ SEND_MESSAGE }')); ?></th>
	<th nowrap="nowrap" width="11%"><a href="<?php echo (isset($this->_rootref['U_SORT_EMAIL'])) ? $this->_rootref['U_SORT_EMAIL'] : ''; ?>"><?php echo ((isset($this->_rootref['L_EMAIL'])) ? $this->_rootref['L_EMAIL'] : ((isset($user->lang['EMAIL'])) ? $user->lang['EMAIL'] : '{ EMAIL }')); ?></a></th>
	<th nowrap="nowrap" width="11%"><a href="<?php echo (isset($this->_rootref['U_SORT_WEBSITE'])) ? $this->_rootref['U_SORT_WEBSITE'] : ''; ?>"><?php echo ((isset($this->_rootref['L_WEBSITE'])) ? $this->_rootref['L_WEBSITE'] : ((isset($user->lang['WEBSITE'])) ? $user->lang['WEBSITE'] : '{ WEBSITE }')); ?></a></th>
	<?php if ($this->_rootref['S_IN_SEARCH_POPUP'] && ! $this->_rootref['S_SELECT_SINGLE']) {  ?><th width="2%" nowrap="nowrap"><?php echo ((isset($this->_rootref['L_MARK'])) ? $this->_rootref['L_MARK'] : ((isset($user->lang['MARK'])) ? $user->lang['MARK'] : '{ MARK }')); ?></th><?php } ?>
</tr>
<?php $_memberrow_count = (isset($this->_tpldata['memberrow'])) ? sizeof($this->_tpldata['memberrow']) : 0;if ($_memberrow_count) {for ($_memberrow_i = 0; $_memberrow_i < $_memberrow_count; ++$_memberrow_i){$_memberrow_val = &$this->_tpldata['memberrow'][$_memberrow_i]; if ($this->_rootref['S_SHOW_GROUP']) {  if ($_memberrow_val['S_FIRST_ROW'] && $_memberrow_val['S_GROUP_LEADER']) {  ?>
			<tr class="row3">
				<td colspan="8"><b class="gensmall"><?php echo ((isset($this->_rootref['L_GROUP_LEADER'])) ? $this->_rootref['L_GROUP_LEADER'] : ((isset($user->lang['GROUP_LEADER'])) ? $user->lang['GROUP_LEADER'] : '{ GROUP_LEADER }')); ?></b></td>
			</tr>
		<?php } else if (! $_memberrow_val['S_GROUP_LEADER'] && ! $this->_tpldata['DEFINE']['.']['S_MEMBER_HEADER']) {  ?>
			<tr class="row3">
				<td colspan="8"><b class="gensmall"><?php echo ((isset($this->_rootref['L_GROUP_MEMBERS'])) ? $this->_rootref['L_GROUP_MEMBERS'] : ((isset($user->lang['GROUP_MEMBERS'])) ? $user->lang['GROUP_MEMBERS'] : '{ GROUP_MEMBERS }')); ?></b></td>
			</tr>
				<?php $this->_tpldata['DEFINE']['.']['S_MEMBER_HEADER'] = 1; } } if (!($_memberrow_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row2"><?php } else { ?>	<tr class="row1"><?php } ?>

		<td class="gen" align="center">&nbsp;<?php echo $_memberrow_val['ROW_NUMBER']; ?>&nbsp;</td>
		<td class="genmed" align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>"><?php echo $_memberrow_val['USERNAME_FULL']; if ($this->_rootref['S_SELECT_SINGLE']) {  ?> [&nbsp;<a href="#" onclick="insert_single('<?php echo $_memberrow_val['A_USERNAME']; ?>'); return false;"><?php echo ((isset($this->_rootref['L_SELECT'])) ? $this->_rootref['L_SELECT'] : ((isset($user->lang['SELECT'])) ? $user->lang['SELECT'] : '{ SELECT }')); ?></a>&nbsp;]<?php } ?></td>
		<td class="genmed" align="center" nowrap="nowrap">&nbsp;<?php echo $_memberrow_val['JOINED']; ?>&nbsp;</td>
		<td class="gen" align="center"><?php echo $_memberrow_val['POSTS']; ?></td>
		<td class="gen" align="center"><?php if ($_memberrow_val['RANK_IMG']) {  echo $_memberrow_val['RANK_IMG']; } else { echo $_memberrow_val['RANK_TITLE']; } ?></td>
		<td class="gen" align="center">&nbsp;<?php if ($_memberrow_val['U_PM']) {  ?><a href="<?php echo $_memberrow_val['U_PM']; ?>"><?php echo (isset($this->_rootref['PM_IMG'])) ? $this->_rootref['PM_IMG'] : ''; ?></a><?php } ?>&nbsp;</td>
		<td class="gen" align="center">&nbsp;<?php if ($_memberrow_val['U_EMAIL']) {  ?><a href="<?php echo $_memberrow_val['U_EMAIL']; ?>"><?php echo (isset($this->_rootref['EMAIL_IMG'])) ? $this->_rootref['EMAIL_IMG'] : ''; ?></a><?php } ?>&nbsp;</td>
		<td class="gen" align="center">&nbsp;<?php if ($_memberrow_val['U_WWW']) {  ?><a href="<?php echo $_memberrow_val['U_WWW']; ?>"><?php echo (isset($this->_rootref['WWW_IMG'])) ? $this->_rootref['WWW_IMG'] : ''; ?></a><?php } ?>&nbsp;</td>
		<?php if ($_memberrow_val['S_PROFILE_FIELD1']) {  ?><!-- Use a construct like this to include admin defined profile fields. Replace FIELD1 with the name of your field. -->
			<td class="gen" align="center">&nbsp;<?php echo $_memberrow_val['PROFILE_FIELD1_VALUE']; ?></td>
		<?php } if ($this->_rootref['S_IN_SEARCH_POPUP'] && ! $this->_rootref['S_SELECT_SINGLE']) {  ?><td align="center"><input type="checkbox" class="radio" name="user" value="<?php echo $_memberrow_val['USERNAME']; ?>" /></td><?php } ?>
	</tr>

<?php }} else { ?>

	<tr>
		<td class="row1" colspan="<?php if ($this->_rootref['S_IN_SEARCH_POPUP']) {  ?>9<?php } else { ?>8<?php } ?>" align="center">
			<span class="gen"><?php if ($this->_rootref['S_SHOW_GROUP']) {  echo ((isset($this->_rootref['L_NO_GROUP_MEMBERS'])) ? $this->_rootref['L_NO_GROUP_MEMBERS'] : ((isset($user->lang['NO_GROUP_MEMBERS'])) ? $user->lang['NO_GROUP_MEMBERS'] : '{ NO_GROUP_MEMBERS }')); } else { echo ((isset($this->_rootref['L_NO_MEMBERS'])) ? $this->_rootref['L_NO_MEMBERS'] : ((isset($user->lang['NO_MEMBERS'])) ? $user->lang['NO_MEMBERS'] : '{ NO_MEMBERS }')); } ?></span>
		</td>
	</tr>

<?php } ?>

<tr>
	<td class="cat" colspan="<?php if ($this->_rootref['S_IN_SEARCH_POPUP']) {  ?>9<?php } else { ?>8<?php } ?>" align="center"><?php if ($this->_rootref['S_IN_SEARCH_POPUP'] && ! $this->_rootref['S_SELECT_SINGLE']) {  ?><input class="btnlite" type="submit" value="<?php echo ((isset($this->_rootref['L_SELECT_MARKED'])) ? $this->_rootref['L_SELECT_MARKED'] : ((isset($user->lang['SELECT_MARKED'])) ? $user->lang['SELECT_MARKED'] : '{ SELECT_MARKED }')); ?>" /><?php } else { ?><span class="gensmall"><?php echo ((isset($this->_rootref['L_SELECT_SORT_METHOD'])) ? $this->_rootref['L_SELECT_SORT_METHOD'] : ((isset($user->lang['SELECT_SORT_METHOD'])) ? $user->lang['SELECT_SORT_METHOD'] : '{ SELECT_SORT_METHOD }')); ?>:</span>&nbsp;<select name="sk"><?php echo (isset($this->_rootref['S_MODE_SELECT'])) ? $this->_rootref['S_MODE_SELECT'] : ''; ?></select>&nbsp; <span class="gensmall"><?php echo ((isset($this->_rootref['L_ORDER'])) ? $this->_rootref['L_ORDER'] : ((isset($user->lang['ORDER'])) ? $user->lang['ORDER'] : '{ ORDER }')); ?></span>&nbsp;<select name="sd"><?php echo (isset($this->_rootref['S_ORDER_SELECT'])) ? $this->_rootref['S_ORDER_SELECT'] : ''; ?></select>&nbsp; <input type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" class="btnlite" /><?php } ?></td>
</tr>
</table>
<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	
</form>

<table width="100%" cellspacing="0" cellpadding="0">
<tr>
	<td class="pagination"><?php echo (isset($this->_rootref['PAGE_NUMBER'])) ? $this->_rootref['PAGE_NUMBER'] : ''; ?> [ <?php echo (isset($this->_rootref['TOTAL_USERS'])) ? $this->_rootref['TOTAL_USERS'] : ''; ?> ]</td>
	<td align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>"><?php if ($this->_rootref['S_IN_SEARCH_POPUP'] && ! $this->_rootref['S_SELECT_SINGLE']) {  ?><b class="nav"><a href="#" onclick="marklist('results', 'user', true); return false;"><?php echo ((isset($this->_rootref['L_MARK_ALL'])) ? $this->_rootref['L_MARK_ALL'] : ((isset($user->lang['MARK_ALL'])) ? $user->lang['MARK_ALL'] : '{ MARK_ALL }')); ?></a> :: <a href="#" onclick="marklist('results', 'user', false); return false;"><?php echo ((isset($this->_rootref['L_UNMARK_ALL'])) ? $this->_rootref['L_UNMARK_ALL'] : ((isset($user->lang['UNMARK_ALL'])) ? $user->lang['UNMARK_ALL'] : '{ UNMARK_ALL }')); ?></a></b><br /><?php } ?><span class="pagination"><?php $this->_tpl_include('pagination.html'); ?></span></td>
</tr>
</table>



<?php if ($this->_rootref['S_IN_SEARCH_POPUP']) {  $this->_tpl_include('simple_footer.html'); } else { ?>
	<br clear="all" />
	
	<?php $this->_tpl_include('breadcrumbs.html'); ?>
	
	<br clear="all" />
	
	<div align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>"><?php $this->_tpl_include('jumpbox.html'); ?></div>	
	<?php $this->_tpl_include('overall_footer.html'); } ?>
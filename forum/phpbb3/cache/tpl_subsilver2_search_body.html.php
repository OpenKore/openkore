<?php $this->_tpl_include('overall_header.html'); ?>

<div id="pagecontent">

	<form method="get" action="<?php echo (isset($this->_rootref['S_SEARCH_ACTION'])) ? $this->_rootref['S_SEARCH_ACTION'] : ''; ?>">
	
	<table class="tablebg" width="100%" cellspacing="1">
	<tr>
		<th colspan="4"><?php echo ((isset($this->_rootref['L_SEARCH_QUERY'])) ? $this->_rootref['L_SEARCH_QUERY'] : ((isset($user->lang['SEARCH_QUERY'])) ? $user->lang['SEARCH_QUERY'] : '{ SEARCH_QUERY }')); ?></th>
	</tr>
	<tr>
		<td class="row1" colspan="2" width="50%"><b class="genmed"><?php echo ((isset($this->_rootref['L_SEARCH_KEYWORDS'])) ? $this->_rootref['L_SEARCH_KEYWORDS'] : ((isset($user->lang['SEARCH_KEYWORDS'])) ? $user->lang['SEARCH_KEYWORDS'] : '{ SEARCH_KEYWORDS }')); ?>: </b><br /><span class="gensmall"><?php echo ((isset($this->_rootref['L_SEARCH_KEYWORDS_EXPLAIN'])) ? $this->_rootref['L_SEARCH_KEYWORDS_EXPLAIN'] : ((isset($user->lang['SEARCH_KEYWORDS_EXPLAIN'])) ? $user->lang['SEARCH_KEYWORDS_EXPLAIN'] : '{ SEARCH_KEYWORDS_EXPLAIN }')); ?></span></td>
		<td class="row2" colspan="2" valign="top"><input type="text" style="width: 300px" class="post" name="keywords" size="30" /><br /><input type="radio" class="radio" name="terms" value="all" checked="checked" /> <span class="genmed"><?php echo ((isset($this->_rootref['L_SEARCH_ALL_TERMS'])) ? $this->_rootref['L_SEARCH_ALL_TERMS'] : ((isset($user->lang['SEARCH_ALL_TERMS'])) ? $user->lang['SEARCH_ALL_TERMS'] : '{ SEARCH_ALL_TERMS }')); ?></span><br /><input type="radio" class="radio" name="terms" value="any" /> <span class="genmed"><?php echo ((isset($this->_rootref['L_SEARCH_ANY_TERMS'])) ? $this->_rootref['L_SEARCH_ANY_TERMS'] : ((isset($user->lang['SEARCH_ANY_TERMS'])) ? $user->lang['SEARCH_ANY_TERMS'] : '{ SEARCH_ANY_TERMS }')); ?></span></td>
	</tr>
	<tr>
		<td class="row1" colspan="2"><b class="genmed"><?php echo ((isset($this->_rootref['L_SEARCH_AUTHOR'])) ? $this->_rootref['L_SEARCH_AUTHOR'] : ((isset($user->lang['SEARCH_AUTHOR'])) ? $user->lang['SEARCH_AUTHOR'] : '{ SEARCH_AUTHOR }')); ?>:</b><br /><span class="gensmall"><?php echo ((isset($this->_rootref['L_SEARCH_AUTHOR_EXPLAIN'])) ? $this->_rootref['L_SEARCH_AUTHOR_EXPLAIN'] : ((isset($user->lang['SEARCH_AUTHOR_EXPLAIN'])) ? $user->lang['SEARCH_AUTHOR_EXPLAIN'] : '{ SEARCH_AUTHOR_EXPLAIN }')); ?></span></td>
		<td class="row2" colspan="2" valign="middle"><input type="text" style="width: 300px" class="post" name="author" size="30" /></td>
	</tr>
	<tr>
		<td class="row1" colspan="2"><b class="genmed"><?php echo ((isset($this->_rootref['L_SEARCH_FORUMS'])) ? $this->_rootref['L_SEARCH_FORUMS'] : ((isset($user->lang['SEARCH_FORUMS'])) ? $user->lang['SEARCH_FORUMS'] : '{ SEARCH_FORUMS }')); ?>: </b><br /><span class="gensmall"><?php echo ((isset($this->_rootref['L_SEARCH_FORUMS_EXPLAIN'])) ? $this->_rootref['L_SEARCH_FORUMS_EXPLAIN'] : ((isset($user->lang['SEARCH_FORUMS_EXPLAIN'])) ? $user->lang['SEARCH_FORUMS_EXPLAIN'] : '{ SEARCH_FORUMS_EXPLAIN }')); ?></span></td>
		<td class="row2" colspan="2"><select name="fid[]" multiple="multiple" size="5"><?php echo (isset($this->_rootref['S_FORUM_OPTIONS'])) ? $this->_rootref['S_FORUM_OPTIONS'] : ''; ?></select></td>
	</tr>
	<tr>
		<th colspan="4"><?php echo ((isset($this->_rootref['L_SEARCH_OPTIONS'])) ? $this->_rootref['L_SEARCH_OPTIONS'] : ((isset($user->lang['SEARCH_OPTIONS'])) ? $user->lang['SEARCH_OPTIONS'] : '{ SEARCH_OPTIONS }')); ?></th>
	</tr>
	<tr>
		<td class="row1" width="25%" nowrap="nowrap"><b class="genmed"><?php echo ((isset($this->_rootref['L_SEARCH_SUBFORUMS'])) ? $this->_rootref['L_SEARCH_SUBFORUMS'] : ((isset($user->lang['SEARCH_SUBFORUMS'])) ? $user->lang['SEARCH_SUBFORUMS'] : '{ SEARCH_SUBFORUMS }')); ?>: </b></td>
		<td class="row2" width="25%" nowrap="nowrap"><input type="radio" class="radio" name="sc" value="1" checked="checked" /> <span class="genmed"><?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></span>&nbsp;&nbsp;<input type="radio" class="radio" name="sc" value="0" /> <span class="genmed"><?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></span></td>
		<td class="row1" width="25%" nowrap="nowrap"><b class="genmed"><?php echo ((isset($this->_rootref['L_SEARCH_WITHIN'])) ? $this->_rootref['L_SEARCH_WITHIN'] : ((isset($user->lang['SEARCH_WITHIN'])) ? $user->lang['SEARCH_WITHIN'] : '{ SEARCH_WITHIN }')); ?>: </b></td>
		<td class="row2" width="25%" nowrap="nowrap"><input type="radio" class="radio" name="sf" value="all" checked="checked" /> <span class="genmed"><?php echo ((isset($this->_rootref['L_SEARCH_TITLE_MSG'])) ? $this->_rootref['L_SEARCH_TITLE_MSG'] : ((isset($user->lang['SEARCH_TITLE_MSG'])) ? $user->lang['SEARCH_TITLE_MSG'] : '{ SEARCH_TITLE_MSG }')); ?></span><br /><input type="radio" class="radio" name="sf" value="msgonly" /> <span class="genmed"><?php echo ((isset($this->_rootref['L_SEARCH_MSG_ONLY'])) ? $this->_rootref['L_SEARCH_MSG_ONLY'] : ((isset($user->lang['SEARCH_MSG_ONLY'])) ? $user->lang['SEARCH_MSG_ONLY'] : '{ SEARCH_MSG_ONLY }')); ?></span> <br /><input type="radio" class="radio" name="sf" value="titleonly" /> <span class="genmed"><?php echo ((isset($this->_rootref['L_SEARCH_TITLE_ONLY'])) ? $this->_rootref['L_SEARCH_TITLE_ONLY'] : ((isset($user->lang['SEARCH_TITLE_ONLY'])) ? $user->lang['SEARCH_TITLE_ONLY'] : '{ SEARCH_TITLE_ONLY }')); ?></span> <br /><input type="radio" class="radio" name="sf" value="firstpost" /> <span class="genmed"><?php echo ((isset($this->_rootref['L_SEARCH_FIRST_POST'])) ? $this->_rootref['L_SEARCH_FIRST_POST'] : ((isset($user->lang['SEARCH_FIRST_POST'])) ? $user->lang['SEARCH_FIRST_POST'] : '{ SEARCH_FIRST_POST }')); ?></span></td>
	</tr>
	<tr>
		<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_RESULT_SORT'])) ? $this->_rootref['L_RESULT_SORT'] : ((isset($user->lang['RESULT_SORT'])) ? $user->lang['RESULT_SORT'] : '{ RESULT_SORT }')); ?>: </b></td>
		<td class="row2" nowrap="nowrap"><?php echo (isset($this->_rootref['S_SELECT_SORT_KEY'])) ? $this->_rootref['S_SELECT_SORT_KEY'] : ''; ?><br /><input type="radio" class="radio" name="sd" value="a" /> <span class="genmed"><?php echo ((isset($this->_rootref['L_SORT_ASCENDING'])) ? $this->_rootref['L_SORT_ASCENDING'] : ((isset($user->lang['SORT_ASCENDING'])) ? $user->lang['SORT_ASCENDING'] : '{ SORT_ASCENDING }')); ?></span><br /><input type="radio" class="radio" name="sd" value="d" checked="checked" /> <span class="genmed"><?php echo ((isset($this->_rootref['L_SORT_DESCENDING'])) ? $this->_rootref['L_SORT_DESCENDING'] : ((isset($user->lang['SORT_DESCENDING'])) ? $user->lang['SORT_DESCENDING'] : '{ SORT_DESCENDING }')); ?></span></td>
		<td class="row1" nowrap="nowrap"><b class="genmed"><?php echo ((isset($this->_rootref['L_DISPLAY_RESULTS'])) ? $this->_rootref['L_DISPLAY_RESULTS'] : ((isset($user->lang['DISPLAY_RESULTS'])) ? $user->lang['DISPLAY_RESULTS'] : '{ DISPLAY_RESULTS }')); ?>: </b></td>
		<td class="row2" nowrap="nowrap"><input type="radio" class="radio" name="sr" value="posts" checked="checked" /> <span class="genmed"><?php echo ((isset($this->_rootref['L_POSTS'])) ? $this->_rootref['L_POSTS'] : ((isset($user->lang['POSTS'])) ? $user->lang['POSTS'] : '{ POSTS }')); ?></span>&nbsp;&nbsp;<input type="radio" class="radio" name="sr" value="topics" /> <span class="genmed"><?php echo ((isset($this->_rootref['L_TOPICS'])) ? $this->_rootref['L_TOPICS'] : ((isset($user->lang['TOPICS'])) ? $user->lang['TOPICS'] : '{ TOPICS }')); ?></span></td>
	</tr>
	<tr>
		<td class="row1" width="25%"><b class="genmed"><?php echo ((isset($this->_rootref['L_RESULT_DAYS'])) ? $this->_rootref['L_RESULT_DAYS'] : ((isset($user->lang['RESULT_DAYS'])) ? $user->lang['RESULT_DAYS'] : '{ RESULT_DAYS }')); ?>: </b></td>
		<td class="row2" width="25%" nowrap="nowrap"><?php echo (isset($this->_rootref['S_SELECT_SORT_DAYS'])) ? $this->_rootref['S_SELECT_SORT_DAYS'] : ''; ?></td>
		<td class="row1" nowrap="nowrap"><b class="genmed"><?php echo ((isset($this->_rootref['L_RETURN_FIRST'])) ? $this->_rootref['L_RETURN_FIRST'] : ((isset($user->lang['RETURN_FIRST'])) ? $user->lang['RETURN_FIRST'] : '{ RETURN_FIRST }')); ?>: </b></td>
		<td class="row2" nowrap="nowrap"><select name="ch"><?php echo (isset($this->_rootref['S_CHARACTER_OPTIONS'])) ? $this->_rootref['S_CHARACTER_OPTIONS'] : ''; ?></select> <span class="genmed"><?php echo ((isset($this->_rootref['L_POST_CHARACTERS'])) ? $this->_rootref['L_POST_CHARACTERS'] : ((isset($user->lang['POST_CHARACTERS'])) ? $user->lang['POST_CHARACTERS'] : '{ POST_CHARACTERS }')); ?></span></td>
	</tr>
	<tr>
		<td class="cat" colspan="4" align="center"><?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?><input class="btnmain" name="submit" type="submit" value="<?php echo ((isset($this->_rootref['L_SEARCH'])) ? $this->_rootref['L_SEARCH'] : ((isset($user->lang['SEARCH'])) ? $user->lang['SEARCH'] : '{ SEARCH }')); ?>" />&nbsp;&nbsp;<input class="btnlite" type="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" /></td>
	</tr>
	</table>
	
	</form>

	<br clear="all" />

	<?php if (sizeof($this->_tpldata['recentsearch'])) {  ?>
	<table class="tablebg" width="100%" cellspacing="1">
	<tr>
		<th colspan="2"><?php echo ((isset($this->_rootref['L_RECENT_SEARCHES'])) ? $this->_rootref['L_RECENT_SEARCHES'] : ((isset($user->lang['RECENT_SEARCHES'])) ? $user->lang['RECENT_SEARCHES'] : '{ RECENT_SEARCHES }')); ?></th>
	</tr>
	<?php $_recentsearch_count = (isset($this->_tpldata['recentsearch'])) ? sizeof($this->_tpldata['recentsearch']) : 0;if ($_recentsearch_count) {for ($_recentsearch_i = 0; $_recentsearch_i < $_recentsearch_count; ++$_recentsearch_i){$_recentsearch_val = &$this->_tpldata['recentsearch'][$_recentsearch_i]; if (!($_recentsearch_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row2"><?php } else { ?><tr class="row1"><?php } ?>

			<td class="genmed" style="padding: 4px;" width="70%"><a href="<?php echo $_recentsearch_val['U_KEYWORDS']; ?>"><?php echo $_recentsearch_val['KEYWORDS']; ?></a></td>
			<td class="genmed" style="padding: 4px;" width="30%" align="center"><?php echo $_recentsearch_val['TIME']; ?></td>
		</tr>
	<?php }} ?>
	</table>

	<br clear="all" />
	<?php } ?>

	</div>

	<?php $this->_tpl_include('breadcrumbs.html'); ?>

	<br clear="all" />

	<div align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>"><?php $this->_tpl_include('jumpbox.html'); ?></div>

<?php $this->_tpl_include('overall_footer.html'); ?>
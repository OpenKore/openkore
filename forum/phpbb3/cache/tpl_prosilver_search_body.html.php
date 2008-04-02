<?php $this->_tpl_include('overall_header.html'); ?>

<h2 class="solo"><?php echo ((isset($this->_rootref['L_SEARCH'])) ? $this->_rootref['L_SEARCH'] : ((isset($user->lang['SEARCH'])) ? $user->lang['SEARCH'] : '{ SEARCH }')); ?></h2>

<form method="get" action="<?php echo (isset($this->_rootref['S_SEARCH_ACTION'])) ? $this->_rootref['S_SEARCH_ACTION'] : ''; ?>">

<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>
	<h3><?php echo ((isset($this->_rootref['L_SEARCH_QUERY'])) ? $this->_rootref['L_SEARCH_QUERY'] : ((isset($user->lang['SEARCH_QUERY'])) ? $user->lang['SEARCH_QUERY'] : '{ SEARCH_QUERY }')); ?></h3>
	
	<fieldset>
	<dl>
		<dt><label for="keywords"><?php echo ((isset($this->_rootref['L_SEARCH_KEYWORDS'])) ? $this->_rootref['L_SEARCH_KEYWORDS'] : ((isset($user->lang['SEARCH_KEYWORDS'])) ? $user->lang['SEARCH_KEYWORDS'] : '{ SEARCH_KEYWORDS }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_SEARCH_KEYWORDS_EXPLAIN'])) ? $this->_rootref['L_SEARCH_KEYWORDS_EXPLAIN'] : ((isset($user->lang['SEARCH_KEYWORDS_EXPLAIN'])) ? $user->lang['SEARCH_KEYWORDS_EXPLAIN'] : '{ SEARCH_KEYWORDS_EXPLAIN }')); ?></span></dt>
		<dd><input type="text" class="inputbox" name="keywords" id="keywords" size="40" title="<?php echo ((isset($this->_rootref['L_SEARCH_KEYWORDS'])) ? $this->_rootref['L_SEARCH_KEYWORDS'] : ((isset($user->lang['SEARCH_KEYWORDS'])) ? $user->lang['SEARCH_KEYWORDS'] : '{ SEARCH_KEYWORDS }')); ?>" /></dd>
		<dd><label for="terms1"><input type="radio" name="terms" id="terms1" value="all" checked="checked" /> <?php echo ((isset($this->_rootref['L_SEARCH_ALL_TERMS'])) ? $this->_rootref['L_SEARCH_ALL_TERMS'] : ((isset($user->lang['SEARCH_ALL_TERMS'])) ? $user->lang['SEARCH_ALL_TERMS'] : '{ SEARCH_ALL_TERMS }')); ?></label></dd>
		<dd><label for="terms2"><input type="radio" name="terms" id="terms2" value="any" /> <?php echo ((isset($this->_rootref['L_SEARCH_ANY_TERMS'])) ? $this->_rootref['L_SEARCH_ANY_TERMS'] : ((isset($user->lang['SEARCH_ANY_TERMS'])) ? $user->lang['SEARCH_ANY_TERMS'] : '{ SEARCH_ANY_TERMS }')); ?></label></dd>
	</dl>
	<dl>
		<dt><label for="author"><?php echo ((isset($this->_rootref['L_SEARCH_AUTHOR'])) ? $this->_rootref['L_SEARCH_AUTHOR'] : ((isset($user->lang['SEARCH_AUTHOR'])) ? $user->lang['SEARCH_AUTHOR'] : '{ SEARCH_AUTHOR }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_SEARCH_AUTHOR_EXPLAIN'])) ? $this->_rootref['L_SEARCH_AUTHOR_EXPLAIN'] : ((isset($user->lang['SEARCH_AUTHOR_EXPLAIN'])) ? $user->lang['SEARCH_AUTHOR_EXPLAIN'] : '{ SEARCH_AUTHOR_EXPLAIN }')); ?></span></dt>
		<dd><input type="text" class="inputbox" name="author" id="author" size="40" title="<?php echo ((isset($this->_rootref['L_SEARCH_AUTHOR'])) ? $this->_rootref['L_SEARCH_AUTHOR'] : ((isset($user->lang['SEARCH_AUTHOR'])) ? $user->lang['SEARCH_AUTHOR'] : '{ SEARCH_AUTHOR }')); ?>" /></dd>
	</dl>
	</fieldset>

	<span class="corners-bottom"><span></span></span></div>
</div>

<div class="panel bg2">
	<div class="inner"><span class="corners-top"><span></span></span>

	<h3><?php echo ((isset($this->_rootref['L_SEARCH_OPTIONS'])) ? $this->_rootref['L_SEARCH_OPTIONS'] : ((isset($user->lang['SEARCH_OPTIONS'])) ? $user->lang['SEARCH_OPTIONS'] : '{ SEARCH_OPTIONS }')); ?></h3>
	
	<fieldset>
	<dl>
		<dt><label for="search_forum"><?php echo ((isset($this->_rootref['L_SEARCH_FORUMS'])) ? $this->_rootref['L_SEARCH_FORUMS'] : ((isset($user->lang['SEARCH_FORUMS'])) ? $user->lang['SEARCH_FORUMS'] : '{ SEARCH_FORUMS }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_SEARCH_FORUMS_EXPLAIN'])) ? $this->_rootref['L_SEARCH_FORUMS_EXPLAIN'] : ((isset($user->lang['SEARCH_FORUMS_EXPLAIN'])) ? $user->lang['SEARCH_FORUMS_EXPLAIN'] : '{ SEARCH_FORUMS_EXPLAIN }')); ?></span></dt>
		<dd><select name="fid[]" id="search_forum" multiple="multiple" size="8" title="<?php echo ((isset($this->_rootref['L_SEARCH_FORUMS'])) ? $this->_rootref['L_SEARCH_FORUMS'] : ((isset($user->lang['SEARCH_FORUMS'])) ? $user->lang['SEARCH_FORUMS'] : '{ SEARCH_FORUMS }')); ?>"><?php echo (isset($this->_rootref['S_FORUM_OPTIONS'])) ? $this->_rootref['S_FORUM_OPTIONS'] : ''; ?></select></dd>
	</dl>
	<dl>
		<dt><label for="search_child1"><?php echo ((isset($this->_rootref['L_SEARCH_SUBFORUMS'])) ? $this->_rootref['L_SEARCH_SUBFORUMS'] : ((isset($user->lang['SEARCH_SUBFORUMS'])) ? $user->lang['SEARCH_SUBFORUMS'] : '{ SEARCH_SUBFORUMS }')); ?>:</label></dt>
		<dd>
			<label for="search_child1"><input type="radio" name="sc" id="search_child1" value="1" checked="checked" /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label> 
			<label for="search_child2"><input type="radio" name="sc" id="search_child2" value="0" /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label>
		</dd>
	</dl>
	<dl>
		<dt><label for="sf1"><?php echo ((isset($this->_rootref['L_SEARCH_WITHIN'])) ? $this->_rootref['L_SEARCH_WITHIN'] : ((isset($user->lang['SEARCH_WITHIN'])) ? $user->lang['SEARCH_WITHIN'] : '{ SEARCH_WITHIN }')); ?>:</label></dt>
		<dd><label for="sf1"><input type="radio" name="sf" id="sf1" value="all" checked="checked" /> <?php echo ((isset($this->_rootref['L_SEARCH_TITLE_MSG'])) ? $this->_rootref['L_SEARCH_TITLE_MSG'] : ((isset($user->lang['SEARCH_TITLE_MSG'])) ? $user->lang['SEARCH_TITLE_MSG'] : '{ SEARCH_TITLE_MSG }')); ?></label></dd>
		<dd><label for="sf2"><input type="radio" name="sf" id="sf2" value="msgonly" /> <?php echo ((isset($this->_rootref['L_SEARCH_MSG_ONLY'])) ? $this->_rootref['L_SEARCH_MSG_ONLY'] : ((isset($user->lang['SEARCH_MSG_ONLY'])) ? $user->lang['SEARCH_MSG_ONLY'] : '{ SEARCH_MSG_ONLY }')); ?></label></dd>
		<dd><label for="sf3"><input type="radio" name="sf" id="sf3" value="titleonly" /> <?php echo ((isset($this->_rootref['L_SEARCH_TITLE_ONLY'])) ? $this->_rootref['L_SEARCH_TITLE_ONLY'] : ((isset($user->lang['SEARCH_TITLE_ONLY'])) ? $user->lang['SEARCH_TITLE_ONLY'] : '{ SEARCH_TITLE_ONLY }')); ?></label></dd>
		<dd><label for="sf4"><input type="radio" name="sf" id="sf4" value="firstpost" /> <?php echo ((isset($this->_rootref['L_SEARCH_FIRST_POST'])) ? $this->_rootref['L_SEARCH_FIRST_POST'] : ((isset($user->lang['SEARCH_FIRST_POST'])) ? $user->lang['SEARCH_FIRST_POST'] : '{ SEARCH_FIRST_POST }')); ?></label></dd>
	</dl>

	<hr class="dashed" />

	<dl>
		<dt><label for="show_results1"><?php echo ((isset($this->_rootref['L_DISPLAY_RESULTS'])) ? $this->_rootref['L_DISPLAY_RESULTS'] : ((isset($user->lang['DISPLAY_RESULTS'])) ? $user->lang['DISPLAY_RESULTS'] : '{ DISPLAY_RESULTS }')); ?>:</label></dt>
		<dd>
			<label for="show_results1"><input type="radio" name="sr" id="show_results1" value="posts" checked="checked" /> <?php echo ((isset($this->_rootref['L_POSTS'])) ? $this->_rootref['L_POSTS'] : ((isset($user->lang['POSTS'])) ? $user->lang['POSTS'] : '{ POSTS }')); ?></label> 
			<label for="show_results2"><input type="radio" name="sr" id="show_results2" value="topics" /> <?php echo ((isset($this->_rootref['L_TOPICS'])) ? $this->_rootref['L_TOPICS'] : ((isset($user->lang['TOPICS'])) ? $user->lang['TOPICS'] : '{ TOPICS }')); ?></label>
		</dd>
	</dl>
	<dl>
		<dt><label for="sd"><?php echo ((isset($this->_rootref['L_RESULT_SORT'])) ? $this->_rootref['L_RESULT_SORT'] : ((isset($user->lang['RESULT_SORT'])) ? $user->lang['RESULT_SORT'] : '{ RESULT_SORT }')); ?>:</label></dt>
		<dd><?php echo (isset($this->_rootref['S_SELECT_SORT_KEY'])) ? $this->_rootref['S_SELECT_SORT_KEY'] : ''; ?>&nbsp;
			<label for="sa"><input type="radio" name="sd" id="sa" value="a" /> <?php echo ((isset($this->_rootref['L_SORT_ASCENDING'])) ? $this->_rootref['L_SORT_ASCENDING'] : ((isset($user->lang['SORT_ASCENDING'])) ? $user->lang['SORT_ASCENDING'] : '{ SORT_ASCENDING }')); ?></label> 
			<label for="sd"><input type="radio" name="sd" id="sd" value="d" checked="checked" /> <?php echo ((isset($this->_rootref['L_SORT_DESCENDING'])) ? $this->_rootref['L_SORT_DESCENDING'] : ((isset($user->lang['SORT_DESCENDING'])) ? $user->lang['SORT_DESCENDING'] : '{ SORT_DESCENDING }')); ?></label>
		</dd>
	</dl>
	<dl>
		<dt><label><?php echo ((isset($this->_rootref['L_RESULT_DAYS'])) ? $this->_rootref['L_RESULT_DAYS'] : ((isset($user->lang['RESULT_DAYS'])) ? $user->lang['RESULT_DAYS'] : '{ RESULT_DAYS }')); ?>:</label></dt>
		<dd><?php echo (isset($this->_rootref['S_SELECT_SORT_DAYS'])) ? $this->_rootref['S_SELECT_SORT_DAYS'] : ''; ?></dd>
	</dl>
	<dl>
		<dt><label><?php echo ((isset($this->_rootref['L_RETURN_FIRST'])) ? $this->_rootref['L_RETURN_FIRST'] : ((isset($user->lang['RETURN_FIRST'])) ? $user->lang['RETURN_FIRST'] : '{ RETURN_FIRST }')); ?>:</label></dt>
		<dd><select name="ch" title="<?php echo ((isset($this->_rootref['L_RETURN_FIRST'])) ? $this->_rootref['L_RETURN_FIRST'] : ((isset($user->lang['RETURN_FIRST'])) ? $user->lang['RETURN_FIRST'] : '{ RETURN_FIRST }')); ?>"><?php echo (isset($this->_rootref['S_CHARACTER_OPTIONS'])) ? $this->_rootref['S_CHARACTER_OPTIONS'] : ''; ?></select> <?php echo ((isset($this->_rootref['L_POST_CHARACTERS'])) ? $this->_rootref['L_POST_CHARACTERS'] : ((isset($user->lang['POST_CHARACTERS'])) ? $user->lang['POST_CHARACTERS'] : '{ POST_CHARACTERS }')); ?></dd>
	</dl>
	</fieldset>

	<span class="corners-bottom"><span></span></span></div>
</div>

<div class="panel bg3">
	<div class="inner"><span class="corners-top"><span></span></span>

	<fieldset class="submit-buttons">
		<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?><input type="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" name="reset" class="button2" />&nbsp; 
		<input type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SEARCH'])) ? $this->_rootref['L_SEARCH'] : ((isset($user->lang['SEARCH'])) ? $user->lang['SEARCH'] : '{ SEARCH }')); ?>" class="button1" />
	</fieldset>

	<span class="corners-bottom"><span></span></span></div>
</div>

</form>

<?php if (sizeof($this->_tpldata['recentsearch'])) {  ?>
<div class="forumbg">
	<div class="inner"><span class="corners-top"><span></span></span>

	<table class="table1" cellspacing="1">
	<thead>
	<tr>
		<th colspan="2" class="name"><?php echo ((isset($this->_rootref['L_RECENT_SEARCHES'])) ? $this->_rootref['L_RECENT_SEARCHES'] : ((isset($user->lang['RECENT_SEARCHES'])) ? $user->lang['RECENT_SEARCHES'] : '{ RECENT_SEARCHES }')); ?></th>
	</tr>
	</thead>
	<tbody>
	<?php $_recentsearch_count = (isset($this->_tpldata['recentsearch'])) ? sizeof($this->_tpldata['recentsearch']) : 0;if ($_recentsearch_count) {for ($_recentsearch_i = 0; $_recentsearch_i < $_recentsearch_count; ++$_recentsearch_i){$_recentsearch_val = &$this->_tpldata['recentsearch'][$_recentsearch_i]; ?>
		<tr class="<?php if (!($_recentsearch_val['S_ROW_COUNT'] & 1)  ) {  ?>bg1<?php } else { ?>bg2<?php } ?>">
			<td><a href="<?php echo $_recentsearch_val['U_KEYWORDS']; ?>"><?php echo $_recentsearch_val['KEYWORDS']; ?></a></td>
			<td class="active"><span>&nbsp;<?php echo $_recentsearch_val['TIME']; ?></span></td>
		</tr>
	<?php }} else { ?>
		<tr class="bg1">
			<td colspan="2"><?php echo ((isset($this->_rootref['L_NO_RECENT_SEARCHES'])) ? $this->_rootref['L_NO_RECENT_SEARCHES'] : ((isset($user->lang['NO_RECENT_SEARCHES'])) ? $user->lang['NO_RECENT_SEARCHES'] : '{ NO_RECENT_SEARCHES }')); ?></td>
		</tr>
	<?php } ?>
	</tbody>
	</table>

	<span class="corners-bottom"><span></span></span></div>
</div>
<?php } $this->_tpl_include('overall_footer.html'); ?>
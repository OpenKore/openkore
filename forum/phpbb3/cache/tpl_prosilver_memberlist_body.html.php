<?php if ($this->_rootref['S_IN_SEARCH_POPUP']) {  $this->_tpl_include('simple_header.html'); $this->_tpl_include('memberlist_search.html'); ?>
	<form method="post" id="results" action="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>" onsubmit="insert_marked(this.user); return false">

<?php } else if ($this->_rootref['S_SEARCH_USER']) {  $this->_tpl_include('overall_header.html'); $this->_tpl_include('memberlist_search.html'); ?>
	<form method="post" action="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>">

<?php } else { $this->_tpl_include('overall_header.html'); ?>
	<form method="post" action="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>">

<?php } if ($this->_rootref['S_SHOW_GROUP']) {  ?>

		<h2<?php if ($this->_rootref['GROUP_COLOR']) {  ?> style="color:#<?php echo (isset($this->_rootref['GROUP_COLOR'])) ? $this->_rootref['GROUP_COLOR'] : ''; ?>;"<?php } ?>><?php echo (isset($this->_rootref['GROUP_NAME'])) ? $this->_rootref['GROUP_NAME'] : ''; ?></h2>
		<p><?php echo (isset($this->_rootref['GROUP_DESC'])) ? $this->_rootref['GROUP_DESC'] : ''; ?> <?php echo (isset($this->_rootref['GROUP_TYPE'])) ? $this->_rootref['GROUP_TYPE'] : ''; ?></p>
		<p>
			<?php if ($this->_rootref['AVATAR_IMG']) {  echo (isset($this->_rootref['AVATAR_IMG'])) ? $this->_rootref['AVATAR_IMG'] : ''; } if ($this->_rootref['RANK_IMG']) {  echo (isset($this->_rootref['RANK_IMG'])) ? $this->_rootref['RANK_IMG'] : ''; } if ($this->_rootref['GROUP_RANK']) {  echo (isset($this->_rootref['GROUP_RANK'])) ? $this->_rootref['GROUP_RANK'] : ''; } ?>
		</p>

	<?php } else { ?>
		<h2 class="solo"><?php echo (isset($this->_rootref['PAGE_TITLE'])) ? $this->_rootref['PAGE_TITLE'] : ''; if ($this->_rootref['SEARCH_WORDS']) {  ?>: <a href="<?php echo (isset($this->_rootref['U_SEARCH_WORDS'])) ? $this->_rootref['U_SEARCH_WORDS'] : ''; ?>"><?php echo (isset($this->_rootref['SEARCH_WORDS'])) ? $this->_rootref['SEARCH_WORDS'] : ''; ?></a><?php } ?></h2>

		<div class="panel">
			<div class="inner"><span class="corners-top"><span></span></span>

			<ul class="linklist">
				<li>

				<?php if ($this->_rootref['U_FIND_MEMBER'] && ! $this->_rootref['S_SEARCH_USER']) {  ?><a href="<?php echo (isset($this->_rootref['U_FIND_MEMBER'])) ? $this->_rootref['U_FIND_MEMBER'] : ''; ?>"><?php echo ((isset($this->_rootref['L_FIND_USERNAME'])) ? $this->_rootref['L_FIND_USERNAME'] : ((isset($user->lang['FIND_USERNAME'])) ? $user->lang['FIND_USERNAME'] : '{ FIND_USERNAME }')); ?></a> &bull; <?php } else if ($this->_rootref['S_SEARCH_USER'] && $this->_rootref['U_HIDE_FIND_MEMBER'] && ! $this->_rootref['S_IN_SEARCH_POPUP']) {  ?><a href="<?php echo (isset($this->_rootref['U_HIDE_FIND_MEMBER'])) ? $this->_rootref['U_HIDE_FIND_MEMBER'] : ''; ?>"><?php echo ((isset($this->_rootref['L_HIDE_MEMBER_SEARCH'])) ? $this->_rootref['L_HIDE_MEMBER_SEARCH'] : ((isset($user->lang['HIDE_MEMBER_SEARCH'])) ? $user->lang['HIDE_MEMBER_SEARCH'] : '{ HIDE_MEMBER_SEARCH }')); ?></a> &bull; <?php } ?>
				<strong style="font-size: 0.95em;"><a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char="><?php echo ((isset($this->_rootref['L_ALL'])) ? $this->_rootref['L_ALL'] : ((isset($user->lang['ALL'])) ? $user->lang['ALL'] : '{ ALL }')); ?></a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=a#memberlist">A</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=b#memberlist">B</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=c#memberlist">C</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=d#memberlist">D</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=e#memberlist">E</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=f#memberlist">F</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=g#memberlist">G</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=h#memberlist">H</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=i#memberlist">I</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=j#memberlist">J</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=k#memberlist">K</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=l#memberlist">L</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=m#memberlist">M</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=n#memberlist">N</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=o#memberlist">O</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=p#memberlist">P</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=q#memberlist">Q</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=r#memberlist">R</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=s#memberlist">S</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=t#memberlist">T</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=u#memberlist">U</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=v#memberlist">V</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=w#memberlist">W</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=x#memberlist">X</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=y#memberlist">Y</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=z#memberlist">Z</a>&nbsp; 
				<a href="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>&amp;first_char=other">#</a></strong>
				</li>
				<li class="rightside pagination">
					<?php echo (isset($this->_rootref['TOTAL_USERS'])) ? $this->_rootref['TOTAL_USERS'] : ''; ?> &bull; 
					<?php if ($this->_rootref['PAGINATION']) {  ?><a href="#" onclick="jumpto(); return false;" title="<?php echo ((isset($this->_rootref['L_JUMP_TO_PAGE'])) ? $this->_rootref['L_JUMP_TO_PAGE'] : ((isset($user->lang['JUMP_TO_PAGE'])) ? $user->lang['JUMP_TO_PAGE'] : '{ JUMP_TO_PAGE }')); ?>"><?php echo (isset($this->_rootref['PAGE_NUMBER'])) ? $this->_rootref['PAGE_NUMBER'] : ''; ?></a> &bull; <span><?php echo (isset($this->_rootref['PAGINATION'])) ? $this->_rootref['PAGINATION'] : ''; ?></span><?php } else { echo (isset($this->_rootref['PAGE_NUMBER'])) ? $this->_rootref['PAGE_NUMBER'] : ''; } ?>
				</li>
			</ul>

			<span class="corners-bottom"><span></span></span></div>
		</div>
	<?php } ?>

	<div class="forumbg forumbg-table">
		<div class="inner"><span class="corners-top"><span></span></span>

		<table class="table1" cellspacing="1" id="memberlist">
		<thead>
		<tr>
			<th class="name"><span class="rank-img"><a href="<?php echo (isset($this->_rootref['U_SORT_RANK'])) ? $this->_rootref['U_SORT_RANK'] : ''; ?>"><?php echo ((isset($this->_rootref['L_RANK'])) ? $this->_rootref['L_RANK'] : ((isset($user->lang['RANK'])) ? $user->lang['RANK'] : '{ RANK }')); ?></a></span><a href="<?php echo (isset($this->_rootref['U_SORT_USERNAME'])) ? $this->_rootref['U_SORT_USERNAME'] : ''; ?>"><?php if ($this->_rootref['S_SHOW_GROUP']) {  echo ((isset($this->_rootref['L_GROUP_LEADER'])) ? $this->_rootref['L_GROUP_LEADER'] : ((isset($user->lang['GROUP_LEADER'])) ? $user->lang['GROUP_LEADER'] : '{ GROUP_LEADER }')); } else { echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); } ?></a></th>
			<th class="posts"><a href="<?php echo (isset($this->_rootref['U_SORT_POSTS'])) ? $this->_rootref['U_SORT_POSTS'] : ''; ?>#memberlist"><?php echo ((isset($this->_rootref['L_POSTS'])) ? $this->_rootref['L_POSTS'] : ((isset($user->lang['POSTS'])) ? $user->lang['POSTS'] : '{ POSTS }')); ?></a></th>
			<th class="info"><a href="<?php echo (isset($this->_rootref['U_SORT_WEBSITE'])) ? $this->_rootref['U_SORT_WEBSITE'] : ''; ?>#memberlist"><?php echo ((isset($this->_rootref['L_WEBSITE'])) ? $this->_rootref['L_WEBSITE'] : ((isset($user->lang['WEBSITE'])) ? $user->lang['WEBSITE'] : '{ WEBSITE }')); ?></a><?php echo ((isset($this->_rootref['L_COMMA_SEPARATOR'])) ? $this->_rootref['L_COMMA_SEPARATOR'] : ((isset($user->lang['COMMA_SEPARATOR'])) ? $user->lang['COMMA_SEPARATOR'] : '{ COMMA_SEPARATOR }')); ?><a href="<?php echo (isset($this->_rootref['U_SORT_LOCATION'])) ? $this->_rootref['U_SORT_LOCATION'] : ''; ?>"><?php echo ((isset($this->_rootref['L_LOCATION'])) ? $this->_rootref['L_LOCATION'] : ((isset($user->lang['LOCATION'])) ? $user->lang['LOCATION'] : '{ LOCATION }')); ?></a></th>
			<th class="joined"><a href="<?php echo (isset($this->_rootref['U_SORT_JOINED'])) ? $this->_rootref['U_SORT_JOINED'] : ''; ?>#memberlist"><?php echo ((isset($this->_rootref['L_JOINED'])) ? $this->_rootref['L_JOINED'] : ((isset($user->lang['JOINED'])) ? $user->lang['JOINED'] : '{ JOINED }')); ?></a></th>
			<?php if ($this->_rootref['U_SORT_ACTIVE']) {  ?><th class="active"><a href="<?php echo (isset($this->_rootref['U_SORT_ACTIVE'])) ? $this->_rootref['U_SORT_ACTIVE'] : ''; ?>#memberlist"><?php echo ((isset($this->_rootref['L_LAST_ACTIVE'])) ? $this->_rootref['L_LAST_ACTIVE'] : ((isset($user->lang['LAST_ACTIVE'])) ? $user->lang['LAST_ACTIVE'] : '{ LAST_ACTIVE }')); ?></a></th><?php } ?>
		</tr>
		</thead>
		<tbody>
		<?php $_memberrow_count = (isset($this->_tpldata['memberrow'])) ? sizeof($this->_tpldata['memberrow']) : 0;if ($_memberrow_count) {for ($_memberrow_i = 0; $_memberrow_i < $_memberrow_count; ++$_memberrow_i){$_memberrow_val = &$this->_tpldata['memberrow'][$_memberrow_i]; if ($this->_rootref['S_SHOW_GROUP']) {  if (! $_memberrow_val['S_GROUP_LEADER'] && ! $this->_tpldata['DEFINE']['.']['S_MEMBER_HEADER']) {  if ($_memberrow_val['S_FIRST_ROW']) {  ?>
				<tr class="bg1">
					<td colspan="<?php if ($this->_rootref['U_SORT_ACTIVE']) {  ?>5<?php } else { ?>4<?php } ?>">&nbsp;</td>
				</tr>
				<?php } ?>
		</tbody>
		</table>

	<span class="corners-bottom"><span></span></span></div>
</div>

<div class="forumbg">
	<div class="inner"><span class="corners-top"><span></span></span>

	<table class="table1" cellspacing="1">
	<thead>
	<tr>
		<th class="name"><?php echo ((isset($this->_rootref['L_GROUP_MEMBERS'])) ? $this->_rootref['L_GROUP_MEMBERS'] : ((isset($user->lang['GROUP_MEMBERS'])) ? $user->lang['GROUP_MEMBERS'] : '{ GROUP_MEMBERS }')); ?></th>
		<th class="posts">&nbsp;</th>
		<th class="info">&nbsp;</th>
		<th class="joined">&nbsp;</th>
		<?php if ($this->_rootref['U_SORT_ACTIVE']) {  ?><th class="active">&nbsp;</th><?php } ?>
	</tr>
	</thead>
	<tbody>
					<?php $this->_tpldata['DEFINE']['.']['S_MEMBER_HEADER'] = 1; } } ?>

	<tr class="<?php if (!($_memberrow_val['S_ROW_COUNT'] & 1)  ) {  ?>bg1<?php } else { ?>bg2<?php } ?>">
		<td><?php if ($_memberrow_val['RANK_IMG']) {  ?><span class="rank-img"><?php echo $_memberrow_val['RANK_IMG']; ?></span><?php } else { ?><span class="rank-img"><?php echo $_memberrow_val['RANK_TITLE']; ?></span><?php } if ($this->_rootref['S_IN_SEARCH_POPUP'] && ! $this->_rootref['S_SELECT_SINGLE']) {  ?><input type="checkbox" name="user" value="<?php echo $_memberrow_val['USERNAME']; ?>" /> <?php } echo $_memberrow_val['USERNAME_FULL']; if ($this->_rootref['S_SELECT_SINGLE']) {  ?><br />[&nbsp;<a href="#" onclick="insert_single('<?php echo $_memberrow_val['A_USERNAME']; ?>'); return false;"><?php echo ((isset($this->_rootref['L_SELECT'])) ? $this->_rootref['L_SELECT'] : ((isset($user->lang['SELECT'])) ? $user->lang['SELECT'] : '{ SELECT }')); ?></a>&nbsp;]<?php } ?></td>
		<td class="posts"><?php if ($_memberrow_val['POSTS']) {  ?><a href="<?php echo $_memberrow_val['U_SEARCH_USER']; ?>" title="<?php echo ((isset($this->_rootref['L_SEARCH_USER_POSTS'])) ? $this->_rootref['L_SEARCH_USER_POSTS'] : ((isset($user->lang['SEARCH_USER_POSTS'])) ? $user->lang['SEARCH_USER_POSTS'] : '{ SEARCH_USER_POSTS }')); ?>"><?php echo $_memberrow_val['POSTS']; ?></a><?php } else { echo $_memberrow_val['POSTS']; } ?></td>
		<td class="info"><?php if ($_memberrow_val['U_WWW'] || $_memberrow_val['LOCATION']) {  if ($_memberrow_val['U_WWW']) {  ?><div><a href="<?php echo $_memberrow_val['U_WWW']; ?>" title="<?php echo ((isset($this->_rootref['L_VISIT_WEBSITE'])) ? $this->_rootref['L_VISIT_WEBSITE'] : ((isset($user->lang['VISIT_WEBSITE'])) ? $user->lang['VISIT_WEBSITE'] : '{ VISIT_WEBSITE }')); ?>: <?php echo $_memberrow_val['U_WWW']; ?>"><?php echo $_memberrow_val['U_WWW']; ?></a></div><?php } if ($_memberrow_val['LOCATION']) {  ?><div><?php echo $_memberrow_val['LOCATION']; ?></div><?php } } else { ?>&nbsp;<?php } ?></td>
		<td><?php echo $_memberrow_val['JOINED']; ?></td>
		<?php if ($this->_rootref['S_VIEWONLINE']) {  ?><td><?php echo $_memberrow_val['VISITED']; ?>&nbsp;</td><?php } ?>
	</tr>
		<?php }} else { ?>
	<tr class="bg1">
		<td colspan="<?php if ($this->_rootref['S_VIEWONLINE']) {  ?>5<?php } else { ?>4<?php } ?>"><?php echo ((isset($this->_rootref['L_NO_MEMBERS'])) ? $this->_rootref['L_NO_MEMBERS'] : ((isset($user->lang['NO_MEMBERS'])) ? $user->lang['NO_MEMBERS'] : '{ NO_MEMBERS }')); ?></td>
	</tr>
		<?php } ?>
	</tbody>
	</table>

	<span class="corners-bottom"><span></span></span></div>
</div>

<?php if ($this->_rootref['S_IN_SEARCH_POPUP'] && ! $this->_rootref['S_SELECT_SINGLE']) {  ?>
<fieldset class="display-actions">
	<input type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SELECT_MARKED'])) ? $this->_rootref['L_SELECT_MARKED'] : ((isset($user->lang['SELECT_MARKED'])) ? $user->lang['SELECT_MARKED'] : '{ SELECT_MARKED }')); ?>" class="button2" />
	<div><a href="#" onclick="marklist('results', 'user', true); return false;"><?php echo ((isset($this->_rootref['L_MARK_ALL'])) ? $this->_rootref['L_MARK_ALL'] : ((isset($user->lang['MARK_ALL'])) ? $user->lang['MARK_ALL'] : '{ MARK_ALL }')); ?></a> &bull; <a href="#" onclick="marklist('results', 'user', false); return false;"><?php echo ((isset($this->_rootref['L_UNMARK_ALL'])) ? $this->_rootref['L_UNMARK_ALL'] : ((isset($user->lang['UNMARK_ALL'])) ? $user->lang['UNMARK_ALL'] : '{ UNMARK_ALL }')); ?></a></div>
</fieldset>
<?php } if ($this->_rootref['S_IN_SEARCH_POPUP']) {  ?>
</form>
<form method="post" id="sort-results" action="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>">
<?php } if ($this->_rootref['S_IN_SEARCH_POPUP'] && ! $this->_rootref['S_SEARCH_USER']) {  ?>
<fieldset class="display-options">
	<?php if ($this->_rootref['PREVIOUS_PAGE']) {  ?><a href="<?php echo (isset($this->_rootref['PREVIOUS_PAGE'])) ? $this->_rootref['PREVIOUS_PAGE'] : ''; ?>" class="left-box <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>"><?php echo ((isset($this->_rootref['L_PREVIOUS'])) ? $this->_rootref['L_PREVIOUS'] : ((isset($user->lang['PREVIOUS'])) ? $user->lang['PREVIOUS'] : '{ PREVIOUS }')); ?></a><?php } if ($this->_rootref['NEXT_PAGE']) {  ?><a href="<?php echo (isset($this->_rootref['NEXT_PAGE'])) ? $this->_rootref['NEXT_PAGE'] : ''; ?>" class="right-box <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>"><?php echo ((isset($this->_rootref['L_NEXT'])) ? $this->_rootref['L_NEXT'] : ((isset($user->lang['NEXT'])) ? $user->lang['NEXT'] : '{ NEXT }')); ?></a><?php } ?>
	<label for="sk"><?php echo ((isset($this->_rootref['L_SELECT_SORT_METHOD'])) ? $this->_rootref['L_SELECT_SORT_METHOD'] : ((isset($user->lang['SELECT_SORT_METHOD'])) ? $user->lang['SELECT_SORT_METHOD'] : '{ SELECT_SORT_METHOD }')); ?>: <select name="sk" id="sk"><?php echo (isset($this->_rootref['S_MODE_SELECT'])) ? $this->_rootref['S_MODE_SELECT'] : ''; ?></select></label> 
	<label for="sd"><?php echo ((isset($this->_rootref['L_ORDER'])) ? $this->_rootref['L_ORDER'] : ((isset($user->lang['ORDER'])) ? $user->lang['ORDER'] : '{ ORDER }')); ?> <select name="sd" id="sd"><?php echo (isset($this->_rootref['S_ORDER_SELECT'])) ? $this->_rootref['S_ORDER_SELECT'] : ''; ?></select> <input type="submit" name="sort" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" class="button2" /></label>
</fieldset>
<?php } ?>

</form>

<hr />

<ul class="linklist">
	<li class="rightside pagination"><?php echo (isset($this->_rootref['TOTAL_USERS'])) ? $this->_rootref['TOTAL_USERS'] : ''; ?> &bull; <?php if ($this->_rootref['PAGINATION']) {  ?><a href="#" onclick="jumpto(); return false;" title="<?php echo ((isset($this->_rootref['L_JUMP_TO_PAGE'])) ? $this->_rootref['L_JUMP_TO_PAGE'] : ((isset($user->lang['JUMP_TO_PAGE'])) ? $user->lang['JUMP_TO_PAGE'] : '{ JUMP_TO_PAGE }')); ?>"><?php echo (isset($this->_rootref['PAGE_NUMBER'])) ? $this->_rootref['PAGE_NUMBER'] : ''; ?></a> &bull; <span><?php echo (isset($this->_rootref['PAGINATION'])) ? $this->_rootref['PAGINATION'] : ''; ?></span><?php } else { echo (isset($this->_rootref['PAGE_NUMBER'])) ? $this->_rootref['PAGE_NUMBER'] : ''; } ?></li>
</ul>

<?php if ($this->_rootref['S_IN_SEARCH_POPUP']) {  $this->_tpl_include('simple_footer.html'); } else { $this->_tpl_include('jumpbox.html'); $this->_tpl_include('overall_footer.html'); } ?>
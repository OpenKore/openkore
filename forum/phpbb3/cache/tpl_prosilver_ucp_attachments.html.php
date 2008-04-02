<?php $this->_tpl_include('ucp_header.html'); ?>

<form id="ucp" method="post" action="<?php echo (isset($this->_rootref['S_UCP_ACTION'])) ? $this->_rootref['S_UCP_ACTION'] : ''; ?>"<?php echo (isset($this->_rootref['S_FORM_ENCTYPE'])) ? $this->_rootref['S_FORM_ENCTYPE'] : ''; ?>>

<h2><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></h2>

<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>
	
	<p><?php echo ((isset($this->_rootref['L_ATTACHMENTS_EXPLAIN'])) ? $this->_rootref['L_ATTACHMENTS_EXPLAIN'] : ((isset($user->lang['ATTACHMENTS_EXPLAIN'])) ? $user->lang['ATTACHMENTS_EXPLAIN'] : '{ ATTACHMENTS_EXPLAIN }')); ?></p>

	<?php if (sizeof($this->_tpldata['attachrow'])) {  ?>
		<ul class="linklist">
			<li class="rightside pagination">
				<?php if ($this->_rootref['TOTAL_ATTACHMENTS']) {  echo (isset($this->_rootref['TOTAL_ATTACHMENTS'])) ? $this->_rootref['TOTAL_ATTACHMENTS'] : ''; ?> <?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); } if ($this->_rootref['PAGE_NUMBER']) {  if ($this->_rootref['PAGINATION']) {  ?> &bull; <a href="#" onclick="jumpto(); return false;" title="<?php echo ((isset($this->_rootref['L_JUMP_TO_PAGE'])) ? $this->_rootref['L_JUMP_TO_PAGE'] : ((isset($user->lang['JUMP_TO_PAGE'])) ? $user->lang['JUMP_TO_PAGE'] : '{ JUMP_TO_PAGE }')); ?>"><?php echo (isset($this->_rootref['PAGE_NUMBER'])) ? $this->_rootref['PAGE_NUMBER'] : ''; ?></a> &bull; <span><?php echo (isset($this->_rootref['PAGINATION'])) ? $this->_rootref['PAGINATION'] : ''; ?></span><?php } else { ?> &bull; <?php echo (isset($this->_rootref['PAGE_NUMBER'])) ? $this->_rootref['PAGE_NUMBER'] : ''; } } ?>
			</li>
		</ul>	
		
		<ul class="topiclist">
			<li class="header">
				<dl>
					<dt style="width: 40%"><a href="<?php echo (isset($this->_rootref['U_SORT_FILENAME'])) ? $this->_rootref['U_SORT_FILENAME'] : ''; ?>"><?php echo ((isset($this->_rootref['L_FILENAME'])) ? $this->_rootref['L_FILENAME'] : ((isset($user->lang['FILENAME'])) ? $user->lang['FILENAME'] : '{ FILENAME }')); ?></a></dt>
					<dd class="extra"><a href="<?php echo (isset($this->_rootref['U_SORT_DOWNLOADS'])) ? $this->_rootref['U_SORT_DOWNLOADS'] : ''; ?>"><?php echo ((isset($this->_rootref['L_DOWNLOADS'])) ? $this->_rootref['L_DOWNLOADS'] : ((isset($user->lang['DOWNLOADS'])) ? $user->lang['DOWNLOADS'] : '{ DOWNLOADS }')); ?></a></dd>
					<dd class="time"><span><a href="<?php echo (isset($this->_rootref['U_SORT_POST_TIME'])) ? $this->_rootref['U_SORT_POST_TIME'] : ''; ?>"><?php echo ((isset($this->_rootref['L_POST_TIME'])) ? $this->_rootref['L_POST_TIME'] : ((isset($user->lang['POST_TIME'])) ? $user->lang['POST_TIME'] : '{ POST_TIME }')); ?></a></span></dd>
					<dd class="mark"><?php echo ((isset($this->_rootref['L_MARK'])) ? $this->_rootref['L_MARK'] : ((isset($user->lang['MARK'])) ? $user->lang['MARK'] : '{ MARK }')); ?></dd>
				</dl>
			</li>
		</ul>
		<ul class="topiclist cplist">

		<?php $_attachrow_count = (isset($this->_tpldata['attachrow'])) ? sizeof($this->_tpldata['attachrow']) : 0;if ($_attachrow_count) {for ($_attachrow_i = 0; $_attachrow_i < $_attachrow_count; ++$_attachrow_i){$_attachrow_val = &$this->_tpldata['attachrow'][$_attachrow_i]; ?>
		<li class="row<?php if (($_attachrow_val['S_ROW_COUNT'] & 1)  ) {  ?> bg1<?php } else { ?> bg2<?php } ?>">
			<dl>
				<dt style="width: 40%"><a href="<?php echo $_attachrow_val['U_VIEW_ATTACHMENT']; ?>" class="topictitle"><?php echo $_attachrow_val['FILENAME']; ?></a> (<?php echo $_attachrow_val['SIZE']; ?>)<br />
					<?php if ($_attachrow_val['S_IN_MESSAGE']) {  echo ((isset($this->_rootref['L_PM'])) ? $this->_rootref['L_PM'] : ((isset($user->lang['PM'])) ? $user->lang['PM'] : '{ PM }')); ?>: <?php } else { echo ((isset($this->_rootref['L_TOPIC'])) ? $this->_rootref['L_TOPIC'] : ((isset($user->lang['TOPIC'])) ? $user->lang['TOPIC'] : '{ TOPIC }')); ?>: <?php } ?><a href="<?php echo $_attachrow_val['U_VIEW_TOPIC']; ?>"><?php echo $_attachrow_val['TOPIC_TITLE']; ?></a></dt>
				<dd class="extra"><?php echo $_attachrow_val['DOWNLOAD_COUNT']; ?></dd>
				<dd class="time"><span><?php echo $_attachrow_val['POST_TIME']; ?></span></dd>
				<dd class="mark"><input type="checkbox" name="attachment[<?php echo $_attachrow_val['ATTACH_ID']; ?>]" value="1" /></dd>
			</dl>
		</li>
		<?php }} ?>
		</ul>

		<fieldset class="display-options">
			<?php if ($this->_rootref['NEXT_PAGE']) {  ?><a href="<?php echo (isset($this->_rootref['NEXT_PAGE'])) ? $this->_rootref['NEXT_PAGE'] : ''; ?>" class="right-box <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>"><?php echo ((isset($this->_rootref['L_NEXT'])) ? $this->_rootref['L_NEXT'] : ((isset($user->lang['NEXT'])) ? $user->lang['NEXT'] : '{ NEXT }')); ?></a><?php } if ($this->_rootref['PREVIOUS_PAGE']) {  ?><a href="<?php echo (isset($this->_rootref['PREVIOUS_PAGE'])) ? $this->_rootref['PREVIOUS_PAGE'] : ''; ?>" class="left-box <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>"><?php echo ((isset($this->_rootref['L_PREVIOUS'])) ? $this->_rootref['L_PREVIOUS'] : ((isset($user->lang['PREVIOUS'])) ? $user->lang['PREVIOUS'] : '{ PREVIOUS }')); ?></a><?php } ?>
			<label for="sk"><?php echo ((isset($this->_rootref['L_SORT_BY'])) ? $this->_rootref['L_SORT_BY'] : ((isset($user->lang['SORT_BY'])) ? $user->lang['SORT_BY'] : '{ SORT_BY }')); ?>: <select name="sk" id="sk"><?php echo (isset($this->_rootref['S_SORT_OPTIONS'])) ? $this->_rootref['S_SORT_OPTIONS'] : ''; ?></select></label> 
			<label><select name="sd" id="sd"><?php echo (isset($this->_rootref['S_ORDER_SELECT'])) ? $this->_rootref['S_ORDER_SELECT'] : ''; ?></select></label>
			<input class="button2" type="submit" name="sort" value="<?php echo ((isset($this->_rootref['L_SORT'])) ? $this->_rootref['L_SORT'] : ((isset($user->lang['SORT'])) ? $user->lang['SORT'] : '{ SORT }')); ?>" />
			<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
		</fieldset>

		<hr />
		
		<ul class="linklist">
			<li class="rightside pagination">
				<?php if ($this->_rootref['TOTAL_ATTACHMENTS']) {  echo (isset($this->_rootref['TOTAL_ATTACHMENTS'])) ? $this->_rootref['TOTAL_ATTACHMENTS'] : ''; ?> <?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); } if ($this->_rootref['PAGE_NUMBER']) {  if ($this->_rootref['PAGINATION']) {  ?> &bull; <a href="#" onclick="jumpto(); return false;" title="<?php echo ((isset($this->_rootref['L_JUMP_TO_PAGE'])) ? $this->_rootref['L_JUMP_TO_PAGE'] : ((isset($user->lang['JUMP_TO_PAGE'])) ? $user->lang['JUMP_TO_PAGE'] : '{ JUMP_TO_PAGE }')); ?>"><?php echo (isset($this->_rootref['PAGE_NUMBER'])) ? $this->_rootref['PAGE_NUMBER'] : ''; ?></a> &bull; <span><?php echo (isset($this->_rootref['PAGINATION'])) ? $this->_rootref['PAGINATION'] : ''; ?></span><?php } else { ?> &bull; <?php echo (isset($this->_rootref['PAGE_NUMBER'])) ? $this->_rootref['PAGE_NUMBER'] : ''; } } ?>
			</li>
		</ul>
	<?php } else { ?>
		<p><strong><?php echo ((isset($this->_rootref['L_UCP_NO_ATTACHMENTS'])) ? $this->_rootref['L_UCP_NO_ATTACHMENTS'] : ((isset($user->lang['UCP_NO_ATTACHMENTS'])) ? $user->lang['UCP_NO_ATTACHMENTS'] : '{ UCP_NO_ATTACHMENTS }')); ?></strong></p>
	<?php } ?>

	<span class="corners-bottom"><span></span></span></div>
</div>
	
<?php if ($this->_rootref['S_ATTACHMENT_ROWS']) {  ?>
	<fieldset class="display-actions">	
		<input class="button2" type="submit" name="delete" value="<?php echo ((isset($this->_rootref['L_DELETE_MARKED'])) ? $this->_rootref['L_DELETE_MARKED'] : ((isset($user->lang['DELETE_MARKED'])) ? $user->lang['DELETE_MARKED'] : '{ DELETE_MARKED }')); ?>" />
		<div><a href="#" onclick="marklist('ucp', 'attachment', true); return false;"><?php echo ((isset($this->_rootref['L_MARK_ALL'])) ? $this->_rootref['L_MARK_ALL'] : ((isset($user->lang['MARK_ALL'])) ? $user->lang['MARK_ALL'] : '{ MARK_ALL }')); ?></a> &bull; <a href="#" onclick="marklist('ucp', 'attachment', false); return false;"><?php echo ((isset($this->_rootref['L_UNMARK_ALL'])) ? $this->_rootref['L_UNMARK_ALL'] : ((isset($user->lang['UNMARK_ALL'])) ? $user->lang['UNMARK_ALL'] : '{ UNMARK_ALL }')); ?></a></div>
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
<?php } ?>
</form>

<?php $this->_tpl_include('ucp_footer.html'); ?>
<?php $this->_tpl_include('ucp_header.html'); ?>

<form id="postform" method="post" action="<?php echo (isset($this->_rootref['S_UCP_ACTION'])) ? $this->_rootref['S_UCP_ACTION'] : ''; ?>"<?php echo (isset($this->_rootref['S_FORM_ENCTYPE'])) ? $this->_rootref['S_FORM_ENCTYPE'] : ''; ?>>

<h2><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></h2>

<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>

	<p><?php echo ((isset($this->_rootref['L_DRAFTS_EXPLAIN'])) ? $this->_rootref['L_DRAFTS_EXPLAIN'] : ((isset($user->lang['DRAFTS_EXPLAIN'])) ? $user->lang['DRAFTS_EXPLAIN'] : '{ DRAFTS_EXPLAIN }')); ?></p>

<?php if ($this->_rootref['S_EDIT_DRAFT']) {  $this->_tpl_include('posting_editor.html'); ?>
		<span class="corners-bottom"><span></span></span></div>
	</div>

			<fieldset class="submit-buttons">
				<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?><input type="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" name="reset" class="button2" />&nbsp;
				<input type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SAVE'])) ? $this->_rootref['L_SAVE'] : ((isset($user->lang['SAVE'])) ? $user->lang['SAVE'] : '{ SAVE }')); ?>" class="button1" />
				<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
			</fieldset>

<?php } else { if (sizeof($this->_tpldata['draftrow'])) {  ?>
		<ul class="topiclist">
			<li class="header">
				<dl>
					<dt><?php echo ((isset($this->_rootref['L_DRAFT_TITLE'])) ? $this->_rootref['L_DRAFT_TITLE'] : ((isset($user->lang['DRAFT_TITLE'])) ? $user->lang['DRAFT_TITLE'] : '{ DRAFT_TITLE }')); ?></dt>
					<dd class="info"><span><?php echo ((isset($this->_rootref['L_SAVE_DATE'])) ? $this->_rootref['L_SAVE_DATE'] : ((isset($user->lang['SAVE_DATE'])) ? $user->lang['SAVE_DATE'] : '{ SAVE_DATE }')); ?></span></dd>
					<dd class="mark"><?php echo ((isset($this->_rootref['L_MARK'])) ? $this->_rootref['L_MARK'] : ((isset($user->lang['MARK'])) ? $user->lang['MARK'] : '{ MARK }')); ?></dd>
				</dl>
			</li>
		</ul>
		<ul class="topiclist cplist">

		<?php $_draftrow_count = (isset($this->_tpldata['draftrow'])) ? sizeof($this->_tpldata['draftrow']) : 0;if ($_draftrow_count) {for ($_draftrow_i = 0; $_draftrow_i < $_draftrow_count; ++$_draftrow_i){$_draftrow_val = &$this->_tpldata['draftrow'][$_draftrow_i]; ?>
			<li class="row<?php if (($_draftrow_val['S_ROW_COUNT'] & 1)  ) {  ?> bg1<?php } else { ?> bg2<?php } ?>">
				<dl>
					<dt>
						<a class="topictitle" href="<?php echo $_draftrow_val['U_VIEW_EDIT']; ?>"><?php echo $_draftrow_val['DRAFT_SUBJECT']; ?></a><br />
						<?php if ($_draftrow_val['S_LINK_TOPIC']) {  echo ((isset($this->_rootref['L_TOPIC'])) ? $this->_rootref['L_TOPIC'] : ((isset($user->lang['TOPIC'])) ? $user->lang['TOPIC'] : '{ TOPIC }')); ?>: <a href="<?php echo $_draftrow_val['U_VIEW']; ?>"><?php echo $_draftrow_val['TITLE']; ?></a>
						<?php } else if ($_draftrow_val['S_LINK_FORUM']) {  echo ((isset($this->_rootref['L_FORUM'])) ? $this->_rootref['L_FORUM'] : ((isset($user->lang['FORUM'])) ? $user->lang['FORUM'] : '{ FORUM }')); ?>: <a href="<?php echo $_draftrow_val['U_VIEW']; ?>"><?php echo $_draftrow_val['TITLE']; ?></a>
						<?php } else if ($this->_rootref['S_PRIVMSGS']) {  } else { echo ((isset($this->_rootref['L_NO_TOPIC_FORUM'])) ? $this->_rootref['L_NO_TOPIC_FORUM'] : ((isset($user->lang['NO_TOPIC_FORUM'])) ? $user->lang['NO_TOPIC_FORUM'] : '{ NO_TOPIC_FORUM }')); } ?>
					</dt>
					<dd class="info"><span><?php echo $_draftrow_val['DATE']; ?><br /><?php if ($_draftrow_val['U_INSERT']) {  ?><a href="<?php echo $_draftrow_val['U_INSERT']; ?>"><?php echo ((isset($this->_rootref['L_LOAD_DRAFT'])) ? $this->_rootref['L_LOAD_DRAFT'] : ((isset($user->lang['LOAD_DRAFT'])) ? $user->lang['LOAD_DRAFT'] : '{ LOAD_DRAFT }')); ?></a> &bull; <?php } ?><a href="<?php echo $_draftrow_val['U_VIEW_EDIT']; ?>"><?php echo ((isset($this->_rootref['L_VIEW_EDIT'])) ? $this->_rootref['L_VIEW_EDIT'] : ((isset($user->lang['VIEW_EDIT'])) ? $user->lang['VIEW_EDIT'] : '{ VIEW_EDIT }')); ?></a></span></dd>
					<dd class="mark"><input type="checkbox" name="d[<?php echo $_draftrow_val['DRAFT_ID']; ?>]" id="d<?php echo $_draftrow_val['DRAFT_ID']; ?>" /></dd>
				</dl>
			</li>
		<?php }} ?>
		</ul>
	<?php } else { ?>
		<p><strong><?php echo ((isset($this->_rootref['L_NO_SAVED_DRAFTS'])) ? $this->_rootref['L_NO_SAVED_DRAFTS'] : ((isset($user->lang['NO_SAVED_DRAFTS'])) ? $user->lang['NO_SAVED_DRAFTS'] : '{ NO_SAVED_DRAFTS }')); ?></strong></p>
	<?php } ?>

		<span class="corners-bottom"><span></span></span></div>
	</div>

	<?php if (sizeof($this->_tpldata['draftrow'])) {  ?>
		<fieldset class="display-actions">
			<input class="button2" type="submit" name="delete" value="<?php echo ((isset($this->_rootref['L_DELETE_MARKED'])) ? $this->_rootref['L_DELETE_MARKED'] : ((isset($user->lang['DELETE_MARKED'])) ? $user->lang['DELETE_MARKED'] : '{ DELETE_MARKED }')); ?>" />
			<div><a href="#" onclick="marklist('postform', '', true); return false;"><?php echo ((isset($this->_rootref['L_MARK_ALL'])) ? $this->_rootref['L_MARK_ALL'] : ((isset($user->lang['MARK_ALL'])) ? $user->lang['MARK_ALL'] : '{ MARK_ALL }')); ?></a> &bull; <a href="#" onclick="marklist('postform', '', false); return false;"><?php echo ((isset($this->_rootref['L_UNMARK_ALL'])) ? $this->_rootref['L_UNMARK_ALL'] : ((isset($user->lang['UNMARK_ALL'])) ? $user->lang['UNMARK_ALL'] : '{ UNMARK_ALL }')); ?></a></div>
			<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
		</fieldset>
	<?php } } ?>

</form>

<?php $this->_tpl_include('ucp_footer.html'); ?>
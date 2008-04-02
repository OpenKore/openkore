<h3><?php echo ((isset($this->_rootref['L_POST_REVIEW'])) ? $this->_rootref['L_POST_REVIEW'] : ((isset($user->lang['POST_REVIEW'])) ? $user->lang['POST_REVIEW'] : '{ POST_REVIEW }')); ?></h3>

<p><?php echo ((isset($this->_rootref['L_POST_REVIEW_EXPLAIN'])) ? $this->_rootref['L_POST_REVIEW_EXPLAIN'] : ((isset($user->lang['POST_REVIEW_EXPLAIN'])) ? $user->lang['POST_REVIEW_EXPLAIN'] : '{ POST_REVIEW_EXPLAIN }')); ?></p>

<?php $_post_review_row_count = (isset($this->_tpldata['post_review_row'])) ? sizeof($this->_tpldata['post_review_row']) : 0;if ($_post_review_row_count) {for ($_post_review_row_i = 0; $_post_review_row_i < $_post_review_row_count; ++$_post_review_row_i){$_post_review_row_val = &$this->_tpldata['post_review_row'][$_post_review_row_i]; ?>
<div id="ppr<?php echo $_post_review_row_val['POST_ID']; ?>" class="post <?php if (($_post_review_row_val['S_ROW_COUNT'] & 1)  ) {  ?>bg1<?php } else { ?>bg2<?php } if ($_post_review_row_val['ONLINE_STATUS']) {  ?> online<?php } ?>">
	<div class="inner"><span class="corners-top"><span></span></span>
	
	<div class="postbody">
		<h3><a href="#ppr<?php echo $_post_review_row_val['POST_ID']; ?>"><?php echo $_post_review_row_val['POST_SUBJECT']; ?></a></h3>
		<p class="author"><?php if ($this->_rootref['S_IS_BOT']) {  echo $_post_review_row_val['MINI_POST_IMG']; } else { ?><a href="<?php echo $_post_review_row_val['U_MINI_POST']; ?>"><?php echo $_post_review_row_val['MINI_POST_IMG']; ?></a><?php } ?> <?php echo ((isset($this->_rootref['L_POST_BY_AUTHOR'])) ? $this->_rootref['L_POST_BY_AUTHOR'] : ((isset($user->lang['POST_BY_AUTHOR'])) ? $user->lang['POST_BY_AUTHOR'] : '{ POST_BY_AUTHOR }')); ?><strong>  <?php echo $_post_review_row_val['POST_AUTHOR_FULL']; ?></strong> <?php echo ((isset($this->_rootref['L_POSTED_ON_DATE'])) ? $this->_rootref['L_POSTED_ON_DATE'] : ((isset($user->lang['POSTED_ON_DATE'])) ? $user->lang['POSTED_ON_DATE'] : '{ POSTED_ON_DATE }')); ?> <?php echo $_post_review_row_val['POST_DATE']; ?></p>
		<div class="content"><?php echo $_post_review_row_val['MESSAGE']; ?></div>

		<?php if ($_post_review_row_val['S_HAS_ATTACHMENTS']) {  ?>
			<dl class="attachbox">
				<dt><?php echo ((isset($this->_rootref['L_ATTACHMENTS'])) ? $this->_rootref['L_ATTACHMENTS'] : ((isset($user->lang['ATTACHMENTS'])) ? $user->lang['ATTACHMENTS'] : '{ ATTACHMENTS }')); ?></dt>
				<?php $_attachment_count = (isset($_post_review_row_val['attachment'])) ? sizeof($_post_review_row_val['attachment']) : 0;if ($_attachment_count) {for ($_attachment_i = 0; $_attachment_i < $_attachment_count; ++$_attachment_i){$_attachment_val = &$_post_review_row_val['attachment'][$_attachment_i]; ?>
					<dd><?php echo $_attachment_val['DISPLAY_ATTACHMENT']; ?></dd>
				<?php }} ?>
			</dl>
		<?php } ?>

	</div>
	
	<span class="corners-bottom"><span></span></span></div>
</div>
<?php }} ?>

<hr />
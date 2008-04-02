<h3 id="review">
	<span class="right-box"><a href="#review" onclick="viewableArea(getElementById('topicreview'), true); var rev_text = getElementById('review').getElementsByTagName('a').item(0).firstChild; if (rev_text.data == '<?php echo ((isset($this->_rootref['LA_EXPAND_VIEW'])) ? $this->_rootref['LA_EXPAND_VIEW'] : ((isset($this->_rootref['L_EXPAND_VIEW'])) ? addslashes($this->_rootref['L_EXPAND_VIEW']) : ((isset($user->lang['EXPAND_VIEW'])) ? addslashes($user->lang['EXPAND_VIEW']) : '{ EXPAND_VIEW }'))); ?>'){rev_text.data = '<?php echo ((isset($this->_rootref['LA_COLLAPSE_VIEW'])) ? $this->_rootref['LA_COLLAPSE_VIEW'] : ((isset($this->_rootref['L_COLLAPSE_VIEW'])) ? addslashes($this->_rootref['L_COLLAPSE_VIEW']) : ((isset($user->lang['COLLAPSE_VIEW'])) ? addslashes($user->lang['COLLAPSE_VIEW']) : '{ COLLAPSE_VIEW }'))); ?>'; } else if (rev_text.data == '<?php echo ((isset($this->_rootref['LA_COLLAPSE_VIEW'])) ? $this->_rootref['LA_COLLAPSE_VIEW'] : ((isset($this->_rootref['L_COLLAPSE_VIEW'])) ? addslashes($this->_rootref['L_COLLAPSE_VIEW']) : ((isset($user->lang['COLLAPSE_VIEW'])) ? addslashes($user->lang['COLLAPSE_VIEW']) : '{ COLLAPSE_VIEW }'))); ?>'){rev_text.data = '<?php echo ((isset($this->_rootref['LA_EXPAND_VIEW'])) ? $this->_rootref['LA_EXPAND_VIEW'] : ((isset($this->_rootref['L_EXPAND_VIEW'])) ? addslashes($this->_rootref['L_EXPAND_VIEW']) : ((isset($user->lang['EXPAND_VIEW'])) ? addslashes($user->lang['EXPAND_VIEW']) : '{ EXPAND_VIEW }'))); ?>'};"><?php echo ((isset($this->_rootref['L_EXPAND_VIEW'])) ? $this->_rootref['L_EXPAND_VIEW'] : ((isset($user->lang['EXPAND_VIEW'])) ? $user->lang['EXPAND_VIEW'] : '{ EXPAND_VIEW }')); ?></a></span>
	<?php echo ((isset($this->_rootref['L_TOPIC_REVIEW'])) ? $this->_rootref['L_TOPIC_REVIEW'] : ((isset($user->lang['TOPIC_REVIEW'])) ? $user->lang['TOPIC_REVIEW'] : '{ TOPIC_REVIEW }')); ?>: <?php echo (isset($this->_rootref['TOPIC_TITLE'])) ? $this->_rootref['TOPIC_TITLE'] : ''; ?>
</h3>

<div id="topicreview">
	<?php $_topic_review_row_count = (isset($this->_tpldata['topic_review_row'])) ? sizeof($this->_tpldata['topic_review_row']) : 0;if ($_topic_review_row_count) {for ($_topic_review_row_i = 0; $_topic_review_row_i < $_topic_review_row_count; ++$_topic_review_row_i){$_topic_review_row_val = &$this->_tpldata['topic_review_row'][$_topic_review_row_i]; ?>
	<div class="post <?php if (($_topic_review_row_val['S_ROW_COUNT'] & 1)  ) {  ?>bg1<?php } else { ?>bg2<?php } ?>">
		<div class="inner"><span class="corners-top"><span></span></span>
		
		<div class="postbody" id="pr<?php echo $_topic_review_row_val['POST_ID']; ?>">
			<?php if ($_topic_review_row_val['POSTER_QUOTE'] && $_topic_review_row_val['DECODED_MESSAGE']) {  ?>
			<ul class="profile-icons">
				<li class="quote-icon"><a href="#postingbox" onclick="addquote(<?php echo $_topic_review_row_val['POST_ID']; ?>, '<?php echo $_topic_review_row_val['POSTER_QUOTE']; ?>');" title="<?php echo ((isset($this->_rootref['L_QUOTE'])) ? $this->_rootref['L_QUOTE'] : ((isset($user->lang['QUOTE'])) ? $user->lang['QUOTE'] : '{ QUOTE }')); ?> <?php echo $_topic_review_row_val['POST_AUTHOR']; ?>"><span><?php echo ((isset($this->_rootref['L_QUOTE'])) ? $this->_rootref['L_QUOTE'] : ((isset($user->lang['QUOTE'])) ? $user->lang['QUOTE'] : '{ QUOTE }')); ?> <?php echo $_topic_review_row_val['POST_AUTHOR']; ?></span></a></li>
			</ul>
			<?php } if ($_topic_review_row_val['U_MCP_DETAILS']) {  ?><div class="right-box"><a href="<?php echo $_topic_review_row_val['U_MCP_DETAILS']; ?>"><?php echo ((isset($this->_rootref['L_POST_DETAILS'])) ? $this->_rootref['L_POST_DETAILS'] : ((isset($user->lang['POST_DETAILS'])) ? $user->lang['POST_DETAILS'] : '{ POST_DETAILS }')); ?></a></div><?php } ?>
			<h3><a href="#pr<?php echo $_topic_review_row_val['POST_ID']; ?>"><?php echo $_topic_review_row_val['POST_SUBJECT']; ?></a></h3>
			<p class="author"><?php if ($this->_rootref['S_IS_BOT']) {  echo $_topic_review_row_val['MINI_POST_IMG']; } else { ?><a href="<?php echo $_topic_review_row_val['U_MINI_POST']; ?>"><?php echo $_topic_review_row_val['MINI_POST_IMG']; ?></a><?php } ?> <?php echo ((isset($this->_rootref['L_POST_BY_AUTHOR'])) ? $this->_rootref['L_POST_BY_AUTHOR'] : ((isset($user->lang['POST_BY_AUTHOR'])) ? $user->lang['POST_BY_AUTHOR'] : '{ POST_BY_AUTHOR }')); ?> <strong><?php echo $_topic_review_row_val['POST_AUTHOR_FULL']; ?></strong> <?php echo ((isset($this->_rootref['L_POSTED_ON_DATE'])) ? $this->_rootref['L_POSTED_ON_DATE'] : ((isset($user->lang['POSTED_ON_DATE'])) ? $user->lang['POSTED_ON_DATE'] : '{ POSTED_ON_DATE }')); ?> <?php echo $_topic_review_row_val['POST_DATE']; ?>  </p>
			<div class="content"><?php echo $_topic_review_row_val['MESSAGE']; ?></div>

			<?php if ($_topic_review_row_val['S_HAS_ATTACHMENTS']) {  ?>
				<dl class="attachbox">
					<dt><?php echo ((isset($this->_rootref['L_ATTACHMENTS'])) ? $this->_rootref['L_ATTACHMENTS'] : ((isset($user->lang['ATTACHMENTS'])) ? $user->lang['ATTACHMENTS'] : '{ ATTACHMENTS }')); ?></dt>
					<?php $_attachment_count = (isset($_topic_review_row_val['attachment'])) ? sizeof($_topic_review_row_val['attachment']) : 0;if ($_attachment_count) {for ($_attachment_i = 0; $_attachment_i < $_attachment_count; ++$_attachment_i){$_attachment_val = &$_topic_review_row_val['attachment'][$_attachment_i]; ?>
						<dd><?php echo $_attachment_val['DISPLAY_ATTACHMENT']; ?></dd>
					<?php }} ?>
				</dl>
			<?php } if ($_topic_review_row_val['POSTER_QUOTE'] && $_topic_review_row_val['DECODED_MESSAGE']) {  ?>
				<div id="message_<?php echo $_topic_review_row_val['POST_ID']; ?>" style="display: none;"><?php echo $_topic_review_row_val['DECODED_MESSAGE']; ?></div>
			<?php } ?>
		</div>
		<span class="corners-bottom"><span></span></span></div>
	</div>
	<?php }} ?>
</div>

<hr />

<?php if ($this->_rootref['S_MCP_REPORT']) {  ?>
	<p><a href="#report" class="top2"><?php echo ((isset($this->_rootref['L_BACK_TO_TOP'])) ? $this->_rootref['L_BACK_TO_TOP'] : ((isset($user->lang['BACK_TO_TOP'])) ? $user->lang['BACK_TO_TOP'] : '{ BACK_TO_TOP }')); ?></a></p>
<?php } else { ?>
	<p><a href="#postingbox" class="top2"><?php echo ((isset($this->_rootref['L_BACK_TO_TOP'])) ? $this->_rootref['L_BACK_TO_TOP'] : ((isset($user->lang['BACK_TO_TOP'])) ? $user->lang['BACK_TO_TOP'] : '{ BACK_TO_TOP }')); ?></a></p>
<?php } ?>
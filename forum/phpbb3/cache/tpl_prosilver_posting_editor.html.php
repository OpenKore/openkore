<fieldset class="fields1">
	<?php if ($this->_rootref['ERROR']) {  ?><p class="error"><?php echo (isset($this->_rootref['ERROR'])) ? $this->_rootref['ERROR'] : ''; ?></p><?php } if ($this->_rootref['S_PRIVMSGS'] && ! $this->_rootref['S_SHOW_DRAFTS']) {  ?>

		<div class="column1">
		<?php if ($this->_rootref['S_ALLOW_MASS_PM']) {  if (sizeof($this->_tpldata['to_recipient'])) {  ?>
				<dl>
					<dt><label><?php echo ((isset($this->_rootref['L_TO'])) ? $this->_rootref['L_TO'] : ((isset($user->lang['TO'])) ? $user->lang['TO'] : '{ TO }')); ?>:</label></dt>
					<dd>
						<?php $_to_recipient_count = (isset($this->_tpldata['to_recipient'])) ? sizeof($this->_tpldata['to_recipient']) : 0;if ($_to_recipient_count) {for ($_to_recipient_i = 0; $_to_recipient_i < $_to_recipient_count; ++$_to_recipient_i){$_to_recipient_val = &$this->_tpldata['to_recipient'][$_to_recipient_i]; if (! $_to_recipient_val['S_FIRST_ROW'] && $_to_recipient_val['S_ROW_COUNT'] % 2 == 0) {  ?></dd><dd><?php } if ($_to_recipient_val['IS_GROUP']) {  ?><a href="<?php echo $_to_recipient_val['U_VIEW']; ?>"><strong><?php echo $_to_recipient_val['NAME']; ?></strong></a>&nbsp;<?php } else { echo $_to_recipient_val['NAME_FULL']; ?>&nbsp;<?php } if (! $this->_rootref['S_EDIT_POST']) {  ?><input type="submit" name="remove_<?php echo $_to_recipient_val['TYPE']; ?>[<?php echo $_to_recipient_val['UG_ID']; ?>]" value="x" class="button2" />&nbsp;<?php } }} ?>
					</dd>
				</dl>
			<?php } if (sizeof($this->_tpldata['bcc_recipient'])) {  ?>
				<dl>
					<dt><label><?php echo ((isset($this->_rootref['L_BCC'])) ? $this->_rootref['L_BCC'] : ((isset($user->lang['BCC'])) ? $user->lang['BCC'] : '{ BCC }')); ?>:</label></dt>
					<dd>
						<?php $_bcc_recipient_count = (isset($this->_tpldata['bcc_recipient'])) ? sizeof($this->_tpldata['bcc_recipient']) : 0;if ($_bcc_recipient_count) {for ($_bcc_recipient_i = 0; $_bcc_recipient_i < $_bcc_recipient_count; ++$_bcc_recipient_i){$_bcc_recipient_val = &$this->_tpldata['bcc_recipient'][$_bcc_recipient_i]; if (! $_bcc_recipient_val['S_FIRST_ROW'] && $_bcc_recipient_val['S_ROW_COUNT'] % 2 == 0) {  ?></dd><dd><?php } if ($_bcc_recipient_val['IS_GROUP']) {  ?><a href="<?php echo $_bcc_recipient_val['U_VIEW']; ?>"><strong><?php echo $_bcc_recipient_val['NAME']; ?></strong></a><?php } else { echo $_bcc_recipient_val['NAME_FULL']; ?>&nbsp;<?php } if (! $this->_rootref['S_EDIT_POST']) {  ?><input type="submit" name="remove_<?php echo $_bcc_recipient_val['TYPE']; ?>[<?php echo $_bcc_recipient_val['UG_ID']; ?>]" value="x" class="button2" />&nbsp;<?php } }} ?>
					</dd>
				</dl>
			<?php } ?>
			<dl class="pmlist">
				<dt><textarea id="username_list" name="username_list" class="inputbox" cols="50" rows="2"></textarea></dt>
				<dd><span><a href="<?php echo (isset($this->_rootref['U_FIND_USERNAME'])) ? $this->_rootref['U_FIND_USERNAME'] : ''; ?>" onclick="find_username(this.href); return false;"><?php echo ((isset($this->_rootref['L_FIND_USERNAME'])) ? $this->_rootref['L_FIND_USERNAME'] : ((isset($user->lang['FIND_USERNAME'])) ? $user->lang['FIND_USERNAME'] : '{ FIND_USERNAME }')); ?></a></span></dd>
				<dd><input type="submit" name="add_to" value="<?php echo ((isset($this->_rootref['L_ADD'])) ? $this->_rootref['L_ADD'] : ((isset($user->lang['ADD'])) ? $user->lang['ADD'] : '{ ADD }')); ?>" class="button2" /></dd>
				<dd><input type="submit" name="add_bcc" value="<?php echo ((isset($this->_rootref['L_ADD_BCC'])) ? $this->_rootref['L_ADD_BCC'] : ((isset($user->lang['ADD_BCC'])) ? $user->lang['ADD_BCC'] : '{ ADD_BCC }')); ?>" class="button2" /></dd>
			</dl>
		<?php } else { ?>
			<dl>
				<dt><label for="username_list"><?php echo ((isset($this->_rootref['L_TO'])) ? $this->_rootref['L_TO'] : ((isset($user->lang['TO'])) ? $user->lang['TO'] : '{ TO }')); ?>:</label><br /><span><a href="<?php echo (isset($this->_rootref['U_FIND_USERNAME'])) ? $this->_rootref['U_FIND_USERNAME'] : ''; ?>" onclick="find_username(this.href); return false"><?php echo ((isset($this->_rootref['L_FIND_USERNAME'])) ? $this->_rootref['L_FIND_USERNAME'] : ((isset($user->lang['FIND_USERNAME'])) ? $user->lang['FIND_USERNAME'] : '{ FIND_USERNAME }')); ?></a></span></dt>
				<?php if (sizeof($this->_tpldata['to_recipient'])) {  ?>
					<dd>
						<?php $_to_recipient_count = (isset($this->_tpldata['to_recipient'])) ? sizeof($this->_tpldata['to_recipient']) : 0;if ($_to_recipient_count) {for ($_to_recipient_i = 0; $_to_recipient_i < $_to_recipient_count; ++$_to_recipient_i){$_to_recipient_val = &$this->_tpldata['to_recipient'][$_to_recipient_i]; if (! $_to_recipient_val['S_FIRST_ROW'] && $_to_recipient_val['S_ROW_COUNT'] % 2 == 0) {  ?></dd><dd><?php } if ($_to_recipient_val['IS_GROUP']) {  ?><a href="<?php echo $_to_recipient_val['U_VIEW']; ?>"><strong><?php echo $_to_recipient_val['NAME']; ?></strong></a><?php } else { echo $_to_recipient_val['NAME_FULL']; ?>&nbsp;<?php } if (! $this->_rootref['S_EDIT_POST']) {  ?><input type="submit" name="remove_<?php echo $_to_recipient_val['TYPE']; ?>[<?php echo $_to_recipient_val['UG_ID']; ?>]" value="x" class="button2" />&nbsp;<?php } }} ?>
					</dd>
				<?php } ?>

				<dd><input class="inputbox" type="text" name="username_list" id="username_list" size="20" value="" /> <input type="submit" name="add_to" value="<?php echo ((isset($this->_rootref['L_ADD'])) ? $this->_rootref['L_ADD'] : ((isset($user->lang['ADD'])) ? $user->lang['ADD'] : '{ ADD }')); ?>" class="button2" /></dd>
			</dl>
		<?php } ?>

		</div>

		<?php if ($this->_rootref['S_GROUP_OPTIONS']) {  ?>
			<div class="column2">
				<dl>
					<dd><label for="group_list"><?php echo ((isset($this->_rootref['L_USERGROUPS'])) ? $this->_rootref['L_USERGROUPS'] : ((isset($user->lang['USERGROUPS'])) ? $user->lang['USERGROUPS'] : '{ USERGROUPS }')); ?>:</label> <select name="group_list[]" id="group_list "multiple="true" size="4" class="inputbox"><?php echo (isset($this->_rootref['S_GROUP_OPTIONS'])) ? $this->_rootref['S_GROUP_OPTIONS'] : ''; ?></select></dd>
				</dl>
			</div>
		<?php } ?>

		<div class="clear"></div>

	<?php } if ($this->_rootref['S_DELETE_ALLOWED']) {  ?>
	<dl>
		<dt><label for="delete"><?php echo ((isset($this->_rootref['L_DELETE_POST'])) ? $this->_rootref['L_DELETE_POST'] : ((isset($user->lang['DELETE_POST'])) ? $user->lang['DELETE_POST'] : '{ DELETE_POST }')); ?>:</label></dt>
		<dd><label for="delete"><input type="checkbox" name="delete" id="delete" /> <?php echo ((isset($this->_rootref['L_DELETE_POST_WARN'])) ? $this->_rootref['L_DELETE_POST_WARN'] : ((isset($user->lang['DELETE_POST_WARN'])) ? $user->lang['DELETE_POST_WARN'] : '{ DELETE_POST_WARN }')); ?></label></dd>
	</dl>
	<?php } if ($this->_rootref['S_SHOW_TOPIC_ICONS'] || $this->_rootref['S_SHOW_PM_ICONS']) {  ?>
	<dl>
		<dt><label for="icon"><?php echo ((isset($this->_rootref['L_ICON'])) ? $this->_rootref['L_ICON'] : ((isset($user->lang['ICON'])) ? $user->lang['ICON'] : '{ ICON }')); ?>:</label></dt>
		<dd>
			<label for="icon"><input type="radio" name="icon" id="icon" value="0" checked="checked" /> <?php if ($this->_rootref['S_SHOW_TOPIC_ICONS']) {  echo ((isset($this->_rootref['L_NO_TOPIC_ICON'])) ? $this->_rootref['L_NO_TOPIC_ICON'] : ((isset($user->lang['NO_TOPIC_ICON'])) ? $user->lang['NO_TOPIC_ICON'] : '{ NO_TOPIC_ICON }')); } else { echo ((isset($this->_rootref['L_NO_PM_ICON'])) ? $this->_rootref['L_NO_PM_ICON'] : ((isset($user->lang['NO_PM_ICON'])) ? $user->lang['NO_PM_ICON'] : '{ NO_PM_ICON }')); } ?></label>
			<?php $_topic_icon_count = (isset($this->_tpldata['topic_icon'])) ? sizeof($this->_tpldata['topic_icon']) : 0;if ($_topic_icon_count) {for ($_topic_icon_i = 0; $_topic_icon_i < $_topic_icon_count; ++$_topic_icon_i){$_topic_icon_val = &$this->_tpldata['topic_icon'][$_topic_icon_i]; ?><label for="icon-<?php echo $_topic_icon_val['ICON_ID']; ?>"><input type="radio" name="icon" id="icon-<?php echo $_topic_icon_val['ICON_ID']; ?>" value="<?php echo $_topic_icon_val['ICON_ID']; ?>" <?php echo $_topic_icon_val['S_ICON_CHECKED']; ?> /><img src="<?php echo $_topic_icon_val['ICON_IMG']; ?>" width="<?php echo $_topic_icon_val['ICON_WIDTH']; ?>" height="<?php echo $_topic_icon_val['ICON_HEIGHT']; ?>" alt="" title="" /></label> <?php }} ?>
		</dd>
	</dl>
	<?php } if (! $this->_rootref['S_PRIVMSGS'] && $this->_rootref['S_DISPLAY_USERNAME']) {  ?>
	<dl>
		<dt><label for="username"><?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?>:</label></dt>
		<dd><input type="text" tabindex="1" name="username" id="username" size="25" value="<?php echo (isset($this->_rootref['USERNAME'])) ? $this->_rootref['USERNAME'] : ''; ?>" class="inputbox" /></dd>
	</dl>
	<?php } if ($this->_rootref['S_POST_ACTION'] || $this->_rootref['S_PRIVMSGS'] || $this->_rootref['S_EDIT_DRAFT']) {  ?>
	<dl style="clear: left;">
		<dt><label for="subject"><?php echo ((isset($this->_rootref['L_SUBJECT'])) ? $this->_rootref['L_SUBJECT'] : ((isset($user->lang['SUBJECT'])) ? $user->lang['SUBJECT'] : '{ SUBJECT }')); ?>:</label></dt>
		<dd><input type="text" name="subject" id="subject" size="45" maxlength="<?php if ($this->_rootref['S_NEW_MESSAGE']) {  ?>60<?php } else { ?>64<?php } ?>" tabindex="2" value="<?php echo (isset($this->_rootref['SUBJECT'])) ? $this->_rootref['SUBJECT'] : ''; echo (isset($this->_rootref['DRAFT_SUBJECT'])) ? $this->_rootref['DRAFT_SUBJECT'] : ''; ?>" class="inputbox autowidth" /></dd>
	</dl>
		<?php if ($this->_rootref['S_CONFIRM_CODE']) {  ?>
		<dl>
			<dt><label for="confirm_code"><?php echo ((isset($this->_rootref['L_CONFIRM_CODE'])) ? $this->_rootref['L_CONFIRM_CODE'] : ((isset($user->lang['CONFIRM_CODE'])) ? $user->lang['CONFIRM_CODE'] : '{ CONFIRM_CODE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_CONFIRM_CODE_EXPLAIN'])) ? $this->_rootref['L_CONFIRM_CODE_EXPLAIN'] : ((isset($user->lang['CONFIRM_CODE_EXPLAIN'])) ? $user->lang['CONFIRM_CODE_EXPLAIN'] : '{ CONFIRM_CODE_EXPLAIN }')); ?></span></dt>
				<dd><input type="hidden" name="confirm_id" value="<?php echo (isset($this->_rootref['CONFIRM_ID'])) ? $this->_rootref['CONFIRM_ID'] : ''; ?>" /><?php echo (isset($this->_rootref['CONFIRM_IMAGE'])) ? $this->_rootref['CONFIRM_IMAGE'] : ''; ?></dd>
				<dd><input type="text" name="confirm_code" id="confirm_code" size="8" maxlength="8" tabindex="3" class="inputbox narrow" title="<?php echo ((isset($this->_rootref['L_CONFIRM_CODE'])) ? $this->_rootref['L_CONFIRM_CODE'] : ((isset($user->lang['CONFIRM_CODE'])) ? $user->lang['CONFIRM_CODE'] : '{ CONFIRM_CODE }')); ?>" /></dd>
		</dl>
		<?php } } $this->_tpl_include('posting_buttons.html'); ?>

	<div id="smiley-box">
		<?php if ($this->_rootref['S_SMILIES_ALLOWED'] && sizeof($this->_tpldata['smiley'])) {  ?>
			<strong><?php echo ((isset($this->_rootref['L_SMILIES'])) ? $this->_rootref['L_SMILIES'] : ((isset($user->lang['SMILIES'])) ? $user->lang['SMILIES'] : '{ SMILIES }')); ?></strong><br />
			<?php $_smiley_count = (isset($this->_tpldata['smiley'])) ? sizeof($this->_tpldata['smiley']) : 0;if ($_smiley_count) {for ($_smiley_i = 0; $_smiley_i < $_smiley_count; ++$_smiley_i){$_smiley_val = &$this->_tpldata['smiley'][$_smiley_i]; ?>
				<a href="#" onclick="insert_text('<?php echo $_smiley_val['A_SMILEY_CODE']; ?>', true); return false;"><img src="<?php echo $_smiley_val['SMILEY_IMG']; ?>" width="<?php echo $_smiley_val['SMILEY_WIDTH']; ?>" height="<?php echo $_smiley_val['SMILEY_HEIGHT']; ?>" alt="<?php echo $_smiley_val['SMILEY_CODE']; ?>" title="<?php echo $_smiley_val['SMILEY_DESC']; ?>" /></a>
			<?php }} } if ($this->_rootref['S_SHOW_SMILEY_LINK'] && $this->_rootref['S_SMILIES_ALLOWED']) {  ?>
			<br /><a href="<?php echo (isset($this->_rootref['U_MORE_SMILIES'])) ? $this->_rootref['U_MORE_SMILIES'] : ''; ?>" onclick="popup(this.href, 300, 350, '_phpbbsmilies'); return false;"><?php echo ((isset($this->_rootref['L_MORE_SMILIES'])) ? $this->_rootref['L_MORE_SMILIES'] : ((isset($user->lang['MORE_SMILIES'])) ? $user->lang['MORE_SMILIES'] : '{ MORE_SMILIES }')); ?></a>
		<?php } if ($this->_rootref['BBCODE_STATUS']) {  if (sizeof($this->_tpldata['smiley'])) {  ?><hr /><?php } ?>
		<?php echo (isset($this->_rootref['BBCODE_STATUS'])) ? $this->_rootref['BBCODE_STATUS'] : ''; ?><br />
		<?php if ($this->_rootref['S_BBCODE_ALLOWED']) {  ?>
			<?php echo (isset($this->_rootref['IMG_STATUS'])) ? $this->_rootref['IMG_STATUS'] : ''; ?><br />
			<?php echo (isset($this->_rootref['FLASH_STATUS'])) ? $this->_rootref['FLASH_STATUS'] : ''; ?><br />
			<?php echo (isset($this->_rootref['URL_STATUS'])) ? $this->_rootref['URL_STATUS'] : ''; ?><br />
			<?php echo (isset($this->_rootref['SMILIES_STATUS'])) ? $this->_rootref['SMILIES_STATUS'] : ''; ?>
		<?php } } if ($this->_rootref['S_EDIT_DRAFT'] || $this->_rootref['S_DISPLAY_REVIEW']) {  if ($this->_rootref['S_DISPLAY_REVIEW']) {  ?><hr /><?php } if ($this->_rootref['S_EDIT_DRAFT']) {  ?><strong><a href="<?php echo (isset($this->_rootref['S_UCP_ACTION'])) ? $this->_rootref['S_UCP_ACTION'] : ''; ?>"><?php echo ((isset($this->_rootref['L_BACK_TO_DRAFTS'])) ? $this->_rootref['L_BACK_TO_DRAFTS'] : ((isset($user->lang['BACK_TO_DRAFTS'])) ? $user->lang['BACK_TO_DRAFTS'] : '{ BACK_TO_DRAFTS }')); ?></a></strong><?php } if ($this->_rootref['S_DISPLAY_REVIEW']) {  ?><strong><a href="#review"><?php echo ((isset($this->_rootref['L_TOPIC_REVIEW'])) ? $this->_rootref['L_TOPIC_REVIEW'] : ((isset($user->lang['TOPIC_REVIEW'])) ? $user->lang['TOPIC_REVIEW'] : '{ TOPIC_REVIEW }')); ?></a></strong><?php } } ?>
	</div>

	<div id="message-box">
		<textarea <?php if ($this->_rootref['S_UCP_ACTION'] && ! $this->_rootref['S_PRIVMSGS'] && ! $this->_rootref['S_EDIT_DRAFT']) {  ?>name="signature" id="signature" style="height: 9em;"<?php } else { ?>name="message" id="message"<?php } ?> rows="15" cols="76" tabindex="3" onselect="storeCaret(this);" onclick="storeCaret(this);" onkeyup="storeCaret(this);" class="inputbox"><?php echo (isset($this->_rootref['MESSAGE'])) ? $this->_rootref['MESSAGE'] : ''; echo (isset($this->_rootref['DRAFT_MESSAGE'])) ? $this->_rootref['DRAFT_MESSAGE'] : ''; echo (isset($this->_rootref['SIGNATURE'])) ? $this->_rootref['SIGNATURE'] : ''; ?></textarea>
	</div>
</fieldset>

<?php if ($this->_tpldata['DEFINE']['.']['EXTRA_POSTING_OPTIONS'] == 1) {  if (! $this->_rootref['S_SHOW_DRAFTS']) {  ?>
		<span class="corners-bottom"><span></span></span></div>
	</div>
	<?php } if ($this->_rootref['S_HAS_ATTACHMENTS']) {  ?>
		<div class="panel bg2">
			<div class="inner"><span class="corners-top"><span></span></span>
			<h3><?php echo ((isset($this->_rootref['L_POSTED_ATTACHMENTS'])) ? $this->_rootref['L_POSTED_ATTACHMENTS'] : ((isset($user->lang['POSTED_ATTACHMENTS'])) ? $user->lang['POSTED_ATTACHMENTS'] : '{ POSTED_ATTACHMENTS }')); ?></h3>

			<fieldset class="fields2">

			<?php $_attach_row_count = (isset($this->_tpldata['attach_row'])) ? sizeof($this->_tpldata['attach_row']) : 0;if ($_attach_row_count) {for ($_attach_row_i = 0; $_attach_row_i < $_attach_row_count; ++$_attach_row_i){$_attach_row_val = &$this->_tpldata['attach_row'][$_attach_row_i]; ?>
			<dl>

				<dt><label for="comment_list[<?php echo $_attach_row_val['ASSOC_INDEX']; ?>]"><?php echo ((isset($this->_rootref['L_FILE_COMMENT'])) ? $this->_rootref['L_FILE_COMMENT'] : ((isset($user->lang['FILE_COMMENT'])) ? $user->lang['FILE_COMMENT'] : '{ FILE_COMMENT }')); ?>:</label></dt>
				<dd><textarea name="comment_list[<?php echo $_attach_row_val['ASSOC_INDEX']; ?>]" id="comment_list[<?php echo $_attach_row_val['ASSOC_INDEX']; ?>]" rows="1" cols="35" class="inputbox"><?php echo $_attach_row_val['FILE_COMMENT']; ?></textarea></dd>
				<dd><a href="<?php echo $_attach_row_val['U_VIEW_ATTACHMENT']; ?>" class="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>"><?php echo $_attach_row_val['FILENAME']; ?></a></dd>
				<dd style="margin-top: 5px;">
					<?php if ($this->_rootref['S_INLINE_ATTACHMENT_OPTIONS']) {  ?><input type="button" value="<?php echo ((isset($this->_rootref['L_PLACE_INLINE'])) ? $this->_rootref['L_PLACE_INLINE'] : ((isset($user->lang['PLACE_INLINE'])) ? $user->lang['PLACE_INLINE'] : '{ PLACE_INLINE }')); ?>" onclick="attach_inline(<?php echo $_attach_row_val['ASSOC_INDEX']; ?>, '<?php echo $_attach_row_val['A_FILENAME']; ?>');" class="button2" />&nbsp; <?php } ?>
					<input type="submit" name="delete_file[<?php echo $_attach_row_val['ASSOC_INDEX']; ?>]" value="<?php echo ((isset($this->_rootref['L_DELETE_FILE'])) ? $this->_rootref['L_DELETE_FILE'] : ((isset($user->lang['DELETE_FILE'])) ? $user->lang['DELETE_FILE'] : '{ DELETE_FILE }')); ?>" class="button2" />
				</dd>
			</dl>
			<?php echo $_attach_row_val['S_HIDDEN']; ?>
				<?php if (! $_attach_row_val['S_LAST_ROW']) {  ?><hr class="dashed" /><?php } }} ?>

			</fieldset>

			<span class="corners-bottom"><span></span></span></div>
		</div>
	<?php } if (! $this->_rootref['S_SHOW_DRAFTS'] && ! $this->_tpldata['DEFINE']['.']['SIG_EDIT'] == 1) {  ?>
	<div class="panel bg2">
		<div class="inner"><span class="corners-top"><span></span></span>
		<fieldset class="submit-buttons">
			<?php echo (isset($this->_rootref['S_HIDDEN_ADDRESS_FIELD'])) ? $this->_rootref['S_HIDDEN_ADDRESS_FIELD'] : ''; ?>
			<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?>
			<?php if ($this->_rootref['S_HAS_DRAFTS']) {  ?><input type="submit" accesskey="d" tabindex="9" name="load" value="<?php echo ((isset($this->_rootref['L_LOAD'])) ? $this->_rootref['L_LOAD'] : ((isset($user->lang['LOAD'])) ? $user->lang['LOAD'] : '{ LOAD }')); ?>" class="button2" onclick="load_draft = true;" />&nbsp; <?php } if ($this->_rootref['S_SAVE_ALLOWED']) {  ?><input type="submit" accesskey="k" tabindex="8" name="save" value="<?php echo ((isset($this->_rootref['L_SAVE'])) ? $this->_rootref['L_SAVE'] : ((isset($user->lang['SAVE'])) ? $user->lang['SAVE'] : '{ SAVE }')); ?>" class="button2" />&nbsp; <?php } ?>
			<input type="submit" tabindex="5" name="preview" value="<?php echo ((isset($this->_rootref['L_PREVIEW'])) ? $this->_rootref['L_PREVIEW'] : ((isset($user->lang['PREVIEW'])) ? $user->lang['PREVIEW'] : '{ PREVIEW }')); ?>" class="button1"<?php if (! $this->_rootref['S_PRIVMSGS']) {  ?> onclick="document.getElementById('postform').action += '#preview';"<?php } ?> />&nbsp;
			<input type="submit" accesskey="s" tabindex="6" name="post" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" class="button1" />&nbsp;

		</fieldset>

		<span class="corners-bottom"><span></span></span></div>
	</div>
	<?php } if (! $this->_rootref['S_PRIVMSGS'] && ! $this->_rootref['S_SHOW_DRAFTS'] && ! $this->_tpldata['DEFINE']['.']['SIG_EDIT'] == 1) {  ?>
		<div id="tabs">
			<ul>
				<li id="options-panel-tab" class="activetab"><a href="#tabs" onclick="subPanels('options-panel'); return false;"><span><?php echo ((isset($this->_rootref['L_OPTIONS'])) ? $this->_rootref['L_OPTIONS'] : ((isset($user->lang['OPTIONS'])) ? $user->lang['OPTIONS'] : '{ OPTIONS }')); ?></span></a></li>
				<?php if ($this->_rootref['S_SHOW_ATTACH_BOX']) {  ?><li id="attach-panel-tab"><a href="#tabs" onclick="subPanels('attach-panel'); return false;"><span><?php echo ((isset($this->_rootref['L_ADD_ATTACHMENT'])) ? $this->_rootref['L_ADD_ATTACHMENT'] : ((isset($user->lang['ADD_ATTACHMENT'])) ? $user->lang['ADD_ATTACHMENT'] : '{ ADD_ATTACHMENT }')); ?></span></a></li><?php } if ($this->_rootref['S_SHOW_POLL_BOX'] || $this->_rootref['S_POLL_DELETE']) {  ?><li id="poll-panel-tab"><a href="#tabs" onclick="subPanels('poll-panel'); return false;"><span><?php echo ((isset($this->_rootref['L_ADD_POLL'])) ? $this->_rootref['L_ADD_POLL'] : ((isset($user->lang['ADD_POLL'])) ? $user->lang['ADD_POLL'] : '{ ADD_POLL }')); ?></span></a></li><?php } ?>
			</ul>
		</div>
	<?php } if (! $this->_rootref['S_SHOW_DRAFTS'] && ! $this->_tpldata['DEFINE']['.']['SIG_EDIT'] == 1) {  ?>
	<div class="panel bg3" id="options-panel">
		<div class="inner"><span class="corners-top"><span></span></span>

		<fieldset class="fields1">
			<?php if ($this->_rootref['S_BBCODE_ALLOWED']) {  ?>
				<div><label for="disable_bbcode"><input type="checkbox" name="disable_bbcode" id="disable_bbcode"<?php echo (isset($this->_rootref['S_BBCODE_CHECKED'])) ? $this->_rootref['S_BBCODE_CHECKED'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_DISABLE_BBCODE'])) ? $this->_rootref['L_DISABLE_BBCODE'] : ((isset($user->lang['DISABLE_BBCODE'])) ? $user->lang['DISABLE_BBCODE'] : '{ DISABLE_BBCODE }')); ?></label></div>
			<?php } if ($this->_rootref['S_SMILIES_ALLOWED']) {  ?>
				<div><label for="disable_smilies"><input type="checkbox" name="disable_smilies" id="disable_smilies"<?php echo (isset($this->_rootref['S_SMILIES_CHECKED'])) ? $this->_rootref['S_SMILIES_CHECKED'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_DISABLE_SMILIES'])) ? $this->_rootref['L_DISABLE_SMILIES'] : ((isset($user->lang['DISABLE_SMILIES'])) ? $user->lang['DISABLE_SMILIES'] : '{ DISABLE_SMILIES }')); ?></label></div>
			<?php } if ($this->_rootref['S_LINKS_ALLOWED']) {  ?>
				<div><label for="disable_magic_url"><input type="checkbox" name="disable_magic_url" id="disable_magic_url"<?php echo (isset($this->_rootref['S_MAGIC_URL_CHECKED'])) ? $this->_rootref['S_MAGIC_URL_CHECKED'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_DISABLE_MAGIC_URL'])) ? $this->_rootref['L_DISABLE_MAGIC_URL'] : ((isset($user->lang['DISABLE_MAGIC_URL'])) ? $user->lang['DISABLE_MAGIC_URL'] : '{ DISABLE_MAGIC_URL }')); ?></label></div>
			<?php } if ($this->_rootref['S_SIG_ALLOWED']) {  ?>
				<div><label for="attach_sig"><input type="checkbox" name="attach_sig" id="attach_sig"<?php echo (isset($this->_rootref['S_SIGNATURE_CHECKED'])) ? $this->_rootref['S_SIGNATURE_CHECKED'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_ATTACH_SIG'])) ? $this->_rootref['L_ATTACH_SIG'] : ((isset($user->lang['ATTACH_SIG'])) ? $user->lang['ATTACH_SIG'] : '{ ATTACH_SIG }')); ?></label></div>
			<?php } if ($this->_rootref['S_NOTIFY_ALLOWED']) {  ?>
				<div><label for="notify"><input type="checkbox" name="notify" id="notify"<?php echo (isset($this->_rootref['S_NOTIFY_CHECKED'])) ? $this->_rootref['S_NOTIFY_CHECKED'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_NOTIFY_REPLY'])) ? $this->_rootref['L_NOTIFY_REPLY'] : ((isset($user->lang['NOTIFY_REPLY'])) ? $user->lang['NOTIFY_REPLY'] : '{ NOTIFY_REPLY }')); ?></label></div>
			<?php } if ($this->_rootref['S_LOCK_TOPIC_ALLOWED']) {  ?>
				<div><label for="lock_topic"><input type="checkbox" name="lock_topic" id="lock_topic"<?php echo (isset($this->_rootref['S_LOCK_TOPIC_CHECKED'])) ? $this->_rootref['S_LOCK_TOPIC_CHECKED'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_LOCK_TOPIC'])) ? $this->_rootref['L_LOCK_TOPIC'] : ((isset($user->lang['LOCK_TOPIC'])) ? $user->lang['LOCK_TOPIC'] : '{ LOCK_TOPIC }')); ?></label></div>
			<?php } if ($this->_rootref['S_LOCK_POST_ALLOWED']) {  ?>
				<div><label for="lock_post"><input type="checkbox" name="lock_post" id="lock_post"<?php echo (isset($this->_rootref['S_LOCK_POST_CHECKED'])) ? $this->_rootref['S_LOCK_POST_CHECKED'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_LOCK_POST'])) ? $this->_rootref['L_LOCK_POST'] : ((isset($user->lang['LOCK_POST'])) ? $user->lang['LOCK_POST'] : '{ LOCK_POST }')); ?> [<?php echo ((isset($this->_rootref['L_LOCK_POST_EXPLAIN'])) ? $this->_rootref['L_LOCK_POST_EXPLAIN'] : ((isset($user->lang['LOCK_POST_EXPLAIN'])) ? $user->lang['LOCK_POST_EXPLAIN'] : '{ LOCK_POST_EXPLAIN }')); ?>]</label></div>
			<?php } if ($this->_rootref['S_TYPE_TOGGLE'] || $this->_rootref['S_TOPIC_TYPE_ANNOUNCE'] || $this->_rootref['S_TOPIC_TYPE_STICKY']) {  ?>
			<hr class="dashed" />
			<?php } if ($this->_rootref['S_TYPE_TOGGLE']) {  ?>
			<dl>
				<dt><label for="topic_type-0"><?php if ($this->_rootref['S_EDIT_POST']) {  echo ((isset($this->_rootref['L_CHANGE_TOPIC_TO'])) ? $this->_rootref['L_CHANGE_TOPIC_TO'] : ((isset($user->lang['CHANGE_TOPIC_TO'])) ? $user->lang['CHANGE_TOPIC_TO'] : '{ CHANGE_TOPIC_TO }')); } else { echo ((isset($this->_rootref['L_POST_TOPIC_AS'])) ? $this->_rootref['L_POST_TOPIC_AS'] : ((isset($user->lang['POST_TOPIC_AS'])) ? $user->lang['POST_TOPIC_AS'] : '{ POST_TOPIC_AS }')); } ?>:</label></dt>
				<dd><?php $_topic_type_count = (isset($this->_tpldata['topic_type'])) ? sizeof($this->_tpldata['topic_type']) : 0;if ($_topic_type_count) {for ($_topic_type_i = 0; $_topic_type_i < $_topic_type_count; ++$_topic_type_i){$_topic_type_val = &$this->_tpldata['topic_type'][$_topic_type_i]; ?><label for="topic_type-<?php echo $_topic_type_val['VALUE']; ?>"><input type="radio" name="topic_type" id="topic_type-<?php echo $_topic_type_val['VALUE']; ?>" value="<?php echo $_topic_type_val['VALUE']; ?>"<?php echo $_topic_type_val['S_CHECKED']; ?> /><?php echo $_topic_type_val['L_TOPIC_TYPE']; ?></label> <?php }} ?></dd>
			</dl>
			<?php } if ($this->_rootref['S_TOPIC_TYPE_ANNOUNCE'] || $this->_rootref['S_TOPIC_TYPE_STICKY']) {  ?>
			<dl>
				<dt><label for="topic_time_limit"><?php echo ((isset($this->_rootref['L_STICK_TOPIC_FOR'])) ? $this->_rootref['L_STICK_TOPIC_FOR'] : ((isset($user->lang['STICK_TOPIC_FOR'])) ? $user->lang['STICK_TOPIC_FOR'] : '{ STICK_TOPIC_FOR }')); ?>:</label></dt>
				<dd><label for="topic_time_limit"><input type="text" name="topic_time_limit" id="topic_time_limit" size="3" maxlength="3" value="<?php echo (isset($this->_rootref['TOPIC_TIME_LIMIT'])) ? $this->_rootref['TOPIC_TIME_LIMIT'] : ''; ?>" class="inputbox autowidth" /> <?php echo ((isset($this->_rootref['L_DAYS'])) ? $this->_rootref['L_DAYS'] : ((isset($user->lang['DAYS'])) ? $user->lang['DAYS'] : '{ DAYS }')); ?></label></dd>
				<dd><?php echo ((isset($this->_rootref['L_STICK_TOPIC_FOR_EXPLAIN'])) ? $this->_rootref['L_STICK_TOPIC_FOR_EXPLAIN'] : ((isset($user->lang['STICK_TOPIC_FOR_EXPLAIN'])) ? $user->lang['STICK_TOPIC_FOR_EXPLAIN'] : '{ STICK_TOPIC_FOR_EXPLAIN }')); ?></dd>
			</dl>
			<?php } if ($this->_rootref['S_EDIT_REASON']) {  ?>
			<dl>
				<dt><label for="edit_reason"><?php echo ((isset($this->_rootref['L_EDIT_REASON'])) ? $this->_rootref['L_EDIT_REASON'] : ((isset($user->lang['EDIT_REASON'])) ? $user->lang['EDIT_REASON'] : '{ EDIT_REASON }')); ?>:</label></dt>
				<dd><input type="text" name="edit_reason" id="edit_reason" value="<?php echo (isset($this->_rootref['EDIT_REASON'])) ? $this->_rootref['EDIT_REASON'] : ''; ?>" class="inputbox" /></dd>
			</dl>
			<?php } ?>
		</fieldset>
		<?php } } ?>
<?php if ($this->_rootref['S_PRIVMSGS']) {  $this->_tpl_include('ucp_header.html'); } else { $this->_tpl_include('overall_header.html'); } if ($this->_rootref['S_FORUM_RULES']) {  ?>
	<div class="forumrules">
		<?php if ($this->_rootref['U_FORUM_RULES']) {  ?>
			<h3><?php echo ((isset($this->_rootref['L_FORUM_RULES'])) ? $this->_rootref['L_FORUM_RULES'] : ((isset($user->lang['FORUM_RULES'])) ? $user->lang['FORUM_RULES'] : '{ FORUM_RULES }')); ?></h3><br />
			<a href="<?php echo (isset($this->_rootref['U_FORUM_RULES'])) ? $this->_rootref['U_FORUM_RULES'] : ''; ?>"><b><?php echo ((isset($this->_rootref['L_FORUM_RULES_LINK'])) ? $this->_rootref['L_FORUM_RULES_LINK'] : ((isset($user->lang['FORUM_RULES_LINK'])) ? $user->lang['FORUM_RULES_LINK'] : '{ FORUM_RULES_LINK }')); ?></b></a>
		<?php } else { ?>
			<h3><?php echo ((isset($this->_rootref['L_FORUM_RULES'])) ? $this->_rootref['L_FORUM_RULES'] : ((isset($user->lang['FORUM_RULES'])) ? $user->lang['FORUM_RULES'] : '{ FORUM_RULES }')); ?></h3><br />
			<?php echo (isset($this->_rootref['FORUM_RULES'])) ? $this->_rootref['FORUM_RULES'] : ''; ?>
		<?php } ?>
	</div>

	<br clear="all" />
<?php } if (! $this->_rootref['S_PRIVMSGS']) {  ?>
	<div id="pageheader">
		<h2><?php if ($this->_rootref['TOPIC_TITLE']) {  ?><a class="titles" href="<?php echo (isset($this->_rootref['U_VIEW_TOPIC'])) ? $this->_rootref['U_VIEW_TOPIC'] : ''; ?>"><?php echo (isset($this->_rootref['TOPIC_TITLE'])) ? $this->_rootref['TOPIC_TITLE'] : ''; ?></a><?php } else { ?><a class="titles" href="<?php echo (isset($this->_rootref['U_VIEW_FORUM'])) ? $this->_rootref['U_VIEW_FORUM'] : ''; ?>"><?php echo (isset($this->_rootref['FORUM_NAME'])) ? $this->_rootref['FORUM_NAME'] : ''; ?></a><?php } ?></h2>

		<?php if ($this->_rootref['MODERATORS']) {  ?>
			<p class="moderators"><?php echo ((isset($this->_rootref['L_MODERATORS'])) ? $this->_rootref['L_MODERATORS'] : ((isset($user->lang['MODERATORS'])) ? $user->lang['MODERATORS'] : '{ MODERATORS }')); ?>: <?php echo (isset($this->_rootref['MODERATORS'])) ? $this->_rootref['MODERATORS'] : ''; ?></p>
		<?php } if ($this->_rootref['U_MCP']) {  ?>
			<p class="linkmcp">[ <a href="<?php echo (isset($this->_rootref['U_MCP'])) ? $this->_rootref['U_MCP'] : ''; ?>"><?php echo ((isset($this->_rootref['L_MCP'])) ? $this->_rootref['L_MCP'] : ((isset($user->lang['MCP'])) ? $user->lang['MCP'] : '{ MCP }')); ?></a> ]</p>
		<?php } ?>
	</div>

	<br clear="all" /><br />
<?php } if (! $this->_rootref['S_SHOW_PM_BOX']) {  ?>
	<form action="<?php echo (isset($this->_rootref['S_POST_ACTION'])) ? $this->_rootref['S_POST_ACTION'] : ''; ?>" method="post" name="postform"<?php echo (isset($this->_rootref['S_FORM_ENCTYPE'])) ? $this->_rootref['S_FORM_ENCTYPE'] : ''; ?>>
<?php } if ($this->_rootref['S_DRAFT_LOADED']) {  ?>
	<table class="tablebg" width="100%" cellspacing="1">
	<tr>
		<th align="center"><?php echo ((isset($this->_rootref['L_INFORMATION'])) ? $this->_rootref['L_INFORMATION'] : ((isset($user->lang['INFORMATION'])) ? $user->lang['INFORMATION'] : '{ INFORMATION }')); ?></th>
	</tr>
	<tr>
		<td class="row1" align="center"><span class="gen"><?php if ($this->_rootref['S_PRIVMSGS']) {  echo ((isset($this->_rootref['L_DRAFT_LOADED_PM'])) ? $this->_rootref['L_DRAFT_LOADED_PM'] : ((isset($user->lang['DRAFT_LOADED_PM'])) ? $user->lang['DRAFT_LOADED_PM'] : '{ DRAFT_LOADED_PM }')); } else { echo ((isset($this->_rootref['L_DRAFT_LOADED'])) ? $this->_rootref['L_DRAFT_LOADED'] : ((isset($user->lang['DRAFT_LOADED'])) ? $user->lang['DRAFT_LOADED'] : '{ DRAFT_LOADED }')); } ?></span></td>
	</tr>
	</table>

	<br clear="all" />
<?php } if ($this->_rootref['S_SHOW_DRAFTS']) {  ?>
	<table class="tablebg" width="100%" cellspacing="1">
	<tr>
		<th colspan="3" align="center"><?php echo ((isset($this->_rootref['L_LOAD_DRAFT'])) ? $this->_rootref['L_LOAD_DRAFT'] : ((isset($user->lang['LOAD_DRAFT'])) ? $user->lang['LOAD_DRAFT'] : '{ LOAD_DRAFT }')); ?></th>
	</tr>
	<tr>
		<td class="row1" colspan="3" align="center"><span class="gen"><?php echo ((isset($this->_rootref['L_LOAD_DRAFT_EXPLAIN'])) ? $this->_rootref['L_LOAD_DRAFT_EXPLAIN'] : ((isset($user->lang['LOAD_DRAFT_EXPLAIN'])) ? $user->lang['LOAD_DRAFT_EXPLAIN'] : '{ LOAD_DRAFT_EXPLAIN }')); ?></span></td>
	</tr>
	<tr>
		<th><?php echo ((isset($this->_rootref['L_SAVE_DATE'])) ? $this->_rootref['L_SAVE_DATE'] : ((isset($user->lang['SAVE_DATE'])) ? $user->lang['SAVE_DATE'] : '{ SAVE_DATE }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_DRAFT_TITLE'])) ? $this->_rootref['L_DRAFT_TITLE'] : ((isset($user->lang['DRAFT_TITLE'])) ? $user->lang['DRAFT_TITLE'] : '{ DRAFT_TITLE }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_OPTIONS'])) ? $this->_rootref['L_OPTIONS'] : ((isset($user->lang['OPTIONS'])) ? $user->lang['OPTIONS'] : '{ OPTIONS }')); ?></th>
	</tr>
	<?php $_draftrow_count = (isset($this->_tpldata['draftrow'])) ? sizeof($this->_tpldata['draftrow']) : 0;if ($_draftrow_count) {for ($_draftrow_i = 0; $_draftrow_i < $_draftrow_count; ++$_draftrow_i){$_draftrow_val = &$this->_tpldata['draftrow'][$_draftrow_i]; if (!($_draftrow_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>

		<td class="postdetails" style="padding: 4px;"><?php echo $_draftrow_val['DATE']; ?></td>
		<td style="padding: 4px;"><b class="gen"><?php echo $_draftrow_val['DRAFT_SUBJECT']; ?></b>
			<?php if ($_draftrow_val['S_LINK_TOPIC']) {  ?><br /><span class="gensmall"><?php echo ((isset($this->_rootref['L_TOPIC'])) ? $this->_rootref['L_TOPIC'] : ((isset($user->lang['TOPIC'])) ? $user->lang['TOPIC'] : '{ TOPIC }')); ?>: <a href="<?php echo $_draftrow_val['U_VIEW']; ?>"><?php echo $_draftrow_val['TITLE']; ?></a></span>
			<?php } else if ($_draftrow_val['S_LINK_FORUM']) {  ?><br /><span class="gensmall"><?php echo ((isset($this->_rootref['L_FORUM'])) ? $this->_rootref['L_FORUM'] : ((isset($user->lang['FORUM'])) ? $user->lang['FORUM'] : '{ FORUM }')); ?>: <a href="<?php echo $_draftrow_val['U_VIEW']; ?>"><?php echo $_draftrow_val['TITLE']; ?></a></span>
			<?php } else if ($_draftrow_val['S_LINK_PM']) {  ?><br /><span class="gensmall"><?php echo ((isset($this->_rootref['L_PRIVATE_MESSAGE'])) ? $this->_rootref['L_PRIVATE_MESSAGE'] : ((isset($user->lang['PRIVATE_MESSAGE'])) ? $user->lang['PRIVATE_MESSAGE'] : '{ PRIVATE_MESSAGE }')); ?></span>
			<?php } else { ?><br /><span class="gensmall"><?php echo ((isset($this->_rootref['L_NO_TOPIC_FORUM'])) ? $this->_rootref['L_NO_TOPIC_FORUM'] : ((isset($user->lang['NO_TOPIC_FORUM'])) ? $user->lang['NO_TOPIC_FORUM'] : '{ NO_TOPIC_FORUM }')); ?></span><?php } ?>
		</td>
		<td style="padding: 4px;" align="center"><span class="gen"><a href="<?php echo $_draftrow_val['U_INSERT']; ?>"><?php echo ((isset($this->_rootref['L_LOAD_DRAFT'])) ? $this->_rootref['L_LOAD_DRAFT'] : ((isset($user->lang['LOAD_DRAFT'])) ? $user->lang['LOAD_DRAFT'] : '{ LOAD_DRAFT }')); ?></a></td>
	</tr>
	<?php }} ?>
	</table>

	<br clear="all" />
<?php } if ($this->_rootref['S_POST_REVIEW']) {  $this->_tpl_include('posting_review.html'); } if ($this->_rootref['S_DISPLAY_PREVIEW']) {  $this->_tpl_include('posting_preview.html'); } if (! $this->_rootref['S_PRIVMSGS'] && $this->_rootref['S_UNGLOBALISE']) {  ?>
	<table class="tablebg" width="100%" cellspacing="1">
	<tr>
		<th><?php echo ((isset($this->_rootref['L_MOVE'])) ? $this->_rootref['L_MOVE'] : ((isset($user->lang['MOVE'])) ? $user->lang['MOVE'] : '{ MOVE }')); ?></th>
	</tr>
	<tr>
		<td class="spacer" colspan="2"><img src="images/spacer.gif" alt="" width="1" height="1" /></td>
	</tr>
	<tr>
		<td class="row2" align="center"><span class="gen"><?php echo ((isset($this->_rootref['L_UNGLOBALISE_EXPLAIN'])) ? $this->_rootref['L_UNGLOBALISE_EXPLAIN'] : ((isset($user->lang['UNGLOBALISE_EXPLAIN'])) ? $user->lang['UNGLOBALISE_EXPLAIN'] : '{ UNGLOBALISE_EXPLAIN }')); ?><br /><br /><?php echo ((isset($this->_rootref['L_SELECT_DESTINATION_FORUM'])) ? $this->_rootref['L_SELECT_DESTINATION_FORUM'] : ((isset($user->lang['SELECT_DESTINATION_FORUM'])) ? $user->lang['SELECT_DESTINATION_FORUM'] : '{ SELECT_DESTINATION_FORUM }')); ?>&nbsp;&nbsp;</span><select name="to_forum_id"><?php echo (isset($this->_rootref['S_FORUM_SELECT'])) ? $this->_rootref['S_FORUM_SELECT'] : ''; ?></select><br /><br /><input class="btnmain" type="submit" name="post" value="<?php echo ((isset($this->_rootref['L_CONFIRM'])) ? $this->_rootref['L_CONFIRM'] : ((isset($user->lang['CONFIRM'])) ? $user->lang['CONFIRM'] : '{ CONFIRM }')); ?>" />&nbsp;&nbsp; <input class="btnlite" type="submit" name="cancel_unglobalise" value="<?php echo ((isset($this->_rootref['L_CANCEL'])) ? $this->_rootref['L_CANCEL'] : ((isset($user->lang['CANCEL'])) ? $user->lang['CANCEL'] : '{ CANCEL }')); ?>" /></td>
	</tr>
	</table>

	<br clear="all" />
<?php } ?>

<table class="tablebg" width="100%" cellspacing="1">
<tr>
	<th colspan="2"><b><?php echo ((isset($this->_rootref['L_POST_A'])) ? $this->_rootref['L_POST_A'] : ((isset($user->lang['POST_A'])) ? $user->lang['POST_A'] : '{ POST_A }')); ?></b></th>
</tr>

<?php if ($this->_rootref['ERROR']) {  ?>
	<tr>
		<td class="row2" colspan="2" align="center"><span class="genmed error"><?php echo (isset($this->_rootref['ERROR'])) ? $this->_rootref['ERROR'] : ''; ?></span></td>
	</tr>
<?php } if ($this->_rootref['S_DELETE_ALLOWED']) {  ?>
	<tr>
		<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_DELETE_POST'])) ? $this->_rootref['L_DELETE_POST'] : ((isset($user->lang['DELETE_POST'])) ? $user->lang['DELETE_POST'] : '{ DELETE_POST }')); ?>:</b></td>
		<td class="row2"><input type="checkbox" class="radio" name="delete" /> <span class="gensmall">[ <?php echo ((isset($this->_rootref['L_DELETE_POST_WARN'])) ? $this->_rootref['L_DELETE_POST_WARN'] : ((isset($user->lang['DELETE_POST_WARN'])) ? $user->lang['DELETE_POST_WARN'] : '{ DELETE_POST_WARN }')); ?> ]</span></td>
	</tr>
<?php } if ($this->_rootref['S_SHOW_TOPIC_ICONS'] || $this->_rootref['S_SHOW_PM_ICONS']) {  ?>
	<tr>
		<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_ICON'])) ? $this->_rootref['L_ICON'] : ((isset($user->lang['ICON'])) ? $user->lang['ICON'] : '{ ICON }')); ?>:</b></td>
		<td class="row2">
			<table width="100%" cellspacing="0" cellpadding="0" border="0">
			<tr>
				<td><input type="radio" class="radio" name="icon" value="0"<?php echo (isset($this->_rootref['S_NO_ICON_CHECKED'])) ? $this->_rootref['S_NO_ICON_CHECKED'] : ''; ?> /><span class="genmed"><?php if ($this->_rootref['S_SHOW_TOPIC_ICONS']) {  echo ((isset($this->_rootref['L_NO_TOPIC_ICON'])) ? $this->_rootref['L_NO_TOPIC_ICON'] : ((isset($user->lang['NO_TOPIC_ICON'])) ? $user->lang['NO_TOPIC_ICON'] : '{ NO_TOPIC_ICON }')); } else { echo ((isset($this->_rootref['L_NO_PM_ICON'])) ? $this->_rootref['L_NO_PM_ICON'] : ((isset($user->lang['NO_PM_ICON'])) ? $user->lang['NO_PM_ICON'] : '{ NO_PM_ICON }')); } ?></span> <?php $_topic_icon_count = (isset($this->_tpldata['topic_icon'])) ? sizeof($this->_tpldata['topic_icon']) : 0;if ($_topic_icon_count) {for ($_topic_icon_i = 0; $_topic_icon_i < $_topic_icon_count; ++$_topic_icon_i){$_topic_icon_val = &$this->_tpldata['topic_icon'][$_topic_icon_i]; ?><span style="white-space: nowrap;"><input type="radio" class="radio" name="icon" value="<?php echo $_topic_icon_val['ICON_ID']; ?>"<?php echo $_topic_icon_val['S_ICON_CHECKED']; ?> /><img src="<?php echo $_topic_icon_val['ICON_IMG']; ?>" width="<?php echo $_topic_icon_val['ICON_WIDTH']; ?>" height="<?php echo $_topic_icon_val['ICON_HEIGHT']; ?>" alt="" title="" hspace="2" vspace="2" /></span> <?php }} ?></td>
			</tr>
			</table>
		</td>
	</tr>
<?php } if (! $this->_rootref['S_PRIVMSGS'] && $this->_rootref['S_DISPLAY_USERNAME']) {  ?>
	<tr>
		<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?>:</b></td>
		<td class="row2"><input class="post" type="text" tabindex="1" name="username" size="25" value="<?php echo (isset($this->_rootref['USERNAME'])) ? $this->_rootref['USERNAME'] : ''; ?>" /></td>
	</tr>
<?php } if ($this->_rootref['S_PRIVMSGS']) {  ?>
	<tr>
		<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_TO'])) ? $this->_rootref['L_TO'] : ((isset($user->lang['TO'])) ? $user->lang['TO'] : '{ TO }')); ?>:</b></td>
		<td class="row2">
			<?php echo (isset($this->_rootref['S_HIDDEN_ADDRESS_FIELD'])) ? $this->_rootref['S_HIDDEN_ADDRESS_FIELD'] : ''; ?>
		<?php $_to_recipient_count = (isset($this->_tpldata['to_recipient'])) ? sizeof($this->_tpldata['to_recipient']) : 0;if ($_to_recipient_count) {for ($_to_recipient_i = 0; $_to_recipient_i < $_to_recipient_count; ++$_to_recipient_i){$_to_recipient_val = &$this->_tpldata['to_recipient'][$_to_recipient_i]; ?>
			<span style="display: block; float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>;" class="nowrap genmed"><strong>
			<?php if ($_to_recipient_val['IS_GROUP']) {  ?><a href="<?php echo $_to_recipient_val['U_VIEW']; ?>"><span class="sep"><?php echo $_to_recipient_val['NAME']; ?></span></a><?php } else { echo $_to_recipient_val['NAME_FULL']; } ?></strong>&nbsp;<?php if (! $this->_rootref['S_EDIT_POST']) {  ?><input class="post" type="submit" name="remove_<?php echo $_to_recipient_val['TYPE']; ?>[<?php echo $_to_recipient_val['UG_ID']; ?>]" value="<?php echo ((isset($this->_rootref['L_REMOVE'])) ? $this->_rootref['L_REMOVE'] : ((isset($user->lang['REMOVE'])) ? $user->lang['REMOVE'] : '{ REMOVE }')); ?>" />&nbsp;<?php } ?>
			</span>
		<?php }} else { ?>
			<span class="genmed"><?php echo ((isset($this->_rootref['L_NO_TO_RECIPIENT'])) ? $this->_rootref['L_NO_TO_RECIPIENT'] : ((isset($user->lang['NO_TO_RECIPIENT'])) ? $user->lang['NO_TO_RECIPIENT'] : '{ NO_TO_RECIPIENT }')); ?></span>
		<?php } ?>
		</td>
	</tr>
	<?php if ($this->_rootref['S_ALLOW_MASS_PM']) {  ?>
	<tr>
		<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_BCC'])) ? $this->_rootref['L_BCC'] : ((isset($user->lang['BCC'])) ? $user->lang['BCC'] : '{ BCC }')); ?>:</b></td>
		<td class="row2">
		<?php $_bcc_recipient_count = (isset($this->_tpldata['bcc_recipient'])) ? sizeof($this->_tpldata['bcc_recipient']) : 0;if ($_bcc_recipient_count) {for ($_bcc_recipient_i = 0; $_bcc_recipient_i < $_bcc_recipient_count; ++$_bcc_recipient_i){$_bcc_recipient_val = &$this->_tpldata['bcc_recipient'][$_bcc_recipient_i]; ?>
			<span class="genmed nowrap"><strong>
			<?php if ($_bcc_recipient_val['IS_GROUP']) {  ?><a href="<?php echo $_bcc_recipient_val['U_VIEW']; ?>"><span class="sep"><?php echo $_bcc_recipient_val['NAME']; ?></span></a><?php } else { echo $_bcc_recipient_val['NAME_FULL']; } ?></strong>&nbsp;<?php if (! $this->_rootref['S_EDIT_POST']) {  ?><input class="post" type="submit" name="remove_<?php echo $_bcc_recipient_val['TYPE']; ?>[<?php echo $_bcc_recipient_val['UG_ID']; ?>]" value="<?php echo ((isset($this->_rootref['L_REMOVE'])) ? $this->_rootref['L_REMOVE'] : ((isset($user->lang['REMOVE'])) ? $user->lang['REMOVE'] : '{ REMOVE }')); ?>" />&nbsp;<?php } ?>
			</span>
		<?php }} else { ?>
			<span class="genmed"><?php echo ((isset($this->_rootref['L_NO_BCC_RECIPIENT'])) ? $this->_rootref['L_NO_BCC_RECIPIENT'] : ((isset($user->lang['NO_BCC_RECIPIENT'])) ? $user->lang['NO_BCC_RECIPIENT'] : '{ NO_BCC_RECIPIENT }')); ?></span>
		<?php } ?>
		</td>
	</tr>
	<?php } } ?>

<tr>
	<td class="row1" width="22%"><b class="genmed"><?php echo ((isset($this->_rootref['L_SUBJECT'])) ? $this->_rootref['L_SUBJECT'] : ((isset($user->lang['SUBJECT'])) ? $user->lang['SUBJECT'] : '{ SUBJECT }')); ?>:</b></td>
	<td class="row2" width="78%"><input class="post" style="width:450px" type="text" name="subject" size="45" maxlength="<?php if ($this->_rootref['S_NEW_MESSAGE']) {  ?>60<?php } else { ?>64<?php } ?>" tabindex="2" value="<?php echo (isset($this->_rootref['SUBJECT'])) ? $this->_rootref['SUBJECT'] : ''; ?>" /></td>
</tr>
<tr>
	<td class="row1" valign="top"><b class="genmed"><?php echo ((isset($this->_rootref['L_MESSAGE_BODY'])) ? $this->_rootref['L_MESSAGE_BODY'] : ((isset($user->lang['MESSAGE_BODY'])) ? $user->lang['MESSAGE_BODY'] : '{ MESSAGE_BODY }')); ?>:</b><br /><span class="gensmall"><?php echo ((isset($this->_rootref['L_MESSAGE_BODY_EXPLAIN'])) ? $this->_rootref['L_MESSAGE_BODY_EXPLAIN'] : ((isset($user->lang['MESSAGE_BODY_EXPLAIN'])) ? $user->lang['MESSAGE_BODY_EXPLAIN'] : '{ MESSAGE_BODY_EXPLAIN }')); ?>&nbsp;</span><br /><br />
	<?php if ($this->_rootref['S_SMILIES_ALLOWED']) {  ?>
		<table width="100%" cellspacing="5" cellpadding="0" border="0" align="center">
		<tr>
			<td class="gensmall" align="center"><b><?php echo ((isset($this->_rootref['L_SMILIES'])) ? $this->_rootref['L_SMILIES'] : ((isset($user->lang['SMILIES'])) ? $user->lang['SMILIES'] : '{ SMILIES }')); ?></b></td>
		</tr>
		<tr>
			<td align="center">
				<?php $_smiley_count = (isset($this->_tpldata['smiley'])) ? sizeof($this->_tpldata['smiley']) : 0;if ($_smiley_count) {for ($_smiley_i = 0; $_smiley_i < $_smiley_count; ++$_smiley_i){$_smiley_val = &$this->_tpldata['smiley'][$_smiley_i]; ?>
					<a href="#" onclick="insert_text('<?php echo $_smiley_val['A_SMILEY_CODE']; ?>', true); return false;" style="line-height: 20px;"><img src="<?php echo $_smiley_val['SMILEY_IMG']; ?>" width="<?php echo $_smiley_val['SMILEY_WIDTH']; ?>" height="<?php echo $_smiley_val['SMILEY_HEIGHT']; ?>" alt="<?php echo $_smiley_val['SMILEY_CODE']; ?>" title="<?php echo $_smiley_val['SMILEY_DESC']; ?>" hspace="2" vspace="2" /></a>
				<?php }} ?>
			</td>
		</tr>

		<?php if ($this->_rootref['S_SHOW_SMILEY_LINK']) {  ?>
			<tr>
				<td align="center"><a class="nav" href="<?php echo (isset($this->_rootref['U_MORE_SMILIES'])) ? $this->_rootref['U_MORE_SMILIES'] : ''; ?>" onclick="popup(this.href, 300, 350, '_phpbbsmilies'); return false;"><?php echo ((isset($this->_rootref['L_MORE_SMILIES'])) ? $this->_rootref['L_MORE_SMILIES'] : ((isset($user->lang['MORE_SMILIES'])) ? $user->lang['MORE_SMILIES'] : '{ MORE_SMILIES }')); ?></a></td>
			</tr>
		<?php } ?>

		</table>
	<?php } ?>
	</td>
	<td class="row2" valign="top">
		<script type="text/javascript">
		// <![CDATA[
			var form_name = 'postform';
			var text_name = 'message';
		// ]]>
		</script>

		<table width="100%" cellspacing="0" cellpadding="0" border="0">
		<?php $this->_tpl_include('posting_buttons.html'); ?>
		<tr>
			<td valign="top" style="width: 100%;"><textarea name="message" rows="15" cols="76" tabindex="3" onselect="storeCaret(this);" onclick="storeCaret(this);" onkeyup="storeCaret(this);" style="width: 98%;"><?php echo (isset($this->_rootref['MESSAGE'])) ? $this->_rootref['MESSAGE'] : ''; ?></textarea></td>
			<?php if ($this->_rootref['S_BBCODE_ALLOWED']) {  ?>
			<td width="80" align="center" valign="top">
				<script type="text/javascript">
				// <![CDATA[
					colorPalette('v', 7, 6)
				// ]]>
				</script>
			</td>
			<?php } ?>
	 	</tr>
		</table>
	</td>
</tr>

<?php if ($this->_rootref['S_INLINE_ATTACHMENT_OPTIONS']) {  ?>
	<tr>
		<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_ATTACHMENTS'])) ? $this->_rootref['L_ATTACHMENTS'] : ((isset($user->lang['ATTACHMENTS'])) ? $user->lang['ATTACHMENTS'] : '{ ATTACHMENTS }')); ?>:</b></td>
		<td class="row2"><select name="attachments"><?php echo (isset($this->_rootref['S_INLINE_ATTACHMENT_OPTIONS'])) ? $this->_rootref['S_INLINE_ATTACHMENT_OPTIONS'] : ''; ?></select>&nbsp;<input type="button" class="btnbbcode" accesskey="a" value="<?php echo ((isset($this->_rootref['L_PLACE_INLINE'])) ? $this->_rootref['L_PLACE_INLINE'] : ((isset($user->lang['PLACE_INLINE'])) ? $user->lang['PLACE_INLINE'] : '{ PLACE_INLINE }')); ?>" name="attachinline" onclick="attach_form = document.forms[form_name].elements['attachments']; attach_inline(attach_form.value, attach_form.options[attach_form.selectedIndex].text);" onmouseover="helpline('a')" onmouseout="helpline('tip')" />
		</td>
	</tr>
<?php } ?>

<tr>
	<td class="row1" valign="top"><b class="genmed"><?php echo ((isset($this->_rootref['L_OPTIONS'])) ? $this->_rootref['L_OPTIONS'] : ((isset($user->lang['OPTIONS'])) ? $user->lang['OPTIONS'] : '{ OPTIONS }')); ?>:</b><br />
		<table cellspacing="2" cellpadding="0" border="0">
		<tr>
			<td class="gensmall"><?php echo (isset($this->_rootref['BBCODE_STATUS'])) ? $this->_rootref['BBCODE_STATUS'] : ''; ?></td>
		</tr>
		<?php if ($this->_rootref['S_BBCODE_ALLOWED']) {  ?>
		<tr>
			<td class="gensmall"><?php echo (isset($this->_rootref['IMG_STATUS'])) ? $this->_rootref['IMG_STATUS'] : ''; ?></td>
		</tr>
		<tr>
			<td class="gensmall"><?php echo (isset($this->_rootref['FLASH_STATUS'])) ? $this->_rootref['FLASH_STATUS'] : ''; ?></td>
		</tr>
		<tr>
			<td class="gensmall"><?php echo (isset($this->_rootref['URL_STATUS'])) ? $this->_rootref['URL_STATUS'] : ''; ?></td>
		</tr>
		<tr>
			<td class="gensmall"><?php echo (isset($this->_rootref['SMILIES_STATUS'])) ? $this->_rootref['SMILIES_STATUS'] : ''; ?></td>
		</tr>
		<?php } ?>
		</table>
	</td>
	<td class="row2">
		<table cellpadding="1">
		<?php if ($this->_rootref['S_BBCODE_ALLOWED']) {  ?>
			<tr>
				<td><input type="checkbox" class="radio" name="disable_bbcode"<?php echo (isset($this->_rootref['S_BBCODE_CHECKED'])) ? $this->_rootref['S_BBCODE_CHECKED'] : ''; ?> /></td>
				<td class="gen"><?php echo ((isset($this->_rootref['L_DISABLE_BBCODE'])) ? $this->_rootref['L_DISABLE_BBCODE'] : ((isset($user->lang['DISABLE_BBCODE'])) ? $user->lang['DISABLE_BBCODE'] : '{ DISABLE_BBCODE }')); ?></td>
			</tr>
		<?php } if ($this->_rootref['S_SMILIES_ALLOWED']) {  ?>
			<tr>
				<td><input type="checkbox" class="radio" name="disable_smilies"<?php echo (isset($this->_rootref['S_SMILIES_CHECKED'])) ? $this->_rootref['S_SMILIES_CHECKED'] : ''; ?> /></td>
				<td class="gen"><?php echo ((isset($this->_rootref['L_DISABLE_SMILIES'])) ? $this->_rootref['L_DISABLE_SMILIES'] : ((isset($user->lang['DISABLE_SMILIES'])) ? $user->lang['DISABLE_SMILIES'] : '{ DISABLE_SMILIES }')); ?></td>
			</tr>
		<?php } if ($this->_rootref['S_LINKS_ALLOWED']) {  ?>
		<tr>
			<td><input type="checkbox" class="radio" name="disable_magic_url"<?php echo (isset($this->_rootref['S_MAGIC_URL_CHECKED'])) ? $this->_rootref['S_MAGIC_URL_CHECKED'] : ''; ?> /></td>
			<td class="gen"><?php echo ((isset($this->_rootref['L_DISABLE_MAGIC_URL'])) ? $this->_rootref['L_DISABLE_MAGIC_URL'] : ((isset($user->lang['DISABLE_MAGIC_URL'])) ? $user->lang['DISABLE_MAGIC_URL'] : '{ DISABLE_MAGIC_URL }')); ?></td>
		</tr>
		<?php } if ($this->_rootref['S_SIG_ALLOWED']) {  ?>
			<tr>
				<td><input type="checkbox" class="radio" name="attach_sig"<?php echo (isset($this->_rootref['S_SIGNATURE_CHECKED'])) ? $this->_rootref['S_SIGNATURE_CHECKED'] : ''; ?> /></td>
				<td class="gen"><?php echo ((isset($this->_rootref['L_ATTACH_SIG'])) ? $this->_rootref['L_ATTACH_SIG'] : ((isset($user->lang['ATTACH_SIG'])) ? $user->lang['ATTACH_SIG'] : '{ ATTACH_SIG }')); ?></td>
			</tr>
		<?php } if ($this->_rootref['S_NOTIFY_ALLOWED']) {  ?>
			<tr>
				<td><input type="checkbox" class="radio" name="notify"<?php echo (isset($this->_rootref['S_NOTIFY_CHECKED'])) ? $this->_rootref['S_NOTIFY_CHECKED'] : ''; ?> /></td>
				<td class="gen"><?php echo ((isset($this->_rootref['L_NOTIFY_REPLY'])) ? $this->_rootref['L_NOTIFY_REPLY'] : ((isset($user->lang['NOTIFY_REPLY'])) ? $user->lang['NOTIFY_REPLY'] : '{ NOTIFY_REPLY }')); ?></td>
			</tr>
		<?php } if (! $this->_rootref['S_PRIVMSGS']) {  if ($this->_rootref['S_LOCK_TOPIC_ALLOWED']) {  ?>
				<tr>
					<td><input type="checkbox" class="radio" name="lock_topic"<?php echo (isset($this->_rootref['S_LOCK_TOPIC_CHECKED'])) ? $this->_rootref['S_LOCK_TOPIC_CHECKED'] : ''; ?> /></td>
					<td class="gen"><?php echo ((isset($this->_rootref['L_LOCK_TOPIC'])) ? $this->_rootref['L_LOCK_TOPIC'] : ((isset($user->lang['LOCK_TOPIC'])) ? $user->lang['LOCK_TOPIC'] : '{ LOCK_TOPIC }')); ?></td>
				</tr>
			<?php } if ($this->_rootref['S_LOCK_POST_ALLOWED']) {  ?>
				<tr>
					<td><input type="checkbox" class="radio" name="lock_post"<?php echo (isset($this->_rootref['S_LOCK_POST_CHECKED'])) ? $this->_rootref['S_LOCK_POST_CHECKED'] : ''; ?> /></td>
					<td class="gen"><?php echo ((isset($this->_rootref['L_LOCK_POST'])) ? $this->_rootref['L_LOCK_POST'] : ((isset($user->lang['LOCK_POST'])) ? $user->lang['LOCK_POST'] : '{ LOCK_POST }')); ?> [<?php echo ((isset($this->_rootref['L_LOCK_POST_EXPLAIN'])) ? $this->_rootref['L_LOCK_POST_EXPLAIN'] : ((isset($user->lang['LOCK_POST_EXPLAIN'])) ? $user->lang['LOCK_POST_EXPLAIN'] : '{ LOCK_POST_EXPLAIN }')); ?>]</td>
				</tr>
			<?php } if ($this->_rootref['S_TYPE_TOGGLE']) {  ?>
				<tr>
					<td>&nbsp;</td>
					<td class="gen"><?php if ($this->_rootref['S_EDIT_POST']) {  echo ((isset($this->_rootref['L_CHANGE_TOPIC_TO'])) ? $this->_rootref['L_CHANGE_TOPIC_TO'] : ((isset($user->lang['CHANGE_TOPIC_TO'])) ? $user->lang['CHANGE_TOPIC_TO'] : '{ CHANGE_TOPIC_TO }')); } else { echo ((isset($this->_rootref['L_POST_TOPIC_AS'])) ? $this->_rootref['L_POST_TOPIC_AS'] : ((isset($user->lang['POST_TOPIC_AS'])) ? $user->lang['POST_TOPIC_AS'] : '{ POST_TOPIC_AS }')); } ?>: <?php $_topic_type_count = (isset($this->_tpldata['topic_type'])) ? sizeof($this->_tpldata['topic_type']) : 0;if ($_topic_type_count) {for ($_topic_type_i = 0; $_topic_type_i < $_topic_type_count; ++$_topic_type_i){$_topic_type_val = &$this->_tpldata['topic_type'][$_topic_type_i]; ?><input type="radio" class="radio" name="topic_type" value="<?php echo $_topic_type_val['VALUE']; ?>"<?php echo $_topic_type_val['S_CHECKED']; ?> /><?php echo $_topic_type_val['L_TOPIC_TYPE']; ?>&nbsp;&nbsp;<?php }} ?></td>
				</tr>
			<?php } } ?>
		</table>
	</td>
</tr>

<?php if ($this->_rootref['S_TOPIC_TYPE_ANNOUNCE'] || $this->_rootref['S_TOPIC_TYPE_STICKY']) {  ?>
	<tr>
		<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_STICK_TOPIC_FOR'])) ? $this->_rootref['L_STICK_TOPIC_FOR'] : ((isset($user->lang['STICK_TOPIC_FOR'])) ? $user->lang['STICK_TOPIC_FOR'] : '{ STICK_TOPIC_FOR }')); ?>:</b><br /><span class="gensmall"><?php echo ((isset($this->_rootref['L_STICKY_ANNOUNCE_TIME_LIMIT'])) ? $this->_rootref['L_STICKY_ANNOUNCE_TIME_LIMIT'] : ((isset($user->lang['STICKY_ANNOUNCE_TIME_LIMIT'])) ? $user->lang['STICKY_ANNOUNCE_TIME_LIMIT'] : '{ STICKY_ANNOUNCE_TIME_LIMIT }')); ?></span></td>
		<td class="row2"><input class="post" type="text" name="topic_time_limit" size="3" maxlength="3" value="<?php echo (isset($this->_rootref['TOPIC_TIME_LIMIT'])) ? $this->_rootref['TOPIC_TIME_LIMIT'] : ''; ?>" />&nbsp;<b class="gen"><?php echo ((isset($this->_rootref['L_DAYS'])) ? $this->_rootref['L_DAYS'] : ((isset($user->lang['DAYS'])) ? $user->lang['DAYS'] : '{ DAYS }')); ?></b> <span class="gensmall"><?php echo ((isset($this->_rootref['L_STICK_TOPIC_FOR_EXPLAIN'])) ? $this->_rootref['L_STICK_TOPIC_FOR_EXPLAIN'] : ((isset($user->lang['STICK_TOPIC_FOR_EXPLAIN'])) ? $user->lang['STICK_TOPIC_FOR_EXPLAIN'] : '{ STICK_TOPIC_FOR_EXPLAIN }')); ?></span></td>
	</tr>
<?php } if ($this->_rootref['S_EDIT_REASON']) {  ?>
	<tr>
		<td class="row1" valign="top"><b class="genmed"><?php echo ((isset($this->_rootref['L_EDIT_REASON'])) ? $this->_rootref['L_EDIT_REASON'] : ((isset($user->lang['EDIT_REASON'])) ? $user->lang['EDIT_REASON'] : '{ EDIT_REASON }')); ?>:</b></td>
		<td class="row2"><input class="post" type="text" name="edit_reason" size="50" value="<?php echo (isset($this->_rootref['EDIT_REASON'])) ? $this->_rootref['EDIT_REASON'] : ''; ?>" /></td>
	</tr>
<?php } if ($this->_rootref['S_CONFIRM_CODE']) {  ?>
	<tr>
		<th colspan="2" valign="middle"><?php echo ((isset($this->_rootref['L_POST_CONFIRMATION'])) ? $this->_rootref['L_POST_CONFIRMATION'] : ((isset($user->lang['POST_CONFIRMATION'])) ? $user->lang['POST_CONFIRMATION'] : '{ POST_CONFIRMATION }')); ?></th>
	</tr>
	<tr>
		<td class="row3" colspan="2"><span class="gensmall"><?php echo ((isset($this->_rootref['L_POST_CONFIRM_EXPLAIN'])) ? $this->_rootref['L_POST_CONFIRM_EXPLAIN'] : ((isset($user->lang['POST_CONFIRM_EXPLAIN'])) ? $user->lang['POST_CONFIRM_EXPLAIN'] : '{ POST_CONFIRM_EXPLAIN }')); ?></span></td>
	</tr>
	<tr>
		<td class="row1" colspan="2" align="center">
			<input type="hidden" name="confirm_id" value="<?php echo (isset($this->_rootref['CONFIRM_ID'])) ? $this->_rootref['CONFIRM_ID'] : ''; ?>" />
			<?php echo (isset($this->_rootref['CONFIRM_IMAGE'])) ? $this->_rootref['CONFIRM_IMAGE'] : ''; ?>
		</td>
	</tr>
	<tr>
		<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_CONFIRM_CODE'])) ? $this->_rootref['L_CONFIRM_CODE'] : ((isset($user->lang['CONFIRM_CODE'])) ? $user->lang['CONFIRM_CODE'] : '{ CONFIRM_CODE }')); ?>: </b><br /><span class="gensmall"><?php echo ((isset($this->_rootref['L_CONFIRM_CODE_EXPLAIN'])) ? $this->_rootref['L_CONFIRM_CODE_EXPLAIN'] : ((isset($user->lang['CONFIRM_CODE_EXPLAIN'])) ? $user->lang['CONFIRM_CODE_EXPLAIN'] : '{ CONFIRM_CODE_EXPLAIN }')); ?></span></td>
		<td class="row2"><input class="post" type="text" name="confirm_code" size="8" maxlength="8" /></td>
	</tr>
<?php } if ($this->_rootref['S_SHOW_ATTACH_BOX'] || $this->_rootref['S_SHOW_POLL_BOX']) {  ?>
	<tr>
		<td class="cat" colspan="2" align="center">
			<input class="btnlite" type="submit" tabindex="5" name="preview" value="<?php echo ((isset($this->_rootref['L_PREVIEW'])) ? $this->_rootref['L_PREVIEW'] : ((isset($user->lang['PREVIEW'])) ? $user->lang['PREVIEW'] : '{ PREVIEW }')); ?>" />
			&nbsp; <input class="btnmain" type="submit" accesskey="s" tabindex="6" name="post" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />
			<?php if ($this->_rootref['S_SAVE_ALLOWED']) {  ?>&nbsp; <input class="btnlite" type="submit" accesskey="k" tabindex="7" name="save" value="<?php echo ((isset($this->_rootref['L_SAVE'])) ? $this->_rootref['L_SAVE'] : ((isset($user->lang['SAVE'])) ? $user->lang['SAVE'] : '{ SAVE }')); ?>" /><?php } if ($this->_rootref['S_HAS_DRAFTS']) {  ?>&nbsp; <input class="btnlite" type="submit" accesskey="d" tabindex="8" name="load" value="<?php echo ((isset($this->_rootref['L_LOAD'])) ? $this->_rootref['L_LOAD'] : ((isset($user->lang['LOAD'])) ? $user->lang['LOAD'] : '{ LOAD }')); ?>" /><?php } ?>
			&nbsp; <input class="btnlite" type="submit" accesskey="c" tabindex="9" name="cancel" value="<?php echo ((isset($this->_rootref['L_CANCEL'])) ? $this->_rootref['L_CANCEL'] : ((isset($user->lang['CANCEL'])) ? $user->lang['CANCEL'] : '{ CANCEL }')); ?>" />
		</td>
	</tr>

	<?php if ($this->_rootref['S_SHOW_ATTACH_BOX']) {  $this->_tpl_include('posting_attach_body.html'); } if ($this->_rootref['S_SHOW_POLL_BOX']) {  $this->_tpl_include('posting_poll_body.html'); } else if ($this->_rootref['S_POLL_DELETE']) {  ?>
		<tr>
			<td class="row1"><span class="genmed"><b><?php echo ((isset($this->_rootref['L_POLL_DELETE'])) ? $this->_rootref['L_POLL_DELETE'] : ((isset($user->lang['POLL_DELETE'])) ? $user->lang['POLL_DELETE'] : '{ POLL_DELETE }')); ?>:</b></span></td>
			<td class="row2"><input type="checkbox" class="radio" name="poll_delete" /></td>
		</tr>
	<?php } } ?>

<tr>
	<td class="cat" colspan="2" align="center"><?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?>
		<input class="btnlite" type="submit" tabindex="10" name="preview" value="<?php echo ((isset($this->_rootref['L_PREVIEW'])) ? $this->_rootref['L_PREVIEW'] : ((isset($user->lang['PREVIEW'])) ? $user->lang['PREVIEW'] : '{ PREVIEW }')); ?>" />
		&nbsp; <input class="btnmain" type="submit" accesskey="s" tabindex="11" name="post" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />
		<?php if (! $this->_rootref['S_SHOW_ATTACH_BOX'] && ! $this->_rootref['S_SHOW_POLL_BOX']) {  if ($this->_rootref['S_SAVE_ALLOWED']) {  ?>&nbsp; <input class="btnlite" type="submit" accesskey="k" tabindex="12" name="save" value="<?php echo ((isset($this->_rootref['L_SAVE'])) ? $this->_rootref['L_SAVE'] : ((isset($user->lang['SAVE'])) ? $user->lang['SAVE'] : '{ SAVE }')); ?>" /><?php } if ($this->_rootref['S_HAS_DRAFTS']) {  ?>&nbsp; <input class="btnlite" type="submit" accesskey="d" tabindex="13" name="load" value="<?php echo ((isset($this->_rootref['L_LOAD'])) ? $this->_rootref['L_LOAD'] : ((isset($user->lang['LOAD'])) ? $user->lang['LOAD'] : '{ LOAD }')); ?>" /><?php } } ?>
		&nbsp; <input class="btnlite" type="submit" accesskey="c" tabindex="14" name="cancel" value="<?php echo ((isset($this->_rootref['L_CANCEL'])) ? $this->_rootref['L_CANCEL'] : ((isset($user->lang['CANCEL'])) ? $user->lang['CANCEL'] : '{ CANCEL }')); ?>" />
	</td>
</tr>
</table>

<br clear="all" />

<?php if ($this->_rootref['S_DISPLAY_REVIEW']) {  $this->_tpl_include('posting_topic_review.html'); } if ($this->_rootref['S_DISPLAY_HISTORY']) {  $this->_tpl_include('ucp_pm_history.html'); } if ($this->_rootref['S_PRIVMSGS']) {  $this->_tpl_include('ucp_footer.html'); } else { $this->_tpl_include('breadcrumbs.html'); ?>
	<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</form>

	<?php if ($this->_rootref['S_DISPLAY_ONLINE_LIST']) {  ?>
		<br clear="all" />

		<table class="tablebg" width="100%" cellspacing="1">
		<tr>
			<td class="cat"><h4><?php echo ((isset($this->_rootref['L_WHO_IS_ONLINE'])) ? $this->_rootref['L_WHO_IS_ONLINE'] : ((isset($user->lang['WHO_IS_ONLINE'])) ? $user->lang['WHO_IS_ONLINE'] : '{ WHO_IS_ONLINE }')); ?></h4></td>
		</tr>
		<tr>
			<td class="row1"><span class="gensmall"><?php echo (isset($this->_rootref['LOGGED_IN_USER_LIST'])) ? $this->_rootref['LOGGED_IN_USER_LIST'] : ''; ?></span></td>
		</tr>
		</table>
	<?php } ?>

	<br clear="all" />

	<table width="100%" cellspacing="1">
	<tr>
		<td align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>"><?php $this->_tpl_include('jumpbox.html'); ?></td>
	</tr>
	</table>

	<?php $this->_tpl_include('overall_footer.html'); } ?>
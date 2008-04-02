<table class="tablebg" width="100%" cellspacing="1">
<tr>
	<th align="center"><?php echo ((isset($this->_rootref['L_TOPIC_REVIEW'])) ? $this->_rootref['L_TOPIC_REVIEW'] : ((isset($user->lang['TOPIC_REVIEW'])) ? $user->lang['TOPIC_REVIEW'] : '{ TOPIC_REVIEW }')); ?> - <?php echo (isset($this->_rootref['TOPIC_TITLE'])) ? $this->_rootref['TOPIC_TITLE'] : ''; ?></th>
</tr>
<tr>
	<td class="row1"><div style="overflow: auto; width: 100%; height: 300px;">

		<table class="tablebg" width="100%" cellspacing="1">
		<tr>
			<th width="22%"><?php echo ((isset($this->_rootref['L_AUTHOR'])) ? $this->_rootref['L_AUTHOR'] : ((isset($user->lang['AUTHOR'])) ? $user->lang['AUTHOR'] : '{ AUTHOR }')); ?></th>
			<th><?php echo ((isset($this->_rootref['L_MESSAGE'])) ? $this->_rootref['L_MESSAGE'] : ((isset($user->lang['MESSAGE'])) ? $user->lang['MESSAGE'] : '{ MESSAGE }')); ?></th>
		</tr>
		<?php $_topic_review_row_count = (isset($this->_tpldata['topic_review_row'])) ? sizeof($this->_tpldata['topic_review_row']) : 0;if ($_topic_review_row_count) {for ($_topic_review_row_i = 0; $_topic_review_row_i < $_topic_review_row_count; ++$_topic_review_row_i){$_topic_review_row_val = &$this->_tpldata['topic_review_row'][$_topic_review_row_i]; if (!($_topic_review_row_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>

				<td rowspan="2" align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>" valign="top"><a id="pr<?php echo $_topic_review_row_val['POST_ID']; ?>"></a>
					<table width="150" cellspacing="0">
					<tr>
						<td align="center"><b class="postauthor"<?php if ($_topic_review_row_val['POST_AUTHOR_COLOUR']) {  ?> style="color: <?php echo $_topic_review_row_val['POST_AUTHOR_COLOUR']; ?>"<?php } ?>><?php echo $_topic_review_row_val['POST_AUTHOR']; ?></b></td>
					</tr>
					</table>
				</td>
				<td width="100%">
					<table width="100%" cellspacing="0">
					<tr>
						<td>&nbsp;</td>
						<td class="gensmall" valign="middle" nowrap="nowrap"><b><?php echo ((isset($this->_rootref['L_POST_SUBJECT'])) ? $this->_rootref['L_POST_SUBJECT'] : ((isset($user->lang['POST_SUBJECT'])) ? $user->lang['POST_SUBJECT'] : '{ POST_SUBJECT }')); ?>:</b>&nbsp;</td>
						<td class="gensmall" width="100%" valign="middle"><?php echo $_topic_review_row_val['POST_SUBJECT']; ?></td>
						<td valign="top" nowrap="nowrap">&nbsp;<?php if ($_topic_review_row_val['POSTER_QUOTE'] && $_topic_review_row_val['DECODED_MESSAGE']) {  ?><a href="#" onclick="addquote(<?php echo $_topic_review_row_val['POST_ID']; ?>,'<?php echo $_topic_review_row_val['POSTER_QUOTE']; ?>'); return false;"><?php echo (isset($this->_rootref['QUOTE_IMG'])) ? $this->_rootref['QUOTE_IMG'] : ''; ?></a><?php } ?></td>
					</tr>
					</table>
				</td>
			</tr>

			<?php if (!($_topic_review_row_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>

				<td valign="top">
					<table width="100%" cellspacing="0">
					<tr>
						<td valign="top">
							<table width="100%" cellspacing="0" cellpadding="2">
							<tr>
								<td>
									<div class="postbody"><?php echo $_topic_review_row_val['MESSAGE']; ?></div>

									<?php if ($_topic_review_row_val['S_HAS_ATTACHMENTS']) {  ?>
										<br clear="all" /><br />

										<table class="tablebg" width="100%" cellspacing="1">
										<tr>
											<td class="row3"><b class="genmed"><?php echo ((isset($this->_rootref['L_ATTACHMENTS'])) ? $this->_rootref['L_ATTACHMENTS'] : ((isset($user->lang['ATTACHMENTS'])) ? $user->lang['ATTACHMENTS'] : '{ ATTACHMENTS }')); ?>: </b></td>
										</tr>
										<?php $_attachment_count = (isset($_topic_review_row_val['attachment'])) ? sizeof($_topic_review_row_val['attachment']) : 0;if ($_attachment_count) {for ($_attachment_i = 0; $_attachment_i < $_attachment_count; ++$_attachment_i){$_attachment_val = &$_topic_review_row_val['attachment'][$_attachment_i]; ?>
											<tr>
												<?php if (!($_attachment_val['S_ROW_COUNT'] & 1)  ) {  ?><td class="row2"><?php } else { ?><td class="row1"><?php } echo $_attachment_val['DISPLAY_ATTACHMENT']; ?></td>
											</tr>
										<?php }} ?>
										</table>
									<?php } if ($_topic_review_row_val['POSTER_QUOTE'] && $_topic_review_row_val['DECODED_MESSAGE']) {  ?>
										<div id="message_<?php echo $_topic_review_row_val['POST_ID']; ?>" style="display: none;"><?php echo $_topic_review_row_val['DECODED_MESSAGE']; ?></div>
									<?php } ?>
								</td>
							</tr>
							</table>
						</td>
					</tr>
					<tr>
						<td>
							<table width="100%" cellspacing="0">
							<tr valign="middle">
								<td width="100%" align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>"><span class="gensmall"><?php if ($_topic_review_row_val['U_MCP_DETAILS']) {  ?>[ <a href="<?php echo $_topic_review_row_val['U_MCP_DETAILS']; ?>"><?php echo ((isset($this->_rootref['L_POST_DETAILS'])) ? $this->_rootref['L_POST_DETAILS'] : ((isset($user->lang['POST_DETAILS'])) ? $user->lang['POST_DETAILS'] : '{ POST_DETAILS }')); ?></a> ]<?php } ?></span></td>
								<td width="10" nowrap="nowrap"><?php if ($this->_rootref['S_IS_BOT']) {  echo $_topic_review_row_val['MINI_POST_IMG']; } else { ?><a href="<?php echo $_topic_review_row_val['U_MINI_POST']; ?>"><?php echo $_topic_review_row_val['MINI_POST_IMG']; ?></a><?php } ?></td>
								<td class="gensmall" nowrap="nowrap"><b><?php echo ((isset($this->_rootref['L_POSTED'])) ? $this->_rootref['L_POSTED'] : ((isset($user->lang['POSTED'])) ? $user->lang['POSTED'] : '{ POSTED }')); ?>:</b> <?php echo $_topic_review_row_val['POST_DATE']; ?></td>
							</tr>
							</table>
						</td>
					</tr>
					</table>
				</td>
			</tr>
			<tr>
				<td class="spacer" colspan="2"><img src="images/spacer.gif" alt="" width="1" height="1" /></td>
			</tr>
		<?php }} ?>
		</table>
	</div></td>
</tr>
</table>

<br clear="all" />
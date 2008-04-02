<table class="tablebg" width="100%" cellspacing="1">
<tr>
	<th align="center"><?php echo ((isset($this->_rootref['L_MESSAGE_HISTORY'])) ? $this->_rootref['L_MESSAGE_HISTORY'] : ((isset($user->lang['MESSAGE_HISTORY'])) ? $user->lang['MESSAGE_HISTORY'] : '{ MESSAGE_HISTORY }')); ?> - <?php echo (isset($this->_rootref['HISTORY_TITLE'])) ? $this->_rootref['HISTORY_TITLE'] : ''; ?></th>
</tr>
<tr>
	<td class="row1"><div style="overflow: auto; width: 100%; height: 300px;">

		<table class="tablebg" width="100%" cellspacing="1">
		<tr>
			<th width="22%"><?php echo ((isset($this->_rootref['L_AUTHOR'])) ? $this->_rootref['L_AUTHOR'] : ((isset($user->lang['AUTHOR'])) ? $user->lang['AUTHOR'] : '{ AUTHOR }')); ?></th>
			<th><?php echo ((isset($this->_rootref['L_MESSAGE'])) ? $this->_rootref['L_MESSAGE'] : ((isset($user->lang['MESSAGE'])) ? $user->lang['MESSAGE'] : '{ MESSAGE }')); ?></th>
		</tr>
	<?php $_history_row_count = (isset($this->_tpldata['history_row'])) ? sizeof($this->_tpldata['history_row']) : 0;if ($_history_row_count) {for ($_history_row_i = 0; $_history_row_i < $_history_row_count; ++$_history_row_i){$_history_row_val = &$this->_tpldata['history_row'][$_history_row_i]; if (!($_history_row_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>
			<td rowspan="2" align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>" valign="top"><a name="<?php echo $_history_row_val['MSG_ID']; ?>"></a>
				<table width="150" cellspacing="0">
				<tr>
					<td align="center" colspan="2"><span class="postauthor"><?php echo $_history_row_val['MESSAGE_AUTHOR_FULL']; ?></span></td>
				</tr>
				</table>
			</td>
			<td width="100%"<?php if ($_history_row_val['S_CURRENT_MSG']) {  ?> style="background-color:lightblue"<?php } ?>>
				<div class="gensmall" style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>;"><b><?php echo ((isset($this->_rootref['L_PM_SUBJECT'])) ? $this->_rootref['L_PM_SUBJECT'] : ((isset($user->lang['PM_SUBJECT'])) ? $user->lang['PM_SUBJECT'] : '{ PM_SUBJECT }')); ?>:</b>&nbsp;<?php echo $_history_row_val['SUBJECT']; ?></div><div class="gensmall" style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>;"><b><?php echo ((isset($this->_rootref['L_FOLDER'])) ? $this->_rootref['L_FOLDER'] : ((isset($user->lang['FOLDER'])) ? $user->lang['FOLDER'] : '{ FOLDER }')); ?>:</b>&nbsp;<?php echo $_history_row_val['FOLDER']; ?></div>
			</td>
		</tr>

		<?php if (!($_history_row_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>
			<td valign="top">
				<table width="100%" cellspacing="0">
				<tr>
					<td valign="top">
						<table width="100%" cellspacing="0" cellpadding="2">
						<tr>
							<td><div id="message_<?php echo $_history_row_val['MSG_ID']; ?>"><div class="postbody"><?php echo $_history_row_val['MESSAGE']; ?></div></div></td>
						</tr>
						</table>
					</td>
				</tr>
				<tr>
					<td>
						<table width="100%" cellspacing="0">
						<tr valign="middle">
							<td width="100%">&nbsp;</td>
							<td width="10" nowrap="nowrap"><?php echo $_history_row_val['MINI_POST_IMG']; ?></td>
							<td class="gensmall" nowrap="nowrap"><b><?php echo ((isset($this->_rootref['L_SENT_AT'])) ? $this->_rootref['L_SENT_AT'] : ((isset($user->lang['SENT_AT'])) ? $user->lang['SENT_AT'] : '{ SENT_AT }')); ?>:</b> <?php echo $_history_row_val['SENT_DATE']; ?></td>
						</tr>
						</table>
					</td>
				</tr>
				</table>
			</td>
		</tr>

		<?php if (!($_history_row_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>
			<td class="gensmall"><a href="<?php echo $_history_row_val['U_VIEW_MESSAGE']; ?>"><?php echo ((isset($this->_rootref['L_VIEW_PM'])) ? $this->_rootref['L_VIEW_PM'] : ((isset($user->lang['VIEW_PM'])) ? $user->lang['VIEW_PM'] : '{ VIEW_PM }')); ?></a></td>
			<td><div class="gensmall" style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>;">&nbsp;<?php if ($_history_row_val['U_PROFILE']) {  ?><a href="<?php echo $_history_row_val['U_PROFILE']; ?>"><?php echo (isset($this->_rootref['PROFILE_IMG'])) ? $this->_rootref['PROFILE_IMG'] : ''; ?></a> <?php } if ($_history_row_val['U_EMAIL']) {  ?><a href="<?php echo $_history_row_val['U_EMAIL']; ?>"><?php echo (isset($this->_rootref['EMAIL_IMG'])) ? $this->_rootref['EMAIL_IMG'] : ''; ?></a> <?php } ?>&nbsp;</div> <div class="gensmall" style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>;"><?php if ($_history_row_val['U_QUOTE']) {  ?><a href="<?php echo $_history_row_val['U_QUOTE']; ?>"><?php echo (isset($this->_rootref['QUOTE_IMG'])) ? $this->_rootref['QUOTE_IMG'] : ''; ?></a> <?php } if ($_history_row_val['U_POST_REPLY_PM']) {  ?><a href="<?php echo $_history_row_val['U_POST_REPLY_PM']; ?>"><?php echo (isset($this->_rootref['REPLY_IMG'])) ? $this->_rootref['REPLY_IMG'] : ''; ?></a><?php } ?>&nbsp;</div></td>
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
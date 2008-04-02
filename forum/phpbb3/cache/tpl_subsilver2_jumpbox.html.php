<?php if ($this->_rootref['S_DISPLAY_JUMPBOX']) {  ?>
	<form method="post" name="jumpbox" action="<?php echo (isset($this->_rootref['S_JUMPBOX_ACTION'])) ? $this->_rootref['S_JUMPBOX_ACTION'] : ''; ?>" onsubmit="if(document.jumpbox.f.value == -1){return false;}">

	<table cellspacing="0" cellpadding="0" border="0">
	<tr>
		<td nowrap="nowrap"><span class="gensmall"><?php if ($this->_rootref['S_IN_MCP'] && $this->_rootref['S_MERGE_SELECT']) {  echo ((isset($this->_rootref['L_SELECT_TOPICS_FROM'])) ? $this->_rootref['L_SELECT_TOPICS_FROM'] : ((isset($user->lang['SELECT_TOPICS_FROM'])) ? $user->lang['SELECT_TOPICS_FROM'] : '{ SELECT_TOPICS_FROM }')); } else if ($this->_rootref['S_IN_MCP']) {  echo ((isset($this->_rootref['L_MODERATE_FORUM'])) ? $this->_rootref['L_MODERATE_FORUM'] : ((isset($user->lang['MODERATE_FORUM'])) ? $user->lang['MODERATE_FORUM'] : '{ MODERATE_FORUM }')); } else { echo ((isset($this->_rootref['L_JUMP_TO'])) ? $this->_rootref['L_JUMP_TO'] : ((isset($user->lang['JUMP_TO'])) ? $user->lang['JUMP_TO'] : '{ JUMP_TO }')); } ?>:</span>&nbsp;<select name="f" onchange="if(this.options[this.selectedIndex].value != -1){ document.forms['jumpbox'].submit() }">

		<?php $_jumpbox_forums_count = (isset($this->_tpldata['jumpbox_forums'])) ? sizeof($this->_tpldata['jumpbox_forums']) : 0;if ($_jumpbox_forums_count) {for ($_jumpbox_forums_i = 0; $_jumpbox_forums_i < $_jumpbox_forums_count; ++$_jumpbox_forums_i){$_jumpbox_forums_val = &$this->_tpldata['jumpbox_forums'][$_jumpbox_forums_i]; if ($_jumpbox_forums_val['S_FORUM_COUNT'] == 1) {  ?><option value="-1">------------------</option><?php } ?>
			<option value="<?php echo $_jumpbox_forums_val['FORUM_ID']; ?>"<?php echo $_jumpbox_forums_val['SELECTED']; ?>><?php $_level_count = (isset($_jumpbox_forums_val['level'])) ? sizeof($_jumpbox_forums_val['level']) : 0;if ($_level_count) {for ($_level_i = 0; $_level_i < $_level_count; ++$_level_i){$_level_val = &$_jumpbox_forums_val['level'][$_level_i]; ?>&nbsp; &nbsp;<?php }} echo $_jumpbox_forums_val['FORUM_NAME']; ?></option>
		<?php }} ?>

		</select>&nbsp;<input class="btnlite" type="submit" value="<?php echo ((isset($this->_rootref['L_GO'])) ? $this->_rootref['L_GO'] : ((isset($user->lang['GO'])) ? $user->lang['GO'] : '{ GO }')); ?>" /></td>
	</tr>
	</table>

	</form>
<?php } ?>
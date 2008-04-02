<?php $this->_tpl_include('ucp_header.html'); ?>

<table class="tablebg" width="100%" cellspacing="1">
<tr>
	<th colspan="3"><?php echo ((isset($this->_rootref['L_USERGROUPS'])) ? $this->_rootref['L_USERGROUPS'] : ((isset($user->lang['USERGROUPS'])) ? $user->lang['USERGROUPS'] : '{ USERGROUPS }')); ?></th>
</tr>
<tr>
	<td class="row1" colspan="3"><span class="genmed"><?php echo ((isset($this->_rootref['L_GROUPS_EXPLAIN'])) ? $this->_rootref['L_GROUPS_EXPLAIN'] : ((isset($user->lang['GROUPS_EXPLAIN'])) ? $user->lang['GROUPS_EXPLAIN'] : '{ GROUPS_EXPLAIN }')); ?></span></td>
</tr>

<tr>
	<th colspan="2"><?php echo ((isset($this->_rootref['L_GROUP_DETAILS'])) ? $this->_rootref['L_GROUP_DETAILS'] : ((isset($user->lang['GROUP_DETAILS'])) ? $user->lang['GROUP_DETAILS'] : '{ GROUP_DETAILS }')); ?></th>
	<th><?php echo ((isset($this->_rootref['L_SELECT'])) ? $this->_rootref['L_SELECT'] : ((isset($user->lang['SELECT'])) ? $user->lang['SELECT'] : '{ SELECT }')); ?></th>
</tr>

<?php $_leader_count = (isset($this->_tpldata['leader'])) ? sizeof($this->_tpldata['leader']) : 0;if ($_leader_count) {for ($_leader_i = 0; $_leader_i < $_leader_count; ++$_leader_i){$_leader_val = &$this->_tpldata['leader'][$_leader_i]; if ($_leader_val['S_FIRST_ROW']) {  ?>
		<tr>
			<td class="row3" colspan="3"><b class="gensmall"><?php echo ((isset($this->_rootref['L_GROUP_LEADER'])) ? $this->_rootref['L_GROUP_LEADER'] : ((isset($user->lang['GROUP_LEADER'])) ? $user->lang['GROUP_LEADER'] : '{ GROUP_LEADER }')); ?></b></td>
		</tr>
	<?php } if (!($_leader_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>
		<td width="6%" align="center" nowrap="nowrap"><?php if ($this->_rootref['S_CHANGE_DEFAULT']) {  ?><input type="radio" class="radio" name="default"<?php if ($_leader_val['S_GROUP_DEFAULT']) {  ?> checked="checked"<?php } ?> value="<?php echo $_leader_val['GROUP_ID']; ?>" /><?php } ?></td>
		<td>
			<b class="genmed"><a href="<?php echo $_leader_val['U_VIEW_GROUP']; ?>"<?php if ($_leader_val['GROUP_COLOUR']) {  ?> style="color: #<?php echo $_leader_val['GROUP_COLOUR']; ?>;"<?php } ?>><?php echo $_leader_val['GROUP_NAME']; ?></a></b>
			<?php if ($_leader_val['GROUP_DESC']) {  ?><br /><span class="genmed"><?php echo $_leader_val['GROUP_DESC']; ?></span><?php } if (! $_leader_val['GROUP_SPECIAL']) {  ?><br /><i class="gensmall"><?php echo $_leader_val['GROUP_STATUS']; ?></i><?php } ?>
		</td>
		<td width="6%" align="center" nowrap="nowrap"><?php if (! $_leader_val['GROUP_SPECIAL']) {  ?><input type="radio" class="radio" name="selected" value="<?php echo $_leader_val['GROUP_ID']; ?>" /><?php } ?></td>
	</tr>
<?php }} $_member_count = (isset($this->_tpldata['member'])) ? sizeof($this->_tpldata['member']) : 0;if ($_member_count) {for ($_member_i = 0; $_member_i < $_member_count; ++$_member_i){$_member_val = &$this->_tpldata['member'][$_member_i]; if ($_member_val['S_FIRST_ROW']) {  ?>
		<tr>
			<td class="row3" colspan="3"><b class="gensmall"><?php echo ((isset($this->_rootref['L_GROUP_MEMBER'])) ? $this->_rootref['L_GROUP_MEMBER'] : ((isset($user->lang['GROUP_MEMBER'])) ? $user->lang['GROUP_MEMBER'] : '{ GROUP_MEMBER }')); ?></b></td>
		</tr>
	<?php } if (!($_member_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>
		<td width="6%" align="center" nowrap="nowrap"><?php if ($this->_rootref['S_CHANGE_DEFAULT']) {  ?><input type="radio" class="radio" name="default"<?php if ($_member_val['S_GROUP_DEFAULT']) {  ?> checked="checked"<?php } ?> value="<?php echo $_member_val['GROUP_ID']; ?>" /><?php } ?></td>
		<td>
			<b class="genmed"><a href="<?php echo $_member_val['U_VIEW_GROUP']; ?>"<?php if ($_member_val['GROUP_COLOUR']) {  ?> style="color: #<?php echo $_member_val['GROUP_COLOUR']; ?>;"<?php } ?>><?php echo $_member_val['GROUP_NAME']; ?></a></b>
			<?php if ($_member_val['GROUP_DESC']) {  ?><br /><span class="genmed"><?php echo $_member_val['GROUP_DESC']; ?></span><?php } if (! $_member_val['GROUP_SPECIAL']) {  ?><br /><i class="gensmall"><?php echo $_member_val['GROUP_STATUS']; ?></i><?php } ?>
		</td>
		<td width="6%" align="center" nowrap="nowrap"><?php if (! $_member_val['GROUP_SPECIAL']) {  ?><input type="radio" class="radio" name="selected" value="<?php echo $_member_val['GROUP_ID']; ?>" /><?php } ?></td>
	</tr>
<?php }} $_pending_count = (isset($this->_tpldata['pending'])) ? sizeof($this->_tpldata['pending']) : 0;if ($_pending_count) {for ($_pending_i = 0; $_pending_i < $_pending_count; ++$_pending_i){$_pending_val = &$this->_tpldata['pending'][$_pending_i]; if ($_pending_val['S_FIRST_ROW']) {  ?>
		<tr>
			<td class="row3" colspan="3"><b class="gensmall"><?php echo ((isset($this->_rootref['L_GROUP_PENDING'])) ? $this->_rootref['L_GROUP_PENDING'] : ((isset($user->lang['GROUP_PENDING'])) ? $user->lang['GROUP_PENDING'] : '{ GROUP_PENDING }')); ?></b></td>
		</tr>
	<?php } if (!($_pending_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>
		<td width="6%" align="center" nowrap="nowrap">&nbsp;</td>
		<td>
			<b class="genmed"><a href="<?php echo $_pending_val['U_VIEW_GROUP']; ?>"<?php if ($_pending_val['GROUP_COLOUR']) {  ?> style="color: #<?php echo $_pending_val['GROUP_COLOUR']; ?>;"<?php } ?>><?php echo $_pending_val['GROUP_NAME']; ?></a></b>
			<?php if ($_pending_val['GROUP_DESC']) {  ?><br /><span class="genmed"><?php echo $_pending_val['GROUP_DESC']; ?></span><?php } if (! $_pending_val['GROUP_SPECIAL']) {  ?><br /><i class="gensmall"><?php echo $_pending_val['GROUP_STATUS']; ?></i><?php } ?>
		</td>
		<td width="6%" align="center" nowrap="nowrap"><?php if (! $_pending_val['GROUP_SPECIAL']) {  ?><input type="radio" class="radio" name="selected" value="<?php echo $_pending_val['GROUP_ID']; ?>" /><?php } ?></td>
	</tr>
<?php }} $_nonmember_count = (isset($this->_tpldata['nonmember'])) ? sizeof($this->_tpldata['nonmember']) : 0;if ($_nonmember_count) {for ($_nonmember_i = 0; $_nonmember_i < $_nonmember_count; ++$_nonmember_i){$_nonmember_val = &$this->_tpldata['nonmember'][$_nonmember_i]; if ($_nonmember_val['S_FIRST_ROW']) {  ?>
		<tr>
			<td class="row3" colspan="3"><b class="gensmall"><?php echo ((isset($this->_rootref['L_GROUP_NONMEMBER'])) ? $this->_rootref['L_GROUP_NONMEMBER'] : ((isset($user->lang['GROUP_NONMEMBER'])) ? $user->lang['GROUP_NONMEMBER'] : '{ GROUP_NONMEMBER }')); ?></b></td>
		</tr>
	<?php } if (!($_nonmember_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>
		<td width="6%" align="center" nowrap="nowrap">&nbsp;</td>
		<td>
			<b class="genmed"><a href="<?php echo $_nonmember_val['U_VIEW_GROUP']; ?>"<?php if ($_nonmember_val['GROUP_COLOUR']) {  ?> style="color: #<?php echo $_nonmember_val['GROUP_COLOUR']; ?>;"<?php } ?>><?php echo $_nonmember_val['GROUP_NAME']; ?></a></b>
			<?php if ($_nonmember_val['GROUP_DESC']) {  ?><br /><span class="genmed"><?php echo $_nonmember_val['GROUP_DESC']; ?></span><?php } if (! $_nonmember_val['GROUP_SPECIAL']) {  ?><br /><i class="gensmall"><?php echo $_nonmember_val['GROUP_STATUS']; ?></i><?php } ?>
		</td>
		<td width="6%" align="center" nowrap="nowrap"><?php if ($_nonmember_val['S_CAN_JOIN']) {  ?><input type="radio" class="radio" name="selected" value="<?php echo $_nonmember_val['GROUP_ID']; ?>" /><?php } ?></td>
	</tr>
<?php }} ?>

<tr>
	<td class="cat" colspan="3"><?php if ($this->_rootref['S_CHANGE_DEFAULT']) {  ?><div style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>;"><input class="btnlite" type="submit" name="change_default" value="<?php echo ((isset($this->_rootref['L_CHANGE_DEFAULT_GROUP'])) ? $this->_rootref['L_CHANGE_DEFAULT_GROUP'] : ((isset($user->lang['CHANGE_DEFAULT_GROUP'])) ? $user->lang['CHANGE_DEFAULT_GROUP'] : '{ CHANGE_DEFAULT_GROUP }')); ?>" /></div><?php } ?><div style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>;"><span class="genmed"><?php echo ((isset($this->_rootref['L_SELECT'])) ? $this->_rootref['L_SELECT'] : ((isset($user->lang['SELECT'])) ? $user->lang['SELECT'] : '{ SELECT }')); ?>: </span><select name="action"><option value="join"><?php echo ((isset($this->_rootref['L_JOIN_SELECTED'])) ? $this->_rootref['L_JOIN_SELECTED'] : ((isset($user->lang['JOIN_SELECTED'])) ? $user->lang['JOIN_SELECTED'] : '{ JOIN_SELECTED }')); ?></option><option value="resign"><?php echo ((isset($this->_rootref['L_RESIGN_SELECTED'])) ? $this->_rootref['L_RESIGN_SELECTED'] : ((isset($user->lang['RESIGN_SELECTED'])) ? $user->lang['RESIGN_SELECTED'] : '{ RESIGN_SELECTED }')); ?></option><option value="demote"><?php echo ((isset($this->_rootref['L_DEMOTE_SELECTED'])) ? $this->_rootref['L_DEMOTE_SELECTED'] : ((isset($user->lang['DEMOTE_SELECTED'])) ? $user->lang['DEMOTE_SELECTED'] : '{ DEMOTE_SELECTED }')); ?></option></select>&nbsp;<input class="btnmain" type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />&nbsp;</div></td>
</tr>
</table>

<?php $this->_tpl_include('ucp_footer.html'); ?>
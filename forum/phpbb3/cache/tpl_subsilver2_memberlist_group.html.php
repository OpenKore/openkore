<table class="tablebg" width="100%" cellspacing="1">
<tr> 
	<th colspan="3"><?php echo ((isset($this->_rootref['L_GROUP_INFORMATION'])) ? $this->_rootref['L_GROUP_INFORMATION'] : ((isset($user->lang['GROUP_INFORMATION'])) ? $user->lang['GROUP_INFORMATION'] : '{ GROUP_INFORMATION }')); ?></th>
</tr>
<tr> 
	<td class="row1" width="20%"><b class="genmed"><?php echo ((isset($this->_rootref['L_GROUP_NAME'])) ? $this->_rootref['L_GROUP_NAME'] : ((isset($user->lang['GROUP_NAME'])) ? $user->lang['GROUP_NAME'] : '{ GROUP_NAME }')); ?>:</b></td>
	<td class="row2"><b class="gen"<?php if ($this->_rootref['GROUP_COLOR']) {  ?> style="color:#<?php echo (isset($this->_rootref['GROUP_COLOR'])) ? $this->_rootref['GROUP_COLOR'] : ''; ?>"<?php } ?>><?php echo (isset($this->_rootref['GROUP_NAME'])) ? $this->_rootref['GROUP_NAME'] : ''; ?></b></td>
<?php if ($this->_rootref['AVATAR_IMG'] || $this->_rootref['RANK_IMG'] || $this->_rootref['GROUP_RANK'] || $this->_rootref['U_PM']) {  ?>
	<td class="row1" width="33%" rowspan="2" align="center"><?php if ($this->_rootref['AVATAR_IMG']) {  echo (isset($this->_rootref['AVATAR_IMG'])) ? $this->_rootref['AVATAR_IMG'] : ''; ?><br /><?php } if ($this->_rootref['RANK_IMG']) {  echo (isset($this->_rootref['RANK_IMG'])) ? $this->_rootref['RANK_IMG'] : ''; } if ($this->_rootref['GROUP_RANK']) {  ?><span class="gensmall"><?php echo (isset($this->_rootref['GROUP_RANK'])) ? $this->_rootref['GROUP_RANK'] : ''; ?></span><br /><br /><?php } if ($this->_rootref['U_PM']) {  ?><a href="<?php echo (isset($this->_rootref['U_PM'])) ? $this->_rootref['U_PM'] : ''; ?>"><?php echo (isset($this->_rootref['PM_IMG'])) ? $this->_rootref['PM_IMG'] : ''; ?></a><?php } ?></td>
<?php } ?>
</tr>
<tr> 
	<td class="row1" width="20%"><b class="genmed"><?php echo ((isset($this->_rootref['L_GROUP_DESC'])) ? $this->_rootref['L_GROUP_DESC'] : ((isset($user->lang['GROUP_DESC'])) ? $user->lang['GROUP_DESC'] : '{ GROUP_DESC }')); ?>:</b></td>
	<td class="row2"><span class="gen"><?php echo (isset($this->_rootref['GROUP_DESC'])) ? $this->_rootref['GROUP_DESC'] : ''; ?></span><p class="forumdesc"><?php echo (isset($this->_rootref['GROUP_TYPE'])) ? $this->_rootref['GROUP_TYPE'] : ''; ?></p></td>
</tr>
</table>
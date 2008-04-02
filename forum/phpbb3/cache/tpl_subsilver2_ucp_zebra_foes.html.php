<?php $this->_tpl_include('ucp_header.html'); ?>

<table class="tablebg" width="100%" cellspacing="1">
<tr>
	<th colspan="2" valign="middle"><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></th>
</tr>
<tr>
	<td class="row3" colspan="2"><span class="gensmall"><?php echo ((isset($this->_rootref['L_FOES_EXPLAIN'])) ? $this->_rootref['L_FOES_EXPLAIN'] : ((isset($user->lang['FOES_EXPLAIN'])) ? $user->lang['FOES_EXPLAIN'] : '{ FOES_EXPLAIN }')); ?></span></td>
</tr>
<?php if ($this->_rootref['ERROR']) {  ?>
	<tr>
		<td class="row3" colspan="2" align="center"><span class="gensmall error"><?php echo (isset($this->_rootref['ERROR'])) ? $this->_rootref['ERROR'] : ''; ?></span></td>
	</tr>
<?php } ?>
<tr>
	<td class="row1" width="40%"><b class="genmed"><?php echo ((isset($this->_rootref['L_YOUR_FOES'])) ? $this->_rootref['L_YOUR_FOES'] : ((isset($user->lang['YOUR_FOES'])) ? $user->lang['YOUR_FOES'] : '{ YOUR_FOES }')); ?>:</b><br /><span class="gensmall"><?php echo ((isset($this->_rootref['L_YOUR_FOES_EXPLAIN'])) ? $this->_rootref['L_YOUR_FOES_EXPLAIN'] : ((isset($user->lang['YOUR_FOES_EXPLAIN'])) ? $user->lang['YOUR_FOES_EXPLAIN'] : '{ YOUR_FOES_EXPLAIN }')); ?></span></td>
	<td class="row2" align="center"><?php if ($this->_rootref['S_USERNAME_OPTIONS']) {  ?><select name="usernames[]" multiple="multiple" size="5"><?php echo (isset($this->_rootref['S_USERNAME_OPTIONS'])) ? $this->_rootref['S_USERNAME_OPTIONS'] : ''; ?></select><?php } else { ?><b class="genmed"><?php echo ((isset($this->_rootref['L_NO_FOES'])) ? $this->_rootref['L_NO_FOES'] : ((isset($user->lang['NO_FOES'])) ? $user->lang['NO_FOES'] : '{ NO_FOES }')); ?></b><?php } ?></td>
</tr>
<tr>
	<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_ADD_FOES'])) ? $this->_rootref['L_ADD_FOES'] : ((isset($user->lang['ADD_FOES'])) ? $user->lang['ADD_FOES'] : '{ ADD_FOES }')); ?>:</b><br /><span class="gensmall"><?php echo ((isset($this->_rootref['L_ADD_FOES_EXPLAIN'])) ? $this->_rootref['L_ADD_FOES_EXPLAIN'] : ((isset($user->lang['ADD_FOES_EXPLAIN'])) ? $user->lang['ADD_FOES_EXPLAIN'] : '{ ADD_FOES_EXPLAIN }')); ?> [ <a href="<?php echo (isset($this->_rootref['U_FIND_USERNAME'])) ? $this->_rootref['U_FIND_USERNAME'] : ''; ?>" onclick="find_username(this.href); return false;"><?php echo ((isset($this->_rootref['L_FIND_USERNAME'])) ? $this->_rootref['L_FIND_USERNAME'] : ((isset($user->lang['FIND_USERNAME'])) ? $user->lang['FIND_USERNAME'] : '{ FIND_USERNAME }')); ?></a> ]</span></td>
	<td class="row2" align="center"><textarea name="add" rows="5" cols="30"><?php echo (isset($this->_rootref['USERNAMES'])) ? $this->_rootref['USERNAMES'] : ''; ?></textarea><br /></td>
</tr>
<tr>
	<td class="cat" colspan="2" align="center"><?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?><input class="btnmain" type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />&nbsp;&nbsp;<input class="btnlite" type="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" name="reset" /></td>
</tr>
</table>
<!-- TEST --><?php $this->_tpl_include('ucp_footer.html'); ?>
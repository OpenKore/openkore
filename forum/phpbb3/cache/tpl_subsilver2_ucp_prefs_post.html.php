<?php $this->_tpl_include('ucp_header.html'); ?>

<table class="tablebg" width="100%" cellspacing="1">
<tr>
	<th colspan="2" valign="middle"><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></th>
</tr>
<?php if ($this->_rootref['ERROR']) {  ?>
	<tr>
		<td class="row3" colspan="2" align="center"><span class="gensmall error"><?php echo (isset($this->_rootref['ERROR'])) ? $this->_rootref['ERROR'] : ''; ?></span></td>
	</tr>
<?php } ?>
<tr>
	<td class="row1" width="50%"><b class="genmed"><?php echo ((isset($this->_rootref['L_DEFAULT_BBCODE'])) ? $this->_rootref['L_DEFAULT_BBCODE'] : ((isset($user->lang['DEFAULT_BBCODE'])) ? $user->lang['DEFAULT_BBCODE'] : '{ DEFAULT_BBCODE }')); ?>:</b></td>
	<td class="row2"><input type="radio" class="radio" name="bbcode" value="1"<?php if ($this->_rootref['S_BBCODE']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></span>&nbsp; &nbsp;<input type="radio" class="radio" name="bbcode" value="0"<?php if (! $this->_rootref['S_BBCODE']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></span></td>
</tr>
<tr>
	<td class="row1" width="50%"><b class="genmed"><?php echo ((isset($this->_rootref['L_DEFAULT_SMILIES'])) ? $this->_rootref['L_DEFAULT_SMILIES'] : ((isset($user->lang['DEFAULT_SMILIES'])) ? $user->lang['DEFAULT_SMILIES'] : '{ DEFAULT_SMILIES }')); ?>:</b></td>
	<td class="row2"><input type="radio" class="radio" name="smilies" value="1"<?php if ($this->_rootref['S_SMILIES']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></span>&nbsp; &nbsp;<input type="radio" class="radio" name="smilies" value="0"<?php if (! $this->_rootref['S_SMILIES']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></span></td>
</tr>
<tr>
	<td class="row1" width="50%"><b class="genmed"><?php echo ((isset($this->_rootref['L_DEFAULT_ADD_SIG'])) ? $this->_rootref['L_DEFAULT_ADD_SIG'] : ((isset($user->lang['DEFAULT_ADD_SIG'])) ? $user->lang['DEFAULT_ADD_SIG'] : '{ DEFAULT_ADD_SIG }')); ?>:</b></td>
	<td class="row2"><input type="radio" class="radio" name="sig" value="1"<?php if ($this->_rootref['S_SIG']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></span>&nbsp; &nbsp;<input type="radio" class="radio" name="sig" value="0"<?php if (! $this->_rootref['S_SIG']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></span></td>
</tr>
<tr>
	<td class="row1" width="50%"><b class="genmed"><?php echo ((isset($this->_rootref['L_DEFAULT_NOTIFY'])) ? $this->_rootref['L_DEFAULT_NOTIFY'] : ((isset($user->lang['DEFAULT_NOTIFY'])) ? $user->lang['DEFAULT_NOTIFY'] : '{ DEFAULT_NOTIFY }')); ?>:</b></td>
	<td class="row2"><input type="radio" class="radio" name="notify" value="1"<?php if ($this->_rootref['S_NOTIFY']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></span>&nbsp; &nbsp;<input type="radio" class="radio" name="notify" value="0"<?php if (! $this->_rootref['S_NOTIFY']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></span></td>
</tr>
<tr>
	<td class="cat" colspan="2" align="center"><?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?><input class="btnmain" type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />&nbsp;&nbsp;<input class="btnlite" type="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" name="reset" /></td>
</tr>
</table>

<?php $this->_tpl_include('ucp_footer.html'); ?>
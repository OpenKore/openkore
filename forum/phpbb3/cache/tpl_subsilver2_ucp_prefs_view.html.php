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
	<td class="row1" width="50%"><b class="genmed"><?php echo ((isset($this->_rootref['L_VIEW_IMAGES'])) ? $this->_rootref['L_VIEW_IMAGES'] : ((isset($user->lang['VIEW_IMAGES'])) ? $user->lang['VIEW_IMAGES'] : '{ VIEW_IMAGES }')); ?>:</b></td>
	<td class="row2"><input type="radio" class="radio" name="images" value="1"<?php if ($this->_rootref['S_IMAGES']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></span>&nbsp; &nbsp;<input type="radio" class="radio" name="images" value="0"<?php if (! $this->_rootref['S_IMAGES']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></span></td>
</tr>
<tr>
	<td class="row1" width="50%"><b class="genmed"><?php echo ((isset($this->_rootref['L_VIEW_FLASH'])) ? $this->_rootref['L_VIEW_FLASH'] : ((isset($user->lang['VIEW_FLASH'])) ? $user->lang['VIEW_FLASH'] : '{ VIEW_FLASH }')); ?>:</b></td>
	<td class="row2"><input type="radio" class="radio" name="flash" value="1"<?php if ($this->_rootref['S_FLASH']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></span>&nbsp; &nbsp;<input type="radio" class="radio" name="flash" value="0"<?php if (! $this->_rootref['S_FLASH']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></span></td>
</tr>
<tr>
	<td class="row1" width="50%"><b class="genmed"><?php echo ((isset($this->_rootref['L_VIEW_SMILIES'])) ? $this->_rootref['L_VIEW_SMILIES'] : ((isset($user->lang['VIEW_SMILIES'])) ? $user->lang['VIEW_SMILIES'] : '{ VIEW_SMILIES }')); ?>:</b></td>
	<td class="row2"><input type="radio" class="radio" name="smilies" value="1"<?php if ($this->_rootref['S_SMILIES']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></span>&nbsp; &nbsp;<input type="radio" class="radio" name="smilies" value="0"<?php if (! $this->_rootref['S_SMILIES']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></span></td>
</tr>
<tr>
	<td class="row1" width="50%"><b class="genmed"><?php echo ((isset($this->_rootref['L_VIEW_SIGS'])) ? $this->_rootref['L_VIEW_SIGS'] : ((isset($user->lang['VIEW_SIGS'])) ? $user->lang['VIEW_SIGS'] : '{ VIEW_SIGS }')); ?>:</b></td>
	<td class="row2"><input type="radio" class="radio" name="sigs" value="1"<?php if ($this->_rootref['S_SIGS']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></span>&nbsp; &nbsp;<input type="radio" class="radio" name="sigs" value="0"<?php if (! $this->_rootref['S_SIGS']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></span></td>
</tr>
<tr>
	<td class="row1" width="50%"><b class="genmed"><?php echo ((isset($this->_rootref['L_VIEW_AVATARS'])) ? $this->_rootref['L_VIEW_AVATARS'] : ((isset($user->lang['VIEW_AVATARS'])) ? $user->lang['VIEW_AVATARS'] : '{ VIEW_AVATARS }')); ?>:</b></td>
	<td class="row2"><input type="radio" class="radio" name="avatars" value="1"<?php if ($this->_rootref['S_AVATARS']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></span>&nbsp; &nbsp;<input type="radio" class="radio" name="avatars" value="0"<?php if (! $this->_rootref['S_AVATARS']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></span></td>
</tr>
<?php if ($this->_rootref['S_CHANGE_CENSORS']) {  ?>
	<tr>
		<td class="row1" width="50%"><b class="genmed"><?php echo ((isset($this->_rootref['L_DISABLE_CENSORS'])) ? $this->_rootref['L_DISABLE_CENSORS'] : ((isset($user->lang['DISABLE_CENSORS'])) ? $user->lang['DISABLE_CENSORS'] : '{ DISABLE_CENSORS }')); ?>:</b></td>
		<td class="row2"><input type="radio" class="radio" name="wordcensor" value="1"<?php if ($this->_rootref['S_DISABLE_CENSORS']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></span>&nbsp; &nbsp;<input type="radio" class="radio" name="wordcensor" value="0"<?php if (! $this->_rootref['S_DISABLE_CENSORS']) {  ?> checked="checked"<?php } ?> /><span class="gen"><?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></span></td>
	</tr>
<?php } ?>
<tr>
	<td colspan="2" class="spacer"></td>
</tr>
<tr>
	<td class="row1" width="50%"><b class="genmed"><?php echo ((isset($this->_rootref['L_VIEW_TOPICS_DAYS'])) ? $this->_rootref['L_VIEW_TOPICS_DAYS'] : ((isset($user->lang['VIEW_TOPICS_DAYS'])) ? $user->lang['VIEW_TOPICS_DAYS'] : '{ VIEW_TOPICS_DAYS }')); ?>:</b></td>
	<td class="row2"><?php echo (isset($this->_rootref['S_TOPIC_SORT_DAYS'])) ? $this->_rootref['S_TOPIC_SORT_DAYS'] : ''; ?></td>
</tr>
<tr>
	<td class="row1" width="50%"><b class="genmed"><?php echo ((isset($this->_rootref['L_VIEW_TOPICS_KEY'])) ? $this->_rootref['L_VIEW_TOPICS_KEY'] : ((isset($user->lang['VIEW_TOPICS_KEY'])) ? $user->lang['VIEW_TOPICS_KEY'] : '{ VIEW_TOPICS_KEY }')); ?>:</b></td>
	<td class="row2"><?php echo (isset($this->_rootref['S_TOPIC_SORT_KEY'])) ? $this->_rootref['S_TOPIC_SORT_KEY'] : ''; ?></td>
</tr>
<tr>
	<td class="row1" width="50%"><b class="genmed"><?php echo ((isset($this->_rootref['L_VIEW_TOPICS_DIR'])) ? $this->_rootref['L_VIEW_TOPICS_DIR'] : ((isset($user->lang['VIEW_TOPICS_DIR'])) ? $user->lang['VIEW_TOPICS_DIR'] : '{ VIEW_TOPICS_DIR }')); ?>:</b></td>
	<td class="row2"><?php echo (isset($this->_rootref['S_TOPIC_SORT_DIR'])) ? $this->_rootref['S_TOPIC_SORT_DIR'] : ''; ?></td>
</tr>
<tr>
	<td colspan="2" class="spacer"></td>
</tr>
<tr>
	<td class="row1" width="50%"><b class="genmed"><?php echo ((isset($this->_rootref['L_VIEW_POSTS_DAYS'])) ? $this->_rootref['L_VIEW_POSTS_DAYS'] : ((isset($user->lang['VIEW_POSTS_DAYS'])) ? $user->lang['VIEW_POSTS_DAYS'] : '{ VIEW_POSTS_DAYS }')); ?>:</b></td>
	<td class="row2"><?php echo (isset($this->_rootref['S_POST_SORT_DAYS'])) ? $this->_rootref['S_POST_SORT_DAYS'] : ''; ?></td>
</tr>
<tr>
	<td class="row1" width="50%"><b class="genmed"><?php echo ((isset($this->_rootref['L_VIEW_POSTS_KEY'])) ? $this->_rootref['L_VIEW_POSTS_KEY'] : ((isset($user->lang['VIEW_POSTS_KEY'])) ? $user->lang['VIEW_POSTS_KEY'] : '{ VIEW_POSTS_KEY }')); ?>:</b></td>
	<td class="row2"><?php echo (isset($this->_rootref['S_POST_SORT_KEY'])) ? $this->_rootref['S_POST_SORT_KEY'] : ''; ?></td>
</tr>
<tr>
	<td class="row1" width="50%"><b class="genmed"><?php echo ((isset($this->_rootref['L_VIEW_POSTS_DIR'])) ? $this->_rootref['L_VIEW_POSTS_DIR'] : ((isset($user->lang['VIEW_POSTS_DIR'])) ? $user->lang['VIEW_POSTS_DIR'] : '{ VIEW_POSTS_DIR }')); ?>:</b></td>
	<td class="row2"><?php echo (isset($this->_rootref['S_POST_SORT_DIR'])) ? $this->_rootref['S_POST_SORT_DIR'] : ''; ?></td>
</tr>
<tr>
	<td class="cat" colspan="2" align="center"><?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?><input class="btnmain" type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />&nbsp;&nbsp;<input class="btnlite" type="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" name="reset" /></td>
</tr>
</table>

<?php $this->_tpl_include('ucp_footer.html'); ?>
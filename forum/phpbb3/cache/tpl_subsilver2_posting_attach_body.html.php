<tr>
	<th colspan="2">
		<script type="text/javascript">
		// <![CDATA[
			/**
			* Show upload progress bar
			*/
			function popup_progress_bar()
			{
				close_waitscreen = 0;
				// no scrollbars
				popup('<?php echo (isset($this->_rootref['UA_PROGRESS_BAR'])) ? $this->_rootref['UA_PROGRESS_BAR'] : ''; ?>', 400, 200, '_upload');
			}
		// ]]>
		</script>

		<?php if ($this->_rootref['S_CLOSE_PROGRESS_WINDOW']) {  ?>
			<script type="text/javascript">
			// <![CDATA[
				close_waitscreen = 1;
			// ]]>
			</script>
		<?php } ?>

		<?php echo ((isset($this->_rootref['L_ADD_ATTACHMENT'])) ? $this->_rootref['L_ADD_ATTACHMENT'] : ((isset($user->lang['ADD_ATTACHMENT'])) ? $user->lang['ADD_ATTACHMENT'] : '{ ADD_ATTACHMENT }')); ?>
	</th>
</tr>
<tr>
	<td class="row3" colspan="2"><span class="gensmall"><?php echo ((isset($this->_rootref['L_ADD_ATTACHMENT_EXPLAIN'])) ? $this->_rootref['L_ADD_ATTACHMENT_EXPLAIN'] : ((isset($user->lang['ADD_ATTACHMENT_EXPLAIN'])) ? $user->lang['ADD_ATTACHMENT_EXPLAIN'] : '{ ADD_ATTACHMENT_EXPLAIN }')); ?></span></td>
</tr>

<tr> 
	<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_FILENAME'])) ? $this->_rootref['L_FILENAME'] : ((isset($user->lang['FILENAME'])) ? $user->lang['FILENAME'] : '{ FILENAME }')); ?></b></td> 
	<td class="row2"><input type="file" name="fileupload" size="40" maxlength="<?php echo (isset($this->_rootref['FILESIZE'])) ? $this->_rootref['FILESIZE'] : ''; ?>" value="" class="btnfile" /></td> 
</tr> 
<tr> 
	<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_FILE_COMMENT'])) ? $this->_rootref['L_FILE_COMMENT'] : ((isset($user->lang['FILE_COMMENT'])) ? $user->lang['FILE_COMMENT'] : '{ FILE_COMMENT }')); ?></b></td> 
	<td class="row2">
		<table border="0" cellspacing="0" cellpadding="2">
		<tr>
			<td><textarea class="post" name="filecomment" rows="3" cols="35"><?php echo (isset($this->_rootref['FILE_COMMENT'])) ? $this->_rootref['FILE_COMMENT'] : ''; ?></textarea>&nbsp;</td>
			<td valign="top">
				<table border="0" cellspacing="4" cellpadding="0">
				<tr>
					<td><input class="btnlite" type="submit" style="width:150px" name="add_file" value="<?php echo ((isset($this->_rootref['L_ADD_FILE'])) ? $this->_rootref['L_ADD_FILE'] : ((isset($user->lang['ADD_FILE'])) ? $user->lang['ADD_FILE'] : '{ ADD_FILE }')); ?>" onclick="popup_progress_bar();" /></td>
				</tr>
				</table>
			</td>
		</tr>
		</table>
	</td>
</tr> 

<?php if ($this->_rootref['S_HAS_ATTACHMENTS']) {  ?>
	<tr>
		<th colspan="2"><?php echo ((isset($this->_rootref['L_POSTED_ATTACHMENTS'])) ? $this->_rootref['L_POSTED_ATTACHMENTS'] : ((isset($user->lang['POSTED_ATTACHMENTS'])) ? $user->lang['POSTED_ATTACHMENTS'] : '{ POSTED_ATTACHMENTS }')); ?></th>
	</tr>

	<?php $_attach_row_count = (isset($this->_tpldata['attach_row'])) ? sizeof($this->_tpldata['attach_row']) : 0;if ($_attach_row_count) {for ($_attach_row_i = 0; $_attach_row_i < $_attach_row_count; ++$_attach_row_i){$_attach_row_val = &$this->_tpldata['attach_row'][$_attach_row_i]; ?>
		<tr>
			<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_FILENAME'])) ? $this->_rootref['L_FILENAME'] : ((isset($user->lang['FILENAME'])) ? $user->lang['FILENAME'] : '{ FILENAME }')); ?></b></td>
			<td class="row2"><a class="genmed" href="<?php echo $_attach_row_val['U_VIEW_ATTACHMENT']; ?>" target="_blank"><?php echo $_attach_row_val['FILENAME']; ?></a></td> 
		</tr>
		<tr> 
			<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_FILE_COMMENT'])) ? $this->_rootref['L_FILE_COMMENT'] : ((isset($user->lang['FILE_COMMENT'])) ? $user->lang['FILE_COMMENT'] : '{ FILE_COMMENT }')); ?></b></td> 
			<td class="row2"><?php echo $_attach_row_val['S_HIDDEN']; ?>
				<table border="0" cellspacing="0" cellpadding="2">
				<tr>
					<td><textarea class="post" name="comment_list[<?php echo $_attach_row_val['ASSOC_INDEX']; ?>]" rows="3" cols="35" wrap="virtual"><?php echo $_attach_row_val['FILE_COMMENT']; ?></textarea>&nbsp;</td>
					<td valign="top">
						<table border="0" cellspacing="4" cellpadding="0">
						<tr>
							<td><input class="btnlite" type="submit" style="width:150px" name="delete_file[<?php echo $_attach_row_val['ASSOC_INDEX']; ?>]" value="<?php echo ((isset($this->_rootref['L_DELETE_FILE'])) ? $this->_rootref['L_DELETE_FILE'] : ((isset($user->lang['DELETE_FILE'])) ? $user->lang['DELETE_FILE'] : '{ DELETE_FILE }')); ?>" /></td>
						</tr>
						</table>
					</td>
				</tr>
				</table>
			</td>
		</tr>
	<?php }} } ?>
<?php $this->_tpl_include('ucp_header.html'); $this->_tpldata['DEFINE']['.']['S_SIGNATURE'] = 1; ?>
<table class="tablebg" width="100%" cellspacing="1">
<tr>
	<th colspan="2"><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></th>
</tr>
<tr>
	<td colspan="2" class="row1"><?php echo ((isset($this->_rootref['L_SIGNATURE_EXPLAIN'])) ? $this->_rootref['L_SIGNATURE_EXPLAIN'] : ((isset($user->lang['SIGNATURE_EXPLAIN'])) ? $user->lang['SIGNATURE_EXPLAIN'] : '{ SIGNATURE_EXPLAIN }')); ?></td>
</tr>

<?php if ($this->_rootref['ERROR']) {  ?>
	<tr>
		<td class="row3" colspan="2" align="center"><span class="genmed error"><?php echo (isset($this->_rootref['ERROR'])) ? $this->_rootref['ERROR'] : ''; ?></span></td>
	</tr>
<?php } ?>

<tr>
	<td colspan="2" class="row2">
		<script type="text/javascript">
		// <![CDATA[
			var form_name = 'ucp';
			var text_name = 'signature';
		// ]]>
		</script>
		
		<table cellspacing="0" cellpadding="2" border="0" width="99%">
		<?php $this->_tpl_include('posting_buttons.html'); ?>
		<tr>
			<td colspan="2"><textarea class="post" name="signature" rows="10" cols="76" style="width: 90%;" onselect="storeCaret(this);" onclick="storeCaret(this);" onkeyup="storeCaret(this);"><?php echo (isset($this->_rootref['SIGNATURE'])) ? $this->_rootref['SIGNATURE'] : ''; ?></textarea></td>
		</tr>
		<?php if ($this->_rootref['S_BBCODE_ALLOWED']) {  ?>
		<tr>
			<td colspan="2">
				<table cellspacing="0" cellpadding="0" border="0" width="100%">
				<tr>
					<td align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>">
						<script type="text/javascript">
						// <![CDATA[
							colorPalette('h', 6, 5)
						// ]]>
						</script>
					</td>
				</tr>
				</table>
			</td>
		</tr>
		<?php } ?>
		</table>
	</td>
</tr>
<tr>
	<td class="row1" valign="top"><b class="genmed"><?php echo ((isset($this->_rootref['L_OPTIONS'])) ? $this->_rootref['L_OPTIONS'] : ((isset($user->lang['OPTIONS'])) ? $user->lang['OPTIONS'] : '{ OPTIONS }')); ?></b><br />
		<table cellspacing="2" cellpadding="0" border="0">
		<tr>
			<td class="gensmall"><?php echo (isset($this->_rootref['BBCODE_STATUS'])) ? $this->_rootref['BBCODE_STATUS'] : ''; ?></td>
		</tr>
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
		</table>
	</td>
	<td class="row2" valign="top">
		<table cellspacing="0" cellpadding="1" border="0">
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
		<?php } ?>
		</table>
	</td>
</tr>

<?php if ($this->_rootref['SIGNATURE_PREVIEW']) {  ?>
	<tr>
		<th colspan="2" valign="middle"><?php echo ((isset($this->_rootref['L_SIGNATURE_PREVIEW'])) ? $this->_rootref['L_SIGNATURE_PREVIEW'] : ((isset($user->lang['SIGNATURE_PREVIEW'])) ? $user->lang['SIGNATURE_PREVIEW'] : '{ SIGNATURE_PREVIEW }')); ?></th>
	</tr>
	<tr> 
		<td class="row1" colspan="2"><div class="postbody" style="padding: 6px;"><?php echo (isset($this->_rootref['SIGNATURE_PREVIEW'])) ? $this->_rootref['SIGNATURE_PREVIEW'] : ''; ?></div></td>
	</tr>
<?php } ?>

<tr>
	<td class="cat" colspan="2" align="center"><?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?><input class="btnlite" type="submit" name="preview" value="<?php echo ((isset($this->_rootref['L_PREVIEW'])) ? $this->_rootref['L_PREVIEW'] : ((isset($user->lang['PREVIEW'])) ? $user->lang['PREVIEW'] : '{ PREVIEW }')); ?>" />&nbsp;&nbsp;<input class="btnmain" type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />&nbsp;&nbsp;<input class="btnlite" type="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" name="reset" /></td>
</tr>
</table>

<?php $this->_tpl_include('ucp_footer.html'); ?>
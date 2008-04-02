<?php $this->_tpl_include('ucp_header.html'); ?>

<form id="postform" method="post" action="<?php echo (isset($this->_rootref['S_UCP_ACTION'])) ? $this->_rootref['S_UCP_ACTION'] : ''; ?>"<?php echo (isset($this->_rootref['S_FORM_ENCTYPE'])) ? $this->_rootref['S_FORM_ENCTYPE'] : ''; ?>>

<h2><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></h2>

<?php if ($this->_rootref['SIGNATURE_PREVIEW']) {  ?>
	<div class="panel">
		<div class="inner"><span class="corners-top"><span></span></span>
		<h3><?php echo ((isset($this->_rootref['L_SIGNATURE_PREVIEW'])) ? $this->_rootref['L_SIGNATURE_PREVIEW'] : ((isset($user->lang['SIGNATURE_PREVIEW'])) ? $user->lang['SIGNATURE_PREVIEW'] : '{ SIGNATURE_PREVIEW }')); ?></h3>
		<div class="postbody pm">
			<div class="signature" style="border-top:none; margin-top: 0; "><?php echo (isset($this->_rootref['SIGNATURE_PREVIEW'])) ? $this->_rootref['SIGNATURE_PREVIEW'] : ''; ?></div>
		</div>
		<span class="corners-bottom"><span></span></span></div>
	</div>
<?php } ?>

<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>

	<p><?php echo ((isset($this->_rootref['L_SIGNATURE_EXPLAIN'])) ? $this->_rootref['L_SIGNATURE_EXPLAIN'] : ((isset($user->lang['SIGNATURE_EXPLAIN'])) ? $user->lang['SIGNATURE_EXPLAIN'] : '{ SIGNATURE_EXPLAIN }')); ?></p>

	<?php $this->_tpldata['DEFINE']['.']['SIG_EDIT'] = 1; $this->_tpl_include('posting_editor.html'); ?>
	<h3><?php echo ((isset($this->_rootref['L_OPTIONS'])) ? $this->_rootref['L_OPTIONS'] : ((isset($user->lang['OPTIONS'])) ? $user->lang['OPTIONS'] : '{ OPTIONS }')); ?></h3>
	<fieldset>
		<?php if ($this->_rootref['S_BBCODE_ALLOWED']) {  ?>
			<div><label for="disable_bbcode"><input type="checkbox" name="disable_bbcode" id="disable_bbcode"<?php echo (isset($this->_rootref['S_BBCODE_CHECKED'])) ? $this->_rootref['S_BBCODE_CHECKED'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_DISABLE_BBCODE'])) ? $this->_rootref['L_DISABLE_BBCODE'] : ((isset($user->lang['DISABLE_BBCODE'])) ? $user->lang['DISABLE_BBCODE'] : '{ DISABLE_BBCODE }')); ?></label></div>
		<?php } if ($this->_rootref['S_SMILIES_ALLOWED']) {  ?>
			<div><label for="disable_smilies"><input type="checkbox" name="disable_smilies" id="disable_smilies"<?php echo (isset($this->_rootref['S_SMILIES_CHECKED'])) ? $this->_rootref['S_SMILIES_CHECKED'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_DISABLE_SMILIES'])) ? $this->_rootref['L_DISABLE_SMILIES'] : ((isset($user->lang['DISABLE_SMILIES'])) ? $user->lang['DISABLE_SMILIES'] : '{ DISABLE_SMILIES }')); ?></label></div>
		<?php } if ($this->_rootref['S_LINKS_ALLOWED']) {  ?>
			<div><label for="disable_magic_url"><input type="checkbox" name="disable_magic_url" id="disable_magic_url"<?php echo (isset($this->_rootref['S_MAGIC_URL_CHECKED'])) ? $this->_rootref['S_MAGIC_URL_CHECKED'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_DISABLE_MAGIC_URL'])) ? $this->_rootref['L_DISABLE_MAGIC_URL'] : ((isset($user->lang['DISABLE_MAGIC_URL'])) ? $user->lang['DISABLE_MAGIC_URL'] : '{ DISABLE_MAGIC_URL }')); ?></label></div>
		<?php } ?>
	
	</fieldset>

	<span class="corners-bottom"><span></span></span></div>
</div>

<fieldset class="submit-buttons">
	<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?>
	<input type="reset" name="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" class="button2" />&nbsp; 
	<input type="submit" name="preview" value="<?php echo ((isset($this->_rootref['L_PREVIEW'])) ? $this->_rootref['L_PREVIEW'] : ((isset($user->lang['PREVIEW'])) ? $user->lang['PREVIEW'] : '{ PREVIEW }')); ?>" class="button2" />&nbsp; 
	<input type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" class="button1" />
	<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
</fieldset>
</form>

<?php $this->_tpl_include('ucp_footer.html'); ?>
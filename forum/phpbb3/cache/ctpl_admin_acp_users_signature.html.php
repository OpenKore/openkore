<script type="text/javascript">
// <![CDATA[

	var form_name = 'user_signature';
	var text_name = 'signature';

	// Define the bbCode tags
	var bbcode = new Array();
	var bbtags = new Array('[b]','[/b]','[i]','[/i]','[u]','[/u]','[quote]','[/quote]','[code]','[/code]','[list]','[/list]','[list=]','[/list]','[img]','[/img]','[url]','[/url]','[flash=]', '[/flash]','[size=]','[/size]'<?php $_custom_tags_count = (isset($this->_tpldata['custom_tags'])) ? sizeof($this->_tpldata['custom_tags']) : 0;if ($_custom_tags_count) {for ($_custom_tags_i = 0; $_custom_tags_i < $_custom_tags_count; ++$_custom_tags_i){$_custom_tags_val = &$this->_tpldata['custom_tags'][$_custom_tags_i]; ?>, <?php echo $_custom_tags_val['BBCODE_NAME']; }} ?>);
	var imageTag = false;

	// Helpline messages
	var help_line = {
		b: '<?php echo ((isset($this->_rootref['LA_BBCODE_B_HELP'])) ? $this->_rootref['LA_BBCODE_B_HELP'] : ((isset($this->_rootref['L_BBCODE_B_HELP'])) ? addslashes($this->_rootref['L_BBCODE_B_HELP']) : ((isset($user->lang['BBCODE_B_HELP'])) ? addslashes($user->lang['BBCODE_B_HELP']) : '{ BBCODE_B_HELP }'))); ?>',
		i: '<?php echo ((isset($this->_rootref['LA_BBCODE_I_HELP'])) ? $this->_rootref['LA_BBCODE_I_HELP'] : ((isset($this->_rootref['L_BBCODE_I_HELP'])) ? addslashes($this->_rootref['L_BBCODE_I_HELP']) : ((isset($user->lang['BBCODE_I_HELP'])) ? addslashes($user->lang['BBCODE_I_HELP']) : '{ BBCODE_I_HELP }'))); ?>',
		u: '<?php echo ((isset($this->_rootref['LA_BBCODE_U_HELP'])) ? $this->_rootref['LA_BBCODE_U_HELP'] : ((isset($this->_rootref['L_BBCODE_U_HELP'])) ? addslashes($this->_rootref['L_BBCODE_U_HELP']) : ((isset($user->lang['BBCODE_U_HELP'])) ? addslashes($user->lang['BBCODE_U_HELP']) : '{ BBCODE_U_HELP }'))); ?>',
		q: '<?php echo ((isset($this->_rootref['LA_BBCODE_Q_HELP'])) ? $this->_rootref['LA_BBCODE_Q_HELP'] : ((isset($this->_rootref['L_BBCODE_Q_HELP'])) ? addslashes($this->_rootref['L_BBCODE_Q_HELP']) : ((isset($user->lang['BBCODE_Q_HELP'])) ? addslashes($user->lang['BBCODE_Q_HELP']) : '{ BBCODE_Q_HELP }'))); ?>',
		c: '<?php echo ((isset($this->_rootref['LA_BBCODE_C_HELP'])) ? $this->_rootref['LA_BBCODE_C_HELP'] : ((isset($this->_rootref['L_BBCODE_C_HELP'])) ? addslashes($this->_rootref['L_BBCODE_C_HELP']) : ((isset($user->lang['BBCODE_C_HELP'])) ? addslashes($user->lang['BBCODE_C_HELP']) : '{ BBCODE_C_HELP }'))); ?>',
		l: '<?php echo ((isset($this->_rootref['LA_BBCODE_L_HELP'])) ? $this->_rootref['LA_BBCODE_L_HELP'] : ((isset($this->_rootref['L_BBCODE_L_HELP'])) ? addslashes($this->_rootref['L_BBCODE_L_HELP']) : ((isset($user->lang['BBCODE_L_HELP'])) ? addslashes($user->lang['BBCODE_L_HELP']) : '{ BBCODE_L_HELP }'))); ?>',
		o: '<?php echo ((isset($this->_rootref['LA_BBCODE_O_HELP'])) ? $this->_rootref['LA_BBCODE_O_HELP'] : ((isset($this->_rootref['L_BBCODE_O_HELP'])) ? addslashes($this->_rootref['L_BBCODE_O_HELP']) : ((isset($user->lang['BBCODE_O_HELP'])) ? addslashes($user->lang['BBCODE_O_HELP']) : '{ BBCODE_O_HELP }'))); ?>',
		p: '<?php echo ((isset($this->_rootref['LA_BBCODE_P_HELP'])) ? $this->_rootref['LA_BBCODE_P_HELP'] : ((isset($this->_rootref['L_BBCODE_P_HELP'])) ? addslashes($this->_rootref['L_BBCODE_P_HELP']) : ((isset($user->lang['BBCODE_P_HELP'])) ? addslashes($user->lang['BBCODE_P_HELP']) : '{ BBCODE_P_HELP }'))); ?>',
		w: '<?php echo ((isset($this->_rootref['LA_BBCODE_W_HELP'])) ? $this->_rootref['LA_BBCODE_W_HELP'] : ((isset($this->_rootref['L_BBCODE_W_HELP'])) ? addslashes($this->_rootref['L_BBCODE_W_HELP']) : ((isset($user->lang['BBCODE_W_HELP'])) ? addslashes($user->lang['BBCODE_W_HELP']) : '{ BBCODE_W_HELP }'))); ?>',
		s: '<?php echo ((isset($this->_rootref['LA_BBCODE_S_HELP'])) ? $this->_rootref['LA_BBCODE_S_HELP'] : ((isset($this->_rootref['L_BBCODE_S_HELP'])) ? addslashes($this->_rootref['L_BBCODE_S_HELP']) : ((isset($user->lang['BBCODE_S_HELP'])) ? addslashes($user->lang['BBCODE_S_HELP']) : '{ BBCODE_S_HELP }'))); ?>',
		f: '<?php echo ((isset($this->_rootref['LA_BBCODE_F_HELP'])) ? $this->_rootref['LA_BBCODE_F_HELP'] : ((isset($this->_rootref['L_BBCODE_F_HELP'])) ? addslashes($this->_rootref['L_BBCODE_F_HELP']) : ((isset($user->lang['BBCODE_F_HELP'])) ? addslashes($user->lang['BBCODE_F_HELP']) : '{ BBCODE_F_HELP }'))); ?>',
		e: '<?php echo ((isset($this->_rootref['LA_BBCODE_E_HELP'])) ? $this->_rootref['LA_BBCODE_E_HELP'] : ((isset($this->_rootref['L_BBCODE_E_HELP'])) ? addslashes($this->_rootref['L_BBCODE_E_HELP']) : ((isset($user->lang['BBCODE_E_HELP'])) ? addslashes($user->lang['BBCODE_E_HELP']) : '{ BBCODE_E_HELP }'))); ?>',
		d: '<?php echo ((isset($this->_rootref['LA_BBCODE_D_HELP'])) ? $this->_rootref['LA_BBCODE_D_HELP'] : ((isset($this->_rootref['L_BBCODE_D_HELP'])) ? addslashes($this->_rootref['L_BBCODE_D_HELP']) : ((isset($user->lang['BBCODE_D_HELP'])) ? addslashes($user->lang['BBCODE_D_HELP']) : '{ BBCODE_D_HELP }'))); ?>',
		t: '<?php echo ((isset($this->_rootref['LA_BBCODE_T_HELP'])) ? $this->_rootref['LA_BBCODE_T_HELP'] : ((isset($this->_rootref['L_BBCODE_T_HELP'])) ? addslashes($this->_rootref['L_BBCODE_T_HELP']) : ((isset($user->lang['BBCODE_T_HELP'])) ? addslashes($user->lang['BBCODE_T_HELP']) : '{ BBCODE_T_HELP }'))); ?>',
		tip: '<?php echo ((isset($this->_rootref['L_STYLES_TIP'])) ? $this->_rootref['L_STYLES_TIP'] : ((isset($user->lang['STYLES_TIP'])) ? $user->lang['STYLES_TIP'] : '{ STYLES_TIP }')); ?>'
		<?php $_custom_tags_count = (isset($this->_tpldata['custom_tags'])) ? sizeof($this->_tpldata['custom_tags']) : 0;if ($_custom_tags_count) {for ($_custom_tags_i = 0; $_custom_tags_i < $_custom_tags_count; ++$_custom_tags_i){$_custom_tags_val = &$this->_tpldata['custom_tags'][$_custom_tags_i]; ?>
			,cb_<?php echo $_custom_tags_val['BBCODE_ID']; ?>: '<?php echo $_custom_tags_val['A_BBCODE_HELPLINE']; ?>'
		<?php }} ?>
	}

// ]]>
</script>
<script type="text/javascript" src="<?php echo (isset($this->_rootref['T_TEMPLATE_PATH'])) ? $this->_rootref['T_TEMPLATE_PATH'] : ''; ?>/editor.js"></script>

<form id="user_signature" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

	<?php if ($this->_rootref['SIGNATURE_PREVIEW']) {  ?>
		<fieldset>
			<legend><?php echo ((isset($this->_rootref['L_ADMIN_SIG_PREVIEW'])) ? $this->_rootref['L_ADMIN_SIG_PREVIEW'] : ((isset($user->lang['ADMIN_SIG_PREVIEW'])) ? $user->lang['ADMIN_SIG_PREVIEW'] : '{ ADMIN_SIG_PREVIEW }')); ?></legend>
			<p><?php echo (isset($this->_rootref['SIGNATURE_PREVIEW'])) ? $this->_rootref['SIGNATURE_PREVIEW'] : ''; ?></p>
		</fieldset>
	<?php } ?>

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_SIGNATURE'])) ? $this->_rootref['L_SIGNATURE'] : ((isset($user->lang['SIGNATURE'])) ? $user->lang['SIGNATURE'] : '{ SIGNATURE }')); ?></legend>
		<p><?php echo ((isset($this->_rootref['L_SIGNATURE_EXPLAIN'])) ? $this->_rootref['L_SIGNATURE_EXPLAIN'] : ((isset($user->lang['SIGNATURE_EXPLAIN'])) ? $user->lang['SIGNATURE_EXPLAIN'] : '{ SIGNATURE_EXPLAIN }')); ?></p>

		<div id="format-buttons">
			<input type="button" class="button2" accesskey="b" name="addbbcode0" value=" B " style="font-weight:bold; width: 30px;" onclick="bbstyle(0)" onmouseover="helpline('b')" onmouseout="helpline('tip')" />
			<input type="button" class="button2" accesskey="i" name="addbbcode2" value=" i " style="font-style:italic; width: 30px;" onclick="bbstyle(2)" onmouseover="helpline('i')" onmouseout="helpline('tip')" />
			<input type="button" class="button2" accesskey="u" name="addbbcode4" value=" u " style="text-decoration: underline; width: 30px;" onclick="bbstyle(4)" onmouseover="helpline('u')" onmouseout="helpline('tip')" />
			<input type="button" class="button2" accesskey="q" name="addbbcode6" value="Quote" style="width: 50px" onclick="bbstyle(6)" onmouseover="helpline('q')" onmouseout="helpline('tip')" />
			<input type="button" class="button2" accesskey="c" name="addbbcode8" value="Code" style="width: 40px" onclick="bbstyle(8)" onmouseover="helpline('c')" onmouseout="helpline('tip')" />
			<input type="button" class="button2" accesskey="l" name="addbbcode10" value="List" style="width: 40px" onclick="bbstyle(10)" onmouseover="helpline('l')" onmouseout="helpline('tip')" />
			<input type="button" class="button2" accesskey="o" name="addbbcode12" value="List=" style="width: 40px" onclick="bbstyle(12)" onmouseover="helpline('o')" onmouseout="helpline('tip')" />
			<input type="button" class="button2" accesskey="t" name="addlitsitem" value="[*]" style="width: 40px" onclick="bbstyle(-1)" onmouseover="helpline('e')" onmouseout="helpline('tip')" />
			<?php if ($this->_rootref['S_BBCODE_IMG']) {  ?>
				<input type="button" class="button2" accesskey="p" name="addbbcode14" value="Img" style="width: 40px" onclick="bbstyle(14)" onmouseover="helpline('p')" onmouseout="helpline('tip')" />
			<?php } if ($this->_rootref['S_LINKS_ALLOWED']) {  ?>
				<input type="button" class="button2" accesskey="w" name="addbbcode16" value="URL" style="text-decoration: underline; width: 40px" onclick="bbstyle(16)" onmouseover="helpline('w')" onmouseout="helpline('tip')" />
			<?php } if ($this->_rootref['S_BBCODE_FLASH']) {  ?>
				<input type="button" class="button2" accesskey="d" name="addbbcode18" value="Flash" onclick="bbstyle(18)" onmouseover="helpline('d')" onmouseout="helpline('tip')" />
			<?php } ?>

			<?php echo ((isset($this->_rootref['L_FONT_SIZE'])) ? $this->_rootref['L_FONT_SIZE'] : ((isset($user->lang['FONT_SIZE'])) ? $user->lang['FONT_SIZE'] : '{ FONT_SIZE }')); ?>: <select name="addbbcode20" onchange="bbfontstyle('[size=' + this.form.addbbcode20.options[this.form.addbbcode20.selectedIndex].value + ']', '[/size]');this.form.addbbcode20.selectedIndex = 2;" title="<?php echo ((isset($this->_rootref['L_FONT_SIZE'])) ? $this->_rootref['L_FONT_SIZE'] : ((isset($user->lang['FONT_SIZE'])) ? $user->lang['FONT_SIZE'] : '{ FONT_SIZE }')); ?>" onmouseover="helpline('f')" onmouseout="helpline('tip')">
				<option value="50"><?php echo ((isset($this->_rootref['L_FONT_TINY'])) ? $this->_rootref['L_FONT_TINY'] : ((isset($user->lang['FONT_TINY'])) ? $user->lang['FONT_TINY'] : '{ FONT_TINY }')); ?></option>
				<option value="85"><?php echo ((isset($this->_rootref['L_FONT_SMALL'])) ? $this->_rootref['L_FONT_SMALL'] : ((isset($user->lang['FONT_SMALL'])) ? $user->lang['FONT_SMALL'] : '{ FONT_SMALL }')); ?></option>
				<option value="100" selected="selected"><?php echo ((isset($this->_rootref['L_FONT_NORMAL'])) ? $this->_rootref['L_FONT_NORMAL'] : ((isset($user->lang['FONT_NORMAL'])) ? $user->lang['FONT_NORMAL'] : '{ FONT_NORMAL }')); ?></option>
				<option value="150"><?php echo ((isset($this->_rootref['L_FONT_LARGE'])) ? $this->_rootref['L_FONT_LARGE'] : ((isset($user->lang['FONT_LARGE'])) ? $user->lang['FONT_LARGE'] : '{ FONT_LARGE }')); ?></option>
				<option value="200"><?php echo ((isset($this->_rootref['L_FONT_HUGE'])) ? $this->_rootref['L_FONT_HUGE'] : ((isset($user->lang['FONT_HUGE'])) ? $user->lang['FONT_HUGE'] : '{ FONT_HUGE }')); ?></option>
			</select>
		<?php if (sizeof($this->_tpldata['custom_tags'])) {  ?>
			<br /><br />
			<?php $_custom_tags_count = (isset($this->_tpldata['custom_tags'])) ? sizeof($this->_tpldata['custom_tags']) : 0;if ($_custom_tags_count) {for ($_custom_tags_i = 0; $_custom_tags_i < $_custom_tags_count; ++$_custom_tags_i){$_custom_tags_val = &$this->_tpldata['custom_tags'][$_custom_tags_i]; ?>
				<input type="button" class="button2" name="addbbcode<?php echo $_custom_tags_val['BBCODE_ID']; ?>" value="<?php echo $_custom_tags_val['BBCODE_TAG']; ?>" onclick="bbstyle(<?php echo $_custom_tags_val['BBCODE_ID']; ?>)"<?php if ($_custom_tags_val['BBCODE_HELPLINE'] !== '') {  ?> onmouseover="helpline('cb_<?php echo $_custom_tags_val['BBCODE_ID']; ?>')" onmouseout="helpline('tip')"<?php } ?> />
			<?php }} } ?>

		</div>

		<p><input type="text" class="text full" style="border: 0; background: none;" name="helpbox" value="<?php echo ((isset($this->_rootref['L_STYLES_TIP'])) ? $this->_rootref['L_STYLES_TIP'] : ((isset($user->lang['STYLES_TIP'])) ? $user->lang['STYLES_TIP'] : '{ STYLES_TIP }')); ?>" /></p>

		<dl>
			<dt style="width: 90px;">
				<script type="text/javascript">
				// <![CDATA[
					colorPalette('v', 12, 10);
				// ]]>
				</script>
			</dt>
			<dd style="margin-left: 90px;"><textarea name="signature" rows="10" cols="60" style="width: 95%;" onselect="storeCaret(this);" onclick="storeCaret(this);" onkeyup="storeCaret(this);"><?php echo (isset($this->_rootref['SIGNATURE'])) ? $this->_rootref['SIGNATURE'] : ''; ?></textarea></dd>
			<dd style="margin-left: 90px; margin-top: 5px;">
			<?php if ($this->_rootref['S_BBCODE_ALLOWED']) {  ?>
				<label><input type="checkbox" class="radio" name="disable_bbcode"<?php echo (isset($this->_rootref['S_BBCODE_CHECKED'])) ? $this->_rootref['S_BBCODE_CHECKED'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_DISABLE_BBCODE'])) ? $this->_rootref['L_DISABLE_BBCODE'] : ((isset($user->lang['DISABLE_BBCODE'])) ? $user->lang['DISABLE_BBCODE'] : '{ DISABLE_BBCODE }')); ?></label>
			<?php } if ($this->_rootref['S_SMILIES_ALLOWED']) {  ?>
				<label><input type="checkbox" class="radio" name="disable_smilies"<?php echo (isset($this->_rootref['S_SMILIES_CHECKED'])) ? $this->_rootref['S_SMILIES_CHECKED'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_DISABLE_SMILIES'])) ? $this->_rootref['L_DISABLE_SMILIES'] : ((isset($user->lang['DISABLE_SMILIES'])) ? $user->lang['DISABLE_SMILIES'] : '{ DISABLE_SMILIES }')); ?></label>
			<?php } if ($this->_rootref['S_LINKS_ALLOWED']) {  ?>
				<label><input type="checkbox" class="radio" name="disable_magic_url"<?php echo (isset($this->_rootref['S_MAGIC_URL_CHECKED'])) ? $this->_rootref['S_MAGIC_URL_CHECKED'] : ''; ?> /> <?php echo ((isset($this->_rootref['L_DISABLE_MAGIC_URL'])) ? $this->_rootref['L_DISABLE_MAGIC_URL'] : ((isset($user->lang['DISABLE_MAGIC_URL'])) ? $user->lang['DISABLE_MAGIC_URL'] : '{ DISABLE_MAGIC_URL }')); ?></label>
			<?php } ?>
			</dd>
			<dd style="margin-left: 90px; margin-top: 10px;"><strong><?php echo ((isset($this->_rootref['L_OPTIONS'])) ? $this->_rootref['L_OPTIONS'] : ((isset($user->lang['OPTIONS'])) ? $user->lang['OPTIONS'] : '{ OPTIONS }')); ?>: </strong><?php echo (isset($this->_rootref['BBCODE_STATUS'])) ? $this->_rootref['BBCODE_STATUS'] : ''; ?> :: <?php echo (isset($this->_rootref['IMG_STATUS'])) ? $this->_rootref['IMG_STATUS'] : ''; ?> :: <?php echo (isset($this->_rootref['FLASH_STATUS'])) ? $this->_rootref['FLASH_STATUS'] : ''; ?> :: <?php echo (isset($this->_rootref['URL_STATUS'])) ? $this->_rootref['URL_STATUS'] : ''; ?> :: <?php echo (isset($this->_rootref['SMILIES_STATUS'])) ? $this->_rootref['SMILIES_STATUS'] : ''; ?></dd>
		</dl>
	</fieldset>

	<fieldset class="submit-buttons">
		<input class="button1" type="submit" name="update" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />&nbsp;
		<input class="button2" type="submit" name="preview" value="<?php echo ((isset($this->_rootref['L_PREVIEW'])) ? $this->_rootref['L_PREVIEW'] : ((isset($user->lang['PREVIEW'])) ? $user->lang['PREVIEW'] : '{ PREVIEW }')); ?>" />
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
</form>
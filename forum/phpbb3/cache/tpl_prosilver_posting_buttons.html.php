<script type="text/javascript">
// <![CDATA[
	var form_name = 'postform';
	var text_name = <?php if ($this->_tpldata['DEFINE']['.']['SIG_EDIT']) {  ?>'signature'<?php } else { ?>'message'<?php } ?>;
	var load_draft = false;
	var upload = false;

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
		a: '<?php echo ((isset($this->_rootref['LA_BBCODE_A_HELP'])) ? $this->_rootref['LA_BBCODE_A_HELP'] : ((isset($this->_rootref['L_BBCODE_A_HELP'])) ? addslashes($this->_rootref['L_BBCODE_A_HELP']) : ((isset($user->lang['BBCODE_A_HELP'])) ? addslashes($user->lang['BBCODE_A_HELP']) : '{ BBCODE_A_HELP }'))); ?>',
		s: '<?php echo ((isset($this->_rootref['LA_BBCODE_S_HELP'])) ? $this->_rootref['LA_BBCODE_S_HELP'] : ((isset($this->_rootref['L_BBCODE_S_HELP'])) ? addslashes($this->_rootref['L_BBCODE_S_HELP']) : ((isset($user->lang['BBCODE_S_HELP'])) ? addslashes($user->lang['BBCODE_S_HELP']) : '{ BBCODE_S_HELP }'))); ?>',
		f: '<?php echo ((isset($this->_rootref['LA_BBCODE_F_HELP'])) ? $this->_rootref['LA_BBCODE_F_HELP'] : ((isset($this->_rootref['L_BBCODE_F_HELP'])) ? addslashes($this->_rootref['L_BBCODE_F_HELP']) : ((isset($user->lang['BBCODE_F_HELP'])) ? addslashes($user->lang['BBCODE_F_HELP']) : '{ BBCODE_F_HELP }'))); ?>',
		e: '<?php echo ((isset($this->_rootref['LA_BBCODE_E_HELP'])) ? $this->_rootref['LA_BBCODE_E_HELP'] : ((isset($this->_rootref['L_BBCODE_E_HELP'])) ? addslashes($this->_rootref['L_BBCODE_E_HELP']) : ((isset($user->lang['BBCODE_E_HELP'])) ? addslashes($user->lang['BBCODE_E_HELP']) : '{ BBCODE_E_HELP }'))); ?>',
		d: '<?php echo ((isset($this->_rootref['LA_BBCODE_D_HELP'])) ? $this->_rootref['LA_BBCODE_D_HELP'] : ((isset($this->_rootref['L_BBCODE_D_HELP'])) ? addslashes($this->_rootref['L_BBCODE_D_HELP']) : ((isset($user->lang['BBCODE_D_HELP'])) ? addslashes($user->lang['BBCODE_D_HELP']) : '{ BBCODE_D_HELP }'))); ?>'
		<?php $_custom_tags_count = (isset($this->_tpldata['custom_tags'])) ? sizeof($this->_tpldata['custom_tags']) : 0;if ($_custom_tags_count) {for ($_custom_tags_i = 0; $_custom_tags_i < $_custom_tags_count; ++$_custom_tags_i){$_custom_tags_val = &$this->_tpldata['custom_tags'][$_custom_tags_i]; ?>
			,cb_<?php echo $_custom_tags_val['BBCODE_ID']; ?>: '<?php echo $_custom_tags_val['A_BBCODE_HELPLINE']; ?>'
		<?php }} ?>
	}

	var panels = new Array('options-panel', 'attach-panel', 'poll-panel');
	var show_panel = 'options-panel';


// ]]>
</script>
<script type="text/javascript" src="<?php echo (isset($this->_rootref['T_TEMPLATE_PATH'])) ? $this->_rootref['T_TEMPLATE_PATH'] : ''; ?>/editor.js"></script>

<?php if ($this->_rootref['S_BBCODE_ALLOWED']) {  ?>
<div id="colour_palette" style="display: none;">
	<dl style="clear: left;">
		<dt><label><?php echo ((isset($this->_rootref['L_FONT_COLOR'])) ? $this->_rootref['L_FONT_COLOR'] : ((isset($user->lang['FONT_COLOR'])) ? $user->lang['FONT_COLOR'] : '{ FONT_COLOR }')); ?>:</label></dt>
		<dd>
		<script type="text/javascript">
		// <![CDATA[
			function change_palette()
			{
				dE('colour_palette');
				e = document.getElementById('colour_palette');
				
				if (e.style.display == 'block')
				{
					document.getElementById('bbpalette').value = '<?php echo ((isset($this->_rootref['LA_FONT_COLOR_HIDE'])) ? $this->_rootref['LA_FONT_COLOR_HIDE'] : ((isset($this->_rootref['L_FONT_COLOR_HIDE'])) ? addslashes($this->_rootref['L_FONT_COLOR_HIDE']) : ((isset($user->lang['FONT_COLOR_HIDE'])) ? addslashes($user->lang['FONT_COLOR_HIDE']) : '{ FONT_COLOR_HIDE }'))); ?>';
				}
				else
				{
					document.getElementById('bbpalette').value = '<?php echo ((isset($this->_rootref['LA_FONT_COLOR'])) ? $this->_rootref['LA_FONT_COLOR'] : ((isset($this->_rootref['L_FONT_COLOR'])) ? addslashes($this->_rootref['L_FONT_COLOR']) : ((isset($user->lang['FONT_COLOR'])) ? addslashes($user->lang['FONT_COLOR']) : '{ FONT_COLOR }'))); ?>';
				}
			}

			colorPalette('h', 15, 10);
		// ]]>
		</script>
		</dd>
	</dl>
</div>

<div id="format-buttons">
	<input type="button" class="button2" accesskey="b" name="addbbcode0" value=" B " style="font-weight:bold; width: 30px" onclick="bbstyle(0)" title="<?php echo ((isset($this->_rootref['L_BBCODE_B_HELP'])) ? $this->_rootref['L_BBCODE_B_HELP'] : ((isset($user->lang['BBCODE_B_HELP'])) ? $user->lang['BBCODE_B_HELP'] : '{ BBCODE_B_HELP }')); ?>" />
	<input type="button" class="button2" accesskey="i" name="addbbcode2" value=" i " style="font-style:italic; width: 30px" onclick="bbstyle(2)" title="<?php echo ((isset($this->_rootref['L_BBCODE_I_HELP'])) ? $this->_rootref['L_BBCODE_I_HELP'] : ((isset($user->lang['BBCODE_I_HELP'])) ? $user->lang['BBCODE_I_HELP'] : '{ BBCODE_I_HELP }')); ?>" />
	<input type="button" class="button2" accesskey="u" name="addbbcode4" value=" u " style="text-decoration: underline; width: 30px" onclick="bbstyle(4)" title="<?php echo ((isset($this->_rootref['L_BBCODE_U_HELP'])) ? $this->_rootref['L_BBCODE_U_HELP'] : ((isset($user->lang['BBCODE_U_HELP'])) ? $user->lang['BBCODE_U_HELP'] : '{ BBCODE_U_HELP }')); ?>" />
	<?php if ($this->_rootref['S_BBCODE_QUOTE']) {  ?>
		<input type="button" class="button2" accesskey="q" name="addbbcode6" value="Quote" style="width: 50px" onclick="bbstyle(6)" title="<?php echo ((isset($this->_rootref['L_BBCODE_Q_HELP'])) ? $this->_rootref['L_BBCODE_Q_HELP'] : ((isset($user->lang['BBCODE_Q_HELP'])) ? $user->lang['BBCODE_Q_HELP'] : '{ BBCODE_Q_HELP }')); ?>" />
	<?php } ?>
	<input type="button" class="button2" accesskey="c" name="addbbcode8" value="Code" style="width: 40px" onclick="bbstyle(8)" title="<?php echo ((isset($this->_rootref['L_BBCODE_C_HELP'])) ? $this->_rootref['L_BBCODE_C_HELP'] : ((isset($user->lang['BBCODE_C_HELP'])) ? $user->lang['BBCODE_C_HELP'] : '{ BBCODE_C_HELP }')); ?>" />
	<input type="button" class="button2" accesskey="l" name="addbbcode10" value="List" style="width: 40px" onclick="bbstyle(10)" title="<?php echo ((isset($this->_rootref['L_BBCODE_L_HELP'])) ? $this->_rootref['L_BBCODE_L_HELP'] : ((isset($user->lang['BBCODE_L_HELP'])) ? $user->lang['BBCODE_L_HELP'] : '{ BBCODE_L_HELP }')); ?>" />
	<input type="button" class="button2" accesskey="o" name="addbbcode12" value="List=" style="width: 40px" onclick="bbstyle(12)" title="<?php echo ((isset($this->_rootref['L_BBCODE_O_HELP'])) ? $this->_rootref['L_BBCODE_O_HELP'] : ((isset($user->lang['BBCODE_O_HELP'])) ? $user->lang['BBCODE_O_HELP'] : '{ BBCODE_O_HELP }')); ?>" />
	<input type="button" class="button2" accesskey="t" name="addlitsitem" value="[*]" style="width: 40px" onclick="bbstyle(-1)" title="<?php echo ((isset($this->_rootref['L_BBCODE_LISTITEM_HELP'])) ? $this->_rootref['L_BBCODE_LISTITEM_HELP'] : ((isset($user->lang['BBCODE_LISTITEM_HELP'])) ? $user->lang['BBCODE_LISTITEM_HELP'] : '{ BBCODE_LISTITEM_HELP }')); ?>" />
	<?php if ($this->_rootref['S_BBCODE_IMG']) {  ?>
		<input type="button" class="button2" accesskey="p" name="addbbcode14" value="Img" style="width: 40px" onclick="bbstyle(14)" title="<?php echo ((isset($this->_rootref['L_BBCODE_P_HELP'])) ? $this->_rootref['L_BBCODE_P_HELP'] : ((isset($user->lang['BBCODE_P_HELP'])) ? $user->lang['BBCODE_P_HELP'] : '{ BBCODE_P_HELP }')); ?>" />
	<?php } if ($this->_rootref['S_LINKS_ALLOWED']) {  ?>
		<input type="button" class="button2" accesskey="w" name="addbbcode16" value="URL" style="text-decoration: underline; width: 40px" onclick="bbstyle(16)" title="<?php echo ((isset($this->_rootref['L_BBCODE_W_HELP'])) ? $this->_rootref['L_BBCODE_W_HELP'] : ((isset($user->lang['BBCODE_W_HELP'])) ? $user->lang['BBCODE_W_HELP'] : '{ BBCODE_W_HELP }')); ?>" />
	<?php } if ($this->_rootref['S_BBCODE_FLASH']) {  ?>
		<input type="button" class="button2" accesskey="d" name="addbbcode18" value="Flash" onclick="bbstyle(18)" title="<?php echo ((isset($this->_rootref['L_BBCODE_D_HELP'])) ? $this->_rootref['L_BBCODE_D_HELP'] : ((isset($user->lang['BBCODE_D_HELP'])) ? $user->lang['BBCODE_D_HELP'] : '{ BBCODE_D_HELP }')); ?>" />
	<?php } ?>
	<select name="addbbcode20" onchange="bbfontstyle('[size=' + this.form.addbbcode20.options[this.form.addbbcode20.selectedIndex].value + ']', '[/size]');this.form.addbbcode20.selectedIndex = 2;" title="<?php echo ((isset($this->_rootref['L_BBCODE_F_HELP'])) ? $this->_rootref['L_BBCODE_F_HELP'] : ((isset($user->lang['BBCODE_F_HELP'])) ? $user->lang['BBCODE_F_HELP'] : '{ BBCODE_F_HELP }')); ?>">
		<option value="50"><?php echo ((isset($this->_rootref['L_FONT_TINY'])) ? $this->_rootref['L_FONT_TINY'] : ((isset($user->lang['FONT_TINY'])) ? $user->lang['FONT_TINY'] : '{ FONT_TINY }')); ?></option>
		<option value="85"><?php echo ((isset($this->_rootref['L_FONT_SMALL'])) ? $this->_rootref['L_FONT_SMALL'] : ((isset($user->lang['FONT_SMALL'])) ? $user->lang['FONT_SMALL'] : '{ FONT_SMALL }')); ?></option>
		<option value="100" selected="selected"><?php echo ((isset($this->_rootref['L_FONT_NORMAL'])) ? $this->_rootref['L_FONT_NORMAL'] : ((isset($user->lang['FONT_NORMAL'])) ? $user->lang['FONT_NORMAL'] : '{ FONT_NORMAL }')); ?></option>
		<option value="150"><?php echo ((isset($this->_rootref['L_FONT_LARGE'])) ? $this->_rootref['L_FONT_LARGE'] : ((isset($user->lang['FONT_LARGE'])) ? $user->lang['FONT_LARGE'] : '{ FONT_LARGE }')); ?></option>
		<option value="200"><?php echo ((isset($this->_rootref['L_FONT_HUGE'])) ? $this->_rootref['L_FONT_HUGE'] : ((isset($user->lang['FONT_HUGE'])) ? $user->lang['FONT_HUGE'] : '{ FONT_HUGE }')); ?></option>
	</select>
	<input type="button" class="button2" name="bbpalette" id="bbpalette" value="<?php echo ((isset($this->_rootref['L_FONT_COLOR'])) ? $this->_rootref['L_FONT_COLOR'] : ((isset($user->lang['FONT_COLOR'])) ? $user->lang['FONT_COLOR'] : '{ FONT_COLOR }')); ?>" onclick="change_palette();" title="<?php echo ((isset($this->_rootref['L_BBCODE_S_HELP'])) ? $this->_rootref['L_BBCODE_S_HELP'] : ((isset($user->lang['BBCODE_S_HELP'])) ? $user->lang['BBCODE_S_HELP'] : '{ BBCODE_S_HELP }')); ?>" />
	<?php $_custom_tags_count = (isset($this->_tpldata['custom_tags'])) ? sizeof($this->_tpldata['custom_tags']) : 0;if ($_custom_tags_count) {for ($_custom_tags_i = 0; $_custom_tags_i < $_custom_tags_count; ++$_custom_tags_i){$_custom_tags_val = &$this->_tpldata['custom_tags'][$_custom_tags_i]; ?>
		<input type="button" class="button2" name="addbbcode<?php echo $_custom_tags_val['BBCODE_ID']; ?>" value="<?php echo $_custom_tags_val['BBCODE_TAG']; ?>" onclick="bbstyle(<?php echo $_custom_tags_val['BBCODE_ID']; ?>)" title="<?php echo $_custom_tags_val['BBCODE_HELPLINE']; ?>" />
	<?php }} ?>
</div>
<?php } ?>
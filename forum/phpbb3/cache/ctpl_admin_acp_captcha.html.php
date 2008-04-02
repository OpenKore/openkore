<?php $this->_tpl_include('overall_header.html'); ?>

<a name="maincontent"></a>

<h1><?php echo ((isset($this->_rootref['L_ACP_VC_SETTINGS'])) ? $this->_rootref['L_ACP_VC_SETTINGS'] : ((isset($user->lang['ACP_VC_SETTINGS'])) ? $user->lang['ACP_VC_SETTINGS'] : '{ ACP_VC_SETTINGS }')); ?></h1>

<p><?php echo ((isset($this->_rootref['L_ACP_VC_SETTINGS_EXPLAIN'])) ? $this->_rootref['L_ACP_VC_SETTINGS_EXPLAIN'] : ((isset($user->lang['ACP_VC_SETTINGS_EXPLAIN'])) ? $user->lang['ACP_VC_SETTINGS_EXPLAIN'] : '{ ACP_VC_SETTINGS_EXPLAIN }')); ?></p>


<form id="acp_captcha" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

<fieldset>
<legend><?php echo ((isset($this->_rootref['L_GENERAL_OPTIONS'])) ? $this->_rootref['L_GENERAL_OPTIONS'] : ((isset($user->lang['GENERAL_OPTIONS'])) ? $user->lang['GENERAL_OPTIONS'] : '{ GENERAL_OPTIONS }')); ?></legend>

<dl>
	<dt><label for="enable_confirm"><?php echo ((isset($this->_rootref['L_VISUAL_CONFIRM_REG'])) ? $this->_rootref['L_VISUAL_CONFIRM_REG'] : ((isset($user->lang['VISUAL_CONFIRM_REG'])) ? $user->lang['VISUAL_CONFIRM_REG'] : '{ VISUAL_CONFIRM_REG }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_VISUAL_CONFIRM_REG_EXPLAIN'])) ? $this->_rootref['L_VISUAL_CONFIRM_REG_EXPLAIN'] : ((isset($user->lang['VISUAL_CONFIRM_REG_EXPLAIN'])) ? $user->lang['VISUAL_CONFIRM_REG_EXPLAIN'] : '{ VISUAL_CONFIRM_REG_EXPLAIN }')); ?></span></dt>
	<dd><label><input type="radio" class="radio" id="enable_confirm" name="enable_confirm" value="1"<?php if ($this->_rootref['REG_ENABLE']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_ENABLED'])) ? $this->_rootref['L_ENABLED'] : ((isset($user->lang['ENABLED'])) ? $user->lang['ENABLED'] : '{ ENABLED }')); ?></label>
		<label><input type="radio" class="radio" name="enable_confirm" value="0"<?php if (! $this->_rootref['REG_ENABLE']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_DISABLED'])) ? $this->_rootref['L_DISABLED'] : ((isset($user->lang['DISABLED'])) ? $user->lang['DISABLED'] : '{ DISABLED }')); ?></label></dd>
</dl>
<dl>
	<dt><label for="enable_post_confirm"><?php echo ((isset($this->_rootref['L_VISUAL_CONFIRM_POST'])) ? $this->_rootref['L_VISUAL_CONFIRM_POST'] : ((isset($user->lang['VISUAL_CONFIRM_POST'])) ? $user->lang['VISUAL_CONFIRM_POST'] : '{ VISUAL_CONFIRM_POST }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_VISUAL_CONFIRM_POST_EXPLAIN'])) ? $this->_rootref['L_VISUAL_CONFIRM_POST_EXPLAIN'] : ((isset($user->lang['VISUAL_CONFIRM_POST_EXPLAIN'])) ? $user->lang['VISUAL_CONFIRM_POST_EXPLAIN'] : '{ VISUAL_CONFIRM_POST_EXPLAIN }')); ?></span></dt>
	<dd><label><input type="radio" class="radio" id="enable_post_confirm" name="enable_post_confirm" value="1"<?php if ($this->_rootref['POST_ENABLE']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_ENABLED'])) ? $this->_rootref['L_ENABLED'] : ((isset($user->lang['ENABLED'])) ? $user->lang['ENABLED'] : '{ ENABLED }')); ?></label>
		<label><input type="radio" class="radio" name="enable_post_confirm" value="0"<?php if (! $this->_rootref['POST_ENABLE']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_DISABLED'])) ? $this->_rootref['L_DISABLED'] : ((isset($user->lang['DISABLED'])) ? $user->lang['DISABLED'] : '{ DISABLED }')); ?></label></dd>
</dl>
<?php if ($this->_rootref['GD']) {  ?>
<dl>
	<dt><label for="captcha_gd"><?php echo ((isset($this->_rootref['L_CAPTCHA_GD'])) ? $this->_rootref['L_CAPTCHA_GD'] : ((isset($user->lang['CAPTCHA_GD'])) ? $user->lang['CAPTCHA_GD'] : '{ CAPTCHA_GD }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_CAPTCHA_GD_EXPLAIN'])) ? $this->_rootref['L_CAPTCHA_GD_EXPLAIN'] : ((isset($user->lang['CAPTCHA_GD_EXPLAIN'])) ? $user->lang['CAPTCHA_GD_EXPLAIN'] : '{ CAPTCHA_GD_EXPLAIN }')); ?></span></dt>
	<dd><label><input id="captcha_gd" name="captcha_gd" value="1" class="radio" type="radio"<?php if ($this->_rootref['CAPTCHA_GD']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
		<label><input name="captcha_gd" value="0" class="radio" type="radio"<?php if (! $this->_rootref['CAPTCHA_GD']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
</dl>
<dl>
	<dt><label for="captcha_gd_foreground_noise"><?php echo ((isset($this->_rootref['L_CAPTCHA_GD_FOREGROUND_NOISE'])) ? $this->_rootref['L_CAPTCHA_GD_FOREGROUND_NOISE'] : ((isset($user->lang['CAPTCHA_GD_FOREGROUND_NOISE'])) ? $user->lang['CAPTCHA_GD_FOREGROUND_NOISE'] : '{ CAPTCHA_GD_FOREGROUND_NOISE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_CAPTCHA_GD_FOREGROUND_NOISE_EXPLAIN'])) ? $this->_rootref['L_CAPTCHA_GD_FOREGROUND_NOISE_EXPLAIN'] : ((isset($user->lang['CAPTCHA_GD_FOREGROUND_NOISE_EXPLAIN'])) ? $user->lang['CAPTCHA_GD_FOREGROUND_NOISE_EXPLAIN'] : '{ CAPTCHA_GD_FOREGROUND_NOISE_EXPLAIN }')); ?></span></dt>
	<dd><label><input id="captcha_gd_foreground_noise" name="captcha_gd_foreground_noise" value="1" class="radio" type="radio"<?php if ($this->_rootref['CAPTCHA_GD_FOREGROUND_NOISE']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
		<label><input name="captcha_gd_foreground_noise" value="0" class="radio" type="radio"<?php if (! $this->_rootref['CAPTCHA_GD_FOREGROUND_NOISE']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
</dl>
<dl>
	<dt><label for="captcha_gd_x_grid"><?php echo ((isset($this->_rootref['L_CAPTCHA_GD_X_GRID'])) ? $this->_rootref['L_CAPTCHA_GD_X_GRID'] : ((isset($user->lang['CAPTCHA_GD_X_GRID'])) ? $user->lang['CAPTCHA_GD_X_GRID'] : '{ CAPTCHA_GD_X_GRID }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_CAPTCHA_GD_X_GRID_EXPLAIN'])) ? $this->_rootref['L_CAPTCHA_GD_X_GRID_EXPLAIN'] : ((isset($user->lang['CAPTCHA_GD_X_GRID_EXPLAIN'])) ? $user->lang['CAPTCHA_GD_X_GRID_EXPLAIN'] : '{ CAPTCHA_GD_X_GRID_EXPLAIN }')); ?></span></dt>
	<dd><input id="captcha_gd_x_grid" name="captcha_gd_x_grid" value="<?php echo (isset($this->_rootref['CAPTCHA_GD_X_GRID'])) ? $this->_rootref['CAPTCHA_GD_X_GRID'] : ''; ?>" type="text" /></dd>
</dl>
<dl>
	<dt><label for="captcha_gd_y_grid"><?php echo ((isset($this->_rootref['L_CAPTCHA_GD_Y_GRID'])) ? $this->_rootref['L_CAPTCHA_GD_Y_GRID'] : ((isset($user->lang['CAPTCHA_GD_Y_GRID'])) ? $user->lang['CAPTCHA_GD_Y_GRID'] : '{ CAPTCHA_GD_Y_GRID }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_CAPTCHA_GD_Y_GRID_EXPLAIN'])) ? $this->_rootref['L_CAPTCHA_GD_Y_GRID_EXPLAIN'] : ((isset($user->lang['CAPTCHA_GD_Y_GRID_EXPLAIN'])) ? $user->lang['CAPTCHA_GD_Y_GRID_EXPLAIN'] : '{ CAPTCHA_GD_Y_GRID_EXPLAIN }')); ?></span></dt>
	<dd><input id="captcha_gd_y_grid" name="captcha_gd_y_grid" value="<?php echo (isset($this->_rootref['CAPTCHA_GD_Y_GRID'])) ? $this->_rootref['CAPTCHA_GD_Y_GRID'] : ''; ?>" type="text" /></dd>
</dl>
<?php } ?>

</fieldset>
<fieldset>
	<legend><?php echo ((isset($this->_rootref['L_PREVIEW'])) ? $this->_rootref['L_PREVIEW'] : ((isset($user->lang['PREVIEW'])) ? $user->lang['PREVIEW'] : '{ PREVIEW }')); ?></legend>
<?php if ($this->_rootref['PREVIEW']) {  ?>
	<div class="successbox">
		<h3><?php echo ((isset($this->_rootref['L_WARNING'])) ? $this->_rootref['L_WARNING'] : ((isset($user->lang['WARNING'])) ? $user->lang['WARNING'] : '{ WARNING }')); ?></h3>
		<p><?php echo ((isset($this->_rootref['L_CAPTCHA_PREVIEW_MSG'])) ? $this->_rootref['L_CAPTCHA_PREVIEW_MSG'] : ((isset($user->lang['CAPTCHA_PREVIEW_MSG'])) ? $user->lang['CAPTCHA_PREVIEW_MSG'] : '{ CAPTCHA_PREVIEW_MSG }')); ?></p>
	</div>
<?php } ?>
<dl>
	<dt><label for="captcha_preview"><?php echo ((isset($this->_rootref['L_PREVIEW'])) ? $this->_rootref['L_PREVIEW'] : ((isset($user->lang['PREVIEW'])) ? $user->lang['PREVIEW'] : '{ PREVIEW }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_CAPTCHA_PREVIEW_EXPLAIN'])) ? $this->_rootref['L_CAPTCHA_PREVIEW_EXPLAIN'] : ((isset($user->lang['CAPTCHA_PREVIEW_EXPLAIN'])) ? $user->lang['CAPTCHA_PREVIEW_EXPLAIN'] : '{ CAPTCHA_PREVIEW_EXPLAIN }')); ?></span></dt>
	<dd><img src="<?php echo (isset($this->_rootref['CAPTCHA_PREVIEW'])) ? $this->_rootref['CAPTCHA_PREVIEW'] : ''; ?>" alt="<?php echo ((isset($this->_rootref['L_PREVIEW'])) ? $this->_rootref['L_PREVIEW'] : ((isset($user->lang['PREVIEW'])) ? $user->lang['PREVIEW'] : '{ PREVIEW }')); ?>" <?php if ($this->_rootref['CAPTCHA_GD_PREVIEWED']) {  ?>width="360" height="96"<?php } else { ?> width="320" height="50"<?php } ?> id="captcha_preview" /></dd>
</dl>
</fieldset>

<fieldset class="submit-buttons">
	<legend><?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?></legend>
	<input class="button1" type="submit" id="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />&nbsp;
	<input class="button2" type="reset" id="reset" name="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" />&nbsp;
	<input class="button2" type="submit" id="preview" name="preview" value="<?php echo ((isset($this->_rootref['L_PREVIEW'])) ? $this->_rootref['L_PREVIEW'] : ((isset($user->lang['PREVIEW'])) ? $user->lang['PREVIEW'] : '{ PREVIEW }')); ?>" />
	<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
</fieldset>
</form>

<?php $this->_tpl_include('overall_footer.html'); ?>
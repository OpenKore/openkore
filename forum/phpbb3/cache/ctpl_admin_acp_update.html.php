<?php $this->_tpl_include('overall_header.html'); ?>

<a name="maincontent"></a>
	
<?php if ($this->_rootref['S_VERSION_CHECK']) {  ?>

	<h1><?php echo ((isset($this->_rootref['L_VERSION_CHECK'])) ? $this->_rootref['L_VERSION_CHECK'] : ((isset($user->lang['VERSION_CHECK'])) ? $user->lang['VERSION_CHECK'] : '{ VERSION_CHECK }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_VERSION_CHECK_EXPLAIN'])) ? $this->_rootref['L_VERSION_CHECK_EXPLAIN'] : ((isset($user->lang['VERSION_CHECK_EXPLAIN'])) ? $user->lang['VERSION_CHECK_EXPLAIN'] : '{ VERSION_CHECK_EXPLAIN }')); ?></p>

	<?php if ($this->_rootref['S_UP_TO_DATE'] && $this->_rootref['S_UP_TO_DATE_AUTO']) {  ?>
		<div class="successbox">
			<p><?php echo ((isset($this->_rootref['L_VERSION_UP_TO_DATE_ACP'])) ? $this->_rootref['L_VERSION_UP_TO_DATE_ACP'] : ((isset($user->lang['VERSION_UP_TO_DATE_ACP'])) ? $user->lang['VERSION_UP_TO_DATE_ACP'] : '{ VERSION_UP_TO_DATE_ACP }')); ?></p>
		</div>
	<?php } else { ?>
		<div class="errorbox">
			<p><?php echo ((isset($this->_rootref['L_VERSION_NOT_UP_TO_DATE_ACP'])) ? $this->_rootref['L_VERSION_NOT_UP_TO_DATE_ACP'] : ((isset($user->lang['VERSION_NOT_UP_TO_DATE_ACP'])) ? $user->lang['VERSION_NOT_UP_TO_DATE_ACP'] : '{ VERSION_NOT_UP_TO_DATE_ACP }')); ?></p>
		</div>
	<?php } ?>

	<fieldset>
		<legend></legend>
	<dl>
		<dt><label><?php echo ((isset($this->_rootref['L_CURRENT_VERSION'])) ? $this->_rootref['L_CURRENT_VERSION'] : ((isset($user->lang['CURRENT_VERSION'])) ? $user->lang['CURRENT_VERSION'] : '{ CURRENT_VERSION }')); ?></label></dt>
		<dd><strong><?php if ($this->_rootref['S_UP_TO_DATE'] && ! $this->_rootref['S_UP_TO_DATE_AUTO']) {  echo (isset($this->_rootref['AUTO_VERSION'])) ? $this->_rootref['AUTO_VERSION'] : ''; } else { echo (isset($this->_rootref['CURRENT_VERSION'])) ? $this->_rootref['CURRENT_VERSION'] : ''; } ?></strong></dd>
	</dl>
	<dl>
		<dt><label><?php echo ((isset($this->_rootref['L_LATEST_VERSION'])) ? $this->_rootref['L_LATEST_VERSION'] : ((isset($user->lang['LATEST_VERSION'])) ? $user->lang['LATEST_VERSION'] : '{ LATEST_VERSION }')); ?></label></dt>
		<dd><strong><?php echo (isset($this->_rootref['LATEST_VERSION'])) ? $this->_rootref['LATEST_VERSION'] : ''; ?></strong></dd>
	</dl>
	</fieldset>

	<?php if ($this->_rootref['S_UP_TO_DATE'] && ! $this->_rootref['S_UP_TO_DATE_AUTO']) {  ?>
		<?php echo ((isset($this->_rootref['L_UPDATE_INSTRUCTIONS_INCOMPLETE'])) ? $this->_rootref['L_UPDATE_INSTRUCTIONS_INCOMPLETE'] : ((isset($user->lang['UPDATE_INSTRUCTIONS_INCOMPLETE'])) ? $user->lang['UPDATE_INSTRUCTIONS_INCOMPLETE'] : '{ UPDATE_INSTRUCTIONS_INCOMPLETE }')); ?>
		<br /><br />
		<?php echo (isset($this->_rootref['UPDATE_INSTRUCTIONS'])) ? $this->_rootref['UPDATE_INSTRUCTIONS'] : ''; ?>
		<br /><br />
	<?php } if (! $this->_rootref['S_UP_TO_DATE']) {  ?>
		<?php echo (isset($this->_rootref['UPDATE_INSTRUCTIONS'])) ? $this->_rootref['UPDATE_INSTRUCTIONS'] : ''; ?>
		<br /><br />
	<?php } } $this->_tpl_include('overall_footer.html'); ?>
<?php $this->_tpl_include('overall_header.html'); ?>

<div <?php if ($this->_rootref['S_USER_NOTICE']) {  ?>class="successbox"<?php } else { ?>class="errorbox"<?php } ?>>
	<h3><?php echo (isset($this->_rootref['MESSAGE_TITLE'])) ? $this->_rootref['MESSAGE_TITLE'] : ''; ?></h3>
	<p><?php echo (isset($this->_rootref['MESSAGE_TEXT'])) ? $this->_rootref['MESSAGE_TEXT'] : ''; ?></p>
</div>

<?php $this->_tpl_include('overall_footer.html'); ?>
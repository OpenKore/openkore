<?php $this->_tpl_include('overall_header.html'); ?>

<div class="panel" id="message">
	<div class="inner"><span class="corners-top"><span></span></span>
	<h2><?php echo (isset($this->_rootref['MESSAGE_TITLE'])) ? $this->_rootref['MESSAGE_TITLE'] : ''; ?></h2>
	<p><?php echo (isset($this->_rootref['MESSAGE_TEXT'])) ? $this->_rootref['MESSAGE_TEXT'] : ''; ?></p>
	<?php if ($this->_rootref['SCRIPT_NAME'] == "search" && ! $this->_rootref['S_BOARD_DISABLED'] && ! $this->_rootref['S_NO_SEARCH']) {  ?><p><a href="<?php echo (isset($this->_rootref['U_SEARCH'])) ? $this->_rootref['U_SEARCH'] : ''; ?>" class="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_BEGIN'])) ? $this->_rootref['S_CONTENT_FLOW_BEGIN'] : ''; ?>"><?php echo ((isset($this->_rootref['L_RETURN_TO_SEARCH_ADV'])) ? $this->_rootref['L_RETURN_TO_SEARCH_ADV'] : ((isset($user->lang['RETURN_TO_SEARCH_ADV'])) ? $user->lang['RETURN_TO_SEARCH_ADV'] : '{ RETURN_TO_SEARCH_ADV }')); ?></a></p><?php } ?>
	<span class="corners-bottom"><span></span></span></div>
</div>

<?php $this->_tpl_include('overall_footer.html'); ?>
<?php $this->_tpl_include('overall_header.html'); ?>

<a name="maincontent"></a>

<h1><?php echo ((isset($this->_rootref['L_ACP_PHP_INFO'])) ? $this->_rootref['L_ACP_PHP_INFO'] : ((isset($user->lang['ACP_PHP_INFO'])) ? $user->lang['ACP_PHP_INFO'] : '{ ACP_PHP_INFO }')); ?></h1>

<p><?php echo ((isset($this->_rootref['L_ACP_PHP_INFO_EXPLAIN'])) ? $this->_rootref['L_ACP_PHP_INFO_EXPLAIN'] : ((isset($user->lang['ACP_PHP_INFO_EXPLAIN'])) ? $user->lang['ACP_PHP_INFO_EXPLAIN'] : '{ ACP_PHP_INFO_EXPLAIN }')); ?></p>

<div class="phpinfo">
	<?php echo (isset($this->_rootref['PHPINFO'])) ? $this->_rootref['PHPINFO'] : ''; ?>
</div>

<?php $this->_tpl_include('overall_footer.html'); ?>
<?php $this->_tpl_include('overall_header.html'); ?>

<table class="tablebg" width="100%" cellspacing="1">
<tr>
	<th><?php echo (isset($this->_rootref['MESSAGE_TITLE'])) ? $this->_rootref['MESSAGE_TITLE'] : ''; ?></th>
</tr>
<tr> 
	<td class="row1" align="center"><br /><p class="gen"><?php echo (isset($this->_rootref['MESSAGE_TEXT'])) ? $this->_rootref['MESSAGE_TEXT'] : ''; ?></p><br /></td>
</tr>
</table>

<br clear="all" />

<?php $this->_tpl_include('breadcrumbs.html'); $this->_tpl_include('overall_footer.html'); ?>
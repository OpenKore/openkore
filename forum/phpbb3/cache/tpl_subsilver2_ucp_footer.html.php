<?php if (! $this->_rootref['S_PRIVMSGS'] || $this->_rootref['S_SHOW_DRAFTS']) {  ?>	<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?></form><?php } ?></td>
</tr>
</table>
<?php if (( $this->_rootref['S_SHOW_PM_BOX'] || $this->_rootref['S_EDIT_POST'] ) && $this->_rootref['S_POST_ACTION']) {  echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?></form><?php } ?>

<br clear="all" />

<?php $this->_tpl_include('breadcrumbs.html'); ?>

<div align="<?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>"><?php $this->_tpl_include('jumpbox.html'); ?></div>

<?php $this->_tpl_include('overall_footer.html'); ?>
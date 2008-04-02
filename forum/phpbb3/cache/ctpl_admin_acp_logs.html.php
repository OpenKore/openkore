<?php $this->_tpl_include('overall_header.html'); ?>

<a name="maincontent"></a>

<h1><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></h1>

<p><?php echo ((isset($this->_rootref['L_EXPLAIN'])) ? $this->_rootref['L_EXPLAIN'] : ((isset($user->lang['EXPLAIN'])) ? $user->lang['EXPLAIN'] : '{ EXPLAIN }')); ?></p>

<form id="list" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

<?php if ($this->_rootref['PAGINATION']) {  ?>
<div class="pagination">
		<a href="#" onclick="jumpto(); return false;" title="<?php echo ((isset($this->_rootref['L_JUMP_TO_PAGE'])) ? $this->_rootref['L_JUMP_TO_PAGE'] : ((isset($user->lang['JUMP_TO_PAGE'])) ? $user->lang['JUMP_TO_PAGE'] : '{ JUMP_TO_PAGE }')); ?>"><?php echo (isset($this->_rootref['S_ON_PAGE'])) ? $this->_rootref['S_ON_PAGE'] : ''; ?></a> &bull; <span><?php echo (isset($this->_rootref['PAGINATION'])) ? $this->_rootref['PAGINATION'] : ''; ?></span>
</div>
<?php } if (sizeof($this->_tpldata['log'])) {  ?>
	<table cellspacing="1">
	<thead>
	<tr>
		<th><?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_IP'])) ? $this->_rootref['L_IP'] : ((isset($user->lang['IP'])) ? $user->lang['IP'] : '{ IP }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_TIME'])) ? $this->_rootref['L_TIME'] : ((isset($user->lang['TIME'])) ? $user->lang['TIME'] : '{ TIME }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_ACTION'])) ? $this->_rootref['L_ACTION'] : ((isset($user->lang['ACTION'])) ? $user->lang['ACTION'] : '{ ACTION }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_MARK'])) ? $this->_rootref['L_MARK'] : ((isset($user->lang['MARK'])) ? $user->lang['MARK'] : '{ MARK }')); ?></th>
	</tr>
	</thead>
	<tbody>
	<?php $_log_count = (isset($this->_tpldata['log'])) ? sizeof($this->_tpldata['log']) : 0;if ($_log_count) {for ($_log_i = 0; $_log_i < $_log_count; ++$_log_i){$_log_val = &$this->_tpldata['log'][$_log_i]; if (!($_log_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>

			<td>
				<?php echo $_log_val['USERNAME']; ?>
				<?php if ($_log_val['REPORTEE_USERNAME']) {  ?>
				<br />&raquo; <?php echo $_log_val['REPORTEE_USERNAME']; ?>
				<?php } ?>
			</td>
			<td style="text-align: center;"><?php echo $_log_val['IP']; ?></td>
			<td style="text-align: center;"><?php echo $_log_val['DATE']; ?></td>
			<td><?php echo $_log_val['ACTION']; if ($_log_val['DATA']) {  ?><br /><span><?php echo $_log_val['DATA']; ?></span><?php } ?></td>
			<td style="text-align: center;"><input type="checkbox" class="radio" name="mark[]" value="<?php echo $_log_val['ID']; ?>" /></td>
		</tr>
	<?php }} ?>
	</tbody>
	</table>

<?php } else { ?>

	<div class="errorbox">
		<p><?php echo ((isset($this->_rootref['L_NO_ENTRIES'])) ? $this->_rootref['L_NO_ENTRIES'] : ((isset($user->lang['NO_ENTRIES'])) ? $user->lang['NO_ENTRIES'] : '{ NO_ENTRIES }')); ?></p>
	</div>

<?php } ?>


<fieldset class="display-options">
	<?php echo ((isset($this->_rootref['L_DISPLAY_LOG'])) ? $this->_rootref['L_DISPLAY_LOG'] : ((isset($user->lang['DISPLAY_LOG'])) ? $user->lang['DISPLAY_LOG'] : '{ DISPLAY_LOG }')); ?>: &nbsp;<?php echo (isset($this->_rootref['S_LIMIT_DAYS'])) ? $this->_rootref['S_LIMIT_DAYS'] : ''; ?>&nbsp;<?php echo ((isset($this->_rootref['L_SORT_BY'])) ? $this->_rootref['L_SORT_BY'] : ((isset($user->lang['SORT_BY'])) ? $user->lang['SORT_BY'] : '{ SORT_BY }')); ?>: <?php echo (isset($this->_rootref['S_SORT_KEY'])) ? $this->_rootref['S_SORT_KEY'] : ''; ?> <?php echo (isset($this->_rootref['S_SORT_DIR'])) ? $this->_rootref['S_SORT_DIR'] : ''; ?>
	<input class="button2" type="submit" value="<?php echo ((isset($this->_rootref['L_GO'])) ? $this->_rootref['L_GO'] : ((isset($user->lang['GO'])) ? $user->lang['GO'] : '{ GO }')); ?>" name="sort" />
	<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
</fieldset>
<hr />
<?php if ($this->_rootref['PAGINATION']) {  ?>
<div class="pagination">
	<a href="#" onclick="jumpto(); return false;" title="<?php echo ((isset($this->_rootref['L_JUMP_TO_PAGE'])) ? $this->_rootref['L_JUMP_TO_PAGE'] : ((isset($user->lang['JUMP_TO_PAGE'])) ? $user->lang['JUMP_TO_PAGE'] : '{ JUMP_TO_PAGE }')); ?>"><?php echo (isset($this->_rootref['S_ON_PAGE'])) ? $this->_rootref['S_ON_PAGE'] : ''; ?></a> &bull; <span><?php echo (isset($this->_rootref['PAGINATION'])) ? $this->_rootref['PAGINATION'] : ''; ?></span>
</div>
<?php } if ($this->_rootref['S_SHOW_FORUMS']) {  ?>
	<fieldset class="quick">
		<?php echo ((isset($this->_rootref['L_SELECT_FORUM'])) ? $this->_rootref['L_SELECT_FORUM'] : ((isset($user->lang['SELECT_FORUM'])) ? $user->lang['SELECT_FORUM'] : '{ SELECT_FORUM }')); ?>: <select name="f" onchange="if(this.options[this.selectedIndex].value != -1){ this.form.submit(); }"><?php echo (isset($this->_rootref['S_FORUM_BOX'])) ? $this->_rootref['S_FORUM_BOX'] : ''; ?></select>
		<input class="button2" type="submit" value="<?php echo ((isset($this->_rootref['L_GO'])) ? $this->_rootref['L_GO'] : ((isset($user->lang['GO'])) ? $user->lang['GO'] : '{ GO }')); ?>" />
	</fieldset>
<?php } if ($this->_rootref['S_CLEARLOGS']) {  ?>
	<fieldset class="quick">
		<input class="button2" type="submit" name="delall" value="<?php echo ((isset($this->_rootref['L_DELETE_ALL'])) ? $this->_rootref['L_DELETE_ALL'] : ((isset($user->lang['DELETE_ALL'])) ? $user->lang['DELETE_ALL'] : '{ DELETE_ALL }')); ?>" />&nbsp;
		<input class="button2" type="submit" name="delmarked" value="<?php echo ((isset($this->_rootref['L_DELETE_MARKED'])) ? $this->_rootref['L_DELETE_MARKED'] : ((isset($user->lang['DELETE_MARKED'])) ? $user->lang['DELETE_MARKED'] : '{ DELETE_MARKED }')); ?>" /><br />
		<p class="small"><a href="#" onclick="marklist('list', 'mark', true); return false;"><?php echo ((isset($this->_rootref['L_MARK_ALL'])) ? $this->_rootref['L_MARK_ALL'] : ((isset($user->lang['MARK_ALL'])) ? $user->lang['MARK_ALL'] : '{ MARK_ALL }')); ?></a> &bull; <a href="#" onclick="marklist('list', 'mark', false); return false;"><?php echo ((isset($this->_rootref['L_UNMARK_ALL'])) ? $this->_rootref['L_UNMARK_ALL'] : ((isset($user->lang['UNMARK_ALL'])) ? $user->lang['UNMARK_ALL'] : '{ UNMARK_ALL }')); ?></a></p>
	</fieldset>
<?php } ?>


</form>

<?php $this->_tpl_include('overall_footer.html'); ?>
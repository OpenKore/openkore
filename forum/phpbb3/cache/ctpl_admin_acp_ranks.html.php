<?php $this->_tpl_include('overall_header.html'); ?>

<a name="maincontent"></a>

<?php if ($this->_rootref['S_EDIT']) {  ?>

	<a href="<?php echo (isset($this->_rootref['U_BACK'])) ? $this->_rootref['U_BACK'] : ''; ?>" style="float: <?php echo (isset($this->_rootref['S_CONTENT_FLOW_END'])) ? $this->_rootref['S_CONTENT_FLOW_END'] : ''; ?>;">&laquo; <?php echo ((isset($this->_rootref['L_BACK'])) ? $this->_rootref['L_BACK'] : ((isset($user->lang['BACK'])) ? $user->lang['BACK'] : '{ BACK }')); ?></a>

	<script type="text/javascript">
	// <![CDATA[
		function update_image(newimage)
		{
			document.getElementById('image').src = (newimage) ? "<?php echo (isset($this->_rootref['RANKS_PATH'])) ? $this->_rootref['RANKS_PATH'] : ''; ?>/" + encodeURI(newimage) : "./images/spacer.gif";
		}

	// ]]>
	</script>

	<h1><?php echo ((isset($this->_rootref['L_ACP_MANAGE_RANKS'])) ? $this->_rootref['L_ACP_MANAGE_RANKS'] : ((isset($user->lang['ACP_MANAGE_RANKS'])) ? $user->lang['ACP_MANAGE_RANKS'] : '{ ACP_MANAGE_RANKS }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_ACP_RANKS_EXPLAIN'])) ? $this->_rootref['L_ACP_RANKS_EXPLAIN'] : ((isset($user->lang['ACP_RANKS_EXPLAIN'])) ? $user->lang['ACP_RANKS_EXPLAIN'] : '{ ACP_RANKS_EXPLAIN }')); ?></p>

	<form id="acp_ranks" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">
	
	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_ACP_RANKS'])) ? $this->_rootref['L_ACP_RANKS'] : ((isset($user->lang['ACP_RANKS'])) ? $user->lang['ACP_RANKS'] : '{ ACP_RANKS }')); ?></legend>
	<dl>
		<dt><label for="title"><?php echo ((isset($this->_rootref['L_RANK_TITLE'])) ? $this->_rootref['L_RANK_TITLE'] : ((isset($user->lang['RANK_TITLE'])) ? $user->lang['RANK_TITLE'] : '{ RANK_TITLE }')); ?>:</label></dt>
		<dd><input name="title" type="text" id="title" value="<?php echo (isset($this->_rootref['RANK_TITLE'])) ? $this->_rootref['RANK_TITLE'] : ''; ?>" maxlength="255" /></dd>
	</dl>
	<dl>
		<dt><label for="rank_image"><?php echo ((isset($this->_rootref['L_RANK_IMAGE'])) ? $this->_rootref['L_RANK_IMAGE'] : ((isset($user->lang['RANK_IMAGE'])) ? $user->lang['RANK_IMAGE'] : '{ RANK_IMAGE }')); ?>:</label></dt>
		<dd><select name="rank_image" id="rank_image" onchange="update_image(this.options[selectedIndex].value);"><?php echo (isset($this->_rootref['S_FILENAME_LIST'])) ? $this->_rootref['S_FILENAME_LIST'] : ''; ?></select></dd>
		<dd><img src="<?php echo (isset($this->_rootref['RANK_IMAGE'])) ? $this->_rootref['RANK_IMAGE'] : ''; ?>" id="image" alt="" /></dd>
	</dl>
	<dl>
		<dt><label for="special_rank"><?php echo ((isset($this->_rootref['L_RANK_SPECIAL'])) ? $this->_rootref['L_RANK_SPECIAL'] : ((isset($user->lang['RANK_SPECIAL'])) ? $user->lang['RANK_SPECIAL'] : '{ RANK_SPECIAL }')); ?>:</label></dt>
		<dd><label><input onchange="dE('posts', -1)" type="radio" class="radio" name="special_rank" value="1" id="special_rank"<?php if ($this->_rootref['S_SPECIAL_RANK']) {  ?> checked="checked"<?php } ?> /><?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input onchange="dE('posts', 1)" type="radio" class="radio" name="special_rank" value="0"<?php if (! $this->_rootref['S_SPECIAL_RANK']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<?php if ($this->_rootref['S_SPECIAL_RANK']) {  ?><div id="posts" style="display: none;"><?php } else { ?><div id="posts"><?php } ?>
	<dl>
		<dt><label for="min_posts"><?php echo ((isset($this->_rootref['L_RANK_MINIMUM'])) ? $this->_rootref['L_RANK_MINIMUM'] : ((isset($user->lang['RANK_MINIMUM'])) ? $user->lang['RANK_MINIMUM'] : '{ RANK_MINIMUM }')); ?>:</label></dt>
		<dd><input name="min_posts" type="text" id="min_posts" maxlength="10" value="<?php echo (isset($this->_rootref['MIN_POSTS'])) ? $this->_rootref['MIN_POSTS'] : ''; ?>" /></dd>
	</dl>
	</div>

	<p class="submit-buttons">
		<input type="hidden" name="action" value="save" />

		<input class="button1" type="submit" id="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />&nbsp;
		<input class="button2" type="reset" id="reset" name="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" />
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</p>
	</fieldset>
	</form>

<?php } else { ?>

	<h1><?php echo ((isset($this->_rootref['L_ACP_MANAGE_RANKS'])) ? $this->_rootref['L_ACP_MANAGE_RANKS'] : ((isset($user->lang['ACP_MANAGE_RANKS'])) ? $user->lang['ACP_MANAGE_RANKS'] : '{ ACP_MANAGE_RANKS }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_ACP_RANKS_EXPLAIN'])) ? $this->_rootref['L_ACP_RANKS_EXPLAIN'] : ((isset($user->lang['ACP_RANKS_EXPLAIN'])) ? $user->lang['ACP_RANKS_EXPLAIN'] : '{ ACP_RANKS_EXPLAIN }')); ?></p>

	<form id="acp_ranks" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">
	<fieldset class="tabulated">
	<legend><?php echo ((isset($this->_rootref['L_ACP_MANAGE_RANKS'])) ? $this->_rootref['L_ACP_MANAGE_RANKS'] : ((isset($user->lang['ACP_MANAGE_RANKS'])) ? $user->lang['ACP_MANAGE_RANKS'] : '{ ACP_MANAGE_RANKS }')); ?></legend>

	<table cellspacing="1">
	<thead>
	<tr>
		<th><?php echo ((isset($this->_rootref['L_RANK_IMAGE'])) ? $this->_rootref['L_RANK_IMAGE'] : ((isset($user->lang['RANK_IMAGE'])) ? $user->lang['RANK_IMAGE'] : '{ RANK_IMAGE }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_RANK_TITLE'])) ? $this->_rootref['L_RANK_TITLE'] : ((isset($user->lang['RANK_TITLE'])) ? $user->lang['RANK_TITLE'] : '{ RANK_TITLE }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_RANK_MINIMUM'])) ? $this->_rootref['L_RANK_MINIMUM'] : ((isset($user->lang['RANK_MINIMUM'])) ? $user->lang['RANK_MINIMUM'] : '{ RANK_MINIMUM }')); ?></th>
		<th><?php echo ((isset($this->_rootref['L_ACTION'])) ? $this->_rootref['L_ACTION'] : ((isset($user->lang['ACTION'])) ? $user->lang['ACTION'] : '{ ACTION }')); ?></th>
	</tr>
	</thead>
	<tbody>
	<?php $_ranks_count = (isset($this->_tpldata['ranks'])) ? sizeof($this->_tpldata['ranks']) : 0;if ($_ranks_count) {for ($_ranks_i = 0; $_ranks_i < $_ranks_count; ++$_ranks_i){$_ranks_val = &$this->_tpldata['ranks'][$_ranks_i]; if (!($_ranks_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>
		<td style="text-align: center;"><?php if ($_ranks_val['S_RANK_IMAGE']) {  ?><img src="<?php echo $_ranks_val['RANK_IMAGE']; ?>" alt="<?php echo $_ranks_val['RANK_TITLE']; ?>" title="<?php echo $_ranks_val['RANK_TITLE']; ?>" /><?php } else { ?>&nbsp; - &nbsp;<?php } ?></td>
		<td style="text-align: center;"><?php echo $_ranks_val['RANK_TITLE']; ?></td>
		<td style="text-align: center;"><?php if ($_ranks_val['S_SPECIAL_RANK']) {  ?>&nbsp; - &nbsp;<?php } else { echo $_ranks_val['MIN_POSTS']; } ?></td>
		<td style="text-align: center;"><a href="<?php echo $_ranks_val['U_EDIT']; ?>"><?php echo (isset($this->_rootref['ICON_EDIT'])) ? $this->_rootref['ICON_EDIT'] : ''; ?></a> <a href="<?php echo $_ranks_val['U_DELETE']; ?>"><?php echo (isset($this->_rootref['ICON_DELETE'])) ? $this->_rootref['ICON_DELETE'] : ''; ?></a></td>
	</tr>
	<?php }} ?>
	</tbody>
	</table>

	<p class="quick">
		<input class="button2" name="add" type="submit" value="<?php echo ((isset($this->_rootref['L_ADD_RANK'])) ? $this->_rootref['L_ADD_RANK'] : ((isset($user->lang['ADD_RANK'])) ? $user->lang['ADD_RANK'] : '{ ADD_RANK }')); ?>" />
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</p>
	</fieldset>
	</form>

<?php } $this->_tpl_include('overall_footer.html'); ?>
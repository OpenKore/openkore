<?php $this->_tpl_include('overall_header.html'); ?>

<h2 class="solo"><?php echo (isset($this->_rootref['PAGE_TITLE'])) ? $this->_rootref['PAGE_TITLE'] : ''; ?></h2>

<form method="post" action="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>">

<div class="forumbg">
	<div class="inner"><span class="corners-top"><span></span></span>

	<table class="table1" cellspacing="1">
	<thead>
	<tr>
		<th class="name"><span class="rank-img"><?php echo ((isset($this->_rootref['L_RANK'])) ? $this->_rootref['L_RANK'] : ((isset($user->lang['RANK'])) ? $user->lang['RANK'] : '{ RANK }')); ?>&nbsp;</span><?php echo ((isset($this->_rootref['L_ADMINISTRATORS'])) ? $this->_rootref['L_ADMINISTRATORS'] : ((isset($user->lang['ADMINISTRATORS'])) ? $user->lang['ADMINISTRATORS'] : '{ ADMINISTRATORS }')); ?></th>
		<th class="info"><?php echo ((isset($this->_rootref['L_PRIMARY_GROUP'])) ? $this->_rootref['L_PRIMARY_GROUP'] : ((isset($user->lang['PRIMARY_GROUP'])) ? $user->lang['PRIMARY_GROUP'] : '{ PRIMARY_GROUP }')); ?></th>
		<th class="info"><?php echo ((isset($this->_rootref['L_FORUMS'])) ? $this->_rootref['L_FORUMS'] : ((isset($user->lang['FORUMS'])) ? $user->lang['FORUMS'] : '{ FORUMS }')); ?></th>
	</tr>
	</thead>
	<tbody>
<?php $_admin_count = (isset($this->_tpldata['admin'])) ? sizeof($this->_tpldata['admin']) : 0;if ($_admin_count) {for ($_admin_i = 0; $_admin_i < $_admin_count; ++$_admin_i){$_admin_val = &$this->_tpldata['admin'][$_admin_i]; ?>
	<tr class="<?php if (!($_admin_val['S_ROW_COUNT'] & 1)  ) {  ?>bg1<?php } else { ?>bg2<?php } ?>">
		<td><?php if ($_admin_val['RANK_IMG']) {  ?><span class="rank-img"><?php echo $_admin_val['RANK_IMG']; ?></span><?php } else { ?><span class="rank-img"><?php echo $_admin_val['RANK_TITLE']; ?></span><?php } echo $_admin_val['USERNAME_FULL']; ?></td>
		<td class="info"><?php if ($_admin_val['U_GROUP']) {  ?>
			<a<?php if ($_admin_val['GROUP_COLOR']) {  ?> style="font-weight: bold; color:#<?php echo $_admin_val['GROUP_COLOR']; ?>"<?php } ?> href="<?php echo $_admin_val['U_GROUP']; ?>"><?php echo $_admin_val['GROUP_NAME']; ?></a>
			<?php } else { ?>
				<?php echo $_admin_val['GROUP_NAME']; ?>
			<?php } ?></td>
		<td class="info">-</td>
	</tr>
<?php }} else { ?>
	<tr class="bg1">
		<td colspan="3"><strong><?php echo ((isset($this->_rootref['L_NO_MEMBERS'])) ? $this->_rootref['L_NO_MEMBERS'] : ((isset($user->lang['NO_MEMBERS'])) ? $user->lang['NO_MEMBERS'] : '{ NO_MEMBERS }')); ?></strong></td>
	</tr>
<?php } ?>
	</tbody>
	</table>
	
	<span class="corners-bottom"><span></span></span></div>
</div>

<div class="forumbg">
	<div class="inner"><span class="corners-top"><span></span></span>
	 
	<table class="table1" cellspacing="1">
	<thead>
	<tr>
		<th class="name"><?php echo ((isset($this->_rootref['L_MODERATORS'])) ? $this->_rootref['L_MODERATORS'] : ((isset($user->lang['MODERATORS'])) ? $user->lang['MODERATORS'] : '{ MODERATORS }')); ?></th>
		<th class="info">&nbsp;</th>
		<th class="info">&nbsp;</th>
	</tr>
	</thead>
	<tbody>
<?php $_mod_count = (isset($this->_tpldata['mod'])) ? sizeof($this->_tpldata['mod']) : 0;if ($_mod_count) {for ($_mod_i = 0; $_mod_i < $_mod_count; ++$_mod_i){$_mod_val = &$this->_tpldata['mod'][$_mod_i]; ?>
	<tr class="<?php if (!($_mod_val['S_ROW_COUNT'] & 1)  ) {  ?>bg1<?php } else { ?>bg2<?php } ?>">
		<td><?php if ($_mod_val['RANK_IMG']) {  ?><span class="rank-img"><?php echo $_mod_val['RANK_IMG']; ?></span><?php } else { ?><span class="rank-img"><?php echo $_mod_val['RANK_TITLE']; ?></span><?php } echo $_mod_val['USERNAME_FULL']; ?></td>
		<td class="info"><?php if ($_mod_val['U_GROUP']) {  ?>
			<a<?php if ($_mod_val['GROUP_COLOR']) {  ?> style="font-weight: bold; color:#<?php echo $_mod_val['GROUP_COLOR']; ?>"<?php } ?> href="<?php echo $_mod_val['U_GROUP']; ?>"><?php echo $_mod_val['GROUP_NAME']; ?></a>
			<?php } else { ?>
				<?php echo $_mod_val['GROUP_NAME']; ?>
			<?php } ?></td>
		<td class="info"><?php if (! $_mod_val['FORUMS']) {  echo ((isset($this->_rootref['L_ALL_FORUMS'])) ? $this->_rootref['L_ALL_FORUMS'] : ((isset($user->lang['ALL_FORUMS'])) ? $user->lang['ALL_FORUMS'] : '{ ALL_FORUMS }')); } else { ?><select style="width: 100%;"><?php echo $_mod_val['FORUMS']; ?></select><?php } ?></td>
	</tr>
<?php }} else { ?>
	<tr class="bg1">
		<td colspan="3"><strong><?php echo ((isset($this->_rootref['L_NO_MEMBERS'])) ? $this->_rootref['L_NO_MEMBERS'] : ((isset($user->lang['NO_MEMBERS'])) ? $user->lang['NO_MEMBERS'] : '{ NO_MEMBERS }')); ?></strong></td>
	</tr>
<?php } ?>
	</tbody>
	</table>
	
	<span class="corners-bottom"><span></span></span></div>
</div>
	
</form>

<?php $this->_tpl_include('jumpbox.html'); $this->_tpl_include('overall_footer.html'); ?>
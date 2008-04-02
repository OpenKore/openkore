<script type="text/javascript">
// <![CDATA[
	var active_pmask = '0';
	var active_fmask = '0';
	var active_cat = '0';

	var id = '000';

	var role_options = new Array();

	<?php if ($this->_rootref['S_ROLE_JS_ARRAY']) {  ?>
		<?php echo (isset($this->_rootref['S_ROLE_JS_ARRAY'])) ? $this->_rootref['S_ROLE_JS_ARRAY'] : ''; ?>
	<?php } ?>
// ]]>
</script>
<script type="text/javascript" src="style/permissions.js"></script>

<?php $_p_mask_count = (isset($this->_tpldata['p_mask'])) ? sizeof($this->_tpldata['p_mask']) : 0;if ($_p_mask_count) {for ($_p_mask_i = 0; $_p_mask_i < $_p_mask_count; ++$_p_mask_i){$_p_mask_val = &$this->_tpldata['p_mask'][$_p_mask_i]; ?>
<div class="clearfix"></div>
<h3><?php echo $_p_mask_val['NAME']; if ($_p_mask_val['S_LOCAL']) {  ?> <span class="small"> [<?php echo $_p_mask_val['L_ACL_TYPE']; ?>]</span><?php } ?></h3>

<?php $_f_mask_count = (isset($_p_mask_val['f_mask'])) ? sizeof($_p_mask_val['f_mask']) : 0;if ($_f_mask_count) {for ($_f_mask_i = 0; $_f_mask_i < $_f_mask_count; ++$_f_mask_i){$_f_mask_val = &$_p_mask_val['f_mask'][$_f_mask_i]; ?>
<div class="clearfix"></div>
<fieldset class="permissions" id="perm<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>">
	<legend id="legend<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>">
		<?php if (! $_p_mask_val['S_VIEW']) {  ?>
			<input type="checkbox" style="display: none;" class="permissions-checkbox" name="inherit[<?php echo $_f_mask_val['UG_ID']; ?>][<?php echo $_f_mask_val['FORUM_ID']; ?>]" id="checkbox<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>" value="1" onclick="toggle_opacity('<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>')" /> 
		<?php } else { } if ($_f_mask_val['PADDING']) {  ?><span class="padding"><?php echo $_f_mask_val['PADDING']; echo $_f_mask_val['PADDING']; ?></span><?php } echo $_f_mask_val['NAME']; ?>
	</legend>
	<?php if (! $_p_mask_val['S_VIEW']) {  ?>
		<div class="permissions-switch">
			<div class="permissions-reset">
				<a href="#" onclick="mark_options('perm<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>', 'y'); reset_role('role<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>'); init_colours('<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>'); return false;"><?php echo ((isset($this->_rootref['L_ALL_YES'])) ? $this->_rootref['L_ALL_YES'] : ((isset($user->lang['ALL_YES'])) ? $user->lang['ALL_YES'] : '{ ALL_YES }')); ?></a> &middot; <a href="#" onclick="mark_options('perm<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>', 'u'); reset_role('role<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>'); init_colours('<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>'); return false;"><?php echo ((isset($this->_rootref['L_ALL_NO'])) ? $this->_rootref['L_ALL_NO'] : ((isset($user->lang['ALL_NO'])) ? $user->lang['ALL_NO'] : '{ ALL_NO }')); ?></a> &middot; <a href="#" onclick="mark_options('perm<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>', 'n'); reset_role('role<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>'); init_colours('<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>'); return false;"><?php echo ((isset($this->_rootref['L_ALL_NEVER'])) ? $this->_rootref['L_ALL_NEVER'] : ((isset($user->lang['ALL_NEVER'])) ? $user->lang['ALL_NEVER'] : '{ ALL_NEVER }')); ?></a>
			</div>
			<a href="#" onclick="swap_options('<?php echo $_p_mask_val['S_ROW_COUNT']; ?>', '<?php echo $_f_mask_val['S_ROW_COUNT']; ?>', '0', true); return false;"><?php echo ((isset($this->_rootref['L_ADVANCED_PERMISSIONS'])) ? $this->_rootref['L_ADVANCED_PERMISSIONS'] : ((isset($user->lang['ADVANCED_PERMISSIONS'])) ? $user->lang['ADVANCED_PERMISSIONS'] : '{ ADVANCED_PERMISSIONS }')); ?></a><?php if (! $_p_mask_val['S_VIEW'] && $_f_mask_val['S_CUSTOM']) {  ?> *<?php } ?>
		</div>
		<dl class="permissions-simple">
			<dt style="width: 20%"><label for="role<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>"><?php echo ((isset($this->_rootref['L_ROLE'])) ? $this->_rootref['L_ROLE'] : ((isset($user->lang['ROLE'])) ? $user->lang['ROLE'] : '{ ROLE }')); ?>:</label></dt>
			<?php if ($_f_mask_val['S_ROLE_OPTIONS']) {  ?>
				<dd style="margin-left: 20%"><select id="role<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>" name="role[<?php echo $_f_mask_val['UG_ID']; ?>][<?php echo $_f_mask_val['FORUM_ID']; ?>]" onchange="set_role_settings(this.options[selectedIndex].value, 'advanced<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>'); init_colours('<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>')"><?php echo $_f_mask_val['S_ROLE_OPTIONS']; ?></select></dd>
			<?php } else { ?>
				<dd><?php echo ((isset($this->_rootref['L_NO_ROLE_AVAILABLE'])) ? $this->_rootref['L_NO_ROLE_AVAILABLE'] : ((isset($user->lang['NO_ROLE_AVAILABLE'])) ? $user->lang['NO_ROLE_AVAILABLE'] : '{ NO_ROLE_AVAILABLE }')); ?></dd>
			<?php } ?>
		</dl>
	<?php } $_category_count = (isset($_f_mask_val['category'])) ? sizeof($_f_mask_val['category']) : 0;if ($_category_count) {for ($_category_i = 0; $_category_i < $_category_count; ++$_category_i){$_category_val = &$_f_mask_val['category'][$_category_i]; if ($_category_val['S_FIRST_ROW']) {  if (! $_p_mask_val['S_VIEW']) {  ?>
				<div class="permissions-advanced" id="advanced<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>" style="display: none;">
			<?php } else { ?>
				<div class="permissions-advanced" id="advanced<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>">
			<?php } ?>

			<div class="permissions-category">
				<ul>
		<?php } if ($_category_val['S_YES']) {  ?>
			<li class="permissions-preset-yes<?php if ($_p_mask_val['S_FIRST_ROW'] && $_f_mask_val['S_FIRST_ROW'] && $_category_val['S_FIRST_ROW']) {  ?> activetab<?php } ?>" id="tab<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; echo $_category_val['S_ROW_COUNT']; ?>">
		<?php } else if ($_category_val['S_NEVER']) {  ?>
			<li class="permissions-preset-never<?php if ($_p_mask_val['S_FIRST_ROW'] && $_f_mask_val['S_FIRST_ROW'] && $_category_val['S_FIRST_ROW']) {  ?> activetab<?php } ?>" id="tab<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; echo $_category_val['S_ROW_COUNT']; ?>">
		<?php } else if ($_category_val['S_NO']) {  ?>
			<li class="permissions-preset-no<?php if ($_p_mask_val['S_FIRST_ROW'] && $_f_mask_val['S_FIRST_ROW'] && $_category_val['S_FIRST_ROW']) {  ?> activetab<?php } ?>" id="tab<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; echo $_category_val['S_ROW_COUNT']; ?>">
		<?php } else { ?>
			<li class="permissions-preset-custom<?php if ($_p_mask_val['S_FIRST_ROW'] && $_f_mask_val['S_FIRST_ROW'] && $_category_val['S_FIRST_ROW']) {  ?> activetab<?php } ?>" id="tab<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; echo $_category_val['S_ROW_COUNT']; ?>">
		<?php } ?>
		<a href="#" onclick="swap_options('<?php echo $_p_mask_val['S_ROW_COUNT']; ?>', '<?php echo $_f_mask_val['S_ROW_COUNT']; ?>', '<?php echo $_category_val['S_ROW_COUNT']; ?>', false<?php if ($_p_mask_val['S_VIEW']) {  ?>, true<?php } ?>); return false;"><span class="tabbg"><span class="colour"></span><?php echo $_category_val['CAT_NAME']; ?></span></a></li>
	<?php }} ?>
				</ul>
			</div>

	<?php $_category_count = (isset($_f_mask_val['category'])) ? sizeof($_f_mask_val['category']) : 0;if ($_category_count) {for ($_category_i = 0; $_category_i < $_category_count; ++$_category_i){$_category_val = &$_f_mask_val['category'][$_category_i]; ?>
		<div class="permissions-panel" id="options<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; echo $_category_val['S_ROW_COUNT']; ?>" <?php if ($_p_mask_val['S_FIRST_ROW'] && $_f_mask_val['S_FIRST_ROW'] && $_category_val['S_FIRST_ROW']) {  } else { ?> style="display: none;"<?php } ?>>
			<span class="corners-top"><span></span></span>
			<div class="tablewrap">
				<table id="table<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; echo $_category_val['S_ROW_COUNT']; ?>" cellspacing="1">
				<colgroup>
					<col class="permissions-name" />
					<col class="permissions-yes" />
					<col class="permissions-no" />
					<?php if (! $_p_mask_val['S_VIEW']) {  ?>
						<col class="permissions-never" />
					<?php } ?>
				</colgroup>
				<thead>
				<tr>
					<th class="name" scope="col"><strong><?php echo ((isset($this->_rootref['L_ACL_SETTING'])) ? $this->_rootref['L_ACL_SETTING'] : ((isset($user->lang['ACL_SETTING'])) ? $user->lang['ACL_SETTING'] : '{ ACL_SETTING }')); ?></strong></th>
				<?php if ($_p_mask_val['S_VIEW']) {  ?>
					<th class="value" scope="col"><?php echo ((isset($this->_rootref['L_ACL_YES'])) ? $this->_rootref['L_ACL_YES'] : ((isset($user->lang['ACL_YES'])) ? $user->lang['ACL_YES'] : '{ ACL_YES }')); ?></th>
					<th class="value" scope="col"><?php echo ((isset($this->_rootref['L_ACL_NEVER'])) ? $this->_rootref['L_ACL_NEVER'] : ((isset($user->lang['ACL_NEVER'])) ? $user->lang['ACL_NEVER'] : '{ ACL_NEVER }')); ?></th>
				<?php } else { ?>
					<th class="value permissions-yes" scope="col"><a href="#" onclick="mark_options('options<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; echo $_category_val['S_ROW_COUNT']; ?>', 'y'); reset_role('role<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>'); set_colours('<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; echo $_category_val['S_ROW_COUNT']; ?>', false, 'yes'); return false;"><?php echo ((isset($this->_rootref['L_ACL_YES'])) ? $this->_rootref['L_ACL_YES'] : ((isset($user->lang['ACL_YES'])) ? $user->lang['ACL_YES'] : '{ ACL_YES }')); ?></a></th>
					<th class="value permissions-no" scope="col"><a href="#" onclick="mark_options('options<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; echo $_category_val['S_ROW_COUNT']; ?>', 'u'); reset_role('role<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>'); set_colours('<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; echo $_category_val['S_ROW_COUNT']; ?>', false, 'no'); return false;"><?php echo ((isset($this->_rootref['L_ACL_NO'])) ? $this->_rootref['L_ACL_NO'] : ((isset($user->lang['ACL_NO'])) ? $user->lang['ACL_NO'] : '{ ACL_NO }')); ?></a></th>
					<th class="value permissions-never" scope="col"><a href="#" onclick="mark_options('options<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; echo $_category_val['S_ROW_COUNT']; ?>', 'n'); reset_role('role<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>'); set_colours('<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; echo $_category_val['S_ROW_COUNT']; ?>', false, 'never'); return false;"><?php echo ((isset($this->_rootref['L_ACL_NEVER'])) ? $this->_rootref['L_ACL_NEVER'] : ((isset($user->lang['ACL_NEVER'])) ? $user->lang['ACL_NEVER'] : '{ ACL_NEVER }')); ?></a></th>
				<?php } ?>
				</tr>
				</thead>
				<tbody>
				<?php $_mask_count = (isset($_category_val['mask'])) ? sizeof($_category_val['mask']) : 0;if ($_mask_count) {for ($_mask_i = 0; $_mask_i < $_mask_count; ++$_mask_i){$_mask_val = &$_category_val['mask'][$_mask_i]; if (!($_mask_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row4"><?php } else { ?><tr class="row3"><?php } ?>
					<th class="permissions-name<?php if (!($_mask_val['S_ROW_COUNT'] & 1)  ) {  ?> row4<?php } else { ?> row3<?php } ?>"><?php if ($_mask_val['U_TRACE']) {  ?><a href="<?php echo $_mask_val['U_TRACE']; ?>" class="trace" onclick="popup(this.href, 750, 515, '_trace'); return false;" title="<?php echo ((isset($this->_rootref['L_TRACE_SETTING'])) ? $this->_rootref['L_TRACE_SETTING'] : ((isset($user->lang['TRACE_SETTING'])) ? $user->lang['TRACE_SETTING'] : '{ TRACE_SETTING }')); ?>"><img src="images/icon_trace.gif" alt="<?php echo ((isset($this->_rootref['L_TRACE_SETTING'])) ? $this->_rootref['L_TRACE_SETTING'] : ((isset($user->lang['TRACE_SETTING'])) ? $user->lang['TRACE_SETTING'] : '{ TRACE_SETTING }')); ?>" /></a> <?php } echo $_mask_val['PERMISSION']; ?></th>
					<?php if ($_p_mask_val['S_VIEW']) {  ?>
						<td<?php if ($_mask_val['S_YES']) {  ?> class="yes"<?php } ?>>&nbsp;</td>
						<td<?php if ($_mask_val['S_NEVER']) {  ?> class="never"<?php } ?>></td>
					<?php } else { ?>
						<td class="permissions-yes"><label for="<?php echo $_mask_val['S_FIELD_NAME']; ?>_y"><input onclick="reset_role('role<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>'); set_colours('<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; echo $_category_val['S_ROW_COUNT']; ?>', false)" id="<?php echo $_mask_val['S_FIELD_NAME']; ?>_y" name="<?php echo $_mask_val['S_FIELD_NAME']; ?>" class="radio" type="radio"<?php if ($_mask_val['S_YES']) {  ?> checked="checked"<?php } ?> value="1" /></label></td>
						<td class="permissions-no"><label for="<?php echo $_mask_val['S_FIELD_NAME']; ?>_u"><input onclick="reset_role('role<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>'); set_colours('<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; echo $_category_val['S_ROW_COUNT']; ?>', false)" id="<?php echo $_mask_val['S_FIELD_NAME']; ?>_u" name="<?php echo $_mask_val['S_FIELD_NAME']; ?>" class="radio" type="radio"<?php if ($_mask_val['S_NO']) {  ?> checked="checked"<?php } ?> value="-1" /></label></td>
						<td class="permissions-never"><label for="<?php echo $_mask_val['S_FIELD_NAME']; ?>_n"><input onclick="reset_role('role<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>'); set_colours('<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; echo $_category_val['S_ROW_COUNT']; ?>', false)" id="<?php echo $_mask_val['S_FIELD_NAME']; ?>_n" name="<?php echo $_mask_val['S_FIELD_NAME']; ?>" class="radio" type="radio"<?php if ($_mask_val['S_NEVER']) {  ?> checked="checked"<?php } ?> value="0" /></label></td>
					<?php } ?>
				</tr>
				<?php }} ?>
				</tbody>
				</table>
			</div>
			
			<?php if (! $_p_mask_val['S_VIEW']) {  ?>
			<fieldset class="quick" style="margin-right: 11px;">
				<p class="small"><?php echo ((isset($this->_rootref['L_APPLY_PERMISSIONS_EXPLAIN'])) ? $this->_rootref['L_APPLY_PERMISSIONS_EXPLAIN'] : ((isset($user->lang['APPLY_PERMISSIONS_EXPLAIN'])) ? $user->lang['APPLY_PERMISSIONS_EXPLAIN'] : '{ APPLY_PERMISSIONS_EXPLAIN }')); ?></p>
				<input class="button1" type="submit" name="psubmit[<?php echo $_f_mask_val['UG_ID']; ?>][<?php echo $_f_mask_val['FORUM_ID']; ?>]" value="<?php echo ((isset($this->_rootref['L_APPLY_PERMISSIONS'])) ? $this->_rootref['L_APPLY_PERMISSIONS'] : ((isset($user->lang['APPLY_PERMISSIONS'])) ? $user->lang['APPLY_PERMISSIONS'] : '{ APPLY_PERMISSIONS }')); ?>" />
				<?php if (sizeof($_p_mask_val['f_mask']) > 1 || sizeof($this->_tpldata['p_mask']) > 1) {  ?>
					<p class="small"><a href="#" onclick="reset_opacity(0, '<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>'); return false;"><?php echo ((isset($this->_rootref['L_MARK_ALL'])) ? $this->_rootref['L_MARK_ALL'] : ((isset($user->lang['MARK_ALL'])) ? $user->lang['MARK_ALL'] : '{ MARK_ALL }')); ?></a> &bull; <a href="#" onclick="reset_opacity(1, '<?php echo $_p_mask_val['S_ROW_COUNT']; echo $_f_mask_val['S_ROW_COUNT']; ?>'); return false;"><?php echo ((isset($this->_rootref['L_UNMARK_ALL'])) ? $this->_rootref['L_UNMARK_ALL'] : ((isset($user->lang['UNMARK_ALL'])) ? $user->lang['UNMARK_ALL'] : '{ UNMARK_ALL }')); ?></a></p>
				<?php } ?>
			</fieldset>
		
			<?php } ?>

			<span class="corners-bottom"><span></span></span>
		</div>
	<?php }} ?>
			<div class="clearfix"></div>
	</div>
</fieldset>
<?php }} }} ?>
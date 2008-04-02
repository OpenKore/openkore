<?php $this->_tpl_include('overall_header.html'); ?>

<a name="maincontent"></a>

<?php if ($this->_rootref['S_SETTINGS']) {  ?>
	<h1><?php echo ((isset($this->_rootref['L_ACP_SEARCH_SETTINGS'])) ? $this->_rootref['L_ACP_SEARCH_SETTINGS'] : ((isset($user->lang['ACP_SEARCH_SETTINGS'])) ? $user->lang['ACP_SEARCH_SETTINGS'] : '{ ACP_SEARCH_SETTINGS }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_ACP_SEARCH_SETTINGS_EXPLAIN'])) ? $this->_rootref['L_ACP_SEARCH_SETTINGS_EXPLAIN'] : ((isset($user->lang['ACP_SEARCH_SETTINGS_EXPLAIN'])) ? $user->lang['ACP_SEARCH_SETTINGS_EXPLAIN'] : '{ ACP_SEARCH_SETTINGS_EXPLAIN }')); ?></p>

	<form id="acp_search" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_GENERAL_SEARCH_SETTINGS'])) ? $this->_rootref['L_GENERAL_SEARCH_SETTINGS'] : ((isset($user->lang['GENERAL_SEARCH_SETTINGS'])) ? $user->lang['GENERAL_SEARCH_SETTINGS'] : '{ GENERAL_SEARCH_SETTINGS }')); ?></legend>
	<dl>
		<dt><label for="load_search"><?php echo ((isset($this->_rootref['L_YES_SEARCH'])) ? $this->_rootref['L_YES_SEARCH'] : ((isset($user->lang['YES_SEARCH'])) ? $user->lang['YES_SEARCH'] : '{ YES_SEARCH }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_YES_SEARCH_EXPLAIN'])) ? $this->_rootref['L_YES_SEARCH_EXPLAIN'] : ((isset($user->lang['YES_SEARCH_EXPLAIN'])) ? $user->lang['YES_SEARCH_EXPLAIN'] : '{ YES_SEARCH_EXPLAIN }')); ?></span></dt>
		<dd><label><input type="radio" class="radio" id="load_search" name="config[load_search]" value="1"<?php if ($this->_rootref['S_YES_SEARCH']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label>
			<label><input type="radio" class="radio" name="config[load_search]" value="0"<?php if (! $this->_rootref['S_YES_SEARCH']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label></dd>
	</dl>
	<dl>
		<dt><label for="search_interval"><?php echo ((isset($this->_rootref['L_SEARCH_INTERVAL'])) ? $this->_rootref['L_SEARCH_INTERVAL'] : ((isset($user->lang['SEARCH_INTERVAL'])) ? $user->lang['SEARCH_INTERVAL'] : '{ SEARCH_INTERVAL }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_SEARCH_INTERVAL_EXPLAIN'])) ? $this->_rootref['L_SEARCH_INTERVAL_EXPLAIN'] : ((isset($user->lang['SEARCH_INTERVAL_EXPLAIN'])) ? $user->lang['SEARCH_INTERVAL_EXPLAIN'] : '{ SEARCH_INTERVAL_EXPLAIN }')); ?></span></dt>
		<dd><input id="search_interval" type="text" size="4" maxlength="4" name="config[search_interval]" value="<?php echo (isset($this->_rootref['SEARCH_INTERVAL'])) ? $this->_rootref['SEARCH_INTERVAL'] : ''; ?>" /> <?php echo ((isset($this->_rootref['L_SECONDS'])) ? $this->_rootref['L_SECONDS'] : ((isset($user->lang['SECONDS'])) ? $user->lang['SECONDS'] : '{ SECONDS }')); ?></dd>
	</dl>
	<dl>
		<dt><label for="search_anonymous_interval"><?php echo ((isset($this->_rootref['L_SEARCH_GUEST_INTERVAL'])) ? $this->_rootref['L_SEARCH_GUEST_INTERVAL'] : ((isset($user->lang['SEARCH_GUEST_INTERVAL'])) ? $user->lang['SEARCH_GUEST_INTERVAL'] : '{ SEARCH_GUEST_INTERVAL }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_SEARCH_GUEST_INTERVAL_EXPLAIN'])) ? $this->_rootref['L_SEARCH_GUEST_INTERVAL_EXPLAIN'] : ((isset($user->lang['SEARCH_GUEST_INTERVAL_EXPLAIN'])) ? $user->lang['SEARCH_GUEST_INTERVAL_EXPLAIN'] : '{ SEARCH_GUEST_INTERVAL_EXPLAIN }')); ?></span></dt>
		<dd><input id="search_anonymous_interval" type="text" size="4" maxlength="4" name="config[search_anonymous_interval]" value="<?php echo (isset($this->_rootref['SEARCH_GUEST_INTERVAL'])) ? $this->_rootref['SEARCH_GUEST_INTERVAL'] : ''; ?>" /> <?php echo ((isset($this->_rootref['L_SECONDS'])) ? $this->_rootref['L_SECONDS'] : ((isset($user->lang['SECONDS'])) ? $user->lang['SECONDS'] : '{ SECONDS }')); ?></dd>
	</dl>
	<dl>
		<dt><label for="limit_search_load"><?php echo ((isset($this->_rootref['L_LIMIT_SEARCH_LOAD'])) ? $this->_rootref['L_LIMIT_SEARCH_LOAD'] : ((isset($user->lang['LIMIT_SEARCH_LOAD'])) ? $user->lang['LIMIT_SEARCH_LOAD'] : '{ LIMIT_SEARCH_LOAD }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_LIMIT_SEARCH_LOAD_EXPLAIN'])) ? $this->_rootref['L_LIMIT_SEARCH_LOAD_EXPLAIN'] : ((isset($user->lang['LIMIT_SEARCH_LOAD_EXPLAIN'])) ? $user->lang['LIMIT_SEARCH_LOAD_EXPLAIN'] : '{ LIMIT_SEARCH_LOAD_EXPLAIN }')); ?></span></dt>
		<dd><input id="limit_search_load" type="text" size="4" maxlength="4" name="config[limit_search_load]" value="<?php echo (isset($this->_rootref['LIMIT_SEARCH_LOAD'])) ? $this->_rootref['LIMIT_SEARCH_LOAD'] : ''; ?>" /></dd>
	</dl>
	<dl>
		<dt><label for="min_search_author_chars"><?php echo ((isset($this->_rootref['L_MIN_SEARCH_AUTHOR_CHARS'])) ? $this->_rootref['L_MIN_SEARCH_AUTHOR_CHARS'] : ((isset($user->lang['MIN_SEARCH_AUTHOR_CHARS'])) ? $user->lang['MIN_SEARCH_AUTHOR_CHARS'] : '{ MIN_SEARCH_AUTHOR_CHARS }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_MIN_SEARCH_AUTHOR_CHARS_EXPLAIN'])) ? $this->_rootref['L_MIN_SEARCH_AUTHOR_CHARS_EXPLAIN'] : ((isset($user->lang['MIN_SEARCH_AUTHOR_CHARS_EXPLAIN'])) ? $user->lang['MIN_SEARCH_AUTHOR_CHARS_EXPLAIN'] : '{ MIN_SEARCH_AUTHOR_CHARS_EXPLAIN }')); ?></span></dt>
		<dd><input id="min_search_author_chars" type="text" size="4" maxlength="4" name="config[min_search_author_chars]" value="<?php echo (isset($this->_rootref['MIN_SEARCH_AUTHOR_CHARS'])) ? $this->_rootref['MIN_SEARCH_AUTHOR_CHARS'] : ''; ?>" /></dd>
	</dl>
	<dl>
		<dt><label for="search_store_results"><?php echo ((isset($this->_rootref['L_SEARCH_STORE_RESULTS'])) ? $this->_rootref['L_SEARCH_STORE_RESULTS'] : ((isset($user->lang['SEARCH_STORE_RESULTS'])) ? $user->lang['SEARCH_STORE_RESULTS'] : '{ SEARCH_STORE_RESULTS }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_SEARCH_STORE_RESULTS_EXPLAIN'])) ? $this->_rootref['L_SEARCH_STORE_RESULTS_EXPLAIN'] : ((isset($user->lang['SEARCH_STORE_RESULTS_EXPLAIN'])) ? $user->lang['SEARCH_STORE_RESULTS_EXPLAIN'] : '{ SEARCH_STORE_RESULTS_EXPLAIN }')); ?></span></dt>
		<dd><input id="search_store_results" type="text" size="4" maxlength="6" name="config[search_store_results]" value="<?php echo (isset($this->_rootref['SEARCH_STORE_RESULTS'])) ? $this->_rootref['SEARCH_STORE_RESULTS'] : ''; ?>" /> <?php echo ((isset($this->_rootref['L_SECONDS'])) ? $this->_rootref['L_SECONDS'] : ((isset($user->lang['SECONDS'])) ? $user->lang['SECONDS'] : '{ SECONDS }')); ?></dd>
	</dl>
	</fieldset>

	<fieldset>
		<legend><?php echo ((isset($this->_rootref['L_SEARCH_TYPE'])) ? $this->_rootref['L_SEARCH_TYPE'] : ((isset($user->lang['SEARCH_TYPE'])) ? $user->lang['SEARCH_TYPE'] : '{ SEARCH_TYPE }')); ?></legend>
	<dl>
		<dt><label for="search_type"><?php echo ((isset($this->_rootref['L_SEARCH_TYPE'])) ? $this->_rootref['L_SEARCH_TYPE'] : ((isset($user->lang['SEARCH_TYPE'])) ? $user->lang['SEARCH_TYPE'] : '{ SEARCH_TYPE }')); ?>:</label><br /><span><?php echo ((isset($this->_rootref['L_SEARCH_TYPE_EXPLAIN'])) ? $this->_rootref['L_SEARCH_TYPE_EXPLAIN'] : ((isset($user->lang['SEARCH_TYPE_EXPLAIN'])) ? $user->lang['SEARCH_TYPE_EXPLAIN'] : '{ SEARCH_TYPE_EXPLAIN }')); ?></span></dt>
		<dd><select id="search_type" name="config[search_type]"><?php echo (isset($this->_rootref['S_SEARCH_TYPES'])) ? $this->_rootref['S_SEARCH_TYPES'] : ''; ?></select></dd>
	</dl>
	</fieldset>

	<?php $_backend_count = (isset($this->_tpldata['backend'])) ? sizeof($this->_tpldata['backend']) : 0;if ($_backend_count) {for ($_backend_i = 0; $_backend_i < $_backend_count; ++$_backend_i){$_backend_val = &$this->_tpldata['backend'][$_backend_i]; ?>

		<fieldset>
			<legend><?php echo $_backend_val['NAME']; ?></legend>
		<?php echo $_backend_val['SETTINGS']; ?>
		</fieldset>

	<?php }} ?>

	<fieldset class="submit-buttons">
		<legend><?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?></legend>
		<input class="button1" type="submit" id="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" />&nbsp;
		<input class="button2" type="reset" id="reset" name="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" />
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>
	</form>

<?php } else if ($this->_rootref['S_INDEX']) {  ?>

	<script type="text/javascript">
	// <![CDATA[
		/**
		* Popup search progress bar
		*/
		function popup_progress_bar(progress_type)
		{
			close_waitscreen = 0;
			// no scrollbars
			popup('<?php echo (isset($this->_rootref['UA_PROGRESS_BAR'])) ? $this->_rootref['UA_PROGRESS_BAR'] : ''; ?>&amp;type=' + progress_type, 400, 240, '_index');
		}
	// ]]>
	</script>

	<h1><?php echo ((isset($this->_rootref['L_ACP_SEARCH_INDEX'])) ? $this->_rootref['L_ACP_SEARCH_INDEX'] : ((isset($user->lang['ACP_SEARCH_INDEX'])) ? $user->lang['ACP_SEARCH_INDEX'] : '{ ACP_SEARCH_INDEX }')); ?></h1>

	<?php if ($this->_rootref['S_CONTINUE_INDEXING']) {  ?>
		<p><?php echo ((isset($this->_rootref['L_CONTINUE_EXPLAIN'])) ? $this->_rootref['L_CONTINUE_EXPLAIN'] : ((isset($user->lang['CONTINUE_EXPLAIN'])) ? $user->lang['CONTINUE_EXPLAIN'] : '{ CONTINUE_EXPLAIN }')); ?></p>

		<form id="acp_search_continue" method="post" action="<?php echo (isset($this->_rootref['U_CONTINUE_INDEXING'])) ? $this->_rootref['U_CONTINUE_INDEXING'] : ''; ?>">
			<fieldset class="submit-buttons">
				<legend><?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?></legend>
				<input class="button1" type="submit" id="continue" name="continue" value="<?php echo ((isset($this->_rootref['L_CONTINUE'])) ? $this->_rootref['L_CONTINUE'] : ((isset($user->lang['CONTINUE'])) ? $user->lang['CONTINUE'] : '{ CONTINUE }')); ?>" onclick="popup_progress_bar('<?php echo (isset($this->_rootref['S_CONTINUE_INDEXING'])) ? $this->_rootref['S_CONTINUE_INDEXING'] : ''; ?>');" />&nbsp;
				<input class="button2" type="submit" id="cancel" name="cancel" value="<?php echo ((isset($this->_rootref['L_CANCEL'])) ? $this->_rootref['L_CANCEL'] : ((isset($user->lang['CANCEL'])) ? $user->lang['CANCEL'] : '{ CANCEL }')); ?>" />
				<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
			</fieldset>
		</form>
	<?php } else { ?>

		<p><?php echo ((isset($this->_rootref['L_ACP_SEARCH_INDEX_EXPLAIN'])) ? $this->_rootref['L_ACP_SEARCH_INDEX_EXPLAIN'] : ((isset($user->lang['ACP_SEARCH_INDEX_EXPLAIN'])) ? $user->lang['ACP_SEARCH_INDEX_EXPLAIN'] : '{ ACP_SEARCH_INDEX_EXPLAIN }')); ?></p>

		<?php $_backend_count = (isset($this->_tpldata['backend'])) ? sizeof($this->_tpldata['backend']) : 0;if ($_backend_count) {for ($_backend_i = 0; $_backend_i < $_backend_count; ++$_backend_i){$_backend_val = &$this->_tpldata['backend'][$_backend_i]; if ($_backend_val['S_STATS']) {  ?>

			<form id="acp_search_index_<?php echo $_backend_val['NAME']; ?>" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">

				<fieldset class="tabulated">

				<?php echo $_backend_val['S_HIDDEN_FIELDS']; ?>

				<legend><?php echo ((isset($this->_rootref['L_INDEX_STATS'])) ? $this->_rootref['L_INDEX_STATS'] : ((isset($user->lang['INDEX_STATS'])) ? $user->lang['INDEX_STATS'] : '{ INDEX_STATS }')); ?>: <?php echo $_backend_val['L_NAME']; ?> <?php if ($_backend_val['S_ACTIVE']) {  ?>(<?php echo ((isset($this->_rootref['L_ACTIVE'])) ? $this->_rootref['L_ACTIVE'] : ((isset($user->lang['ACTIVE'])) ? $user->lang['ACTIVE'] : '{ ACTIVE }')); ?>) <?php } ?></legend>

				<table cellspacing="1">
					<caption><?php echo $_backend_val['L_NAME']; ?> <?php if ($_backend_val['S_ACTIVE']) {  ?>(<?php echo ((isset($this->_rootref['L_ACTIVE'])) ? $this->_rootref['L_ACTIVE'] : ((isset($user->lang['ACTIVE'])) ? $user->lang['ACTIVE'] : '{ ACTIVE }')); ?>) <?php } ?></caption>
					<col class="col1" /><col class="col2" /><col class="col1" /><col class="col2" />
				<thead>
				<tr>
					<th><?php echo ((isset($this->_rootref['L_STATISTIC'])) ? $this->_rootref['L_STATISTIC'] : ((isset($user->lang['STATISTIC'])) ? $user->lang['STATISTIC'] : '{ STATISTIC }')); ?></th>
					<th><?php echo ((isset($this->_rootref['L_VALUE'])) ? $this->_rootref['L_VALUE'] : ((isset($user->lang['VALUE'])) ? $user->lang['VALUE'] : '{ VALUE }')); ?></th>
					<th><?php echo ((isset($this->_rootref['L_STATISTIC'])) ? $this->_rootref['L_STATISTIC'] : ((isset($user->lang['STATISTIC'])) ? $user->lang['STATISTIC'] : '{ STATISTIC }')); ?></th>
					<th><?php echo ((isset($this->_rootref['L_VALUE'])) ? $this->_rootref['L_VALUE'] : ((isset($user->lang['VALUE'])) ? $user->lang['VALUE'] : '{ VALUE }')); ?></th>
				</tr>
				</thead>
				<tbody>
				<?php $_data_count = (isset($_backend_val['data'])) ? sizeof($_backend_val['data']) : 0;if ($_data_count) {for ($_data_i = 0; $_data_i < $_data_count; ++$_data_i){$_data_val = &$_backend_val['data'][$_data_i]; ?>
					<tr>
						<td><?php echo $_data_val['STATISTIC_1']; ?>:</td>
						<td><?php echo $_data_val['VALUE_1']; ?></td>
						<td><?php echo $_data_val['STATISTIC_2']; if ($_data_val['STATISTIC_2']) {  ?>:<?php } ?></td>
						<td><?php echo $_data_val['VALUE_2']; ?></td>
					</tr>
				<?php }} ?>
				</tbody>
				</table>
			
			<?php } ?>
			
			<p class="quick">
			<?php if ($_backend_val['S_INDEXED']) {  ?>
				<input class="button2" type="submit" name="action[delete]" value="<?php echo ((isset($this->_rootref['L_DELETE_INDEX'])) ? $this->_rootref['L_DELETE_INDEX'] : ((isset($user->lang['DELETE_INDEX'])) ? $user->lang['DELETE_INDEX'] : '{ DELETE_INDEX }')); ?>" onclick="popup_progress_bar('delete');" />
			<?php } else { ?>
				<input class="button2" type="submit" name="action[create]" value="<?php echo ((isset($this->_rootref['L_CREATE_INDEX'])) ? $this->_rootref['L_CREATE_INDEX'] : ((isset($user->lang['CREATE_INDEX'])) ? $user->lang['CREATE_INDEX'] : '{ CREATE_INDEX }')); ?>" onclick="popup_progress_bar('create');" />
			<?php } ?>
			</p>
			<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
			</fieldset>
			
			</form>
		<?php }} } } $this->_tpl_include('overall_footer.html'); ?>
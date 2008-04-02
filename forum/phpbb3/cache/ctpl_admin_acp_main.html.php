<?php $this->_tpl_include('overall_header.html'); ?>

<a name="maincontent"></a>

<?php if ($this->_rootref['S_RESTORE_PERMISSIONS']) {  ?>

	<h1><?php echo ((isset($this->_rootref['L_PERMISSIONS_TRANSFERRED'])) ? $this->_rootref['L_PERMISSIONS_TRANSFERRED'] : ((isset($user->lang['PERMISSIONS_TRANSFERRED'])) ? $user->lang['PERMISSIONS_TRANSFERRED'] : '{ PERMISSIONS_TRANSFERRED }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_PERMISSIONS_TRANSFERRED_EXPLAIN'])) ? $this->_rootref['L_PERMISSIONS_TRANSFERRED_EXPLAIN'] : ((isset($user->lang['PERMISSIONS_TRANSFERRED_EXPLAIN'])) ? $user->lang['PERMISSIONS_TRANSFERRED_EXPLAIN'] : '{ PERMISSIONS_TRANSFERRED_EXPLAIN }')); ?></p>

<?php } else { ?>

	<h1><?php echo ((isset($this->_rootref['L_WELCOME_PHPBB'])) ? $this->_rootref['L_WELCOME_PHPBB'] : ((isset($user->lang['WELCOME_PHPBB'])) ? $user->lang['WELCOME_PHPBB'] : '{ WELCOME_PHPBB }')); ?></h1>

	<p><?php echo ((isset($this->_rootref['L_ADMIN_INTRO'])) ? $this->_rootref['L_ADMIN_INTRO'] : ((isset($user->lang['ADMIN_INTRO'])) ? $user->lang['ADMIN_INTRO'] : '{ ADMIN_INTRO }')); ?></p>

	<?php if ($this->_rootref['S_REMOVE_INSTALL']) {  ?>
		<div class="errorbox">
			<h3><?php echo ((isset($this->_rootref['L_WARNING'])) ? $this->_rootref['L_WARNING'] : ((isset($user->lang['WARNING'])) ? $user->lang['WARNING'] : '{ WARNING }')); ?></h3>
			<p><?php echo ((isset($this->_rootref['L_REMOVE_INSTALL'])) ? $this->_rootref['L_REMOVE_INSTALL'] : ((isset($user->lang['REMOVE_INSTALL'])) ? $user->lang['REMOVE_INSTALL'] : '{ REMOVE_INSTALL }')); ?></p>
		</div>
	<?php } ?>

	<table cellspacing="1">
		<caption><?php echo ((isset($this->_rootref['L_FORUM_STATS'])) ? $this->_rootref['L_FORUM_STATS'] : ((isset($user->lang['FORUM_STATS'])) ? $user->lang['FORUM_STATS'] : '{ FORUM_STATS }')); ?></caption>
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
	<tr>
		<td><?php echo ((isset($this->_rootref['L_NUMBER_POSTS'])) ? $this->_rootref['L_NUMBER_POSTS'] : ((isset($user->lang['NUMBER_POSTS'])) ? $user->lang['NUMBER_POSTS'] : '{ NUMBER_POSTS }')); ?>: </td>
		<td><strong><?php echo (isset($this->_rootref['TOTAL_POSTS'])) ? $this->_rootref['TOTAL_POSTS'] : ''; ?></strong></td>
		<td><?php echo ((isset($this->_rootref['L_POSTS_PER_DAY'])) ? $this->_rootref['L_POSTS_PER_DAY'] : ((isset($user->lang['POSTS_PER_DAY'])) ? $user->lang['POSTS_PER_DAY'] : '{ POSTS_PER_DAY }')); ?>: </td>
		<td><strong><?php echo (isset($this->_rootref['POSTS_PER_DAY'])) ? $this->_rootref['POSTS_PER_DAY'] : ''; ?></strong></td>
	</tr>
	<tr>
		<td><?php echo ((isset($this->_rootref['L_NUMBER_TOPICS'])) ? $this->_rootref['L_NUMBER_TOPICS'] : ((isset($user->lang['NUMBER_TOPICS'])) ? $user->lang['NUMBER_TOPICS'] : '{ NUMBER_TOPICS }')); ?>: </td>
		<td><strong><?php echo (isset($this->_rootref['TOTAL_TOPICS'])) ? $this->_rootref['TOTAL_TOPICS'] : ''; ?></strong></td>
		<td><?php echo ((isset($this->_rootref['L_TOPICS_PER_DAY'])) ? $this->_rootref['L_TOPICS_PER_DAY'] : ((isset($user->lang['TOPICS_PER_DAY'])) ? $user->lang['TOPICS_PER_DAY'] : '{ TOPICS_PER_DAY }')); ?>: </td>
		<td><strong><?php echo (isset($this->_rootref['TOPICS_PER_DAY'])) ? $this->_rootref['TOPICS_PER_DAY'] : ''; ?></strong></td>
	</tr>
	<tr>
		<td><?php echo ((isset($this->_rootref['L_NUMBER_USERS'])) ? $this->_rootref['L_NUMBER_USERS'] : ((isset($user->lang['NUMBER_USERS'])) ? $user->lang['NUMBER_USERS'] : '{ NUMBER_USERS }')); ?>: </td>
		<td><strong><?php echo (isset($this->_rootref['TOTAL_USERS'])) ? $this->_rootref['TOTAL_USERS'] : ''; ?></strong></td>
		<td><?php echo ((isset($this->_rootref['L_USERS_PER_DAY'])) ? $this->_rootref['L_USERS_PER_DAY'] : ((isset($user->lang['USERS_PER_DAY'])) ? $user->lang['USERS_PER_DAY'] : '{ USERS_PER_DAY }')); ?>: </td>
		<td><strong><?php echo (isset($this->_rootref['USERS_PER_DAY'])) ? $this->_rootref['USERS_PER_DAY'] : ''; ?></strong></td>
	</tr>
	<tr>
		<td><?php echo ((isset($this->_rootref['L_NUMBER_FILES'])) ? $this->_rootref['L_NUMBER_FILES'] : ((isset($user->lang['NUMBER_FILES'])) ? $user->lang['NUMBER_FILES'] : '{ NUMBER_FILES }')); ?>: </td>
		<td><strong><?php echo (isset($this->_rootref['TOTAL_FILES'])) ? $this->_rootref['TOTAL_FILES'] : ''; ?></strong></td>
		<td><?php echo ((isset($this->_rootref['L_FILES_PER_DAY'])) ? $this->_rootref['L_FILES_PER_DAY'] : ((isset($user->lang['FILES_PER_DAY'])) ? $user->lang['FILES_PER_DAY'] : '{ FILES_PER_DAY }')); ?>: </td>
		<td><strong><?php echo (isset($this->_rootref['FILES_PER_DAY'])) ? $this->_rootref['FILES_PER_DAY'] : ''; ?></strong></td>
	</tr>


	<tr>
		<td><?php echo ((isset($this->_rootref['L_BOARD_STARTED'])) ? $this->_rootref['L_BOARD_STARTED'] : ((isset($user->lang['BOARD_STARTED'])) ? $user->lang['BOARD_STARTED'] : '{ BOARD_STARTED }')); ?>: </td>
		<td><strong><?php echo (isset($this->_rootref['START_DATE'])) ? $this->_rootref['START_DATE'] : ''; ?></strong></td>
		<td><?php echo ((isset($this->_rootref['L_AVATAR_DIR_SIZE'])) ? $this->_rootref['L_AVATAR_DIR_SIZE'] : ((isset($user->lang['AVATAR_DIR_SIZE'])) ? $user->lang['AVATAR_DIR_SIZE'] : '{ AVATAR_DIR_SIZE }')); ?>: </td>
		<td><strong><?php echo (isset($this->_rootref['AVATAR_DIR_SIZE'])) ? $this->_rootref['AVATAR_DIR_SIZE'] : ''; ?></strong></td>
	</tr>
	<tr>
		<td><?php echo ((isset($this->_rootref['L_DATABASE_SIZE'])) ? $this->_rootref['L_DATABASE_SIZE'] : ((isset($user->lang['DATABASE_SIZE'])) ? $user->lang['DATABASE_SIZE'] : '{ DATABASE_SIZE }')); ?>: </td>
		<td><strong><?php echo (isset($this->_rootref['DBSIZE'])) ? $this->_rootref['DBSIZE'] : ''; ?></strong></td>
		<td><?php echo ((isset($this->_rootref['L_UPLOAD_DIR_SIZE'])) ? $this->_rootref['L_UPLOAD_DIR_SIZE'] : ((isset($user->lang['UPLOAD_DIR_SIZE'])) ? $user->lang['UPLOAD_DIR_SIZE'] : '{ UPLOAD_DIR_SIZE }')); ?>: </td>
		<td><strong><?php echo (isset($this->_rootref['UPLOAD_DIR_SIZE'])) ? $this->_rootref['UPLOAD_DIR_SIZE'] : ''; ?></strong></td>
	</tr>
	<tr>
		<td><?php echo ((isset($this->_rootref['L_DATABASE_SERVER_INFO'])) ? $this->_rootref['L_DATABASE_SERVER_INFO'] : ((isset($user->lang['DATABASE_SERVER_INFO'])) ? $user->lang['DATABASE_SERVER_INFO'] : '{ DATABASE_SERVER_INFO }')); ?>: </td>
		<td><strong><?php echo (isset($this->_rootref['DATABASE_INFO'])) ? $this->_rootref['DATABASE_INFO'] : ''; ?></strong></td>
		<td><?php echo ((isset($this->_rootref['L_GZIP_COMPRESSION'])) ? $this->_rootref['L_GZIP_COMPRESSION'] : ((isset($user->lang['GZIP_COMPRESSION'])) ? $user->lang['GZIP_COMPRESSION'] : '{ GZIP_COMPRESSION }')); ?>: </td>
		<td><strong><?php echo (isset($this->_rootref['GZIP_COMPRESSION'])) ? $this->_rootref['GZIP_COMPRESSION'] : ''; ?></strong></td>
	</tr>
	<tr>
		<td><?php echo ((isset($this->_rootref['L_BOARD_VERSION'])) ? $this->_rootref['L_BOARD_VERSION'] : ((isset($user->lang['BOARD_VERSION'])) ? $user->lang['BOARD_VERSION'] : '{ BOARD_VERSION }')); ?>: </td>
		<td><strong><?php echo (isset($this->_rootref['BOARD_VERSION'])) ? $this->_rootref['BOARD_VERSION'] : ''; ?></strong></td>
	<?php if ($this->_rootref['S_TOTAL_ORPHAN']) {  ?>
		<td><?php echo ((isset($this->_rootref['L_NUMBER_ORPHAN'])) ? $this->_rootref['L_NUMBER_ORPHAN'] : ((isset($user->lang['NUMBER_ORPHAN'])) ? $user->lang['NUMBER_ORPHAN'] : '{ NUMBER_ORPHAN }')); ?>: </td>
		<td><strong><?php echo (isset($this->_rootref['TOTAL_ORPHAN'])) ? $this->_rootref['TOTAL_ORPHAN'] : ''; ?></strong></td>
	<?php } else { ?>
		<td>&nbsp;</td>
		<td>&nbsp;</td>
	<?php } ?>
	</tr>
	</tbody>
	</table>

	<?php if ($this->_rootref['S_ACTION_OPTIONS']) {  ?>
		<fieldset>
			<legend><?php echo ((isset($this->_rootref['L_STATISTIC_RESYNC_OPTIONS'])) ? $this->_rootref['L_STATISTIC_RESYNC_OPTIONS'] : ((isset($user->lang['STATISTIC_RESYNC_OPTIONS'])) ? $user->lang['STATISTIC_RESYNC_OPTIONS'] : '{ STATISTIC_RESYNC_OPTIONS }')); ?></legend>

			<form id="action_online_form" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">
				<dl>
					<dt><label for="action_online"><?php echo ((isset($this->_rootref['L_RESET_ONLINE'])) ? $this->_rootref['L_RESET_ONLINE'] : ((isset($user->lang['RESET_ONLINE'])) ? $user->lang['RESET_ONLINE'] : '{ RESET_ONLINE }')); ?></label><br /><span>&nbsp;</span></dt>
					<dd><input type="hidden" name="action" value="online" /><input class="button2" type="submit" id="action_online" name="action_online" value="<?php echo ((isset($this->_rootref['L_RUN'])) ? $this->_rootref['L_RUN'] : ((isset($user->lang['RUN'])) ? $user->lang['RUN'] : '{ RUN }')); ?>" /></dd>
				</dl>
			</form>

			<form id="action_date_form" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">
				<dl>
					<dt><label for="action_date"><?php echo ((isset($this->_rootref['L_RESET_DATE'])) ? $this->_rootref['L_RESET_DATE'] : ((isset($user->lang['RESET_DATE'])) ? $user->lang['RESET_DATE'] : '{ RESET_DATE }')); ?></label><br /><span>&nbsp;</span></dt>
					<dd><input type="hidden" name="action" value="date" /><input class="button2" type="submit" id="action_date" name="action_date" value="<?php echo ((isset($this->_rootref['L_RUN'])) ? $this->_rootref['L_RUN'] : ((isset($user->lang['RUN'])) ? $user->lang['RUN'] : '{ RUN }')); ?>" /></dd>
				</dl>
			</form>

			<form id="action_stats_form" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">
				<dl>
					<dt><label for="action_stats"><?php echo ((isset($this->_rootref['L_RESYNC_STATS'])) ? $this->_rootref['L_RESYNC_STATS'] : ((isset($user->lang['RESYNC_STATS'])) ? $user->lang['RESYNC_STATS'] : '{ RESYNC_STATS }')); ?></label><br /><span><?php echo ((isset($this->_rootref['L_RESYNC_STATS_EXPLAIN'])) ? $this->_rootref['L_RESYNC_STATS_EXPLAIN'] : ((isset($user->lang['RESYNC_STATS_EXPLAIN'])) ? $user->lang['RESYNC_STATS_EXPLAIN'] : '{ RESYNC_STATS_EXPLAIN }')); ?></span></dt>
					<dd><input type="hidden" name="action" value="stats" /><input class="button2" type="submit" id="action_stats" name="action_stats" value="<?php echo ((isset($this->_rootref['L_RUN'])) ? $this->_rootref['L_RUN'] : ((isset($user->lang['RUN'])) ? $user->lang['RUN'] : '{ RUN }')); ?>" /></dd>
				</dl>
			</form>

			<form id="action_user_form" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">
				<dl>
					<dt><label for="action_user"><?php echo ((isset($this->_rootref['L_RESYNC_POSTCOUNTS'])) ? $this->_rootref['L_RESYNC_POSTCOUNTS'] : ((isset($user->lang['RESYNC_POSTCOUNTS'])) ? $user->lang['RESYNC_POSTCOUNTS'] : '{ RESYNC_POSTCOUNTS }')); ?></label><br /><span><?php echo ((isset($this->_rootref['L_RESYNC_POSTCOUNTS_EXPLAIN'])) ? $this->_rootref['L_RESYNC_POSTCOUNTS_EXPLAIN'] : ((isset($user->lang['RESYNC_POSTCOUNTS_EXPLAIN'])) ? $user->lang['RESYNC_POSTCOUNTS_EXPLAIN'] : '{ RESYNC_POSTCOUNTS_EXPLAIN }')); ?></span></dt>
					<dd><input type="hidden" name="action" value="user" /><input class="button2" type="submit" id="action_user" name="action_user" value="<?php echo ((isset($this->_rootref['L_RUN'])) ? $this->_rootref['L_RUN'] : ((isset($user->lang['RUN'])) ? $user->lang['RUN'] : '{ RUN }')); ?>" /></dd>
				</dl>
			</form>

			<form id="action_db_track_form" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">
				<dl>
					<dt><label for="action_db_track"><?php echo ((isset($this->_rootref['L_RESYNC_POST_MARKING'])) ? $this->_rootref['L_RESYNC_POST_MARKING'] : ((isset($user->lang['RESYNC_POST_MARKING'])) ? $user->lang['RESYNC_POST_MARKING'] : '{ RESYNC_POST_MARKING }')); ?></label><br /><span><?php echo ((isset($this->_rootref['L_RESYNC_POST_MARKING_EXPLAIN'])) ? $this->_rootref['L_RESYNC_POST_MARKING_EXPLAIN'] : ((isset($user->lang['RESYNC_POST_MARKING_EXPLAIN'])) ? $user->lang['RESYNC_POST_MARKING_EXPLAIN'] : '{ RESYNC_POST_MARKING_EXPLAIN }')); ?></span></dt>
					<dd><input type="hidden" name="action" value="db_track" /><input class="button2" type="submit" id="action_db_track" name="action_db_track" value="<?php echo ((isset($this->_rootref['L_RUN'])) ? $this->_rootref['L_RUN'] : ((isset($user->lang['RUN'])) ? $user->lang['RUN'] : '{ RUN }')); ?>" /></dd>
				</dl>
			</form>

			<?php if ($this->_rootref['S_FOUNDER']) {  ?>
			<form id="action_purge_cache_form" method="post" action="<?php echo (isset($this->_rootref['U_ACTION'])) ? $this->_rootref['U_ACTION'] : ''; ?>">
				<dl>
					<dt><label for="action_purge_cache"><?php echo ((isset($this->_rootref['L_PURGE_CACHE'])) ? $this->_rootref['L_PURGE_CACHE'] : ((isset($user->lang['PURGE_CACHE'])) ? $user->lang['PURGE_CACHE'] : '{ PURGE_CACHE }')); ?></label><br /><span><?php echo ((isset($this->_rootref['L_PURGE_CACHE_EXPLAIN'])) ? $this->_rootref['L_PURGE_CACHE_EXPLAIN'] : ((isset($user->lang['PURGE_CACHE_EXPLAIN'])) ? $user->lang['PURGE_CACHE_EXPLAIN'] : '{ PURGE_CACHE_EXPLAIN }')); ?></span></dt>
					<dd><input type="hidden" name="action" value="purge_cache" /><input class="button2" type="submit" id="action_purge_cache" name="action_purge_cache" value="<?php echo ((isset($this->_rootref['L_RUN'])) ? $this->_rootref['L_RUN'] : ((isset($user->lang['RUN'])) ? $user->lang['RUN'] : '{ RUN }')); ?>" /></dd>
				</dl>
			</form>
			<?php } ?>
  		</fieldset>
	<?php } if (sizeof($this->_tpldata['log'])) {  ?>
		<h2><?php echo ((isset($this->_rootref['L_ADMIN_LOG'])) ? $this->_rootref['L_ADMIN_LOG'] : ((isset($user->lang['ADMIN_LOG'])) ? $user->lang['ADMIN_LOG'] : '{ ADMIN_LOG }')); ?></h2>

		<p><?php echo ((isset($this->_rootref['L_ADMIN_LOG_INDEX_EXPLAIN'])) ? $this->_rootref['L_ADMIN_LOG_INDEX_EXPLAIN'] : ((isset($user->lang['ADMIN_LOG_INDEX_EXPLAIN'])) ? $user->lang['ADMIN_LOG_INDEX_EXPLAIN'] : '{ ADMIN_LOG_INDEX_EXPLAIN }')); ?></p>

		<div style="text-align: right;"><a href="<?php echo (isset($this->_rootref['U_ADMIN_LOG'])) ? $this->_rootref['U_ADMIN_LOG'] : ''; ?>">&raquo; <?php echo ((isset($this->_rootref['L_VIEW_ADMIN_LOG'])) ? $this->_rootref['L_VIEW_ADMIN_LOG'] : ((isset($user->lang['VIEW_ADMIN_LOG'])) ? $user->lang['VIEW_ADMIN_LOG'] : '{ VIEW_ADMIN_LOG }')); ?></a></div>

		<table cellspacing="1">
		<thead>
		<tr>
			<th><?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?></th>
			<th><?php echo ((isset($this->_rootref['L_IP'])) ? $this->_rootref['L_IP'] : ((isset($user->lang['IP'])) ? $user->lang['IP'] : '{ IP }')); ?></th>
			<th><?php echo ((isset($this->_rootref['L_TIME'])) ? $this->_rootref['L_TIME'] : ((isset($user->lang['TIME'])) ? $user->lang['TIME'] : '{ TIME }')); ?></th>
			<th><?php echo ((isset($this->_rootref['L_ACTION'])) ? $this->_rootref['L_ACTION'] : ((isset($user->lang['ACTION'])) ? $user->lang['ACTION'] : '{ ACTION }')); ?></th>
		</tr>
		</thead>
		<tbody>
		<?php $_log_count = (isset($this->_tpldata['log'])) ? sizeof($this->_tpldata['log']) : 0;if ($_log_count) {for ($_log_i = 0; $_log_i < $_log_count; ++$_log_i){$_log_val = &$this->_tpldata['log'][$_log_i]; if (!($_log_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>

				<td><?php echo $_log_val['USERNAME']; ?></td>
				<td style="text-align: center;"><?php echo $_log_val['IP']; ?></td>
				<td style="text-align: center;"><?php echo $_log_val['DATE']; ?></td>
				<td><?php echo $_log_val['ACTION']; ?></td>
			</tr>
		<?php }} ?>
		</tbody>
		</table>

		<br />

	<?php } if ($this->_rootref['S_INACTIVE_USERS']) {  ?>
		<h2><?php echo ((isset($this->_rootref['L_INACTIVE_USERS'])) ? $this->_rootref['L_INACTIVE_USERS'] : ((isset($user->lang['INACTIVE_USERS'])) ? $user->lang['INACTIVE_USERS'] : '{ INACTIVE_USERS }')); ?></h2>

		<p><?php echo ((isset($this->_rootref['L_INACTIVE_USERS_EXPLAIN_INDEX'])) ? $this->_rootref['L_INACTIVE_USERS_EXPLAIN_INDEX'] : ((isset($user->lang['INACTIVE_USERS_EXPLAIN_INDEX'])) ? $user->lang['INACTIVE_USERS_EXPLAIN_INDEX'] : '{ INACTIVE_USERS_EXPLAIN_INDEX }')); ?></p>

		<div style="text-align: right;"><a href="<?php echo (isset($this->_rootref['U_INACTIVE_USERS'])) ? $this->_rootref['U_INACTIVE_USERS'] : ''; ?>">&raquo; <?php echo ((isset($this->_rootref['L_VIEW_INACTIVE_USERS'])) ? $this->_rootref['L_VIEW_INACTIVE_USERS'] : ((isset($user->lang['VIEW_INACTIVE_USERS'])) ? $user->lang['VIEW_INACTIVE_USERS'] : '{ VIEW_INACTIVE_USERS }')); ?></a></div>

		<table cellspacing="1">
		<thead>
		<tr>
			<th><?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?></th>
			<th><?php echo ((isset($this->_rootref['L_JOINED'])) ? $this->_rootref['L_JOINED'] : ((isset($user->lang['JOINED'])) ? $user->lang['JOINED'] : '{ JOINED }')); ?></th>
			<th><?php echo ((isset($this->_rootref['L_INACTIVE_DATE'])) ? $this->_rootref['L_INACTIVE_DATE'] : ((isset($user->lang['INACTIVE_DATE'])) ? $user->lang['INACTIVE_DATE'] : '{ INACTIVE_DATE }')); ?></th>
			<th><?php echo ((isset($this->_rootref['L_INACTIVE_REASON'])) ? $this->_rootref['L_INACTIVE_REASON'] : ((isset($user->lang['INACTIVE_REASON'])) ? $user->lang['INACTIVE_REASON'] : '{ INACTIVE_REASON }')); ?></th>
			<th><?php echo ((isset($this->_rootref['L_LAST_VISIT'])) ? $this->_rootref['L_LAST_VISIT'] : ((isset($user->lang['LAST_VISIT'])) ? $user->lang['LAST_VISIT'] : '{ LAST_VISIT }')); ?></th>
		</tr>
		</thead>
		<tbody>
		<?php $_inactive_count = (isset($this->_tpldata['inactive'])) ? sizeof($this->_tpldata['inactive']) : 0;if ($_inactive_count) {for ($_inactive_i = 0; $_inactive_i < $_inactive_count; ++$_inactive_i){$_inactive_val = &$this->_tpldata['inactive'][$_inactive_i]; if (!($_inactive_val['S_ROW_COUNT'] & 1)  ) {  ?><tr class="row1"><?php } else { ?><tr class="row2"><?php } ?>

				<td><a href="<?php echo $_inactive_val['U_USER_ADMIN']; ?>"><?php echo $_inactive_val['USERNAME']; ?></a></td>
				<td><?php echo $_inactive_val['JOINED']; ?></td>
				<td><?php echo $_inactive_val['INACTIVE_DATE']; ?></td>
				<td><?php echo $_inactive_val['REASON']; ?></td>
				<td><?php echo $_inactive_val['LAST_VISIT']; ?></td>
			</tr>
		<?php }} else { ?>
			<tr>
				<td colspan="5" style="text-align: center;"><?php echo ((isset($this->_rootref['L_NO_INACTIVE_USERS'])) ? $this->_rootref['L_NO_INACTIVE_USERS'] : ((isset($user->lang['NO_INACTIVE_USERS'])) ? $user->lang['NO_INACTIVE_USERS'] : '{ NO_INACTIVE_USERS }')); ?></td>
			</tr>
		<?php } ?>
		</tbody>
		</table>

	<?php } } $this->_tpl_include('overall_footer.html'); ?>
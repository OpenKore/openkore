<?php $this->_tpl_include('ucp_header.html'); ?>

<h2><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></h2>

<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>

	<p><?php echo ((isset($this->_rootref['L_UCP_WELCOME'])) ? $this->_rootref['L_UCP_WELCOME'] : ((isset($user->lang['UCP_WELCOME'])) ? $user->lang['UCP_WELCOME'] : '{ UCP_WELCOME }')); ?></p>

<?php if (sizeof($this->_tpldata['topicrow'])) {  ?>
	<h3><?php echo ((isset($this->_rootref['L_IMPORTANT_NEWS'])) ? $this->_rootref['L_IMPORTANT_NEWS'] : ((isset($user->lang['IMPORTANT_NEWS'])) ? $user->lang['IMPORTANT_NEWS'] : '{ IMPORTANT_NEWS }')); ?></h3>

	<ul class="topiclist cplist">
	<?php $_topicrow_count = (isset($this->_tpldata['topicrow'])) ? sizeof($this->_tpldata['topicrow']) : 0;if ($_topicrow_count) {for ($_topicrow_i = 0; $_topicrow_i < $_topicrow_count; ++$_topicrow_i){$_topicrow_val = &$this->_tpldata['topicrow'][$_topicrow_i]; ?>
		<li class="row<?php if (($_topicrow_val['S_ROW_COUNT'] & 1)  ) {  ?> bg1<?php } else { ?> bg2<?php } ?>">
			<dl class="icon" style="background-image: url(<?php echo $_topicrow_val['TOPIC_FOLDER_IMG_SRC']; ?>); background-repeat: no-repeat;">
				<dt <?php if ($_topicrow_val['TOPIC_ICON_IMG']) {  ?>style="background-image: url(<?php echo (isset($this->_rootref['T_ICONS_PATH'])) ? $this->_rootref['T_ICONS_PATH'] : ''; echo $_topicrow_val['TOPIC_ICON_IMG']; ?>); background-repeat: no-repeat;"<?php } ?>>
					<?php if ($_topicrow_val['S_UNREAD']) {  ?><a href="<?php echo $_topicrow_val['U_NEWEST_POST']; ?>"><?php echo (isset($this->_rootref['NEWEST_POST_IMG'])) ? $this->_rootref['NEWEST_POST_IMG'] : ''; ?></a> <?php } ?><a href="<?php echo $_topicrow_val['U_VIEW_TOPIC']; ?>" class="topictitle"><?php echo $_topicrow_val['TOPIC_TITLE']; ?></a><br />
					<?php if ($_topicrow_val['PAGINATION']) {  ?><strong class="pagination"><span><?php echo $_topicrow_val['PAGINATION']; ?></span></strong><?php } if ($_topicrow_val['ATTACH_ICON_IMG']) {  echo $_topicrow_val['ATTACH_ICON_IMG']; ?> <?php } echo ((isset($this->_rootref['L_POST_BY_AUTHOR'])) ? $this->_rootref['L_POST_BY_AUTHOR'] : ((isset($user->lang['POST_BY_AUTHOR'])) ? $user->lang['POST_BY_AUTHOR'] : '{ POST_BY_AUTHOR }')); ?> <?php echo $_topicrow_val['TOPIC_AUTHOR_FULL']; ?> <?php echo ((isset($this->_rootref['L_POSTED_ON_DATE'])) ? $this->_rootref['L_POSTED_ON_DATE'] : ((isset($user->lang['POSTED_ON_DATE'])) ? $user->lang['POSTED_ON_DATE'] : '{ POSTED_ON_DATE }')); ?> <?php echo $_topicrow_val['FIRST_POST_TIME']; ?> 
				</dt>
				<dd class="lastpost"><span><?php echo ((isset($this->_rootref['L_LAST_POST'])) ? $this->_rootref['L_LAST_POST'] : ((isset($user->lang['LAST_POST'])) ? $user->lang['LAST_POST'] : '{ LAST_POST }')); ?> <?php echo ((isset($this->_rootref['L_POST_BY_AUTHOR'])) ? $this->_rootref['L_POST_BY_AUTHOR'] : ((isset($user->lang['POST_BY_AUTHOR'])) ? $user->lang['POST_BY_AUTHOR'] : '{ POST_BY_AUTHOR }')); ?> <?php echo $_topicrow_val['LAST_POST_AUTHOR_FULL']; ?>
					<a href="<?php echo $_topicrow_val['U_LAST_POST']; ?>"><?php echo (isset($this->_rootref['LAST_POST_IMG'])) ? $this->_rootref['LAST_POST_IMG'] : ''; ?></a> <br /><?php echo ((isset($this->_rootref['L_POSTED_ON_DATE'])) ? $this->_rootref['L_POSTED_ON_DATE'] : ((isset($user->lang['POSTED_ON_DATE'])) ? $user->lang['POSTED_ON_DATE'] : '{ POSTED_ON_DATE }')); ?> <?php echo $_topicrow_val['LAST_POST_TIME']; ?></span>
				</dd>
			</dl>
		</li>
	<?php }} ?>
	</ul>
<?php } ?>

	<h3><?php echo ((isset($this->_rootref['L_YOUR_DETAILS'])) ? $this->_rootref['L_YOUR_DETAILS'] : ((isset($user->lang['YOUR_DETAILS'])) ? $user->lang['YOUR_DETAILS'] : '{ YOUR_DETAILS }')); ?></h3>

	<dl class="details">
		<dt><?php echo ((isset($this->_rootref['L_JOINED'])) ? $this->_rootref['L_JOINED'] : ((isset($user->lang['JOINED'])) ? $user->lang['JOINED'] : '{ JOINED }')); ?>:</dt> <dd><?php echo (isset($this->_rootref['JOINED'])) ? $this->_rootref['JOINED'] : ''; ?></dd>
		<dt><?php echo ((isset($this->_rootref['L_VISITED'])) ? $this->_rootref['L_VISITED'] : ((isset($user->lang['VISITED'])) ? $user->lang['VISITED'] : '{ VISITED }')); ?>:</dt> <dd><?php echo (isset($this->_rootref['LAST_VISIT_YOU'])) ? $this->_rootref['LAST_VISIT_YOU'] : ''; ?></dd>
		<dt><?php echo ((isset($this->_rootref['L_TOTAL_POSTS'])) ? $this->_rootref['L_TOTAL_POSTS'] : ((isset($user->lang['TOTAL_POSTS'])) ? $user->lang['TOTAL_POSTS'] : '{ TOTAL_POSTS }')); ?>:</dt> <dd><?php if ($this->_rootref['POSTS_PCT']) {  echo (isset($this->_rootref['POSTS'])) ? $this->_rootref['POSTS'] : ''; ?> | <strong><a href="<?php echo (isset($this->_rootref['U_SEARCH_USER'])) ? $this->_rootref['U_SEARCH_USER'] : ''; ?>"><?php echo ((isset($this->_rootref['L_SEARCH_YOUR_POSTS'])) ? $this->_rootref['L_SEARCH_YOUR_POSTS'] : ((isset($user->lang['SEARCH_YOUR_POSTS'])) ? $user->lang['SEARCH_YOUR_POSTS'] : '{ SEARCH_YOUR_POSTS }')); ?></a></strong><br />(<?php echo (isset($this->_rootref['POSTS_DAY'])) ? $this->_rootref['POSTS_DAY'] : ''; ?> / <?php echo (isset($this->_rootref['POSTS_PCT'])) ? $this->_rootref['POSTS_PCT'] : ''; ?>)<?php } else { echo (isset($this->_rootref['POSTS'])) ? $this->_rootref['POSTS'] : ''; } ?></dd>
		<dt><?php echo ((isset($this->_rootref['L_ACTIVE_IN_FORUM'])) ? $this->_rootref['L_ACTIVE_IN_FORUM'] : ((isset($user->lang['ACTIVE_IN_FORUM'])) ? $user->lang['ACTIVE_IN_FORUM'] : '{ ACTIVE_IN_FORUM }')); ?>:</dt> <dd><?php if ($this->_rootref['ACTIVE_FORUM']) {  ?><strong><a href="<?php echo (isset($this->_rootref['U_ACTIVE_FORUM'])) ? $this->_rootref['U_ACTIVE_FORUM'] : ''; ?>"><?php echo (isset($this->_rootref['ACTIVE_FORUM'])) ? $this->_rootref['ACTIVE_FORUM'] : ''; ?></a></strong><br />(<?php echo (isset($this->_rootref['ACTIVE_FORUM_POSTS'])) ? $this->_rootref['ACTIVE_FORUM_POSTS'] : ''; ?> / <?php echo (isset($this->_rootref['ACTIVE_FORUM_PCT'])) ? $this->_rootref['ACTIVE_FORUM_PCT'] : ''; ?>)<?php } else { ?> - <?php } ?></dd>
		<dt><?php echo ((isset($this->_rootref['L_ACTIVE_IN_TOPIC'])) ? $this->_rootref['L_ACTIVE_IN_TOPIC'] : ((isset($user->lang['ACTIVE_IN_TOPIC'])) ? $user->lang['ACTIVE_IN_TOPIC'] : '{ ACTIVE_IN_TOPIC }')); ?>:</dt> <dd><?php if ($this->_rootref['ACTIVE_TOPIC']) {  ?><strong><a href="<?php echo (isset($this->_rootref['U_ACTIVE_TOPIC'])) ? $this->_rootref['U_ACTIVE_TOPIC'] : ''; ?>"><?php echo (isset($this->_rootref['ACTIVE_TOPIC'])) ? $this->_rootref['ACTIVE_TOPIC'] : ''; ?></a></strong><br />(<?php echo (isset($this->_rootref['ACTIVE_TOPIC_POSTS'])) ? $this->_rootref['ACTIVE_TOPIC_POSTS'] : ''; ?> / <?php echo (isset($this->_rootref['ACTIVE_TOPIC_PCT'])) ? $this->_rootref['ACTIVE_TOPIC_PCT'] : ''; ?>)<?php } else { ?> - <?php } ?></dd>
		<?php if ($this->_rootref['WARNINGS']) {  ?><dt><?php echo ((isset($this->_rootref['L_YOUR_WARNINGS'])) ? $this->_rootref['L_YOUR_WARNINGS'] : ((isset($user->lang['YOUR_WARNINGS'])) ? $user->lang['YOUR_WARNINGS'] : '{ YOUR_WARNINGS }')); ?>:</dt> <dd class="error"><?php echo (isset($this->_rootref['WARNING_IMG'])) ? $this->_rootref['WARNING_IMG'] : ''; ?> [<?php echo (isset($this->_rootref['WARNINGS'])) ? $this->_rootref['WARNINGS'] : ''; ?>]</dd><?php } ?>
	</dl>

	<span class="corners-bottom"><span></span></span></div>
</div>

<?php $this->_tpl_include('ucp_footer.html'); ?>
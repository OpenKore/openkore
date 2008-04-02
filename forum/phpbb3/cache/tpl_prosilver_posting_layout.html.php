<?php $this->_tpl_include('overall_header.html'); if ($this->_rootref['TOPIC_TITLE']) {  ?>
	<h2><a href="<?php echo (isset($this->_rootref['U_VIEW_TOPIC'])) ? $this->_rootref['U_VIEW_TOPIC'] : ''; ?>"><?php echo (isset($this->_rootref['TOPIC_TITLE'])) ? $this->_rootref['TOPIC_TITLE'] : ''; ?></a></h2>
<?php } else { ?>
	<h2><a href="<?php echo (isset($this->_rootref['U_VIEW_FORUM'])) ? $this->_rootref['U_VIEW_FORUM'] : ''; ?>"><?php echo (isset($this->_rootref['FORUM_NAME'])) ? $this->_rootref['FORUM_NAME'] : ''; ?></a></h2>
 <?php } if ($this->_rootref['S_FORUM_RULES']) {  ?>
	<div class="rules">
		<div class="inner"><span class="corners-top"><span></span></span>
		
		<?php if ($this->_rootref['U_FORUM_RULES']) {  ?>
			<a href="<?php echo (isset($this->_rootref['U_FORUM_RULES'])) ? $this->_rootref['U_FORUM_RULES'] : ''; ?>"><?php echo ((isset($this->_rootref['L_FORUM_RULES'])) ? $this->_rootref['L_FORUM_RULES'] : ((isset($user->lang['FORUM_RULES'])) ? $user->lang['FORUM_RULES'] : '{ FORUM_RULES }')); ?></a>
		<?php } else { ?>
			<strong><?php echo ((isset($this->_rootref['L_FORUM_RULES'])) ? $this->_rootref['L_FORUM_RULES'] : ((isset($user->lang['FORUM_RULES'])) ? $user->lang['FORUM_RULES'] : '{ FORUM_RULES }')); ?></strong><br />
			<?php echo (isset($this->_rootref['FORUM_RULES'])) ? $this->_rootref['FORUM_RULES'] : ''; ?>
		<?php } ?>
		
		<span class="corners-bottom"><span></span></span></div>
	</div>
<?php } ?>

<form id="postform" method="post" action="<?php echo (isset($this->_rootref['S_POST_ACTION'])) ? $this->_rootref['S_POST_ACTION'] : ''; ?>"<?php echo (isset($this->_rootref['S_FORM_ENCTYPE'])) ? $this->_rootref['S_FORM_ENCTYPE'] : ''; ?>>

<?php if ($this->_rootref['S_DRAFT_LOADED']) {  ?>
	<div class="panel">
		<div class="inner"><span class="corners-top"><span></span></span>
		
		<h3><?php echo ((isset($this->_rootref['L_INFORMATION'])) ? $this->_rootref['L_INFORMATION'] : ((isset($user->lang['INFORMATION'])) ? $user->lang['INFORMATION'] : '{ INFORMATION }')); ?></h3>
		<p><?php echo ((isset($this->_rootref['L_DRAFT_LOADED'])) ? $this->_rootref['L_DRAFT_LOADED'] : ((isset($user->lang['DRAFT_LOADED'])) ? $user->lang['DRAFT_LOADED'] : '{ DRAFT_LOADED }')); ?></p>
		
		<span class="corners-bottom"><span></span></span></div>
	</div>
<?php } if ($this->_rootref['S_SHOW_DRAFTS']) {  $this->_tpl_include('drafts.html'); } if ($this->_rootref['S_POST_REVIEW']) {  $this->_tpl_include('posting_review.html'); } if ($this->_rootref['S_UNGLOBALISE']) {  ?>
	<div class="panel bg3">
		<div class="inner"><span class="corners-top"><span></span></span>
		<fieldset class="fields1">
			<h2><?php echo ((isset($this->_rootref['L_SELECT_DESTINATION_FORUM'])) ? $this->_rootref['L_SELECT_DESTINATION_FORUM'] : ((isset($user->lang['SELECT_DESTINATION_FORUM'])) ? $user->lang['SELECT_DESTINATION_FORUM'] : '{ SELECT_DESTINATION_FORUM }')); ?></h2>
			<p><?php echo ((isset($this->_rootref['L_UNGLOBALISE_EXPLAIN'])) ? $this->_rootref['L_UNGLOBALISE_EXPLAIN'] : ((isset($user->lang['UNGLOBALISE_EXPLAIN'])) ? $user->lang['UNGLOBALISE_EXPLAIN'] : '{ UNGLOBALISE_EXPLAIN }')); ?></p>
			<dl>
				<dt><label for="to_forum_id"><?php echo ((isset($this->_rootref['L_MOVE'])) ? $this->_rootref['L_MOVE'] : ((isset($user->lang['MOVE'])) ? $user->lang['MOVE'] : '{ MOVE }')); ?>:</label></dt>
				<dd><select id="to_forum_id" name="to_forum_id"><?php echo (isset($this->_rootref['S_FORUM_SELECT'])) ? $this->_rootref['S_FORUM_SELECT'] : ''; ?></select></dd>
			</dl>
			
			<dl>
				<dt>&nbsp;</dt>
				<dd><input class="button1" type="submit" name="post" value="<?php echo ((isset($this->_rootref['L_CONFIRM'])) ? $this->_rootref['L_CONFIRM'] : ((isset($user->lang['CONFIRM'])) ? $user->lang['CONFIRM'] : '{ CONFIRM }')); ?>" /> <input class="button2" type="submit" name="cancel_unglobalise" value="<?php echo ((isset($this->_rootref['L_CANCEL'])) ? $this->_rootref['L_CANCEL'] : ((isset($user->lang['CANCEL'])) ? $user->lang['CANCEL'] : '{ CANCEL }')); ?>" /></dd>
			</dl>
		</fieldset>

		<span class="corners-bottom"><span></span></span></div>
	</div>
<?php } if ($this->_rootref['S_DISPLAY_PREVIEW']) {  $this->_tpl_include('posting_preview.html'); } ?>

<div class="panel" id="postingbox">
	<div class="inner"><span class="corners-top"><span></span></span>
	
	<h3><?php echo ((isset($this->_rootref['L_POST_A'])) ? $this->_rootref['L_POST_A'] : ((isset($user->lang['POST_A'])) ? $user->lang['POST_A'] : '{ POST_A }')); ?></h3>

	<?php $this->_tpldata['DEFINE']['.']['EXTRA_POSTING_OPTIONS'] = 1; $this->_tpl_include('posting_editor.html'); ?>
	<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	<span class="corners-bottom"><span></span></span></div>
</div>

<?php if ($this->_rootref['S_SHOW_ATTACH_BOX']) {  $this->_tpl_include('posting_attach_body.html'); } if ($this->_rootref['S_SHOW_POLL_BOX'] || $this->_rootref['S_POLL_DELETE']) {  $this->_tpl_include('posting_poll_body.html'); } if ($this->_rootref['S_DISPLAY_REVIEW']) {  $this->_tpl_include('posting_topic_review.html'); } ?>

</form>
<?php if (! $this->_rootref['S_PRIVMSGS']) {  ?>
<script type="text/javascript">
// <![CDATA[
	subPanels(show_panel);
// ]]>
</script>
<?php } $this->_tpl_include('overall_footer.html'); ?>
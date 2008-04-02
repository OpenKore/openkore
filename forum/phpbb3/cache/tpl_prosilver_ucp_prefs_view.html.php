<?php $this->_tpl_include('ucp_header.html'); ?>

<form id="ucp" method="post" action="<?php echo (isset($this->_rootref['S_UCP_ACTION'])) ? $this->_rootref['S_UCP_ACTION'] : ''; ?>"<?php echo (isset($this->_rootref['S_FORM_ENCTYPE'])) ? $this->_rootref['S_FORM_ENCTYPE'] : ''; ?>>

<h2><?php echo ((isset($this->_rootref['L_TITLE'])) ? $this->_rootref['L_TITLE'] : ((isset($user->lang['TITLE'])) ? $user->lang['TITLE'] : '{ TITLE }')); ?></h2>

<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>

		<fieldset>
		<?php if ($this->_rootref['ERROR']) {  ?><p class="error"><?php echo (isset($this->_rootref['ERROR'])) ? $this->_rootref['ERROR'] : ''; ?></p><?php } ?>
		<dl>
			<dt><label for="images1"><?php echo ((isset($this->_rootref['L_VIEW_IMAGES'])) ? $this->_rootref['L_VIEW_IMAGES'] : ((isset($user->lang['VIEW_IMAGES'])) ? $user->lang['VIEW_IMAGES'] : '{ VIEW_IMAGES }')); ?>:</label></dt>
			<dd>
				<label for="images1"><input type="radio" name="images" id="images1" value="1"<?php if ($this->_rootref['S_IMAGES']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label> 
				<label for="images0"><input type="radio" name="images" id="images0" value="0"<?php if (! $this->_rootref['S_IMAGES']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label>
			</dd>
		</dl>
		<dl>
			<dt><label for="flash0"><?php echo ((isset($this->_rootref['L_VIEW_FLASH'])) ? $this->_rootref['L_VIEW_FLASH'] : ((isset($user->lang['VIEW_FLASH'])) ? $user->lang['VIEW_FLASH'] : '{ VIEW_FLASH }')); ?>:</label></dt>
			<dd>
				<label for="flash1"><input type="radio" name="flash" id="flash1" value="1"<?php if ($this->_rootref['S_FLASH']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label> 
				<label for="flash0"><input type="radio" name="flash" id="flash0" value="0"<?php if (! $this->_rootref['S_FLASH']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label>
			</dd>
		</dl>
		<dl>
			<dt><label for="smilies1"><?php echo ((isset($this->_rootref['L_VIEW_SMILIES'])) ? $this->_rootref['L_VIEW_SMILIES'] : ((isset($user->lang['VIEW_SMILIES'])) ? $user->lang['VIEW_SMILIES'] : '{ VIEW_SMILIES }')); ?>:</label></dt>
			<dd>
				<label for="smilies1"><input type="radio" name="smilies" id="smilies1" value="1"<?php if ($this->_rootref['S_SMILIES']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label> 
				<label for="smilies0"><input type="radio" name="smilies" id="smilies0" value="0"<?php if (! $this->_rootref['S_SMILIES']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label>
			</dd>
		</dl>
		<dl>
			<dt><label for="sigs1"><?php echo ((isset($this->_rootref['L_VIEW_SIGS'])) ? $this->_rootref['L_VIEW_SIGS'] : ((isset($user->lang['VIEW_SIGS'])) ? $user->lang['VIEW_SIGS'] : '{ VIEW_SIGS }')); ?>:</label></dt>
			<dd>
				<label for="sigs1"><input type="radio" name="sigs" id="sigs1" value="1"<?php if ($this->_rootref['S_SIGS']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label> 
				<label for="sigs0"><input type="radio" name="sigs" id="sigs0" value="0"<?php if (! $this->_rootref['S_SIGS']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label>
			</dd>
		</dl>
		<dl>
			<dt><label for="avatars1"><?php echo ((isset($this->_rootref['L_VIEW_AVATARS'])) ? $this->_rootref['L_VIEW_AVATARS'] : ((isset($user->lang['VIEW_AVATARS'])) ? $user->lang['VIEW_AVATARS'] : '{ VIEW_AVATARS }')); ?>:</label></dt>
			<dd>
				<label for="avatars1"><input type="radio" name="avatars" id="avatars1" value="1"<?php if ($this->_rootref['S_AVATARS']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label> 
				<label for="avatars0"><input type="radio" name="avatars" id="avatars0" value="0"<?php if (! $this->_rootref['S_AVATARS']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label>
			</dd>
		</dl>
		<?php if ($this->_rootref['S_CHANGE_CENSORS']) {  ?>
			<dl>
				<dt><label for="wordcensor1"><?php echo ((isset($this->_rootref['L_DISABLE_CENSORS'])) ? $this->_rootref['L_DISABLE_CENSORS'] : ((isset($user->lang['DISABLE_CENSORS'])) ? $user->lang['DISABLE_CENSORS'] : '{ DISABLE_CENSORS }')); ?>:</label></dt>
				<dd>
					<label for="wordcensor1"><input type="radio" name="wordcensor" id="wordcensor1" value="1"<?php if ($this->_rootref['S_DISABLE_CENSORS']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_YES'])) ? $this->_rootref['L_YES'] : ((isset($user->lang['YES'])) ? $user->lang['YES'] : '{ YES }')); ?></label> 
					<label for="wordcensor0"><input type="radio" name="wordcensor" id="wordcensor0" value="0"<?php if (! $this->_rootref['S_DISABLE_CENSORS']) {  ?> checked="checked"<?php } ?> /> <?php echo ((isset($this->_rootref['L_NO'])) ? $this->_rootref['L_NO'] : ((isset($user->lang['NO'])) ? $user->lang['NO'] : '{ NO }')); ?></label>
				</dd>
			</dl>
		<?php } ?>
		<hr />
		<dl>
			<dt><label><?php echo ((isset($this->_rootref['L_VIEW_TOPICS_DAYS'])) ? $this->_rootref['L_VIEW_TOPICS_DAYS'] : ((isset($user->lang['VIEW_TOPICS_DAYS'])) ? $user->lang['VIEW_TOPICS_DAYS'] : '{ VIEW_TOPICS_DAYS }')); ?>:</label></dt>
			<dd><?php echo (isset($this->_rootref['S_TOPIC_SORT_DAYS'])) ? $this->_rootref['S_TOPIC_SORT_DAYS'] : ''; ?></dd>
		</dl>
		<dl>
			<dt><label><?php echo ((isset($this->_rootref['L_VIEW_TOPICS_KEY'])) ? $this->_rootref['L_VIEW_TOPICS_KEY'] : ((isset($user->lang['VIEW_TOPICS_KEY'])) ? $user->lang['VIEW_TOPICS_KEY'] : '{ VIEW_TOPICS_KEY }')); ?>:</label></dt>
			<dd><?php echo (isset($this->_rootref['S_TOPIC_SORT_KEY'])) ? $this->_rootref['S_TOPIC_SORT_KEY'] : ''; ?></dd>
		</dl>
		<dl>
			<dt><label><?php echo ((isset($this->_rootref['L_VIEW_TOPICS_DIR'])) ? $this->_rootref['L_VIEW_TOPICS_DIR'] : ((isset($user->lang['VIEW_TOPICS_DIR'])) ? $user->lang['VIEW_TOPICS_DIR'] : '{ VIEW_TOPICS_DIR }')); ?>:</label></dt>
			<dd><?php echo (isset($this->_rootref['S_TOPIC_SORT_DIR'])) ? $this->_rootref['S_TOPIC_SORT_DIR'] : ''; ?></dd>
		</dl>
		<hr />
		<dl>
			<dt><label><?php echo ((isset($this->_rootref['L_VIEW_POSTS_DAYS'])) ? $this->_rootref['L_VIEW_POSTS_DAYS'] : ((isset($user->lang['VIEW_POSTS_DAYS'])) ? $user->lang['VIEW_POSTS_DAYS'] : '{ VIEW_POSTS_DAYS }')); ?>:</label></dt>
			<dd><?php echo (isset($this->_rootref['S_POST_SORT_DAYS'])) ? $this->_rootref['S_POST_SORT_DAYS'] : ''; ?></dd>
		</dl>
		<dl>
			<dt><label><?php echo ((isset($this->_rootref['L_VIEW_POSTS_KEY'])) ? $this->_rootref['L_VIEW_POSTS_KEY'] : ((isset($user->lang['VIEW_POSTS_KEY'])) ? $user->lang['VIEW_POSTS_KEY'] : '{ VIEW_POSTS_KEY }')); ?>:</label></dt>
			<dd><?php echo (isset($this->_rootref['S_POST_SORT_KEY'])) ? $this->_rootref['S_POST_SORT_KEY'] : ''; ?></dd>
		</dl>
		<dl>
			<dt><label><?php echo ((isset($this->_rootref['L_VIEW_POSTS_DIR'])) ? $this->_rootref['L_VIEW_POSTS_DIR'] : ((isset($user->lang['VIEW_POSTS_DIR'])) ? $user->lang['VIEW_POSTS_DIR'] : '{ VIEW_POSTS_DIR }')); ?>:</label></dt>
			<dd><?php echo (isset($this->_rootref['S_POST_SORT_DIR'])) ? $this->_rootref['S_POST_SORT_DIR'] : ''; ?></dd>
		</dl>
		</fieldset>

	<span class="corners-bottom"><span></span></span></div>
</div>

<fieldset class="submit-buttons">
	<?php echo (isset($this->_rootref['S_HIDDEN_FIELDS'])) ? $this->_rootref['S_HIDDEN_FIELDS'] : ''; ?><input type="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" name="reset" class="button2" />&nbsp; 
	<input type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SUBMIT'])) ? $this->_rootref['L_SUBMIT'] : ((isset($user->lang['SUBMIT'])) ? $user->lang['SUBMIT'] : '{ SUBMIT }')); ?>" class="button1" />
	<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
</fieldset>
</form>

<?php $this->_tpl_include('ucp_footer.html'); ?>
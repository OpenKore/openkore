<?php if ($this->_rootref['S_IN_SEARCH_POPUP']) {  ?><!-- You should retain this javascript in your own template! -->
<script type="text/javascript">
// <![CDATA[
function insert_user(user)
{
	opener.document.forms['<?php echo (isset($this->_rootref['S_FORM_NAME'])) ? $this->_rootref['S_FORM_NAME'] : ''; ?>'].<?php echo (isset($this->_rootref['S_FIELD_NAME'])) ? $this->_rootref['S_FIELD_NAME'] : ''; ?>.value = ( opener.document.forms['<?php echo (isset($this->_rootref['S_FORM_NAME'])) ? $this->_rootref['S_FORM_NAME'] : ''; ?>'].<?php echo (isset($this->_rootref['S_FIELD_NAME'])) ? $this->_rootref['S_FIELD_NAME'] : ''; ?>.value.length && opener.document.forms['<?php echo (isset($this->_rootref['S_FORM_NAME'])) ? $this->_rootref['S_FORM_NAME'] : ''; ?>'].<?php echo (isset($this->_rootref['S_FIELD_NAME'])) ? $this->_rootref['S_FIELD_NAME'] : ''; ?>.type == "textarea" ) ? opener.document.forms['<?php echo (isset($this->_rootref['S_FORM_NAME'])) ? $this->_rootref['S_FORM_NAME'] : ''; ?>'].<?php echo (isset($this->_rootref['S_FIELD_NAME'])) ? $this->_rootref['S_FIELD_NAME'] : ''; ?>.value + "\n" + user : user;
}

function insert_marked(users)
{
	if (typeof(users.length) == "undefined")
	{
		if (users.checked)
		{
			insert_user(users.value);
		}
	}
	else if (users.length > 0)
	{
		for (i = 0; i < users.length; i++)
		{
			if (users[i].checked)
			{
				insert_user(users[i].value);
			}
		}
	}

	self.close();
}

function insert_single(user)
{
	opener.document.forms['<?php echo (isset($this->_rootref['S_FORM_NAME'])) ? $this->_rootref['S_FORM_NAME'] : ''; ?>'].<?php echo (isset($this->_rootref['S_FIELD_NAME'])) ? $this->_rootref['S_FIELD_NAME'] : ''; ?>.value = user;
	self.close();
}
// ]]>
</script>
<script type="text/javascript" src="<?php echo (isset($this->_rootref['T_TEMPLATE_PATH'])) ? $this->_rootref['T_TEMPLATE_PATH'] : ''; ?>/forum_fn.js"></script>
<?php } ?>

<h2 class="solo"><?php echo ((isset($this->_rootref['L_FIND_USERNAME'])) ? $this->_rootref['L_FIND_USERNAME'] : ((isset($user->lang['FIND_USERNAME'])) ? $user->lang['FIND_USERNAME'] : '{ FIND_USERNAME }')); ?></h2>

<form method="post" action="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>" id="search_memberlist">
<div class="panel">
	<div class="inner"><span class="corners-top"><span></span></span>

	<p><?php echo ((isset($this->_rootref['L_FIND_USERNAME_EXPLAIN'])) ? $this->_rootref['L_FIND_USERNAME_EXPLAIN'] : ((isset($user->lang['FIND_USERNAME_EXPLAIN'])) ? $user->lang['FIND_USERNAME_EXPLAIN'] : '{ FIND_USERNAME_EXPLAIN }')); ?></p>

	<fieldset class="fields1 column1">
	<dl>
		<dt><label for="username"><?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?>:</label></dt>
		<dd><input type="text" name="username" id="username" value="<?php echo (isset($this->_rootref['USERNAME'])) ? $this->_rootref['USERNAME'] : ''; ?>" class="inputbox" /></dd>
	</dl>
	<dl>
		<dt><label for="email"><?php echo ((isset($this->_rootref['L_EMAIL'])) ? $this->_rootref['L_EMAIL'] : ((isset($user->lang['EMAIL'])) ? $user->lang['EMAIL'] : '{ EMAIL }')); ?>:</label></dt>
		<dd><input type="text" name="email" id="email" value="<?php echo (isset($this->_rootref['EMAIL'])) ? $this->_rootref['EMAIL'] : ''; ?>" class="inputbox" /></dd>
	</dl>
	<dl>
		<dt><label for="icq"><?php echo ((isset($this->_rootref['L_ICQ'])) ? $this->_rootref['L_ICQ'] : ((isset($user->lang['ICQ'])) ? $user->lang['ICQ'] : '{ ICQ }')); ?>:</label></dt>
		<dd><input type="text" name="icq" id="icq" value="<?php echo (isset($this->_rootref['ICQ'])) ? $this->_rootref['ICQ'] : ''; ?>" class="inputbox" /></dd>
	</dl>
	<dl>
		<dt><label for="aim"><?php echo ((isset($this->_rootref['L_AIM'])) ? $this->_rootref['L_AIM'] : ((isset($user->lang['AIM'])) ? $user->lang['AIM'] : '{ AIM }')); ?>:</label></dt>
		<dd><input type="text" name="aim" id="aim" value="<?php echo (isset($this->_rootref['AIM'])) ? $this->_rootref['AIM'] : ''; ?>" class="inputbox" /></dd>
	</dl>
	<dl>
		<dt><label for="yim"><?php echo ((isset($this->_rootref['L_YIM'])) ? $this->_rootref['L_YIM'] : ((isset($user->lang['YIM'])) ? $user->lang['YIM'] : '{ YIM }')); ?>:</label></dt>
		<dd><input type="text" name="yim" id="yim" value="<?php echo (isset($this->_rootref['YIM'])) ? $this->_rootref['YIM'] : ''; ?>" class="inputbox" /></dd>
	</dl>
	<dl>
		<dt><label for="msn"><?php echo ((isset($this->_rootref['L_MSNM'])) ? $this->_rootref['L_MSNM'] : ((isset($user->lang['MSNM'])) ? $user->lang['MSNM'] : '{ MSNM }')); ?>:</label></dt>
		<dd><input type="text" name="msn" id="msn" value="<?php echo (isset($this->_rootref['MSNM'])) ? $this->_rootref['MSNM'] : ''; ?>" class="inputbox" /></dd>
	</dl>
	</fieldset>

	<fieldset class="fields1 column2">
	<dl>
		<dt><label for="joined"><?php echo ((isset($this->_rootref['L_JOINED'])) ? $this->_rootref['L_JOINED'] : ((isset($user->lang['JOINED'])) ? $user->lang['JOINED'] : '{ JOINED }')); ?>:</label></dt>
		<dd><select name="joined_select"><?php echo (isset($this->_rootref['S_JOINED_TIME_OPTIONS'])) ? $this->_rootref['S_JOINED_TIME_OPTIONS'] : ''; ?></select> <input class="inputbox medium" type="text" name="joined" id="joined" value="<?php echo (isset($this->_rootref['JOINED'])) ? $this->_rootref['JOINED'] : ''; ?>" /></dd>
	</dl>
<?php if ($this->_rootref['S_VIEWONLINE']) {  ?>
	<dl>
		<dt><label for="active"><?php echo ((isset($this->_rootref['L_LAST_ACTIVE'])) ? $this->_rootref['L_LAST_ACTIVE'] : ((isset($user->lang['LAST_ACTIVE'])) ? $user->lang['LAST_ACTIVE'] : '{ LAST_ACTIVE }')); ?>:</label></dt>
		<dd><select name="active_select"><?php echo (isset($this->_rootref['S_ACTIVE_TIME_OPTIONS'])) ? $this->_rootref['S_ACTIVE_TIME_OPTIONS'] : ''; ?></select> <input class="inputbox medium" type="text" name="active" id="active" value="<?php echo (isset($this->_rootref['ACTIVE'])) ? $this->_rootref['ACTIVE'] : ''; ?>" /></dd>
	</dl>
<?php } ?>
	<dl>
		<dt><label for="count"><?php echo ((isset($this->_rootref['L_POSTS'])) ? $this->_rootref['L_POSTS'] : ((isset($user->lang['POSTS'])) ? $user->lang['POSTS'] : '{ POSTS }')); ?>:</label></dt>
		<dd><select name="count_select"><?php echo (isset($this->_rootref['S_COUNT_OPTIONS'])) ? $this->_rootref['S_COUNT_OPTIONS'] : ''; ?></select> <input class="inputbox medium" type="text" name="count" id="count" value="<?php echo (isset($this->_rootref['COUNT'])) ? $this->_rootref['COUNT'] : ''; ?>" /></dd>
	</dl>
<?php if ($this->_rootref['S_IP_SEARCH_ALLOWED']) {  ?>
	<dl>
		<dt><label for="ip"><?php echo ((isset($this->_rootref['L_POST_IP'])) ? $this->_rootref['L_POST_IP'] : ((isset($user->lang['POST_IP'])) ? $user->lang['POST_IP'] : '{ POST_IP }')); ?>:</label></dt>
		<dd><input class="inputbox medium" type="text" name="ip" id="ip" value="<?php echo (isset($this->_rootref['IP'])) ? $this->_rootref['IP'] : ''; ?>" /></dd>
	</dl>
<?php } ?>
	<dl>
		<dt><label for="search_group_id"><?php echo ((isset($this->_rootref['L_GROUP'])) ? $this->_rootref['L_GROUP'] : ((isset($user->lang['GROUP'])) ? $user->lang['GROUP'] : '{ GROUP }')); ?>:</label></dt>
		<dd><select name="search_group_id" id="search_group_id"><?php echo (isset($this->_rootref['S_GROUP_SELECT'])) ? $this->_rootref['S_GROUP_SELECT'] : ''; ?></select></dd>
	</dl>
	<dl>
		<dt><label for="sk" class="label3"><?php echo ((isset($this->_rootref['L_SORT_BY'])) ? $this->_rootref['L_SORT_BY'] : ((isset($user->lang['SORT_BY'])) ? $user->lang['SORT_BY'] : '{ SORT_BY }')); ?>:</label></dt>
		<dd><select name="sk" id="sk"><?php echo (isset($this->_rootref['S_SORT_OPTIONS'])) ? $this->_rootref['S_SORT_OPTIONS'] : ''; ?></select> <select name="sd"><?php echo (isset($this->_rootref['S_ORDER_SELECT'])) ? $this->_rootref['S_ORDER_SELECT'] : ''; ?></select></dd>
	</dl>
	</fieldset>

	<div class="clear"></div>

	<hr />

	<fieldset class="submit-buttons">
		<input type="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" name="reset" class="button2" />&nbsp;
		<input type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SEARCH'])) ? $this->_rootref['L_SEARCH'] : ((isset($user->lang['SEARCH'])) ? $user->lang['SEARCH'] : '{ SEARCH }')); ?>" class="button1" />
		<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
	</fieldset>

	<span class="corners-bottom"><span></span></span></div>
</div>

</form>
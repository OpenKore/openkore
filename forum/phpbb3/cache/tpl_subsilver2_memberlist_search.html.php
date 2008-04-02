<!-- You should retain this javascript in your own template! --><?php if ($this->_rootref['S_IN_SEARCH_POPUP']) {  ?>
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

		/**
		* Mark/unmark checklist
		* id = ID of parent container, name = name prefix, state = state [true/false]
		*/
		function marklist(id, name, state)
		{
			var parent = document.getElementById(id);
			if (!parent)
			{
				eval('parent = document.' + id);
			}

			if (!parent)
			{
				return;
			}

			var rb = parent.getElementsByTagName('input');
			
			for (var r = 0; r < rb.length; r++)
			{
				if (rb[r].name.substr(0, name.length) == name)
				{
					rb[r].checked = state;
				}
			}
		}
	// ]]>
	</script>
<?php } ?>

<form method="post" action="<?php echo (isset($this->_rootref['S_MODE_ACTION'])) ? $this->_rootref['S_MODE_ACTION'] : ''; ?>" name="search">

<table class="tablebg" width="100%" cellspacing="1">
<tr>
	<th colspan="4"><?php echo ((isset($this->_rootref['L_FIND_USERNAME'])) ? $this->_rootref['L_FIND_USERNAME'] : ((isset($user->lang['FIND_USERNAME'])) ? $user->lang['FIND_USERNAME'] : '{ FIND_USERNAME }')); ?></th>
</tr>
<tr>
	<td class="row3" colspan="4"><span class="gensmall"><?php echo ((isset($this->_rootref['L_FIND_USERNAME_EXPLAIN'])) ? $this->_rootref['L_FIND_USERNAME_EXPLAIN'] : ((isset($user->lang['FIND_USERNAME_EXPLAIN'])) ? $user->lang['FIND_USERNAME_EXPLAIN'] : '{ FIND_USERNAME_EXPLAIN }')); ?></span></td>
</tr>
<tr>
	<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_USERNAME'])) ? $this->_rootref['L_USERNAME'] : ((isset($user->lang['USERNAME'])) ? $user->lang['USERNAME'] : '{ USERNAME }')); ?>:</b></td>
	<td class="row2"><input class="post" type="text" name="username" value="<?php echo (isset($this->_rootref['USERNAME'])) ? $this->_rootref['USERNAME'] : ''; ?>" /></td>
	<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_ICQ'])) ? $this->_rootref['L_ICQ'] : ((isset($user->lang['ICQ'])) ? $user->lang['ICQ'] : '{ ICQ }')); ?>:</b></td>
	<td class="row2"><input class="post" type="text" name="icq" value="<?php echo (isset($this->_rootref['ICQ'])) ? $this->_rootref['ICQ'] : ''; ?>" /></td>
</tr>
<tr>
	<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_EMAIL'])) ? $this->_rootref['L_EMAIL'] : ((isset($user->lang['EMAIL'])) ? $user->lang['EMAIL'] : '{ EMAIL }')); ?>:</b></td>
	<td class="row2"><input class="post" type="text" name="email" value="<?php echo (isset($this->_rootref['EMAIL'])) ? $this->_rootref['EMAIL'] : ''; ?>" /></td>
	<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_AIM'])) ? $this->_rootref['L_AIM'] : ((isset($user->lang['AIM'])) ? $user->lang['AIM'] : '{ AIM }')); ?>:</b></td>
	<td class="row2"><input class="post" type="text" name="aim" value="<?php echo (isset($this->_rootref['AIM'])) ? $this->_rootref['AIM'] : ''; ?>" /></td>
</tr>
<tr>
	<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_JOINED'])) ? $this->_rootref['L_JOINED'] : ((isset($user->lang['JOINED'])) ? $user->lang['JOINED'] : '{ JOINED }')); ?>:</b></td>
	<td class="row2"><select name="joined_select"><?php echo (isset($this->_rootref['S_JOINED_TIME_OPTIONS'])) ? $this->_rootref['S_JOINED_TIME_OPTIONS'] : ''; ?></select> <input class="post" type="text" name="joined" value="<?php echo (isset($this->_rootref['JOINED'])) ? $this->_rootref['JOINED'] : ''; ?>" /></td>
	<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_YIM'])) ? $this->_rootref['L_YIM'] : ((isset($user->lang['YIM'])) ? $user->lang['YIM'] : '{ YIM }')); ?>:</b></td>
	<td class="row2"><input class="post" type="text" name="yahoo" value="<?php echo (isset($this->_rootref['YAHOO'])) ? $this->_rootref['YAHOO'] : ''; ?>" /></td>
</tr>
<tr>
<?php if ($this->_rootref['S_VIEWONLINE']) {  ?>
	<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_LAST_ACTIVE'])) ? $this->_rootref['L_LAST_ACTIVE'] : ((isset($user->lang['LAST_ACTIVE'])) ? $user->lang['LAST_ACTIVE'] : '{ LAST_ACTIVE }')); ?>:</b></td>
	<td class="row2"><select name="active_select"><?php echo (isset($this->_rootref['S_ACTIVE_TIME_OPTIONS'])) ? $this->_rootref['S_ACTIVE_TIME_OPTIONS'] : ''; ?></select> <input class="post" type="text" name="active" value="<?php echo (isset($this->_rootref['ACTIVE'])) ? $this->_rootref['ACTIVE'] : ''; ?>" /></td>
<?php } else { ?>
	<td colspan="2" class="row1">&nbsp;</td>
<?php } ?>
	<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_MSNM'])) ? $this->_rootref['L_MSNM'] : ((isset($user->lang['MSNM'])) ? $user->lang['MSNM'] : '{ MSNM }')); ?>:</b></td>
	<td class="row2"><input class="post" type="text" name="msn" value="<?php echo (isset($this->_rootref['MSNM'])) ? $this->_rootref['MSNM'] : ''; ?>" /></td>
</tr>
<tr>
	<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_POSTS'])) ? $this->_rootref['L_POSTS'] : ((isset($user->lang['POSTS'])) ? $user->lang['POSTS'] : '{ POSTS }')); ?>:</b></td>
	<td class="row2"><select name="count_select"><?php echo (isset($this->_rootref['S_COUNT_OPTIONS'])) ? $this->_rootref['S_COUNT_OPTIONS'] : ''; ?></select> <input class="post" type="text" name="count" value="<?php echo (isset($this->_rootref['COUNT'])) ? $this->_rootref['COUNT'] : ''; ?>" /></td>
	<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_JABBER'])) ? $this->_rootref['L_JABBER'] : ((isset($user->lang['JABBER'])) ? $user->lang['JABBER'] : '{ JABBER }')); ?>:</b></td>
	<td class="row2"><input class="post" type="text" name="jabber" value="<?php echo (isset($this->_rootref['JABBER'])) ? $this->_rootref['JABBER'] : ''; ?>" /></td>
</tr>
<tr>
	<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_SORT_BY'])) ? $this->_rootref['L_SORT_BY'] : ((isset($user->lang['SORT_BY'])) ? $user->lang['SORT_BY'] : '{ SORT_BY }')); ?>:</b></td>
	<td class="row2" nowrap="nowrap"><select name="sk"><?php echo (isset($this->_rootref['S_SORT_OPTIONS'])) ? $this->_rootref['S_SORT_OPTIONS'] : ''; ?></select> <select name="sd"><?php echo (isset($this->_rootref['S_ORDER_SELECT'])) ? $this->_rootref['S_ORDER_SELECT'] : ''; ?></select>&nbsp;</td>
<?php if ($this->_rootref['S_IP_SEARCH_ALLOWED']) {  ?>
	<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_POST_IP'])) ? $this->_rootref['L_POST_IP'] : ((isset($user->lang['POST_IP'])) ? $user->lang['POST_IP'] : '{ POST_IP }')); ?>:</b></td>
	<td class="row2"><input class="post" type="text" name="ip" value="<?php echo (isset($this->_rootref['IP'])) ? $this->_rootref['IP'] : ''; ?>" /></td>
</tr>
<tr>
	<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_GROUP'])) ? $this->_rootref['L_GROUP'] : ((isset($user->lang['GROUP'])) ? $user->lang['GROUP'] : '{ GROUP }')); ?>:</b></td>
	<td class="row2" nowrap="nowrap"><select name="search_group_id"><?php echo (isset($this->_rootref['S_GROUP_SELECT'])) ? $this->_rootref['S_GROUP_SELECT'] : ''; ?></select></td>
	<td class="row1">&nbsp;</td>
	<td class="row2">&nbsp;</td>
</tr>
<?php } else { ?>
	<td class="row1"><b class="genmed"><?php echo ((isset($this->_rootref['L_GROUP'])) ? $this->_rootref['L_GROUP'] : ((isset($user->lang['GROUP'])) ? $user->lang['GROUP'] : '{ GROUP }')); ?>:</b></td>
	<td class="row2" nowrap="nowrap"><select name="search_group_id"><?php echo (isset($this->_rootref['S_GROUP_SELECT'])) ? $this->_rootref['S_GROUP_SELECT'] : ''; ?></select></td>
</tr>
<?php } ?>
<tr>
	<td class="cat" colspan="4" align="center"><input class="btnmain" type="submit" name="submit" value="<?php echo ((isset($this->_rootref['L_SEARCH'])) ? $this->_rootref['L_SEARCH'] : ((isset($user->lang['SEARCH'])) ? $user->lang['SEARCH'] : '{ SEARCH }')); ?>" />&nbsp;&nbsp;<input class="btnlite" type="reset" value="<?php echo ((isset($this->_rootref['L_RESET'])) ? $this->_rootref['L_RESET'] : ((isset($user->lang['RESET'])) ? $user->lang['RESET'] : '{ RESET }')); ?>" /></td>
</tr>
</table>
<?php echo (isset($this->_rootref['S_FORM_TOKEN'])) ? $this->_rootref['S_FORM_TOKEN'] : ''; ?>
</form>

<br clear="all" />
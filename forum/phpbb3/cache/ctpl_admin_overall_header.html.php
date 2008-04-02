<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" dir="<?php echo (isset($this->_rootref['S_CONTENT_DIRECTION'])) ? $this->_rootref['S_CONTENT_DIRECTION'] : ''; ?>" lang="<?php echo (isset($this->_rootref['S_USER_LANG'])) ? $this->_rootref['S_USER_LANG'] : ''; ?>" xml:lang="<?php echo (isset($this->_rootref['S_USER_LANG'])) ? $this->_rootref['S_USER_LANG'] : ''; ?>">
<head>

<meta http-equiv="Content-Type" content="text/html; charset=<?php echo (isset($this->_rootref['S_CONTENT_ENCODING'])) ? $this->_rootref['S_CONTENT_ENCODING'] : ''; ?>" />
<meta http-equiv="Content-Style-Type" content="text/css" />
<meta http-equiv="Content-Language" content="<?php echo (isset($this->_rootref['S_USER_LANG'])) ? $this->_rootref['S_USER_LANG'] : ''; ?>" />
<meta http-equiv="imagetoolbar" content="no" />
<?php if ($this->_rootref['META']) {  echo (isset($this->_rootref['META'])) ? $this->_rootref['META'] : ''; } ?>
<title><?php echo (isset($this->_rootref['PAGE_TITLE'])) ? $this->_rootref['PAGE_TITLE'] : ''; ?></title>

<link href="style/admin.css" rel="stylesheet" type="text/css" media="screen" />

<script type="text/javascript">
// <![CDATA[
var jump_page = '<?php echo ((isset($this->_rootref['LA_JUMP_PAGE'])) ? $this->_rootref['LA_JUMP_PAGE'] : ((isset($this->_rootref['L_JUMP_PAGE'])) ? addslashes($this->_rootref['L_JUMP_PAGE']) : ((isset($user->lang['JUMP_PAGE'])) ? addslashes($user->lang['JUMP_PAGE']) : '{ JUMP_PAGE }'))); ?>:';
var on_page = '<?php echo (isset($this->_rootref['ON_PAGE'])) ? $this->_rootref['ON_PAGE'] : ''; ?>';
var per_page = '<?php echo (isset($this->_rootref['PER_PAGE'])) ? $this->_rootref['PER_PAGE'] : ''; ?>';
var base_url = '<?php echo (isset($this->_rootref['A_BASE_URL'])) ? $this->_rootref['A_BASE_URL'] : ''; ?>';

var menu_state = 'shown';


/**
* Jump to page
*/
function jumpto()
{
	var page = prompt(jump_page, on_page);

	if (page !== null && !isNaN(page) && page > 0)	
	{
		document.location.href = base_url.replace(/&amp;/g, '&') + '&start=' + ((page - 1) * per_page);
	}
}

/**
* Set display of page element
* s[-1,0,1] = hide,toggle display,show
*/
function dE(n, s, type)
{
	if (!type)
	{
		type = 'block';
	}

	var e = document.getElementById(n);
	if (!s)
	{
		s = (e.style.display == '') ? -1 : 1;
	}
	e.style.display = (s == 1) ? type : 'none';
}

/**
* Mark/unmark checkboxes
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

/**
* Find a member
*/
function find_username(url)
{
	popup(url, 760, 570, '_usersearch');
	return false;
}

/**
* Window popup
*/
function popup(url, width, height, name)
{
	if (!name)
	{
		name = '_popup';
	}

	window.open(url.replace(/&amp;/g, '&'), name, 'height=' + height + ',resizable=yes,scrollbars=yes, width=' + width);
	return false;
}

/**
* Hiding/Showing the side menu
*/
function switch_menu()
{
	var menu = document.getElementById('menu');
	var main = document.getElementById('main');
	var toggle = document.getElementById('toggle');
	var handle = document.getElementById('toggle-handle');

	switch (menu_state)
	{
		// hide
		case 'shown':
			main.style.width = '93%';
			menu_state = 'hidden';
			menu.style.display = 'none';
			toggle.style.width = '20px';
			handle.style.backgroundImage = 'url(images/toggle.gif)';
			handle.style.backgroundRepeat = 'no-repeat';

			<?php if ($this->_rootref['S_CONTENT_DIRECTION'] == 'rtl') {  ?>
				handle.style.backgroundPosition = '0% 50%';
				toggle.style.left = '96%';
			<?php } else { ?>
				handle.style.backgroundPosition = '100% 50%';
				toggle.style.left = '0';
			<?php } ?>
		break;

		// show
		case 'hidden':
			main.style.width = '76%';
			menu_state = 'shown';
			menu.style.display = 'block';
			toggle.style.width = '5%';
			handle.style.backgroundImage = 'url(images/toggle.gif)';
			handle.style.backgroundRepeat = 'no-repeat';

			<?php if ($this->_rootref['S_CONTENT_DIRECTION'] == 'rtl') {  ?>
				handle.style.backgroundPosition = '100% 50%';
				toggle.style.left = '75%';
			<?php } else { ?>
				handle.style.backgroundPosition = '0% 50%';
				toggle.style.left = '15%';
			<?php } ?>
		break;
	}
}

// ]]>
</script>
</head>

<body class="<?php echo (isset($this->_rootref['S_CONTENT_DIRECTION'])) ? $this->_rootref['S_CONTENT_DIRECTION'] : ''; ?>">

<div id="wrap">
	<div id="page-header">
		<h1><?php echo ((isset($this->_rootref['L_ADMIN_PANEL'])) ? $this->_rootref['L_ADMIN_PANEL'] : ((isset($user->lang['ADMIN_PANEL'])) ? $user->lang['ADMIN_PANEL'] : '{ ADMIN_PANEL }')); ?></h1>
		<p><a href="<?php echo (isset($this->_rootref['U_ADM_INDEX'])) ? $this->_rootref['U_ADM_INDEX'] : ''; ?>"><?php echo ((isset($this->_rootref['L_ADMIN_INDEX'])) ? $this->_rootref['L_ADMIN_INDEX'] : ((isset($user->lang['ADMIN_INDEX'])) ? $user->lang['ADMIN_INDEX'] : '{ ADMIN_INDEX }')); ?></a> &bull; <a href="<?php echo (isset($this->_rootref['U_INDEX'])) ? $this->_rootref['U_INDEX'] : ''; ?>"><?php echo ((isset($this->_rootref['L_FORUM_INDEX'])) ? $this->_rootref['L_FORUM_INDEX'] : ((isset($user->lang['FORUM_INDEX'])) ? $user->lang['FORUM_INDEX'] : '{ FORUM_INDEX }')); ?></a></p>
		<p id="skip"><a href="#acp"><?php echo ((isset($this->_rootref['L_SKIP'])) ? $this->_rootref['L_SKIP'] : ((isset($user->lang['SKIP'])) ? $user->lang['SKIP'] : '{ SKIP }')); ?></a></p>
	</div>
	
	<div id="page-body">
		<div id="tabs">
			<ul>
			<?php $_t_block1_count = (isset($this->_tpldata['t_block1'])) ? sizeof($this->_tpldata['t_block1']) : 0;if ($_t_block1_count) {for ($_t_block1_i = 0; $_t_block1_i < $_t_block1_count; ++$_t_block1_i){$_t_block1_val = &$this->_tpldata['t_block1'][$_t_block1_i]; ?>
				<li<?php if ($_t_block1_val['S_SELECTED']) {  ?> id="activetab"<?php } ?>><a href="<?php echo $_t_block1_val['U_TITLE']; ?>"><span><?php echo $_t_block1_val['L_TITLE']; ?></span></a></li>
			<?php }} ?>
			</ul>
		</div>

		<div id="acp">
		<div class="panel">
			<span class="corners-top"><span></span></span>
				<div id="content">
					<?php if (! $this->_rootref['S_USER_NOTICE']) {  ?> 
					<div id="toggle">						
						<a id="toggle-handle" accesskey="m" title="<?php echo ((isset($this->_rootref['L_MENU_TOGGLE'])) ? $this->_rootref['L_MENU_TOGGLE'] : ((isset($user->lang['MENU_TOGGLE'])) ? $user->lang['MENU_TOGGLE'] : '{ MENU_TOGGLE }')); ?>" onclick="switch_menu(); return false;" href="#"></a></div>
					<?php } ?>
					<div id="menu">
						<p><?php echo ((isset($this->_rootref['L_LOGGED_IN_AS'])) ? $this->_rootref['L_LOGGED_IN_AS'] : ((isset($user->lang['LOGGED_IN_AS'])) ? $user->lang['LOGGED_IN_AS'] : '{ LOGGED_IN_AS }')); ?><br /><strong><?php echo (isset($this->_rootref['USERNAME'])) ? $this->_rootref['USERNAME'] : ''; ?></strong> [&nbsp;<a href="<?php echo (isset($this->_rootref['U_LOGOUT'])) ? $this->_rootref['U_LOGOUT'] : ''; ?>"><?php echo ((isset($this->_rootref['L_LOGOUT'])) ? $this->_rootref['L_LOGOUT'] : ((isset($user->lang['LOGOUT'])) ? $user->lang['LOGOUT'] : '{ LOGOUT }')); ?></a>&nbsp;]</p>
						<ul>
						<?php $_l_block1_count = (isset($this->_tpldata['l_block1'])) ? sizeof($this->_tpldata['l_block1']) : 0;if ($_l_block1_count) {for ($_l_block1_i = 0; $_l_block1_i < $_l_block1_count; ++$_l_block1_i){$_l_block1_val = &$this->_tpldata['l_block1'][$_l_block1_i]; if ($_l_block1_val['S_SELECTED']) {  $_l_block2_count = (isset($_l_block1_val['l_block2'])) ? sizeof($_l_block1_val['l_block2']) : 0;if ($_l_block2_count) {for ($_l_block2_i = 0; $_l_block2_i < $_l_block2_count; ++$_l_block2_i){$_l_block2_val = &$_l_block1_val['l_block2'][$_l_block2_i]; if (sizeof($_l_block2_val['l_block3'])) {  ?>
							<li class="header"><?php echo $_l_block2_val['L_TITLE']; ?></li>
							<?php } $_l_block3_count = (isset($_l_block2_val['l_block3'])) ? sizeof($_l_block2_val['l_block3']) : 0;if ($_l_block3_count) {for ($_l_block3_i = 0; $_l_block3_i < $_l_block3_count; ++$_l_block3_i){$_l_block3_val = &$_l_block2_val['l_block3'][$_l_block3_i]; ?>
								<li<?php if ($_l_block3_val['S_SELECTED']) {  ?> id="activemenu"<?php } ?>><a href="<?php echo $_l_block3_val['U_TITLE']; ?>"><span><?php echo $_l_block3_val['L_TITLE']; ?></span></a></li>
							<?php }} }} } }} ?>
						</ul>
					</div>
	
					<div id="main">
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html dir="{S_CONTENT_DIRECTION}">
<head>
<meta http-equiv="Content-Type" content="text/html; charset={S_CONTENT_ENCODING}">
<meta http-equiv="Content-Style-Type" content="text/css">
{META}
{NAV_LINKS}
<title>{PAGE_TITLE} :: {SITENAME}</title>
<link href="http://www.openkore.com/include/openkore-topbar.css" media="screen" rel="stylesheet" type="text/css">
<link href="http://www.openkore.com/include/statcounter.css" media="screen" rel="stylesheet" type="text/css">
<link href="http://www.openkore.com/include/independent.css" media="screen" rel="stylesheet" type="text/css">
<link rel="stylesheet" href="templates/subSilver/{T_HEAD_STYLESHEET}" type="text/css">
<!-- Fix broken PNG transparency and CSS support for IE/Win5-6+ -->
<!--[if gte IE 5.5000]>
<script type="text/javascript" src="http://www.openkore.com/include/pngfix.js"></script>
<link href="http://www.openkore.com/include/iefixes.css" media="screen" rel="stylesheet" type="text/css">
<![endif]-->
<script type="text/javascript" src="templates/subSilver/jquery.js"></script>

<script type="text/javascript">
<!--
	<!-- BEGIN switch_enable_pm_popup -->
	if ( {PRIVATE_MESSAGE_NEW_FLAG} )
	{
		window.open('{U_PRIVATEMSGS_POPUP}', '_phpbbprivmsg', 'HEIGHT=225,resizable=yes,WIDTH=400');;
	}
	<!-- END switch_enable_pm_popup -->

	function showMore() {
		$('#openkore_forum_topbar div.more').css("display", "inline");
		$('#openkore_forum_topbar li.more').hide();
	}

	function showLess() {
		$('#openkore_forum_topbar div.more').hide();
		$('#openkore_forum_topbar li.more').css("display", "inline");
	}
//-->
</script>
<!-- Begin Syntax Highlighting Mod -->
<link rel="stylesheet" href="templates/subSilver/geshi.css" type="text/css">
<!-- End Syntax Highlighting Mod -->
</head>
<body bgcolor="{T_BODY_BGCOLOR}" text="{T_BODY_TEXT}" link="{T_BODY_LINK}" vlink="{T_BODY_VLINK}">

{FIREFOX_BOX}
<a name="top"></a>

<div id="openkore_topbar">
	<div id="openkore_navigation" style="margin-left: 0.2cm;">
		<table id="openkore_navigation_table" cellspacing="0" cellpadding="0">
		<tr>
		<td>

		<ul>
		<li><a href="http://www.openkore.com/"><img src="http://www.openkore.com/images/home.png" width="48" height="48" alt=""><br>Home</a></li>
		<li><a href="http://www.openkore.com/wiki/index.php/Support"><img src="http://www.openkore.com/images/help.png" width="48" height="48" alt=""><br>Help!</a></li>
		</ul>

		</td>
		<td>

		<table id="openkore_navigation_language_bar" cellspacing="0" cellpadding="0">
		<tr>
			<td><a href="http://forums.openkore.com/" title="International forum"><img src="images/international.png" width="24" height="24" alt="">International</a></td>
			<td><a href="http://www.ingamers.de/" title="Deutsche forum"><img src="images/germany.png" width="24" height="24" alt="">Deutsch</a></td>
			<td><a href="http://www.openkore.com.br/" title="Fórum Brasileiro"><img src="images/brazil.png" width="24" height="24" alt="">Brazil</a></td> <!-- --Roger-- -->
			<td><a href="http://www.rofan.ru/" title="Россия"><img src="/images/russia.png" width="24" height="24" alt="">Россия</a></td><!-- kLabMouse -->
			<td><a href="http://ro.yyro.com/" title="中文"><img src="images/chinese.png" width="24" height="24" alt="">中文</a></td><!-- lkm -->
		</tr>
		<tr>
			<td><a href="http://darkmoon.ath.cx/" title="Filipino forum"><img src="images/philippines.png" width="24" height="24" alt="">Philippines</a></td>
			<td><a href="http://openkore-fr.ath.cx/" title="Forum Français"><img src="images/france.png" width="24" height="24" alt="">Français</a></td> <!-- Tic Or Tac -->
			<td><a href="http://www.openkore-hispano.uni.cc/" title="Hispano"><img src="images/spain.png" width="24" height="24" alt="">Hispano</a></td> <!-- Rodrigo01 -->
			<td><a href="http://www.d-bests.com" title="Bahasa Indonesia"><img src="/images/indonesia.png" width="24" height="24" alt="">Indonesia</a></td> <!-- h4rry84 -->
			<td><a href="http://www.openkore-thailand.com/" title="ภาษาไทย"><img src="/images/thailand.png" width="24" height="24" alt="">ภาษาไทย</a></td><!-- abt123 -->
		</tr>
		</table>

		</td>
		</tr>
		</table>
	</div>

	<div id="openkore_donation">
		<div>Support OpenKore:</div>
		<div><a href="http://www.openkore.com/wiki/index.php/Fund_pool">
			<span>Learn about<br>the Fund Pool</span>
		</a></div>
	</div>
</div>

<div id="openkore_forum_topbar">

	<span class="title"><a href="http://www.openkore.com/"><img src="/images/small-logo.png" alt="The OpenKore Project" width="92" height="18"></a></span>
	<ul>
	<li><a href="{U_SEARCH}"><img src="templates/subSilver/images/icon_mini_search.gif" width="12" height="13" alt="{L_SEARCH}"><b>{L_SEARCH}</b></a></li>
	<!-- BEGIN switch_user_logged_in -->
	<li><a href="{U_PRIVATEMSGS}"><img src="templates/subSilver/images/icon_mini_message.gif" width="12" height="13" alt="{PRIVATE_MESSAGE_INFO}">{PRIVATE_MESSAGE_INFO}</a></li>
	<!-- END switch_user_logged_in -->
	<li><a href="{U_LOGIN_LOGOUT}"><img src="templates/subSilver/images/icon_mini_login.gif" width="12" height="13" border="0" alt="{L_LOGIN_LOGOUT}" hspace="3" />{L_LOGIN_LOGOUT}</a></li>
	<!-- BEGIN switch_user_logged_out -->
	<li><a href="profile.php?mode=register&amp;agreed=yes"><img src="templates/subSilver/images/icon_mini_register.gif" width="12" height="13" alt="{L_REGISTER}">{L_REGISTER}</a></li>
	<!-- END switch_user_logged_out -->
	<li class="more"><a href="javascript:void(showMore())">More »</a></li>
	</ul>

	<div class="more">
	<ul>
	<!-- BEGIN switch_user_logged_in -->
	<li><a href="{U_PROFILE}"><img src="templates/subSilver/images/icon_mini_profile.gif" width="12" height="13" alt="{L_PROFILE}">{L_PROFILE}</a></li>
	<!-- END switch_user_logged_in -->
	<li><a href="{U_MEMBERLIST}"><img src="templates/subSilver/images/icon_mini_members.gif" width="12" height="13" alt="{L_MEMBERLIST}">{L_MEMBERLIST}</a></li>
	<li><a href="{U_GROUP_CP}"><img src="templates/subSilver/images/icon_mini_groups.gif" width="12" height="13" alt="{L_USERGROUPS}">{L_USERGROUPS}</a></li>
	<li><a href="javascript:void(showLess())">Less «</a></li>
	</ul>
	</div>

</div>

<div id="openkore_forum_inner">

<table width="100%" cellspacing="0" cellpadding="10" border="0" align="center"> 
	<tr> 
		<td class="bodyline">

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html dir="{S_CONTENT_DIRECTION}">
<head>
<meta http-equiv="Content-Type" content="text/html; charset={S_CONTENT_ENCODING}">
<meta http-equiv="Content-Style-Type" content="text/css">
{META}
{NAV_LINKS}
<title>{SITENAME} :: {PAGE_TITLE}</title>
<link rel="stylesheet" href="templates/subSilver/{T_HEAD_STYLESHEET}" type="text/css">
<link href="http://www.openkore.com/include/openkore-topbar.css" media="screen" rel="stylesheet" type="text/css">
<link href="http://www.openkore.com/include/statcounter.css" media="screen" rel="stylesheet" type="text/css">
<link href="http://www.openkore.com/include/independent.css" media="screen" rel="stylesheet" type="text/css">
<!-- Fix broken PNG transparency and CSS support for IE/Win5-6+ -->
<!--[if gte IE 5.5000]>
<script type="text/javascript" src="/include/pngfix.js"></script>
<link href="http://www.openkore.com/include/iefixes.css" media="screen" rel="stylesheet" type="text/css">
<![endif]-->

<!-- BEGIN switch_enable_pm_popup -->
<script language="Javascript" type="text/javascript">
<!--
	if ( {PRIVATE_MESSAGE_NEW_FLAG} )
	{
		window.open('{U_PRIVATEMSGS_POPUP}', '_phpbbprivmsg', 'HEIGHT=225,resizable=yes,WIDTH=400');;
	}
//-->
</script>
<!-- END switch_enable_pm_popup -->
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
			<td><a href="http://www.openkore-brasil.com/" title="Brazilian forum"><img src="images/brazil.png" width="24" height="24" alt="">Brazil</a></td>
			<td><a href="http://www.d-bests.com/" title="Indonesian forum"><img src="images/indonesia.png" width="24" height="24" alt="">Indonesia</a></td>
			<td><a href="http://www.openkore-thailand.com/" title="ภาษาไทย"><img src="/images/thailand.png" width="24" height="24" alt="">ภาษาไทย</a></td><!-- abt123 -->
			<td><a href="http://ro.yyro.com/" title="中文"><img src="images/chinese.png" width="24" height="24" alt="">中文</a></td><!-- lkm -->
		</tr>
		<tr>
			<td><a href="http://darkmoon.ath.cx/" title="Filipino forum"><img src="images/philippines.png" width="24" height="24" alt="">Philippines</a></td>
			<td><a href="http://www.openkore-hispano.uni.cc/" title="Hispano"><img src="images/spain.png" width="24" height="24" alt="">Hispano</a></td>
			<td><a href="http://www.openkore.de/" title="Deutsch"><img src="images/germany.png" width="24" height="24" alt="">Deutsch</a></td>
			<td><a href="http://openkore.dnip.net" title="한국"><img src="/images/korea.png" width="24" height="24" alt="">한국</a></td>
		</tr>
		</table>

		</td>
		</tr>
		</table>
	</div>

	<div id="openkore_donation">
		<form action="https://www.paypal.com/cgi-bin/webscr" method="post">
		<div>
		Support OpenKore:<br>
		<input type="hidden" name="cmd" value="_xclick">
		<input type="hidden" name="business" value="rbvkinfo@gmail.com">
		<input type="hidden" name="item_name" value="OpenKore Donation">
		<input type="hidden" name="item_number" value="1">
		<input type="hidden" name="page_style" value="PayPal">
		<input type="hidden" name="no_shipping" value="1">
		<input type="hidden" name="return" value="http://www.openkore.com/donation-ok.php">
		<input type="hidden" name="cancel_return" value="http://www.openkore.com/">
		<input type="hidden" name="cn" value="Comments">
		<input type="hidden" name="currency_code" value="USD">
		<input type="hidden" name="tax" value="0">
		<input type="hidden" name="bn" value="PP-DonationsBF">
		<input type="image" src="https://www.paypal.com/en_US/i/btn/x-click-but21.gif" name="submit" alt="Make payments with PayPal - it's fast, free and secure!" style="vertical-align: middle;">
		</div>
		</form>
	</div>
</div>

<div style="clear: both;"></div>

<div id="openkore_forum_inner">

<table width="100%" cellspacing="0" cellpadding="10" border="0" align="center"> 
	<tr> 
		<td class="bodyline"><table width="100%" cellspacing="0" cellpadding="0" border="0">
			<tr> 
				<td><a href="http://www.openkore.com/"><img src="/images/logo.jpg" border="0" alt="The OpenKore Website" vspace="1" /></a></td>
				<td align="center" width="100%" valign="middle"><span class="maintitle">{SITENAME}</span><br /><span class="gen">{SITE_DESCRIPTION}<br />&nbsp; </span> 
				<table cellspacing="0" cellpadding="2" border="0">
					<tr> 
						<td align="center" valign="top" nowrap="nowrap"><!-- <span class="mainmenu">&nbsp;<a href="{U_FAQ}" class="mainmenu"><img src="templates/subSilver/images/icon_mini_faq.gif" width="12" height="13" border="0" alt="{L_FAQ}" hspace="3" />{L_FAQ}</a>&nbsp; &nbsp; --><a href="{U_SEARCH}" class="mainmenu"><img src="templates/subSilver/images/icon_mini_search.gif" width="12" height="13" border="0" alt="{L_SEARCH}" hspace="3" />{L_SEARCH}</a>&nbsp; &nbsp;<a href="{U_MEMBERLIST}" class="mainmenu"><img src="templates/subSilver/images/icon_mini_members.gif" width="12" height="13" border="0" alt="{L_MEMBERLIST}" hspace="3" />{L_MEMBERLIST}</a>&nbsp; &nbsp;<a href="{U_GROUP_CP}" class="mainmenu"><img src="templates/subSilver/images/icon_mini_groups.gif" width="12" height="13" border="0" alt="{L_USERGROUPS}" hspace="3" />{L_USERGROUPS}</a>&nbsp; 
						<!-- BEGIN switch_user_logged_out -->
						&nbsp;<a href="profile.php?mode=register&amp;agreed=yes" class="mainmenu"><img src="templates/subSilver/images/icon_mini_register.gif" width="12" height="13" border="0" alt="{L_REGISTER}" hspace="3" />{L_REGISTER}</a>&nbsp;
						<!-- END switch_user_logged_out -->
						</td>
					</tr>
					<tr>
						<td height="25" align="center" valign="top" nowrap="nowrap"><span class="mainmenu">&nbsp;<a href="{U_PROFILE}" class="mainmenu"><img src="templates/subSilver/images/icon_mini_profile.gif" width="12" height="13" border="0" alt="{L_PROFILE}" hspace="3" />{L_PROFILE}</a>&nbsp; &nbsp;<a href="{U_PRIVATEMSGS}" class="mainmenu"><img src="templates/subSilver/images/icon_mini_message.gif" width="12" height="13" border="0" alt="{PRIVATE_MESSAGE_INFO}" hspace="3" />{PRIVATE_MESSAGE_INFO}</a>&nbsp; &nbsp;<a href="{U_LOGIN_LOGOUT}" class="mainmenu"><img src="templates/subSilver/images/icon_mini_login.gif" width="12" height="13" border="0" alt="{L_LOGIN_LOGOUT}" hspace="3" />{L_LOGIN_LOGOUT}</a>&nbsp;</span></td>
					</tr>
				</table></td>
			</tr>
		</table>

		<br />

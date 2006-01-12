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

<a name="top"></a>

<div id="openkore_topbar">
	<div id="openkore_navigation" style="margin-left: 0.2cm;">
		<ul>
		<li><a href="http://www.openkore.com/"><img src="http://www.openkore.com/images/home.png" width="48" height="48" alt=""><br>Home</a></li>
		<li><a href="http://www.openkore.com/wiki/index.php/Support"><img src="http://www.openkore.com/images/help.png" width="48" height="48" alt=""><br>Help!</a></li>
		<li style="margin-left: 0.5cm;">&nbsp;</li>
		<li><a href="http://forums.openkore.com/" title="International forum"><img src="images/international.png" width="48" height="48" alt=""><br>International</a></li>
		<li><a href="http://www.openkore-brasil.com/" title="Brazilian forum"><img src="images/brazil.png" width="48" height="48" alt=""><br>Brazil</a></li>
		<li><a href="http://techie.sytes.net/index.php" title="Filipino forum"><img src="images/philippines.png" width="48" height="48" alt=""><br>Philippines</a></li>
		</ul>
	</div>

	<div id="openkore_donation">
		<form action="https://www.paypal.com/cgi-bin/webscr" method="post">
		<input type="hidden" name="cmd" value="_s-xclick">
		<input type="image" src="https://www.paypal.com/en_US/i/btn/x-click-but21.gif" name="submit" alt="Make payments with PayPal - it's fast, free and secure!">
		<input type="hidden" name="encrypted" value="-----BEGIN PKCS7-----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-----END PKCS7-----
">
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
						&nbsp;<a href="/enter.php?redirect=%2Fprofile.php%3Fmode%3Dregister%26agreed%3Dtrue" class="mainmenu"><img src="templates/subSilver/images/icon_mini_register.gif" width="12" height="13" border="0" alt="{L_REGISTER}" hspace="3" />{L_REGISTER}</a>&nbsp;
						<!-- END switch_user_logged_out -->
						</span></td>
					</tr>
					<tr>
						<td height="25" align="center" valign="top" nowrap="nowrap"><span class="mainmenu">&nbsp;<a href="{U_PROFILE}" class="mainmenu"><img src="templates/subSilver/images/icon_mini_profile.gif" width="12" height="13" border="0" alt="{L_PROFILE}" hspace="3" />{L_PROFILE}</a>&nbsp; &nbsp;<a href="{U_PRIVATEMSGS}" class="mainmenu"><img src="templates/subSilver/images/icon_mini_message.gif" width="12" height="13" border="0" alt="{PRIVATE_MESSAGE_INFO}" hspace="3" />{PRIVATE_MESSAGE_INFO}</a>&nbsp; &nbsp;<a href="{U_LOGIN_LOGOUT}" class="mainmenu"><img src="templates/subSilver/images/icon_mini_login.gif" width="12" height="13" border="0" alt="{L_LOGIN_LOGOUT}" hspace="3" />{L_LOGIN_LOGOUT}</a>&nbsp;</span></td>
					</tr>
				</table></td>
			</tr>
		</table>

		<br />

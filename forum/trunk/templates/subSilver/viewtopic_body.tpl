<!-- BEGIN important_announcement -->
<div class="openkore_announcement">
    {IMPORTANT_ANNOUNCEMENT}
</div>
<!-- END important_announcement -->

{ADVERTISEMENT}

<table width="100%" cellspacing="2" cellpadding="2" border="0">
  <tr> 
	<td align="left" valign="bottom" colspan="2"><a class="maintitle" href="{U_VIEW_TOPIC}">{TOPIC_TITLE}</a><br />
	  <span class="gensmall"><b>{PAGINATION}</b><br />
	  &nbsp; </span></td>
  </tr>
</table>

<table width="100%" cellspacing="2" cellpadding="2" border="0">
  <tr> 
	<td align="left" valign="bottom" nowrap="nowrap"><span class="nav"><a href="{U_POST_NEW_TOPIC}"><img src="{POST_IMG}" border="0" alt="{L_POST_NEW_TOPIC}" valign="middle" /></a>&nbsp;&nbsp;&nbsp;<a href="{U_POST_REPLY_TOPIC}"><img src="{REPLY_IMG}" border="0" alt="{L_POST_REPLY_TOPIC}" valign="middle" /></a>&nbsp;&nbsp;&nbsp;<a href="http://bugs.openkore.com/"><img src="/images/report-bug.png" border="0" alt="Report a bug" valign="middle"/></a></span></td>
	<td align="left" valign="middle" width="100%"><span class="nav">&nbsp;&nbsp;&nbsp;<a href="{U_INDEX}" class="nav">{L_INDEX}</a> <!-- IF PARENT_FORUM --> -> <a class="nav" href="{U_VIEW_PARENT_FORUM}">{PARENT_FORUM_NAME}</a><!-- ENDIF -->
	  -> <a href="{U_VIEW_FORUM}" class="nav">{FORUM_NAME}</a></span></td>
  </tr>
</table>

<table class="forumline" width="100%" cellspacing="1" cellpadding="3" border="0">
	<tr align="right">
		<td class="catHead" colspan="2" height="28"><span class="nav"><a href="{U_VIEW_OLDER_TOPIC}" class="nav">{L_VIEW_PREVIOUS_TOPIC}</a> :: <a href="{U_VIEW_NEWER_TOPIC}" class="nav">{L_VIEW_NEXT_TOPIC}</a> &nbsp;</span></td>
	</tr>
	{POLL_DISPLAY} 
	<tr>
		<th class="thLeft" width="150" height="26" nowrap="nowrap">{L_AUTHOR}</th>
		<th class="thRight" nowrap="nowrap">{L_MESSAGE}</th>
	</tr>
	<!-- BEGIN postrow -->
	<tr> 
		<td width="150" align="left" valign="top" class="{postrow.ROW_CLASS}"><span class="name"><a name="{postrow.U_POST_ID}"></a><b><a href="javascript:emoticon('[b]{postrow.POSTER_NAME}[/b], ')">{postrow.POSTER_NAME}</a></b></span><br /><span class="postdetails">{postrow.POSTER_RANK}<br />{postrow.RANK_IMAGE}{postrow.POSTER_AVATAR}<br /><br />{postrow.POSTER_JOINED}<br />{postrow.POSTER_POSTS}<br />{postrow.POSTER_FROM}</span><br /></td>
		<td class="{postrow.ROW_CLASS}" width="100%" height="28" valign="top"><table width="100%" border="0" cellspacing="0" cellpadding="0">
			<tr>
				<td width="100%"><a href="{postrow.U_MINI_POST}"><img src="{postrow.MINI_POST_IMG}" width="12" height="9" alt="{postrow.L_MINI_POST_ALT}" title="{postrow.L_MINI_POST_ALT}" border="0" /></a><span class="postdetails">{L_POSTED}: {postrow.POST_DATE}<span class="gen">&nbsp;</span>&nbsp; &nbsp;{L_POST_SUBJECT}: {postrow.POST_SUBJECT}</span></td>
				<td valign="top" nowrap="nowrap">{postrow.QUOTE_IMG} {postrow.EDIT_IMG} {postrow.DELETE_IMG} {postrow.IP_IMG}</td>
			</tr>
			<tr> 
				<td colspan="2"><hr /></td>
			</tr>
			<tr>
				<td colspan="2"><span class="postbody">{postrow.MESSAGE}</span>{postrow.ATTACHMENTS}<span class="postbody">{postrow.SIGNATURE}</span><span class="gensmall">{postrow.EDITED_MESSAGE}</span></td>
			</tr>
		</table></td>
	</tr>
	<tr> 
		<td class="{postrow.ROW_CLASS}" width="150" align="left" valign="middle"><span class="nav"><a href="#top" class="nav">{L_BACK_TO_TOP}</a></span></td>
		<td class="{postrow.ROW_CLASS}" width="100%" height="28" valign="bottom" nowrap="nowrap"><table cellspacing="0" cellpadding="0" border="0" height="18" width="18">
			<tr> 
				<td valign="middle" nowrap="nowrap">{postrow.PROFILE_IMG} {postrow.PM_IMG} {postrow.EMAIL_IMG} {postrow.WWW_IMG} {postrow.AIM_IMG} {postrow.YIM_IMG} {postrow.MSN_IMG}<script language="JavaScript" type="text/javascript"><!-- 

	if ( navigator.userAgent.toLowerCase().indexOf('mozilla') != -1 && navigator.userAgent.indexOf('5.') == -1 && navigator.userAgent.indexOf('6.') == -1 )
		document.write(' {postrow.ICQ_IMG}');
	else
		document.write('</td><td>&nbsp;</td><td valign="top" nowrap="nowrap"><div style="position:relative"><div style="position:absolute">{postrow.ICQ_IMG}</div><div style="position:absolute;left:3px;top:-1px">{postrow.ICQ_STATUS_IMG}</div></div>');
				
				//--></script><noscript>{postrow.ICQ_IMG}</noscript></td>
			</tr>
		</table></td>
	</tr>
	<tr> 
		<td class="spaceRow" colspan="2" height="1"><img src="templates/subSilver/images/spacer.gif" alt="" width="1" height="1" /></td>
	</tr>
	<!-- END postrow -->
	<tr align="center"> 
		<td class="row1" colspan="2" >
		{QUICKREPLY_OUTPUT}
		</td>
	</tr>
	<tr align="center"> 
		<td class="catBottom" colspan="2" height="28"><table cellspacing="0" cellpadding="0" border="0">
			<tr><form method="post" action="{S_POST_DAYS_ACTION}">
				<td align="center"><span class="gensmall">{L_DISPLAY_POSTS}: {S_SELECT_POST_DAYS}&nbsp;{S_SELECT_POST_ORDER}&nbsp;<input type="submit" value="{L_GO}" class="liteoption" name="submit" /></span></td>
			</form></tr>
		</table></td>
	</tr>
</table>

<table width="100%" cellspacing="2" cellpadding="2" border="0" align="center">
  <tr> 
	<td align="left" valign="middle" nowrap="nowrap"><span class="nav"><a href="{U_POST_NEW_TOPIC}"><img src="{POST_IMG}" border="0" alt="{L_POST_NEW_TOPIC}" align="middle" /></a>&nbsp;&nbsp;&nbsp;<a href="{U_POST_REPLY_TOPIC}"><img src="{REPLY_IMG}" border="0" alt="{L_POST_REPLY_TOPIC}" align="middle" /></a></span></td>
	<td align="left" valign="middle" width="100%"><span class="nav">&nbsp;&nbsp;&nbsp;<a href="{U_INDEX}" class="nav">{L_INDEX}</a> <!-- IF PARENT_FORUM --> -> <a class="nav" href="{U_VIEW_PARENT_FORUM}">{PARENT_FORUM_NAME}</a><!-- ENDIF -->
	  -> <a href="{U_VIEW_FORUM}" class="nav">{FORUM_NAME}</a></span></td>
	<td align="right" valign="top" nowrap="nowrap"><span class="gensmall">{S_TIMEZONE}</span><br /><span class="nav">{PAGINATION}</span> 
	  </td>
  </tr>
  <tr>
	<td align="left" colspan="3"><span class="nav">{PAGE_NUMBER}</span></td>
  </tr>
</table>

<table width="100%" cellspacing="2" border="0" align="center">
  <tr> 
	<td width="40%" valign="top" nowrap="nowrap" align="left"><span class="gensmall">{S_WATCH_TOPIC}</span><br />
	  <!-- BEGIN is_forum_contributor -->
	  <script type="text/javascript" src="/contributors.js"></script>
	  <script type="text/javascript">setParams({TOPIC_ID}, "{SID}");</script>
	  <div style="margin-top: 1em; font-size: 10pt;">
	  	<b>Forum contributors actions:</b>
	  	<ul style="margin: 0; padding: 0; margin-left: 2em;">
	  	<li><a href="javascript:void( contribute('to_support') )">Move to support forum</a></li>
	  	<li><a href="javascript:void( contribute('rtfm', 'Please give a hint, or leave empty.') )">"Read the documentation / FAQ!"</a></li>
	  	<li><a href="javascript:void( contribute('violation', 'Please state the rule that was violated, or leave empty.') )">"You violated the rules."</a></li>
	  	</ul>
	  </div>
	  <!-- END is_forum_contributor -->
	  &nbsp;<br />
	  {S_TOPIC_ADMIN}
	  <!-- BEGIN is_moderator -->
	  <div style="margin: 0.5em; background: #e0e0ff; padding: 0.75em; display: none;" id="trash-and-warn">
		Warning message:
		<form action="{is_moderator.URL}" method="post" style="margin: 0; padding: 0;">
		<div>
			<textarea name="warning" cols="40" rows="6" style="width: 100%; border: solid 1px #cccccc;"></textarea>
			<div style="margin-bottom: 0.5em;"></div>
			<input type="submit" value="Lock &amp; Trash" style="font-weight: bold; margin-right: 0.5em;">
			<input type="button" value="Hide" onclick="document.getElementById('trash-and-warn').style.display = 'none'">
		</div>
		</form>
	  </div>
	  <!-- END is_moderator -->
	</td>
	<td align="right" valign="top" nowrap="nowrap">{JUMPBOX}<span class="gensmall">{S_AUTH_LIST}</span></td>
  </tr>
</table>

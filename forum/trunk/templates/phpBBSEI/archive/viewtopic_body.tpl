 <table width="100%" cellspacing="2" cellpadding="2" border="0"> 
  <tr> 
    <td align="left" valign="bottom" colspan="2"><a class="maintitle" href="{U_VIEW_TOPIC}">{TOPIC_TITLE}</a><br /> 
      <a class="gensmall" href="{O_VIEW_TOPIC}">Click here to go to the original topic</a><br />
      <span class="gensmall"><b>{PAGINATION}</b><br /> 
&nbsp; </span></td> 
  </tr> 
</table>
<table width="100%" cellspacing="2" cellpadding="2" border="0"> 
  <tr> 
    <td align="left" valign="bottom" nowrap="nowrap"><span class="nav">&nbsp;&nbsp;&nbsp;</span></td> 
    <td align="left" valign="middle" width="100%"><span class="nav">&nbsp;&nbsp;&nbsp;<a href="{U_INDEX}" class="nav">{L_INDEX}</a> -> <a href="{U_VIEW_FORUM}" class="nav">{FORUM_NAME}</a></span></td> 
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
    <td width="150" align="left" valign="top" class="{postrow.ROW_CLASS}"><span class="name"><a name="{postrow.U_POST_ID}"></a><b>{postrow.POSTER_NAME}</b></span><br /> 
      <span class="postdetails">{postrow.POSTER_RANK}<br /> 
      {postrow.RANK_IMAGE}{postrow.POSTER_AVATAR}<br /> 
      <br /> 
      {postrow.POSTER_JOINED}<br /> 
      {postrow.POSTER_POSTS}<br /> 
      {postrow.POSTER_FROM}</span><br /></td> 
    <td class="{postrow.ROW_CLASS}" width="100%" height="28" valign="top"><table width="100%" border="0" cellspacing="0" cellpadding="0"> 
        <tr> 
          <td width="100%"><span class="postdetails">{L_POSTED}: {postrow.POST_DATE}<span class="gen">&nbsp;</span>&nbsp; &nbsp;{L_POST_SUBJECT}: {postrow.POST_SUBJECT}</span></td> 
          <td valign="top" nowrap="nowrap">&nbsp;   </td> 
        </tr> 
        <tr> 
          <td colspan="2"><hr /></td> 
        </tr> 
        <tr> 
          <td colspan="2"><span class="postbody">{postrow.MESSAGE}{postrow.SIGNATURE}</span><span class="gensmall">{postrow.EDITED_MESSAGE}</span></td> 
        </tr> 
      </table></td> 
  </tr> 
  <tr> 
    <td class="{postrow.ROW_CLASS}" width="150" align="left" valign="middle"><span class="nav"><a href="#top" class="nav">{L_BACK_TO_TOP}</a></span></td> 
    <td class="{postrow.ROW_CLASS}" width="100%" height="28" valign="bottom" nowrap="nowrap">&nbsp;</td> 
  </tr> 
  <!-- END postrow --> 
  <tr align="center"> 
    <td class="catBottom" colspan="2" height="28">&nbsp;</td> 
  </tr> 
</table>
<table width="100%" cellspacing="2" cellpadding="2" border="0" align="center"> 
  <tr> 
    <td align="left" valign="middle" nowrap="nowrap"><span class="nav">&nbsp;&nbsp;&nbsp;</span></td> 
    <td align="left" valign="middle" width="100%"><span class="nav">&nbsp;&nbsp;&nbsp;<a href="{U_INDEX}" class="nav">{L_INDEX}</a> -> <a href="{U_VIEW_FORUM}" class="nav">{FORUM_NAME}</a></span></td> 
    <td align="right" valign="top" nowrap="nowrap"> <span class="nav">{PAGINATION}</span> </td> 
  </tr> 
  <tr> 
    <td align="left" colspan="3"><span class="nav">{PAGE_NUMBER}</span></td> 
  </tr> 
</table>
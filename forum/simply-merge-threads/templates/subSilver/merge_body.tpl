<form name="post" action="{S_ACTION}" method="post">
<table width="100%" cellspacing="2" cellpadding="2" border="0" align="center">
<tr> 
	<td align="left"><span class="nav"><a href="{U_INDEX}" class="nav">{L_INDEX}</a>{NAV_CAT_DESC}</span></td>
</tr>
</table>

<table border="0" cellpadding="3" cellspacing="1" width="100%" class="forumline">
<tr>
	<th colspan="2" height="25" valign="middle">{L_TITLE}</th>
</tr>
<tr>
	<td class="row1"><span class="gen">{L_TOPIC_TITLE}<br /></span><span class="gensmall">{L_TOPIC_TITLE_EXPLAIN}</span></td>
	<td class="row2">
		<span class="gen">
			<input type="text" class="post" name="topic_title" size="50" maxlength="60" value="{TOPIC_TITLE}" />
		</span>
	</td>
</tr>
<tr>
	<td class="row1" width="50%"><span class="gen">{L_FROM_TOPIC}<br /></span><span class="gensmall">{L_FROM_TOPIC_EXPLAIN}</span></td>
	<td class="row2" width="50%">
		<span class="gen">
			<input type="text" class="post" name="from_topic" size="50" maxlength="60" value="{FROM_TOPIC}" />
			<input type="submit" class="liteoption" name="select_from" value="{L_SEARCH}" />
		</span>
	</td>
</tr>
<tr>
	<td class="row1" width="50%"><span class="gen">{L_TO_TOPIC}<br /></span><span class="gensmall">{L_TO_TOPIC_EXPLAIN}</span></td>
	<td class="row2" width="50%">
		<span class="gen">
			<input type="text" class="post" name="to_topic" size="50" maxlength="60" value="{TO_TOPIC}" />
			<input type="submit" class="liteoption" name="select_to" value="{L_SEARCH}" />
		</span>
	</td>
</tr>
<tr>
	<td class="row1" width="50%"><span class="gen">{L_SHADOW}</span></td>
	<td class="row2" width="50%"><span class="gen"><input type="checkbox" name="shadow"{SHADOW} /></span></td>
</tr>
<tr>
	<td class="catBottom" colspan="2" align="center" height="28">
		<input type="submit" name="submit" value="{L_SUBMIT}" class="mainoption" />
		<input type="submit" name="refresh" value="{L_REFRESH}" class="liteoption" />
		{S_HIDDEN_FIELDS}
	</td>
</tr>
</table>
</form>
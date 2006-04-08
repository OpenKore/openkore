<script language="JavaScript"><!--
 function SetDays()	{ document.DaysFrm.submit() }
 // --></script>

<h1>{L_PRUNE_USERS}</h1>

<p>{L_PRUNE_USERS_EXPLAIN}</p>
<form name="DaysFrm" action="{S_PRUNE_USERS}" method="post">
<table cellspacing="1" cellpadding="4" border="0" align="center" class="forumline">

	<tr> 
		<td class="catBottom" align="center"><b>{L_DAYS}</b></td>
	      <td class="catBottom" align="center" nowrap><b>{L_PRUNE_ACTION}</b></td> 
		<td class="catBottom" align="center"><b>{L_PRUNE_LIST}</b></td>
	</tr>
<!-- BEGIN prune_list -->
	<tr> 
		<td class="row1" align="left">{prune_list.S_DAYS}</td>
		<td class="row2" align="left">({prune_list.USER_COUNT})<br/>{prune_list.U_PRUNE}<br/>{prune_list.L_PRUNE_EXPLAIN}</td>	
		<td class="row3" align="left">{prune_list.LIST}</td>
	</tr>
<!-- END prune_list -->
</table></form>


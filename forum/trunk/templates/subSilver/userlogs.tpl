<a href="index.php" class="nav"><b>Forum Index</b></a>

<style class="text/css">
td, .search {
	font-size: small;
}
.row1 {
	background: #eeeeee;
}
</style>

<form class="search" method="get" action="userlogs.php" style="margin-top: 1em;">
<div>
	<input type="hidden" name="sid" value="{SID}">
	<input type="text" name="search">
	<select name="type">
		<option>Username</option>
		<option>IP</option>
	</select>
	<input type="submit" value="Search" class="mainoption">
</div>
</form>

<h3>{STATUS}</h3>

<table class="forumline" width="85%">
<tr>
	<th>Username</th>
	<th>IP</th>
	<th>Last Visit</th>
</tr>
{DATA}
</table>
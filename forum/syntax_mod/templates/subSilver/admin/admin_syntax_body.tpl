<h1>{L_SYNTAX_TITLE}</h1>

<p>{L_SYNTAX_EXPLAIN}</p>

<p>{L_SYNTAX_MODE}</p>

<hr />
<h2>{L_MAIN_CONTROL}</h2>

<!-- BEGIN s_advanced_mode_enabled -->
{s_advanced_mode_enabled.L_MAIN_CONTROL_EXPLAIN}
<form action="{S_SYNTAX_ACTION}" method="post"><table cellspacing="1" cellpadding="4" border="0" align="center" class="forumline">
	<tr>
		<td class="row1"><input type="radio" name="enable_disable_syntax" value="2"{s_advanced_mode_enabled.SYNTAX_ENABLED_CHECKED}/> {s_advanced_mode_enabled.L_ENABLED}</td>
	</tr>
	<tr>
		<td class="row2"><input type="radio" name="enable_disable_syntax" value="1"{s_advanced_mode_enabled.SYNTAX_PARTIAL_CHECKED}/> {s_advanced_mode_enabled.L_PARTIAL}</td>
	</tr>
	<tr>
		<td class="row1"><input type="radio" name="enable_disable_syntax" value="0"{s_advanced_mode_enabled.SYNTAX_DISABLED_CHECKED}/> {s_advanced_mode_enabled.L_DISABLED}</td>
	</tr>
	<tr>
		<td class="catBottom" align="center"><input type="hidden" name="mode" value="overall_control" /><input type="submit" class="mainoption" name="syntax_enable_disable" value="{s_advanced_mode_enabled.L_UPDATE}" /></td>
	</tr>
</table></form>
<!-- END s_advanced_mode_enabled -->
<!-- BEGIN s_advanced_mode_disabled -->
<p>{s_advanced_mode_disabled.L_MAIN_CONTROL_DISABLED}</p>
<!-- END s_advanced_mode_disabled -->

<hr />
<h2>{L_LANGUAGE_CONTROL}</h2>

<!-- BEGIN s_advanced_mode_enabled -->
<p>{s_advanced_mode_enabled.L_LANGUAGE_CONTROL_EXPLAIN}</p>

<form action="{S_SYNTAX_ACTION}" method="post"><table cellspacing="1" cellpadding="4" border="0" align="center" class="forumline" width="90%">
	<tr>
		<th class="thHead" align="center" title="{s_advanced_mode_enabled.L_LANGUAGE_NAME_EXPLAIN}">{s_advanced_mode_enabled.L_LANGUAGE_NAME}</th>
		<th class="thHead" align="center" title="{s_advanced_mode_enabled.L_LANGUAGE_ENABLED_EXPLAIN}">{s_advanced_mode_enabled.L_LANGUAGE_ENABLED}</th>
		<th class="thHead" align="center" title="{s_advanced_mode_enabled.L_LANGUAGE_CODE_EXPLAIN}">{s_advanced_mode_enabled.L_LANGUAGE_CODE}</th>
		<th class="thHead" align="center" title="{s_advanced_mode_enabled.L_LANGUAGE_DISPLAY_NAME_EXPLAIN}">{s_advanced_mode_enabled.L_LANGUAGE_DISPLAY_NAME}</th>
	</tr>
	<!-- BEGIN language_file -->
	<tr>
		<td class="row1">{s_advanced_mode_enabled.language_file.LANGUAGE_NAME}</td>
		<td class="row2" align="center"><input type="checkbox" name="{s_advanced_mode_enabled.language_file.LANGUAGE_NAME}_enabled"{s_advanced_mode_enabled.language_file.LANGUAGE_ENABLED} /></td>
		<td class="row1"><input type="text" name="{s_advanced_mode_enabled.language_file.LANGUAGE_NAME}_code" size="15" value="{s_advanced_mode_enabled.language_file.LANGUAGE_CODE}" /></td>
		<td class="row2"><input type="text" name="{s_advanced_mode_enabled.language_file.LANGUAGE_NAME}_display" size="15" value="{s_advanced_mode_enabled.language_file.LANGUAGE_DISPLAY_NAME}" /></td>
	</tr>
	<!-- END language_file -->
	<tr>
		<td class="catBottom" colspan="4" align="center"><input type="hidden" name="mode" value="update_language_files" /><input type="submit" class="mainoption" value="{s_advanced_mode_enabled.L_UPDATE_LANGUAGE_OPTIONS}" />&nbsp; &nbsp;<input type="reset" class="liteoption" value="{s_advanced_mode_enabled.L_RESET_LANGUAGE_FORM}" /></td>
	</tr>
</table></form>
<!-- END s_advanced_mode_enabled -->

<!-- BEGIN s_advanced_mode_disabled -->
<p>{s_advanced_mode_disabled.L_LANGUAGE_CONTROL_EXPLAIN}</p>

<form action="{S_SYNTAX_ACTION}" method="post"><table cellspacing="1" cellpadding="4" border="0" align="center" class="forumline" width="70%">
	<tr>
		<th class="thHead" align="center">{s_advanced_mode_disabled.L_LANGUAGE_NAME}</th>
		<th class="thHead" align="center">{s_advanced_mode_disabled.L_LANGUAGE_ENABLED}</th>
	</tr>
	<!-- BEGIN language_file -->
	<tr>
		<td class="row1">{s_advanced_mode_disabled.language_file.LANGUAGE_NAME}</td>
		<td class="row2" align="center"><input type="checkbox" name="{s_advanced_mode_disabled.language_file.LANGUAGE_NAME}_enabled"{s_advanced_mode_disabled.language_file.LANGUAGE_ENABLED} /></td>
	</tr>
	<!-- END language_file -->
	<tr>
		<td class="catBottom" colspan="4" align="center"><input type="hidden" name="mode" value="update_language_files_simple" /><input type="submit" class="mainoption" value="{s_advanced_mode_disabled.L_UPDATE_LANGUAGE_OPTIONS}" />&nbsp; &nbsp;<input type="reset" class="liteoption" value="{s_advanced_mode_disabled.L_RESET_LANGUAGE_FORM}" /></td>
	</tr>
</table></form>
<!-- END s_advanced_mode_disabled -->

<hr />
<h2>{L_CACHE_CONTROL}</h2>

<!-- BEGIN s_advanced_mode_enabled -->
<form action="{S_SYNTAX_ACTION}" method="post"><table cellspacing="1" cellpadding="4" border="0" align="center" class="forumline">
	<tr>
		<td><input type="checkbox" name="enable_cache"{s_advanced_mode_enabled.CACHE_CHECKED_ENABLED} /> {s_advanced_mode_enabled.L_ENABLE_CACHE}</td>
	</tr>
	<tr>
		<td class="catBottom" align="center"><input type="hidden" name="mode" value="enable_disable_cache" /><input type="submit" class="mainoption" value="{s_advanced_mode_enabled.L_UPDATE_CACHE_ENABLED}" /></td>
	</tr>
</table></form>
<!-- END s_advanced_mode_enabled -->
<!-- BEGIN s_advanced_mode_disabled -->
<p>{s_advanced_mode_disabled.L_CACHE_CONTROL_DISABLED}</p>
<!-- END s_advanced_mode_disabled -->

<h3>{L_CLEAR_THE_CACHE}</h3>

<form action="{S_SYNTAX_ACTION}" method="post"><table cellspacing="1" cellpadding="4" border="0" align="center" class="forumline">
	<tr>
		<td><input type="checkbox" name="sure" /> {L_CLEAR_CACHE_YES_NO}</td>
	</tr>
	<tr>
		<td class="catBottom" align="center"><input type="hidden" name="mode" value="clear_cache" /><input type="submit" class="mainoption" value="{L_CLEAR_CACHE}" /></td>
	</tr>
</table></form>

<h3>{L_CACHE_OPTIONS}</h3>
<!-- BEGIN s_advanced_mode_enabled -->
<form action="{S_SYNTAX_ACTION}" method="post"><table cellspacing="1" cellpadding="4" border="0" align="center" class="forumline">
	<tr>
		<td width="35%"><input type="text" name="cache_dir_size" value="{s_advanced_mode_enabled.CACHE_DIR_SIZE}" size="15" /> <select name="cache_dir_size_units">
			<option value="B" selected="selected">{s_advanced_mode_enabled.L_BYTES}</option>
			<option value="K">{s_advanced_mode_enabled.L_KILOBYTES}</option>
			<option value="M">{s_advanced_mode_enabled.L_MEGABYTES}</option>
			<option value="G">{s_advanced_mode_enabled.L_GIGABYTES}</option>
		</select></td><td>{s_advanced_mode_enabled.L_CACHE_DIR_SIZE}</td>
	</tr>
	<tr>
		<td width="35%"><input type="text" name="cache_expiry_time" value="{s_advanced_mode_enabled.CACHE_EXPIRY_TIME}" size="15" /> <select name="cache_expiry_time_units">
			<option value="S" selected="selected">{s_advanced_mode_enabled.L_SECONDS}</option>
			<option value="M">{s_advanced_mode_enabled.L_MINUTES}</option>
			<option value="H">{s_advanced_mode_enabled.L_HOURS}</option>
			<option value="D">{s_advanced_mode_enabled.L_DAYS}</option>
			<option value="M">{s_advanced_mode_enabled.L_MONTHS}</option>
			<option value="Y">{s_advanced_mode_enabled.L_YEARS}</option>
		</select></td><td>{s_advanced_mode_enabled.L_CACHE_EXPIRY_TIME}</td>
	</tr>
	<tr>
		<td class="catBottom" align="center" colspan="2"><input type="hidden" name="mode" value="cache_options" /><input type="submit" class="mainoption" value="{s_advanced_mode_enabled.L_SET_CACHE_OPTIONS}" /></td>
	</tr>
</table></form>
<!-- END s_advanced_mode_enabled -->
<!-- BEGIN s_advanced_mode_disabled -->
<p>{s_advanced_mode_disabled.L_CACHE_OPTIONS_DISABLED}</p>
<!-- END s_advanced_mode_disabled -->

<hr />

<h3>{L_GENERAL_OPTIONS}</h3>

<!-- BEGIN s_advanced_mode_enabled -->
<form method="post" action="{S_SYNTAX_ACTION}"><table cellspacing="1" cellpadding="4" border="0" align="center" class="forumline">
	<tr>
		<td><input type="checkbox" name="enable_line_numbers"{s_advanced_mode_enabled.LINE_NUMBERS_ENABLED} /> {s_advanced_mode_enabled.L_LINE_NUMBERS_ENABLED}</td>
	</tr>
	<tr>
		<td><input type="checkbox" name="enable_function_urls"{s_advanced_mode_enabled.FUNCTION_URLS_ENABLED} /> {s_advanced_mode_enabled.L_FUNCTION_URLS_ENABLED}</td>
	</tr>
	<tr>
		<td class="catBottom" align="center"><input type="hidden" name="mode" value="general_options" /><input type="submit" class="mainoption" value="{s_advanced_mode_enabled.L_CHANGE_GENERAL_OPTIONS}" /></td>
	</tr>
</table></form>
<!-- END s_advanced_mode_enabled -->
<!-- BEGIN s_advanced_mode_disabled -->
<p>{s_advanced_mode_disabled.L_GENERAL_OPTIONS_DISABLED}</p>
<!-- END s_advanced_mode_disabled -->

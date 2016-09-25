<?php include "../common/header.tpl.php"; ?>
<?php
$h_name = htmlspecialchars(var_export($name, true));
$h_value = htmlspecialchars($value);
?>
<form method="post" action="">
	<fieldset>
		<legend><?php echo sprintf(_T("Editing Variable %s"), $h_name); ?></legend>
		<textarea name="value" style="width: 100%; height: 200px; overflow-y: auto" <?php echo $editable ? "" : "disabled=disabled"; ?>><?php echo $h_value; ?></textarea><br>
		<input type="submit" <?php echo $editable ? "" : "disabled=disabled"; ?>>
		<?php
		if (!$editable) {
			echo sprintf(_T("Set %s in config to enable"), "\$config['enable_eval'] = true");
		}
		?>
	</fieldset>
</form>
<?php include "../common/footer.tpl.php"; ?>

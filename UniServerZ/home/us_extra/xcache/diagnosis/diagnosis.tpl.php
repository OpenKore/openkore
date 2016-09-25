<?php include "../common/header.tpl.php"; ?>
<table cellspacing="0" cellpadding="4" class="cycles" id="diagnosisResult">
	<caption>
		<?php echo _T("Diagnosis Result"); ?>
	</caption>
	<tr>
		<th>
			<?php echo _T("Item"); ?>
		</th>
		<th>
			<?php echo _T("Level"); ?>
		</th>
		<th>
			<?php echo _T("Result"); ?>
		</th>
		<th>
			<?php echo _T("Explanation/Suggestion"); ?>
		</th>
	</tr>
<?php foreach ($notes as $note) { ?>
	<tr class="<?php echo $note['type']; ?>">
		<td nowrap="nowrap" align="right"><?php echo $note['item']; ?></td>
		<td nowrap="nowrap"><?php echo ucfirst(__($note['type'])); ?></td>
		<td nowrap="nowrap"><?php echo nl2br($note['result']); ?></td>
		<td><?php echo nl2br($note['suggestion']); ?></td>
	</tr>
<?php } ?>
</table>
<?php include "../common/footer.tpl.php"; ?>

<?php $cycleClass = new Cycle('class="col1"', 'class="col2"'); ?>
<form action="" method="post">
	<table cellspacing="0" cellpadding="4" class="cycles entries">
		<caption><?php echo $caption; ?></caption>
<?php

echo <<<TR
		<tr>

TR;

if ($isphp) {
	echo
		th(N_("entry.id"))
		;
}
else {
	echo
		th(N_("entry.remove"))
		;
}

echo
	th(N_("entry.name"))
	, th(N_("entry.hits"))
	, th(N_("entry.size"))
	;

if ($isphp) {
	echo
		th(N_("entry.refcount"))
		, th(N_("entry.phprefcount"))
		, th(N_("entry.class_cnt"))
		, th(N_("entry.function_cnt"))
		, th(N_("entry.file_size"))
		, th(N_("entry.file_mtime"))
		;
	echo
		th(N_("entry.file_device"))
		, th(N_("entry.file_inode"))
		;
}
echo
	th(N_("entry.hash"))
	, th(N_("entry.atime"))
	, th(N_("entry.ctime"))
	;

if ($listName == 'Deleted') {
	echo
		th(N_("entry.delete"))
		;
}
?>
		</tr>
<?php
foreach ($entries as $i => $entry) {
	$class = $cycleClass->next();
	echo <<<TR
		<tr $class>

TR;
	$hits     = number_format($entry['hits']);
	$size     = size($entry['size']);
	if ($isphp) {
		$class_cnt    = number_format($entry['class_cnt']);
		$function_cnt = number_format($entry['function_cnt']);
		$phprefcount  = number_format($entry['phprefcount']);
		$file_size    = size($entry['file_size']);
	}

	if ($isphp) {
		$file_mtime = age($entry['file_mtime']);
	}
	$ctime = age($entry['ctime']);
	$atime = age($entry['atime']);
	if ($listName == 'Deleted') {
		$dtime = age($entry['dtime']);
	}

	if ($isphp) {
		$hname = htmlspecialchars($entry['name']);
		$namelink = $hname;
		echo <<<ENTRY
			<td>{$entry['cache_name']} {$i}</td>

ENTRY;
	}
	else {
		$name = $entry['name'];
		if (!empty($config['enable_eval'])) {
			$name = var_export($name, true);
		}
		$uname = urlencode($name);
		$hname = htmlspecialchars(str_replace("\0", "\\0", $entry['name']));
		echo <<<ENTRY
			<td><label><input type="checkbox" name="remove[]" value="{$hname}"/>{$entry['cache_name']} {$i}</label></td>

ENTRY;
		$namelink = "<a href=\"edit.php?name=$uname\">$hname</a>";
	}

	echo <<<ENTRY
			<td>{$namelink}</td>
			<td align="right" int="{$entry['hits']}">{$entry['hits']}</td>
			<td align="right" int="{$entry['size']}">{$size}</td>

ENTRY;
	if ($isphp) {
		$refcount = number_format($entry['refcount']);
		echo <<<ENTRY
			<td align="right" int="{$entry['refcount']}">{$entry['refcount']}</td>
			<td align="right" int="{$entry['phprefcount']}">{$phprefcount}</td>
			<td align="right" int="{$entry['class_cnt']}">{$class_cnt}</td>
			<td align="right" int="{$entry['function_cnt']}">{$function_cnt}</td>
			<td align="right" int="{$entry['file_size']}">{$file_size}</td>
			<td align="right" int="{$entry['file_mtime']}">{$file_mtime}</td>

ENTRY;
		if (isset($entry['file_inode'])) {
			echo <<<ENTRY
			<td align="right" int="{$entry['file_device']}">{$entry['file_device']}</td>
			<td align="right" int="{$entry['file_inode']}">{$entry['file_inode']}</td>

ENTRY;
		}
	}
	echo <<<ENTRY
			<td align="right" int="{$entry['hvalue']}">{$entry['hvalue']}</td>
			<td align="right" int="{$entry['atime']}">{$atime}</td>
			<td align="right" int="{$entry['ctime']}">{$ctime}</td>

ENTRY;
	if ($listName == 'Deleted') {
		echo <<<ENTRY
			<td align="right" int="{$entry['dtime']}">{$dtime}</td>

ENTRY;
	}

	echo <<<TR
		</tr>

TR;
}
?>
	</table>
<?php if (!$isphp && $listName != 'Deleted') { ?>
	<input type="submit" value="<?php echo _T("Remove Selected"); ?>">
<?php } ?>
</form>
<?php
unset($cycleClass);
?>

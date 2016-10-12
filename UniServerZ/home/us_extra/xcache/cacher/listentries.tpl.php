<?php include "../common/header.tpl.php"; ?>
<div class="switcher"><?php echo switcher("do", $doTypes); ?></div>
<?php include "./sub/summary.tpl.php"; ?>
<?php
$entryList = getEntryList();
$isphp = $entryList['type'] == XC_TYPE_PHP;
ob_start($config['path_nicer']);

$listName = 'Cached';
$entries = $entryList['cache_list'];
$caption = $isphp ? _T("php Cached") : _T("var Cached");
include "./sub/entrylist.tpl.php";

$listName = 'Deleted';
$caption = $isphp ? _T("php Deleted") : _T("var Deleted");
$entries = $entryList['deleted_list'];
include "./sub/entrylist.tpl.php";

ob_end_flush();
unset($isphp);
?>
<?php include "../common/footer.tpl.php"; ?>

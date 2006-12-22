<?php
if (empty($_GET['q'])) {
	require_once('includes/phpbb.php');
	PhpBB::init(array('template' => true, 'title' => 'Search forum'));
	$template->set_filenames(array('body' => 'newsearch.tpl'));
	$template->pparse('body');
	PhpBB::finalize();
} else {
	header("Location: http://search.yahoo.com/search?p=site%3Aopenkore.com+" . urlencode($_GET['q']));
}
?>
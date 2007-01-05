<?php
if (empty($_GET['q'])) {
	require_once('includes/phpbb.php');
	PhpBB::init(array('template' => true, 'title' => 'Search forum'));
	$template->set_filenames(array('body' => 'newsearch.tpl'));
	$template->pparse('body');
	PhpBB::finalize();
} else {
	header("Location: http://www.google.com/search?as_q=" . urlencode($_GET['q']) . "&hl=en&hs=nsk&num=10&btnG=Google+Search&as_epq=&as_oq=&as_eq=&lr=&as_ft=i&as_filetype=&as_qdr=all&as_nlo=&as_nhi=&as_occt=any&as_dt=i&as_sitesearch=openkore.com&as_rights=&safe=off");
}
?>

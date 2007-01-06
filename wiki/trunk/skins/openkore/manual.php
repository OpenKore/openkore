<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html>
	<meta http-equiv="content-type" CONTENT="text/html; charset=UTF-8">
	<meta http-equiv="content-style-type" content="text/css">
	<?php $this->html('headlinks') ?>
	<title><?php $this->html('pagetitle') ?></title>
	<link href="<?php $this->text('stylepath') ?>/<?php $this->text('stylename') ?>/main.css" rel="stylesheet" type="text/css">
	<link href="<?php $this->text('stylepath') ?>/<?php $this->text('stylename') ?>/manual.css" rel="stylesheet" type="text/css">
	<link href="/include/openkore-body.css" media="screen" rel="stylesheet" type="text/css">
	<link href="/include/independent.css" media="screen" rel="stylesheet" type="text/css">
	<script type="<?php $this->text('jsmimetype') ?>" src="<?php $this->text('stylepath' ) ?>/common/wikibits.js"></script>

	<!-- Fix broken PNG transparency and CSS support for IE/Win5-6+ -->
	<!--[if gte IE 5.5000]>
	<script type="text/javascript" src="/include/pngfix.js"></script>
	<link href="/include/iefixes.css" media="screen" rel="stylesheet" type="text/css">
	<![endif]-->
</head>

<body>

<div class="body">
	<h1><?php $this->text('title') ?></h1>
	<div class="para">
		<!-- start content -->
		<?php
		$this->html('bodytext');
		?>
		<!-- end content -->
	</div>

	<!-- Start of StatCounter Code -->
	<script type="text/javascript" language="javascript">
	<!-- 
	var sc_project=1188444; 
	var sc_invisible=1; 
	var sc_partition=10; 
	var sc_security="f6c0ca54"; 
	var sc_remove_link=1; 
	//-->
	</script>

	<script type="text/javascript" language="javascript" src="http://www.statcounter.com/counter/counter.js"></script>
	<noscript><div><img src="http://c11.statcounter.com/counter.php?sc_project=1188444&amp;amp;java=0&amp;amp;security=f6c0ca54&amp;amp;invisible=1" alt="free web page counters"></div></noscript>
	<!-- End of StatCounter Code -->
</div>

</body>
</html>
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
	<meta http-equiv="content-type" CONTENT="text/html; charset=UTF-8">
	<?php if ($this->isPrivate()) { ?>
	<meta name="robots" content="noindex">
	<?php } ?>
	<meta http-equiv="content-style-type" content="text/css">
	<?php $this->html('headlinks') ?>
	<title><?php $this->html('pagetitle') ?></title>
	<link href="<?php $this->text('stylepath') ?>/<?php $this->text('stylename') ?>/main.css" rel="stylesheet" type="text/css">
	<link href="/include/common.css" media="screen" rel="stylesheet" type="text/css">
	<link href="/include/statcounter.css" media="screen" rel="stylesheet" type="text/css">
	<link href="/include/openkore-topbar.css" media="screen" rel="stylesheet" type="text/css">
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

<?php include('/home/openkore/web/include/noie.php'); ?>

<div id="openkore_topbar">
	<div id="openkore_logo">
		<a href="/"><img src="/images/logo-with-gradient.jpg" width="300" height="88" alt="The OpenKore Project"></a>
	</div>

	<div id="openkore_navigation">
		<ul>
		<?php include('../include/navigation.php'); ?>
		</ul>
	</div>

	<?php
	if (!$no_donation) {
	?>

	<div id="openkore_donation">
		<?php
		require('/home/openkore/resources/paypal.php');
		printPaypalButton("Support OpenKore:<br>");
		?>
	</div>
	<?php } ?>

</div>

<div align="center">
	<?php include($_SERVER['DOCUMENT_ROOT']."/include/banner.html") ?>
</div>

<div class="body">

	<h1><?php $this->text('title') ?></h1>
	<div class="para">
		<!-- start content -->
		<?php $this->html('bodytext') ?>
		<!-- end content -->
	</div>

	<hr>

	<div id="wikifooter">
		<ul>
		<?php if($this->data['lastmod'   ]) { ?><li id="f-lastmod"><?php    $this->html('lastmod')    ?></li><?php } ?>
		<?php if($this->data['viewcount' ]) { ?><li id="f-viewcount"><?php  $this->html('viewcount')  ?></li><?php } ?>
		<?php if($this->data['numberofwatchingusers' ]) { ?><li id="f-numberofwatchingusers"><?php  $this->html('numberofwatchingusers') ?></li><?php } ?>
		<?php if($this->data['credits'   ]) { ?><li id="f-credits"><?php    $this->html('credits')    ?></li><?php } ?>
		<?php if($this->data['copyright' ]) { ?><li id="f-copyright"><?php  $this->html('copyright')  ?></li><?php } ?>
		<?php if($this->data['tagline']) { ?><li id="f-tagline"><?php echo $this->data['tagline'] ?></li><?php } ?>
		<li id="statcounter">
			<!-- Start of StatCounter Code -->
			<script type="text/javascript">
			var sc_project=1188444; 
			var sc_invisible=1; 
			var sc_partition=10; 
			var sc_security="f6c0ca54"; 
			</script>
			
			<script type="text/javascript" src="http://www.statcounter.com/counter/counter.js"></script>
			<noscript><div><a href="http://www.statcounter.com/" target="_blank"><img src="http://c11.statcounter.com/counter.php?sc_project=1188444&amp;amp;java=0&amp;amp;security=f6c0ca54&amp;amp;invisible=1" alt="advanced web statistics"></a></div></noscript>
			<!-- End of StatCounter Code --><a href="http://my.statcounter.com/project/standard/stats.php?project_id=1188444&amp;guest=1">View My Stats</a>
		</li>
		</ul>
	</div>

	<div id="wikiactions">
		<div style="float: right;">
		<?php include('../include/sidelinks.php'); ?>
		</div>

		<ul class="wikiactions_group">
		<?php
			$tab = "";
			foreach ($this->data['content_actions'] as $key => $action) {
				if ($action['text'] == "Discussion")
					continue;
				printf('%s<li id="ca-%s"', $tab, htmlspecialchars($key));
				if ($action['class'])
					printf(' class="%s"', htmlspecialchars($action['class']));
				echo '>';
	
				printf('<a href="%s">', htmlspecialchars($action['href']));
				echo htmlspecialchars($action['text']);
				echo "</a></li>\n";
	
				$tab = "	";
			}
		?>
		</ul>

		<ul class="wikiactions_group">
			<li><a href="/wiki/index.php/Special:Recentchanges">Recent changes</a></li>
			<li><a href="/wiki/index.php/Special:Specialpages">Special pages</a></li>
			<li><a href="/wiki/index.php/How_to_translate_Wiki_pages">Translation guide</a></li>
		</ul>

		<ul class="wikiactions_group">
		<?php
			$tab = "";
			foreach ($this->data['personal_urls'] as $key => $item) {
				if ($key == "mytalk" || $key == "preferences") {
					continue;
				}

				if ($key == "userpage") {
					printf('%s%s%s', $tab, htmlspecialchars($item['text']), "\n");
				} else {
					printf('%s<li id="pt-%s"><a href="%s"%s>%s</a></li>%s',
						$tab,
						htmlspecialchars($key),
						htmlspecialchars($item['href']),
						empty($item['class']) ? '' : $item['class'],
						htmlspecialchars($item['text']),
						"\n");
				}
				$tab = "		";
			}
		?>
		<li>
			<form action="<?php $this->text('searchaction') ?>" id="searchform">
			<div>
				<?php
				$value = isset($this->data['search']) ? ' value="' . $this->text('search') . '"' : "";
				printf('<input id="searchInput" name="search" type="text"%s>%s', $value, "\n");
				?>
				<input type="submit" name="go" class="searchButton" id="searchGoButton"	value="<?php $this->msg('go') ?>">
				<input type='submit' name="fulltext" class="searchButton" value="<?php $this->msg('search') ?>">
			</div>
			</form>
		</li>
		</ul>
	</div>
</div>

</body>
</html>

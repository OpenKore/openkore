<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
	<title>OpenKore CVS Guide</title>
	<link rel="stylesheet" type="text/css" href="../../openkore.css">
	<link rel="stylesheet" type="text/css" href="../../links.css">
	<!-- Fix broken PNG transparency for IE/Win5-6+ -->
	<!--[if gte IE 5.5000]>
	<script type="text/javascript" src="pngfix.js"></script>
	<![endif]-->
</head>

<body>

<div id="title">OpenKore CVS Guide for users</div>

<div id="navigation">
	<ul>
	<li><a href="http://openkore.sourceforge.net/">Main website</a></li>
	<li><a href="../../index.html">Table of contents</a></li>
	<li><a href="../index.html">Development Introduction Guide</a></li>
	<li><b>CVS Guide</b></li>
	</ul>
</div>

<div id="main">


<h2>Step 1: Preparations</h2>

<?php include('preparations.txt'); ?>


<h2>Step 2: Determine what you want to download</h2>

<?php include('modules.txt'); ?>


<h2>Step 3: Download (checkout) a module from CVS</h2>

<?php include('download.txt'); ?>


<h2>Step 4: Regularly update the module</h2>

<img src="update.png" width="197" height="104" alt="Menu for CVS update" style="float: right;">
You should regularly <em>update</em> the module. This means telling TortoiseCVS to download
the latest stuff from CVS. TortoiseCVS will only download the things that have changed, so it saves bandwidth.

<p>
Rightclick on an empty spot in the module's folder and choose <em>"CVS Update"</em>. That's all.
<br style="clear: right;">


<h2>So what now?</h2>

Now you have the source code, and know how to keep it up-to-date. But how do you run OpenKore?
See <a href="run.html">Running OpenKore from source code</a>.


</div>
</body>
</html>

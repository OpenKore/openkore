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

<div id="title">OpenKore CVS Guide for developers</div>

<div id="navigation">
	<ul>
	<li><a href="http://openkore.sourceforge.net/">Main website</a></li>
	<li><a href="../../index.html">Table of contents</a></li>
	<li><a href="../index.html">Development Introduction Guide</a></li>
	<li><b>CVS Guide</b></li>
	</ul>
</div>

<div id="main">


<h2>The big picture</h2>

If you'd like to work on OpenKore's code, you shouldn't just take the latest public release and modify
that. Instead, you should get the code from CVS and work on that instead.

<p>
Basically, this is what you're supposed to do:
<ol>
<li>Download (checkout) a module from CVS.</li>
<li>Modify the source code.</li>
<li>Merge your changes with the latest changes in CVS (if necessary).</li>
<li>Make a <em>patch</em> and submit it to the forums.</li>
</ol>

Each step will be explained in detail.


<h2>Preparations</h2>

<?php include('preparations.txt'); ?>


<h2>Determine what you want to download</h2>

<?php include('modules.txt'); ?>


<h2>1. Download (checkout) a module from CVS</h2>

<?php include('download.txt'); ?>


<h2>2. Modify the source code</h2>

This step is up to you. ;)


<h2>3. Merge your changes with the latest changes in CVS</h2>

<?php include('merge.txt'); ?>


<h2>4. Make a patch and submit it to the forums</h2>

A patch is a text file that contains the changes you've made. Select all the files
that you want to make a patch for (or select nothing if you want to make a patch of all
files that you have modified).
Rightclick and choose <em>"CVS Diff..."</em> or <em>"CVS-&gt;Make patch"</em>.

<p>
TortoiseCVS will ask you where to save the patch file. Make sure you save it with the <em>.patch</em> or <em>.diff</em> extension.

<p>
After having saved the patch file, go to the forums, section Developers Corner. Make a new topic. There are two ways to post your source code:
<ul>
<li>Copy & paste your code from Notepad to the web browser. Put the source code between [CODE] UBB tags (recommended way).</li>
<li>Add your patch file as attachment.</li>
</ul>


If you're a good contributor you may get CVS write access. This means you'll be able to directly upload changes to CVS, without posting patches to the forum.


<h2>Further documentation</h2>

<ul>
<li><a href="conflicts.html">How to resolve merging conflicts</a></li>
<li>Full CVS manual: <a href="http://www.gnu.org/software/cvs/manual/html_chapter/cvs_toc.html">http://www.gnu.org/software/cvs/manual/html_chapter/cvs_toc.html</a></li>
</ul>


</div>
</body>
</html>

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
<li>Upload (commit) your changes from CVS.</li>
</ol>

Each step will be explained in detail.


<h2>Preparations</h2>

<?php include('preparations.txt'); ?>


<h2>Determine what you want to download</h2>

<?php include('modules.txt'); ?>


<h2>1. Download (checkout) a module from CVS</h2>

<img src="checkout.png" style="float: right;" width="197" height="75" alt="Menu for CVS checkout">
Go to the folder in which you want to put the source code.
Rightclick on an empty spot in the folder, and click on <em>"CVS Checkout..."</em>.
A dialog will appear. Fill in this for the <em>"CVSROOT"</em> field:

<blockquote>
<tt>:ext:developername@cvs.sourceforge.net:/cvsroot/openkore</tt>
</blockquote>

(Replace <em>"developername"</em> with your own SourceForge account name.)

<p>
For the <em>"Module"</em> field, enter a module name (see the the previous paragraph for a list of modules).
When you're done, click on <em>OK</em>. TortoiseCVS will now download the code; the result will appear in a subfolder
with the same name of the module.


<h2>2. Modify the source code</h2>

This step is up to you. ;)


<h2>3. Merge your changes with the latest changes in CVS</h2>

<?php include('merge.txt'); ?>


<h2>4. Upload (commit) your changes to CVS</h2>

<a href="commit.png"><img src="commit_small.png" style="float: right;" width="118" height="150" alt="CVS Commit dialog"></a>
Your changes will not be in the CVS repository until you commit them.

<p>
Rightclick on an empty spot in your module folder and choose <em>"CVS Commit..."</em>. A dialog will pop up. In this dialog, you can:
<ul>
<li>Select the files you want to commit.</li>
<li>Enter a comment about what you have changed in this commit. This comment should be a short, brief, one-line description.</li>
</ul>


<h2>Adding files to CVS</h2>

You can add all kinds of other files and folders to the module folder (for example, adding the control and tables folders). If you do a commit those new files will not be uploaded to CVS. So you don't have to worry about accidentally committing your config.txt (with your username and password in it) to CVS.

<p>
If you want to add a specific file to CVS, you have to mark it for adding first. Rightclick on it
and choose <em>"CVS Add..."</em>. The file isn't in CVS yet! You've only marked the file. The file
will really be committed to CVS when you do a CVS commit.

<p>
<b>Note:</b> there are two kinds of CVS files: text and binary. If you're uploading source code or
text files (.txt, .pl, .cpp, etc; everything that you can read in Notepad), you should mark the file
as <em>"Text/ASCII"</em> in the <em>"TortoiseCVS - Add"</em> dialog. If it's a binary file (for example, images),
change it to <em>"Binary"</em>.


<h2>Further documentation</h2>

<ul>
<li><a href="conflicts.html">How to resolve merging conflicts</a></li>
<li>Full CVS manual: <a href="http://www.gnu.org/software/cvs/manual/html_chapter/cvs_toc.html">http://www.gnu.org/software/cvs/manual/html_chapter/cvs_toc.html</a></li>
</ul>


</div>
</body>
</html>

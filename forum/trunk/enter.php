<?php
	if ($_GET['reading'] != "1") {
		if ($_COOKIE['openkore_forum_read_rules'] == "1") {
			$agree = 1;

		} elseif ($_GET['agree'] == "yes") {
			setcookie("openkore_forum_read_rules", 1, time() + 99999999);
			$agree = 1;
		}

		if ($agree) {
			if (isset($_GET['redirect']))
				header("Location: $_GET[redirect]");
			else if (isset($_GET['t']))
				header("Location: /viewtopic.php?t=$_GET[t]");
			else
				header("Location: /");
			exit;
		}
	}
?>

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<html>
<head>
	<meta http-equiv="content-type" CONTENT="text/html; charset=UTF-8">
	<meta http-equiv="content-style-type" content="text/css">
	<title>Forum rules</title>
	<link href="http://openkore.sourceforge.net/misc/default.css" media="screen" rel="stylesheet" type="text/css">

	<!-- Fix broken PNG transparency for IE/Win5-6+ -->
	<!--[if gte IE 5.5000]>
	<script type="text/javascript" src="http://openkore.sourceforge.net/misc/pngfix.js"></script>
	<![endif]-->

	<style type="text/css">
	<!--
	ol li {
		margin-bottom: 0.2cm;
	}
	-->
	</style>
</head>

<body class="rules">

<h1>Before you do anything else...</h1>
<div class="content"><p>

<div class="note">
	<img src="http://openkore.sourceforge.net/images/stop.png" width="48" height="48" alt="Read this!">
	<h2><a href="http://openkore.sourceforge.net/docs.php">Did you read the documentation?</a></h2>
	We've spend quite a lot of time writing documentation.
	Before you ask a question at the forums, <b>please</b> read the manual first.
</div>
</div>

<h1>Forum Rules &amp; Regulations</h1>
<div class="content"><p>

<ul style="color: red; font-weight: bold;">
<li>Read these rules carefully, or you won't be able to continue! Read everything, line-by-line, and don't skim or skip. If you do this, it's guaranteed to work.</li>
<li> Before posting a problem in the forums, please do read the manual. You can always get answers from the manual.
	It contains answers to many common problems.</li>
<li>Use the "search" button. It is always your friend here. It will bring you to "wonderland" where you can find
	all your answers and additional information.</li>
</ul>

The rules are split into 2 levels.

<h2>Level 1:</h2>
<ol>
<li>No flame throwing. Yes, flaming is fun but it can be very bad. I always believe "one hand cannot clap, but 2
	hands can clap as loud as you can". Whenever someone starts to flame, please ignore him/her and report to
	any Admins/Mods. We will warn him/her. If you do not ignore and join in the battle, you are considered as
	the "other hand" which now "2 hands can clap louder". Both of you are going to get a warning from
	administrators/moderators.</li>
<li>Do not insult people who contribute time to bring OpenKore forums up to let you enjoy botting. If you are new,
	do not try to be a smartass. Everyone here is willing to help you. Ask in a good manner. If somehow they
	gave you false information, please respond in a proper way. Do not start cursing or insulting; instead,
	rethink it yourself whether or not you are making your point clear for people to understand.</li>
<li>OpenKore is an English bot. So we expect users to speak/type in English. Please do not speak/type in foreign
	languages that confuse other users. You will always be welcomed and receive help if you speak with proper manner.<br>
      <b>3.1)</b> If you cannot speak/type English properly, look for special threads that support your native language.
      Do not simply abuse it.</li>
<li>Do not ask for KS function. We do not support KSers here. We are quite sensitive to this topic. You will get warned immediately.</li>
<li>Use descriptive subjects for your topics. Do not post silly wording nor unrelevant topic to your post. For example, "|-|3lp |\/|3" or "Must Read!" as the subject, then content is "can you please help me this, help me that."</li>
<li>Do not spam. We are getting enough spam already. If you have an issue with another user, just simply pm and start your conversation. Do not use a post to make conversation. For example, User A: "Hi B, I saw you in prontera.". User B:"I saw you too. Let's meet again tonight.". Both users will be warned.</li>
<li>Do not double post. If you did it accidentally because of bad connections, delete the last one using the 'X' or 'edit' button.</li>
<li>This is an OpenKore forum, not ModKore, Revemu, KoreEasy, or other Kore. So do not ask about how to use other bots. Of course, you can still recommend or add a feature from other bots to OpenKore.</li>
<li>Do not cross post. Post in the right forum. For example, do not ask about where to level on the Developers' Corner. Have you ever noticed there is always a small descriptive information about what the forums are about?</li>
<li>No porn allowed in your post, avatar, or signature. Remember, this site may also be accessed by persons under-age.</li>
<li>You cannot post or release any information or screenshots of other users without their permissions. This includes character names, account info, email address, etc. Please respect others' privacy.</li>
<li>Read the Frequenly Asked Questions subforum before posting anything in the Support subforum.</li>
<li>To continue to the forum or the forum registration page, click on the little underscore (stripe) on the bottom right of the red box. Do not click on the agree or disagree links.</li>
<li>Do not post the entire configs, post only the section which could possibly be relevant to your problem. You wouldn't want people to ignore you just because you are straining their eyes.</li>
<li>Do not post your e-mail. We don't entertain people by sending config to their e-mail. If you get yourself tons of junk mail or viruses, don't blame us.</li>
</ol>

<h2>Level 2:</h2>
<ol>
<li>Do not insult adminstrators/moderators. Although administrators/moderators are not god, they are the most dedicated people around to help you. If you refuse, you shall know what is going to happen to you.</li>
<li>Have you heard of <a href="http://visualkore.aaanime.net/">VisualKore</a>? It is a licensed product. Do not distribute illegal copies! Please report if you found someone distributing it.</li>
<li>Do not ask for entire configurations. This proves that you are incapable of being an OpenKore user.</li>
<li>Do not attempt to hack the forum. You will be banned.</li>
</ol>

Splitting rules level will make it easy to manage and explain.

<h2>Sanctions</h2>
<ul>
<li>For level 1 offender, you will receive a warning on your first offense. Second offense, you will receive PROBATION as your title for 2 weeks. Third offense, <span class="hugee">permanent ban</span>.</li>
<li>For level 2 offender, you are not capable of being an OpenKore user. You deserve a <span class="hugee">permanent ban</span>.</li>
</ul>

Topics being Trashed or Locked will depend on how offensive the information is being discussed.
<p>
Posts being Deleted will depend on how offensive the information is being discussed.
<p>
<b>Notes:</b> OpenKore's forum currently is still open for bad words. Please do not abuse it. Using aggressively will result in offending rule level 1.
<p>
Administrators/moderators reserve the rights to amend any rules. Any amendments will take effect immediately.

<script language="javascript" type="text/javascript">
<!--
function agree()
{
	alert("YOU DIDN'T READ THE RULES!!!! You're NOT supposed to click this!");
	alert("Read the rules! Because if you don't, and you violate the rules, you will be BANNED!");
	alert("Do you have any idea how many hundreds of man hours have been wasted on people who violate the rules and keep asking the same thing over and over?");
	alert("The only way to figure out how to continue is by reading the rules!");
	for (i = 0; i < 10; i++) {
		alert("Read the entire page!!");
	}
}

function disagree()
{
	alert("You STILL didn't read the entire page! You're NOT supposed to click this!");
	alert("Read the entire page, line-by-line. Don't skim or skip anything; read carefully!");
	alert("Read it like a study book. You will be guaranteed to find out how to continue if you do this.");
}

function help()
{
	alert("To be able to continue, you must read the entire page - carefully! This means:\n" +
		"- Read the rules like a study book.\n" +
		"- Do not skip anything.\n" +
		"- Do not skim.\n" +
		"- Read every single line carefully.\n" +
		"Instructions about how to continue is on this page. If you didn't see those " +
		"instructions, then you didn't read carefully enough.\n\n" +
		"Here's a tip: read every line out loud. Yes I mean it, try it. If you do that, " +
		"then you are guaranteed to be able to find the instructions.");
}
// -->
</script>

<div style="margin-top: 3cm; border: 1px solid #ffaaaa; padding: 0.4cm; background: #ffdddd;">
<?php
$agree = 'enter.php?agree=yes';
$quiz = 'quiz.php';
if ($_SERVER['QUERY_STRING'] != '') {
	$agree .= "&" . $_SERVER['QUERY_STRING'];
	$quiz .= "?" . $_SERVER['QUERY_STRING'];
}

if ($_GET['vk']) {
	echo "<a href=\"$agree\">I agree with these terms</a>\n";
	echo "<br><br>\n";
	echo '<a href="http://www.google.com/">I disagree with these terms</a>' . "\n";

} else {
	//echo "<a href=\"$quiz\">I am not a newbie - skip the rules</a>\n";
	//echo "<br><br>\n";
	echo '<a href="javascript:agree();">I agree with these terms</a>' . "\n";
	echo "<br><br>\n";
	echo '<a href="javascript:disagree();">I disagree with these terms</a>' . "\n";
	echo "<br><br>\n";
	echo "<a href=\"javascript:help();\">Help</a>\n";
}
?>
</div>

<div align="right">
<?php
	echo '<a style="size: small; border: none;" href="' . $agree . '">_</a>';
?>
</div>

</body>
</html>

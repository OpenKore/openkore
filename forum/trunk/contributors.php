<?php
require_once('includes/phpbb.php');
PhpBB::init(array('template' => false, 'check_sid' => true));
require_once('includes/openkore.php');

validate();
$topic = new Topic($_GET['t']);
$task = $_GET['task'];
authenticate($topic);

switch ($task) {
case 'to_support':
	$forum_id = PhpBB::findForumId(OConstants::SUPPORT_FORUM_NAME);
	if (is_null($forum_id)) {
		message_die(GENERAL_ERROR, "Cannot find forum ID for '" . OConstants::SUPPORT_FORUM_NAME . "'.");
	}
	$msg = "[b][color=Olive]Dear user,\n\n" .
		"You have posted your message in the wrong forum section. Your message is a support request. " .
		"That is why it should have been posted in the section " .
		"[url=http://forums.openkore.com/viewforum.php?f=$forum_id]'" . OConstants::SUPPORT_FORUM_NAME . "'[/url].\n" .
		"Please remember to post in the correct forum section next time. That will keep our forum " .
		"clean, for the sake of all users.\n\n" .
		"Thank you for your understanding,\n" .
		"[i]- The OpenKore community[/i][/color][/b]";

	$topic->moveTopic($forum_id);
	$post_id = $topic->addReply($msg);
	header("Location: viewtopic.php?p=$post_id#$post_id");
	break;

case 'rtfm':
	$msg = "[b][color=Olive]Dear user,\n\n" .
		"Your answer to your problem can be found in the " .
		"[url=http://www.openkore.com/wiki/index.php/Support]documentation[/url] " .
		"or the [url=http://forums.openkore.com/viewforum.php?f=16]FAQ forum[/url].\n";
	if (!empty($_GET['hint'])) {
		$msg .= "Here is a hint: [i]" . $_GET['hint'] . "[/i]\n";
	}
	$msg .= "\n" .
		"We spent [i]a lot[/i] of time on writing documentation, for the sake of our users. " .
		"Many questions are already answered in our documentation and FAQ. " .
		"Please do not let our effort be in waste, and please read the documentation/FAQ " .
		"before asking a question on this forum.\n\n" .
		"Thank you for your understanding,\n" .
		"[i]- The OpenKore community[/i][/color][/b]";
	$post_id = $topic->addReply($msg);
	$topic->lockTopic();
	header("Location: viewtopic.php?p=$post_id#$post_id");
	break;

case 'violation':
	$trash_forum = PhpBB::findForumId(OConstants::TRASH_FORUM_NAME);
	if (is_null($trash_forum)) {
		message_die(GENERAL_ERROR, "Cannot find forum ID for '" . OConstants::TRASH_FORUM_NAME . "'.");
	}

	$msg = "[b][color=Olive]" .
		"You have violated [url=http://www.openkore.com/wiki/index.php/International_forum_rules]the rules[/url]. ";
	if (!empty($_GET['hint'])) {
		$msg .= "This is the rule you violated: [i]" . $_GET['hint'] . "[/i]\n";
	}
	$msg .= "Therefore, your post has been trashed. This is a warning. Please respect our rules, " .
		"or you may risk being banned.\n\n" .
		"Please understand that we are doing this in order to keep our forums clean, for the benefit of all users.\n\n" .
		"Thank you for your understanding,\n" .
		"[i]- The OpenKore community[/i][/color][/b]";
	$post_id = $topic->addReply($msg);
	$topic->lockTopic();
	$topic->moveTopic($trash_forum);
	header("Location: viewtopic.php?p=$post_id#$post_id");
	break;

default:
	message_die(GENERAL_ERROR, 'Invalid task.');
}

PhpBB::finalize();


// Validate parameters.
function validate() {
	if (empty($_GET['t']) || empty($_GET['task'])) {
		message_die(GENERAL_ERROR, 'Invalid parameters.');
	}
}

// Check whether visitor is authorized to moderate topic.
function authenticate($topic) {
	global $lang;
	global $is_auth;
	global $userdata;

	$is_auth = auth(AUTH_ALL, $topic->getForumId(), $userdata);
	if (!OUtils::isForumContributor()) {
		message_die(GENERAL_MESSAGE, $lang['Not_Moderator'], $lang['Not_Authorised']);
	}
}
?>
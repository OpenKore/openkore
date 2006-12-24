var topic_id;
var sid;

function setParams(topicID, the_sid) {
	topic_id = topicID;
	sid = the_sid;
}

function contribute(task, hint_prompt) {
	var hint, url;

	url = "/contributors.php?task=" + task + "&t=" + topic_id + "&sid=" + sid;
	if (hint_prompt !== undefined) {
		hint = window.prompt(hint_prompt, '');
		if (hint === null) {
			return;
		} else if (hint != "") {
			url += "&hint=" + encodeURIComponent(hint);
		}
	}
	location.href = location.protocol + "//" + location.host + url;
}

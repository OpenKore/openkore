<?php
if (isset($_GET['t'])) {
	header("Location: http://forums.openkore.com/viewtopic.php?t=" . $_GET['t']);
} else {
	header("Location: http://forums.openkore.com/");
}
?>
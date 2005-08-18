<?php
function sendmail($to, $subject, $body)
{
	mail($to, $subject, $body, "From: OpenKore Emailer <noreply@sourceforge.net>");
}

function readlong($h)
{
	$buf = fread($h, 4);
	$array = unpack("Vlen", $buf);
	return $array['len'];
}

function readstr($h)
{
	$len = readlong($h);
	return fread($h, $len);
}


error_reporting(E_ALL ^ E_WARNING);
$file = 'mail.archive';

$f = fopen($file, "r");
if (!$f) {
	echo "Cannot open $file for reading.\n";
	exit(1);
}

$emails = Array();
while (!feof($f)) {
	$email = Array();
	$email['to'] = readstr($f);
	if (feof($f))
		break;
	$email['subject'] = readstr($f);
	$email['body'] = readstr($f);
	$email['time'] = readlong($f);
	$emails[] = $email;
}
fclose($f);
unlink($file);

$max = count($emails);
$i = 1;
foreach ($emails as $email) {
	echo "Sending $i of $max... (to $email[to])\n";
	sendmail($email['to'], $email['subject'], $email['body']);
	$i++;
}
?>

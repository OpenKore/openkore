<?php

class Cycle
{
	var $values;
	var $i;
	var $count;

	function Cycle($v)
	{
		$this->values = func_get_args();
		$this->i = -1;
		$this->count = count($this->values);
	}

	function next()
	{
		$this->i = ($this->i + 1) % $this->count;
		return $this->values[$this->i];
	}

	function cur()
	{
		return $this->values[$this->i];
	}

	function reset()
	{
		$this->i = -1;
	}
}

function switcher($name, $options)
{
	$n = isset($_GET[$name]) ? $_GET[$name] : null;
	$html = array();
	foreach ($options as $k => $v) {
		$html[] = sprintf('<a href="?%s=%s"%s>%s</a>', $name, $k, $k == $n ? ' class="active"' : '', $v);
	}
	return implode('', $html);
}

function mainnav()
{
	foreach (array(
				"http://xcache.lighttpd.net/" => "XCache",
				"http://xcache.lighttpd.net/wiki/DocTOC" => _T("Document"),
				"http://xcache.lighttpd.net/wiki/PhpIni" => _T("INI Reference"),
				"http://xcache.lighttpd.net/wiki/GetSupport" => _T("Get Support"),
				"https://groups.google.com/group/xcache/" => _T("Discusson"),
				"http://www.php.net/" => "PHP",
				"http://www.lighttpd.net/" => "Lighttpd",
				) as $url => $title) {
		$html[] = sprintf('<a href="%s" rel="external">%s</a>', $url, $title);
	}
	return implode('|', $html);
}

function subnav()
{
	global $module, $modules;
	$html = array();
	foreach ($modules as $k => $v) {
		$html[] = sprintf('<a href="../%s/"%s>%s</a>', $k, $k == $module ? ' class="active"' : '', $v);
	}
	return implode('', $html);
}

function th($name, $attrs = null)
{
	$translated = __($name);
	if ($translated == $name) {
		$translated = "$name|$name";
	}
	list($text, $title) = explode('|', $translated, 2);
	return sprintf('%s<th%s id="%s" class="h" title="%s"><a href="javascript:" onclick="resort(this); return false">%s</a></th>%s'
			, "\t"
			, $attrs ? " $attrs" : ""
			, $name, htmlspecialchars(trim($title)), trim($text)
			, "\n");
}

function xcache_validateFileName($name)
{
	return preg_match('!^[a-zA-Z0-9._-]+$!', $name);
}

function get_language_file_ex($dir, $lang)
{
	static $langMap = array(
			'zh'    => 'zh-simplified',
			'zh-hk' => 'zh-traditional',
			'zh-tw' => 'zh-traditional',
			);

	if (isset($langMap[$lang])) {
		$lang = $langMap[$lang];
	}
	else if (!xcache_validateFileName($lang)) {
		return null;
	}

	$file = "$dir/$lang.php";
	if (file_exists($file)) {
		return $file;
	}
	return null;
}

function get_language_file($dir)
{
	global $config;
	if (!empty($config['lang'])) {
		$lang = strtolower($config['lang']);
		$file = get_language_file_ex($dir, $lang);
		if (!isset($file)) {
			$lang = strtok($lang, ':-');
			$file = get_language_file_ex($dir, $lang);
		}
	}
	else {
		$config['lang'] = 'en';

		if (!empty($_SERVER['HTTP_ACCEPT_LANGUAGE'])) {
			foreach (explode(',', str_replace(' ', '', $_SERVER['HTTP_ACCEPT_LANGUAGE'])) as $lang) {
				$lang = strtok($lang, ':;');
				$file = get_language_file_ex($dir, $lang);
				if (isset($file)) {
					$config['lang'] = $lang;
					break;
				}
				if (strpos($lang, '-') !== false) {
					$file = get_language_file_ex($dir, strtok($lang, ':-'));
					if (isset($file)) {
						$config['lang'] = $lang;
						break;
					}
				}
			}
		}
	}
	return isset($file) ? $file : "$dir/en.php";
}

function _T($str)
{
	if (isset($GLOBALS['strings'][$str])) {
		return $GLOBALS['strings'][$str];
	}
	if (!empty($GLOBALS['config']['show_todo_strings'])) {
		return '<span style="color:red">' . $str . '</span>|';
	}
	return $str;
}

function __($str)
{
	return _T($str);
}

function N_($str)
{
	return $str;
}

function number_formats($a, $keys)
{
	foreach ($keys as $k) {
		$a[$k] = number_format($a[$k]);
	}
	return $a;
}

function size($size)
{
	$size = (int) $size;
	if ($size < 1024)
		return number_format($size, 2) . ' b';

	if ($size < 1048576)
		return number_format($size / 1024, 2) . ' K';

	return number_format($size / 1048576, 2) . ' M';
}

function age($time)
{
	if (!$time) return '';
	$delta = REQUEST_TIME - $time;

	if ($delta < 0) {
		$delta = -$delta;
	}
	
  	static $seconds = array(1, 60, 3600, 86400, 604800, 2678400, 31536000);
	static $name = array('s', 'm', 'h', 'd', 'w', 'M', 'Y');

	for ($i = 6; $i >= 0; $i --) {
		if ($delta >= $seconds[$i]) {
			$ret = (int) ($delta / $seconds[$i]);
			return $ret . $name[$i];
		}
	}

	return '0s';
}

function stripaddslashes_array($value, $mqs = false)
{
	if (is_array($value)) {
		foreach($value as $k => $v) {
			$value[$k] = stripaddslashes_array($v, $mqs);
		}
	}
	else if(is_string($value)) {
		$value = $mqs ? str_replace('\'\'', '\'', $value) : stripslashes($value);
	}
	return $value;
}

function ob_filter_path_nicer_default($list_html)
{
	$sep = DIRECTORY_SEPARATOR;
	$docRoot = $_SERVER['DOCUMENT_ROOT'];
	if ($sep != '/') {
		$docRoot = str_replace('/', $sep, $docRoot);
	}
	$list_html = str_replace(">$docRoot",  ">{DOCROOT}" . (substr($docRoot, -1) == $sep ? $sep : ""), $list_html);
	$xcachedir = realpath(dirname(__FILE__) . "$sep..$sep");
	$list_html = str_replace(">$xcachedir$sep", ">{XCache}$sep", $list_html);
	if ($sep == '/') {
		$list_html = str_replace(">/home/", ">{H}/", $list_html);
	}
	return $list_html;
}

error_reporting(E_ALL);
ini_set('display_errors', 'On');
define('REQUEST_TIME', time());

if (function_exists('get_magic_quotes_gpc') && @get_magic_quotes_gpc()) {
	$mqs = (bool) ini_get('magic_quotes_sybase');
	$_GET = stripaddslashes_array($_GET, $mqs);
	$_POST = stripaddslashes_array($_POST, $mqs);
	$_REQUEST = stripaddslashes_array($_REQUEST, $mqs);
	unset($mqs);
}
ini_set('magic_quotes_runtime', '0');

$config = array();
if (file_exists("./config.default.php")) {
	include "./config.default.php";
}
include "../config.default.php";
if (file_exists("../config.php")) {
	include "../config.php";
}
if (file_exists("./config.php")) {
	include "./config.php";
}

$strings = array();
include get_language_file("../common/lang");

$modules = array();
if (file_exists("../cacher/index.php")) {
	$modules["cacher"] = _T("Cacher");
}
if (file_exists("../coverager/index.php")) {
	$modules["coverager"] = _T("Coverager");
}
if (file_exists("../diagnosis/index.php")) {
	$modules["diagnosis"] = _T("Diagnosis");
}
header("Cache-Control: no-cache, must-revalidate");
header("Expires: Sat, 26 Jul 1997 05:00:00 GMT");
header("Content-Type: text/html; " . $GLOBALS['config']['charset']);
header("Content-Language: " . $GLOBALS['config']['lang']);

?>

<?php

include "../common/common.php";
include get_language_file("./lang");

$knownUnstablePhpVersions = array(
		array('=', '5.3.14', 'random corrupt memory on high concurrent'),
		);

$module = "diagnosis";

$notes = array();
$activeNote = null;
function checking($item) // {{{
{
	global $activeNote;
	$activeNote = array('item' => $item);
}
// }}}
function result($type, $result, $suggestion = "") // {{{
{
	global $notes, $activeNote;
	$notes[] = array(
			'type' => $type
			, 'result' => ($type != 'skipped' && !$suggestion ? "OK. " : "") . $result
			, 'suggestion' => $suggestion
			) + $activeNote;
}
// }}}
function getCacheInfos() // {{{
{
	$phpCacheCount = xcache_count(XC_TYPE_PHP);
	$varCacheCount = xcache_count(XC_TYPE_VAR);

	$cacheInfos = array();
	for ($i = 0; $i < $phpCacheCount; $i ++) {
		$cacheInfo = xcache_info(XC_TYPE_PHP, $i);
		$cacheInfo['type'] = XC_TYPE_PHP;
		$cacheInfos[] = $cacheInfo;
	}

	for ($i = 0; $i < $varCacheCount; $i ++) {
		$cacheInfo = xcache_info(XC_TYPE_VAR, $i);
		$cacheInfo['type'] = XC_TYPE_VAR;
		$cacheInfos[] = $cacheInfo;
	}
	return $cacheInfos;
}
// }}}
function getIniFileInfo() // {{{
{
	ob_start();
	phpinfo(INFO_GENERAL);
	$info = ob_get_clean();
	ob_start();
	if (preg_match_all("!<tr>[^<]*<td[^>]*>[^<]*(?:Configuration|ini|Server API)[^<]*</td>[^<]*<td[^>]*>[^<]*</td>[^<]*</tr>!s", $info, $m)) {
		$iniInfo = '<table class="phpinfo">'
			. implode('', $m[0])
			. '</table>';
	}
	else {
		$iniInfo = '';
	}
	$loadedIni = '';
	$iniDirectory = '';
	if (preg_match('!<td class="v">(.*?\\.ini)!', $info, $m)) {
		$loadedIni = $m[1];
	}
	else if (preg_match('!Configuration File \\(php.ini\\) Path *</td><td class="v">([^<]+)!', $info, $m)) {
		$iniDirectory = $m[1];
	}
	return array($loadedIni, $iniDirectory, $iniInfo);
}
// }}}

$xcacheLoaded = extension_loaded('XCache');
checking(_T("XCache extension")); // {{{
if (!$xcacheLoaded) {
	list($loadedIni, $iniDirectory, $iniInfo) = getIniFileInfo();
	if ($loadedIni) {
		echo sprintf(_T("Add extension=xcache.so (or xcache.dll) in %s"), $loadedIni);
	}
	else if (preg_match('!Configuration File \\(php.ini\\) Path *</td><td class="v">([^<]+)!', $info, $m)) {
		echo sprintf(_T("Please put a php.ini in %s and add extension=xcache.so (or xcache.dll) in it"), $iniDirectory);
	}
	else {
		echo _T("Cannot detect php.ini location");
	}
	echo " ", _T("(See above)");
	result(N_("error"), _T('Not loaded'), ob_get_clean());
}
else {
	result(N_("info"), _T('Loaded'));
}
// }}}
if ($xcacheLoaded) { // {{{ load XCache summary
	$cacheInfos = getCacheInfos();

	$ooms = 0;
	$errors = 0;
	$disabled = 0;
	$compiling = 0;
	$readonlyProtection = false;
	$phpCacheCount = xcache_count(XC_TYPE_PHP);
	$phpCached = 0;
	$varCached = 0;
	foreach ($cacheInfos as $cacheInfo) {
		$ooms += $cacheInfo['ooms'];
		$errors += $cacheInfo['errors'];
		$disabled += $cacheInfo['disabled'] ? 1 : 0;
		if ($cacheInfo['type'] == XC_TYPE_PHP) {
			$compiling += $cacheInfo['compiling'] ? 1 : 0;
			$phpCached += $cacheInfo['cached'];
		}
		if ($cacheInfo['type'] == XC_TYPE_VAR && $cacheInfo['cached']) {
			$varCached += $cacheInfo['cached'];
		}
		if ($cacheInfo['can_readonly']) {
			$readonlyProtection = true;
		}
	}
}
// }}}
checking(_T("Enabling PHP Cacher")); // {{{
if (!$xcacheLoaded) {
	result(N_("skipped"), "XCache not loaded");
}
else if (!ini_get("xcache.size")) {
	result(N_("error")
		, _T("Not enabled")
		, _T("Your PHP pages is not accelerated by XCache. Set xcache.size to non-zero, set xcache.cacher = On")
		);
}
else if (!$phpCached) {
	result(N_("error")
		, _T("No php script cached")
		, _T("Your PHP pages is not accelerated by XCache. Set xcache.cacher = On")
		);
}
else {
	result(N_("info"), _T('Enabled'));
}
// }}}
checking(_T("PHP Compile Time Error")); // {{{
if (!$xcacheLoaded) {
	result(N_("skipped"), "XCache not loaded");
}
else if (!$phpCacheCount) {
	result(N_("skipped"), "XCache PHP cacher not enabled");
}
else if ($errors) {
	result(N_("warning")
		, _T("Error happened when compiling at least one of your PHP code")
		, _T("This usually means there is syntax error in your PHP code. Enable PHP error_log to see what parser error is it, fix your code")
		);
}
else {
	result(N_("info"), _T('No error happened'));
}
// }}}
checking(_T("Busy Compiling")); // {{{
if (!$xcacheLoaded) {
	result(N_("skipped"), "XCache not loaded");
}
else if (!$phpCacheCount) {
	result(N_("skipped"), "XCache PHP cacher not enabled");
}
else if ($compiling) {
	result(N_("warning")
		, _T("Cache marked as busy for compiling")
		, _T("It's ok if this status don't stay for long. Otherwise, it could be a sign of PHP crash/coredump, report to XCache devs")
		);
}
else {
	result(N_("info"), _T('Idle'));
}
// }}}
checking(_T("Enabling VAR Cacher")); // {{{
if (!$xcacheLoaded) {
	result(N_("skipped"), "XCache not loaded");
}
else if (!ini_get("xcache.var_size")) {
	result(N_("error")
		, _T("Not enabled")
		, _T("PHP code that use XCache caching backend have to use other caching backend instead. Set xcache.var_size to non-zero")
		);
}
else {
	result(N_("info"), _T('Enabled'));

	checking(_T("Using VAR Cacher")); // {{{
	if (!$varCached) {
		result(N_("warning")
			, _T("No variable data cached")
			, _T("Var Cacher won't work simply by enabling it."
				. " PHP code must call XCache APIs like xcache_set() to use it as cache backend. 3rd party web apps may come with XCache support, config it to use XCache as caching backend")
			);
	}
	else {
		result(N_("info"), _T('Cache in use'));
	}
	// }}}
}
// }}}
checking(_T("Cache Size")); // {{{
if (!$xcacheLoaded) {
	result(N_("skipped"), "XCache not loaded");
}
else if ($ooms) {
	result(N_("warning")
		, _T("Out of memory happened when trying to write to cache")
		, _T("Increase xcache.size and/or xcache.var_size")
		);
}
else {
	result(N_("info"), _T('Enough'));
}
// }}}
checking(_T("Hash Slots")); // {{{
$slotsTooBig = null;
$slotsTooSmall = null;
foreach ($cacheInfos as $cacheInfo) {
	if ($cacheInfo['size'] < '1024000' && $cacheInfo['slots'] >= '8192') {
		$slotsTooBig = $cacheInfo['type'];
		break;
	}
	if ($cacheInfo['slots'] < $cacheInfo['cached'] / 2) {
		$slotsTooSmall = $cacheInfo['type'];
		break;
	}
}
if (isset($slotsTooBig)) {
	$prefix = $slotsTooBig == XC_TYPE_PHP ? '' : 'var_';
	result(N_("warning")
		, _T("Slots value too big")
		, sprintf(_T("A very small value is set to %s value and leave %s value is too big.\n"
			. "Decrease %s if small cache is really what you want"), "xcache.{$prefix}size", "xcache.{$prefix}slots", "xcache.{$prefix}slots")
		);
}
else if (isset($slotsTooSmall)) {
	$prefix = $slotsTooSmall == XC_TYPE_PHP ? '' : 'var_';
	result(N_("warning")
		, _T("Slots value too small")
		, sprintf(_T("So many item are cached. Increase %s to a more proper value"), "xcache.{$prefix}slots")
		);
}
else {
	result(N_("info"), _T('Looks good'));
}
// }}}
checking(_T("Cache Status")); // {{{
if (!$xcacheLoaded) {
	result(N_("skipped"), "XCache not loaded");
}
else if ($disabled) {
	result(N_("warning")
		, _T("At least one of the caches is disabled. ")
		, _T("Enable the cache.")
			. (ini_get("xcache.crash_on_coredump") ? " " . _T("It was disabled by PHP crash/coredump handler or you disabled it manually.") : _T('You disabled it manually.'))
			. (ini_get("xcache.crash_on_coredump") ? " " . _T("If it was caused by PHP crash/coredump, report to XCache devs") : "")
		);
}
else {
	result(N_("info"), _T('Idle'));
}
// }}}

checking(_T("Coredump Directory")); // {{{
if (!$xcacheLoaded) {
	result(N_("skipped"), "XCache not loaded");
}
else if (!ini_get("xcache.coredump_directory")) {
	result(N_("info")
			, _T("Not enabled")
			, _T("Enable coredump to save debugging information in case when PHP crash. It can also be enabled in other module like php-fpm beside XCache")
			);
}
else if (ini_get("xcache.coredump_directory")) {
	$coreDir = ini_get("xcache.coredump_directory");
	if (substr($coreDir, -1) != DIRECTORY_SEPARATOR) {
		$coreDir .= DIRECTORY_SEPARATOR;
	}
	$coreFiles = glob($coreDir . "core*");
	if ($coreFiles) {
		result(N_("error")
				, _T("Core files found:\n") . implode("\n", $coreFiles)
				, _T("Disable XCache PHP Cacher (set xcache.size=0), remove the core file(s), then restart PHP. If core file appears again, report call stack backtrace in the core to XCache devs")
				);
	}
	else {
		result(N_("info")
				, _T("Enabled")
				, sprintf(_T("You can see core files if PHP crash in %s if PHP crash"), ini_get("xcache.coredump_directory"))
				);
	}
}
// }}}
checking(_T("Readonly Protection")); // {{{
if (!$xcacheLoaded) {
	result(N_("skipped"), "XCache not loaded");
}
else if (ini_get("xcache.readonly_protection") && !$readonlyProtection) {
	result(N_("error")
		, _T("Set to enabled but not available")
		, _T("Use xcache.mmap_path other than /dev/zero")
		);
}
else {
	result(N_("info")
		, $readonlyProtection ? _T("Enabled") : _T("Disabled")
		, _T("Enable readonly_protection == --performance & ++stability. "
			. "Disable readonly_protection == ++performance & --stability")
		);
}
// }}}
checking(_T("XCache modules")); // {{{
if (!$xcacheLoaded) {
	result(N_("skipped"), "XCache not loaded");
}
else {
	$xcacheModules = explode(" ", XCACHE_MODULES);
	$unexpectedModules = array_intersect($xcacheModules, array("coverager", "disassembler"));
	if ($unexpectedModules) {
		result(N_("warning")
			, implode("\n", $unexpectedModules)
			, _T("Acceptable. Module(s) listed are built into XCache but not for production server.\n"
				. "Leave it as is if you're feeling good.\n"
				. "Re-configure XCache with the module(s) disabled if you're strict with server security.")
			);
	}
	else {
		result(N_("info"), _T('Idle'));
	}
}
// }}}
checking(_T("XCache test setting")); // {{{
if (!$xcacheLoaded) {
	result(N_("skipped"), "XCache not loaded");
}
else if ((int) ini_get('xcache.test') == 1) {
	result(N_("warning")
		, _T("Enabled")
		, _T("xcache.test is for testing only, not for server. set it to off")
		);
}
else {
	result(N_("info"), _T('Disabled'));
}
// }}}
checking(_T("PHP Version")); // {{{
$phpVersion = phpversion();
$unstablePhpVersionReason = null;
foreach ($knownUnstablePhpVersions as $knownUnstablePhpVersion) {
	list($compareOp, $unstablePhpVersion, $reason) = $knownUnstablePhpVersion;
	if ($compareOp) {
		$isUnstable = version_compare($phpVersion, $unstablePhpVersion, $compareOp);
	}
	else {
		$isUnstable = substr($phpVersion, 0, strlen($unstablePhpVersion)) == $unstablePhpVersion;
	}

	if ($isUnstable) {
		$unstablePhpVersionReason = $reason;
		break;
	}
}
if ($unstablePhpVersionReason) {
	result(N_("error")
			, _T("The version of PHP you're using is known to be unstable: ") . $unstablePhpVersionReason
			, _T("Upgrade to new version of PHP"));
}
else {
	result(N_("info"), _T("Looks good"));
}
// }}}
checking(_T("Extension Compatibility")); // {{{
$loadedZendExtensions = get_loaded_extensions(true);
if (array_search("Zend Optimizer", $loadedZendExtensions) !== false) {
	result(N_("info")
		, _T("Zend Optimizer loaded")
		, _T("Optimizer feature of 'Zend Optimizer' is disabled by XCache due to compatibility reason; the Loader of it is still available, encoded files are still supported")
		);
}
else {
	result(N_("info"), _T("Looks good"));
}
// }}}
checking(_T("SAPI Compatibility")); // {{{

if (php_sapi_name() == "cgi" || php_sapi_name() == "cgi-fcgi" && !isset($_SERVER["FCGI_ROLE"])) {
	result(N_("error"), _T("CGI is not supported"), _T("Use FastCGI or FPM instead"));
}
else if (php_sapi_name() == "cgi-fcgi" && isset($_SERVER["FCGI_ROLE"]) && (int) getenv("PHP_FCGI_CHILDREN") < 1) {
	result(N_("error")
		, "PHP_FCGI_CHILDREN<1"
		, _T("PHP_FCGI_CHILDREN should be >= 1 and use 1 group of parent/childs model. See http://xcache.lighttpd.net/wiki/Faq"));
}
else {
	result(N_("info"), _T("Looks good"));
}
// }}}

include "./diagnosis.tpl.php";


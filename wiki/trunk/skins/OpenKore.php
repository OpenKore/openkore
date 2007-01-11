<?php
/**
 * See skin.txt
 *
 * @todo document
 * @package MediaWiki
 * @subpackage Skins
 */

include('/home/openkore/resources/ban.php');
if( !defined( 'MEDIAWIKI' ) )
	die();

/** */
require_once('MonoBook.php');

/**
 * @todo document
 * @package MediaWiki
 * @subpackage Skins
 */
class SkinOpenKore extends SkinTemplate {
	function initPage( &$out ) {
		SkinTemplate::initPage( $out );
		$this->skinname  = 'openkore';
		$this->stylename = 'openkore';
		$this->template  = 'OpenKoreTemplate';
	}
}

class OpenKoreTemplate extends QuickTemplate {
	function gethtml($str) {
		$html = parent::gethtml($str);
		// We want HTML, not XHTML
		$html = preg_replace('/<(.*?) \/>/', '<${1}>', $html);
		// Get rid of <p> tags that Mediawiki puts before and after <html>
		$html = preg_replace('/<p>(\n)*<(div|dl)/', '<${2}', $html);
		$html = preg_replace('/<\/(div|dl)>(\n)*<\/p>/', '</${1}>', $html);
		return $html;
	}

	function html($str) {
		echo $this->gethtml($str);
	}

	function execute() {
		if (isset($_GET['isManual']))
			$this->myPrintManualLayout();
		else
			$this->myPrintNormalLayout();
	}

	function isPrivate() {
		return !empty($_GET['diff'])
		|| !empty($_GET['action'])
		|| preg_match('/^Special:/', $this->data['thispage'])
		|| preg_match('/^Template:/', $this->data['thispage']);
	}

	function myPrintManualLayout() {
		// Suppress warnings to prevent notices about missing indexes in $this->data
		wfSuppressWarnings();
		include(dirname(__FILE__) . '/openkore/manual.php');
		wfRestoreWarnings();
	}

	function myPrintNormalLayout() {
		// Suppress warnings to prevent notices about missing indexes in $this->data
		wfSuppressWarnings();
		include(dirname(__FILE__) . '/openkore/normal.php');
		wfRestoreWarnings();
	}
}

?>

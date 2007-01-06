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
		return preg_replace('/<(.*?) \/>/', '<${1}>', $html);
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
		include('/home/openkore/web/wiki/skins/openkore/manual.php');
		wfRestoreWarnings();
	}

	function myPrintNormalLayout() {
		// Suppress warnings to prevent notices about missing indexes in $this->data
		wfSuppressWarnings();
		include('/home/openkore/web/wiki/skins/openkore/normal.php');
		wfRestoreWarnings();
	}
}

?>

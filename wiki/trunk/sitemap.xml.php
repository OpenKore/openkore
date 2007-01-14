<?php
# -----------------------------------------------------
# MediaWiki - Google Sitemaps generation. v0.3
# 
# A page that'll generate valid Google Sitemaps code
# from the current MediaWiki installation.
# v0.3: Small changes to fix others situations
# v0.2: Updated for MediaWiki 1.5.x
# v0.1: First attempt for MediaWiki 1.4.x
#
# See http://www.thinklemon.com/wiki/MediaWiki:Google_Sitemaps
#
# TODO: Further refinements like caching...
# -----------------------------------------------------

# -----------------------------------------------------
# Includes
# Need to include/require some Mediawiki stuff 
# especially LocalSettings.php for definitions.
# -----------------------------------------------------

define( 'MEDIAWIKI', true );

require_once( './LocalSettings.php' );
require_once( 'includes/GlobalFunctions.php' );

# -----------------------------------------------------
# Send XML header, tell agents this is XML.
# -----------------------------------------------------

header("Content-Type: application/xml; charset=UTF-8");

# -----------------------------------------------------
# Send xml-prolog
# -----------------------------------------------------

echo '<'.'?xml version="1.0" encoding="utf-8" ?'.">\n"; 

# -----------------------------------------------------
# Start connection
# -----------------------------------------------------

$connWikiDB = mysql_connect($wgDBserver, $wgDBuser, $wgDBpassword)
	or trigger_error(mysql_error(),E_USER_ERROR); 
mysql_select_db($wgDBname, $connWikiDB);

# -----------------------------------------------------
# Build query
# Skipping redirects and MediaWiki namespace
# -----------------------------------------------------

$query_rsPages = "SELECT page_namespace, page_title, page_touched ".
	"FROM ".$wgDBprefix."page ".
	"WHERE (page_is_redirect = 0 AND page_namespace NOT IN (8, 9)) ".
	"ORDER BY page_touched DESC";

# -----------------------------------------------------
# Fetch the data from the DB
# -----------------------------------------------------

$rsPages = mysql_query($query_rsPages, $connWikiDB) or die(mysql_error());
# Fetch the array of pages
$row_rsPages = mysql_fetch_assoc($rsPages);
$totalRows_rsPages = mysql_num_rows($rsPages);

# -----------------------------------------------------
# Start output
# -----------------------------------------------------

?>
<!-- MediaWiki - Google Sitemaps - v0.3 -->
<!-- <?php echo $totalRows_rsPages ?> wikipages found. -->
<urlset xmlns="http://www.google.com/schemas/sitemap/0.84">
<?php 

// Find Project Namespace
if($wgMetaNamespace === FALSE)
	$wgMetaNamespace = str_replace( ' ', '_', $wgSitename );

do { 

	# -----------------------------------------------------
	# 1. Determine the pagetitle using namespace:page_name
	# 2. Set priority of the namespace
	# -----------------------------------------------------
	
	$nPriority = 0;
	$skip = 0;

	switch ($row_rsPages['page_namespace']) {
		case "1":
			$sPageName = "Talk:".$row_rsPages['page_title'];
			$nPriority = 0.9;
			break;
		case 2:
			$sPageName = "User:".$row_rsPages['page_title'];
			$nPriority = 0.7;
			break;
		case 3:
			$sPageName = "User_talk:".$row_rsPages['page_title'];
			$nPriority = 0.6;
			break;
		case 4:
			$sPageName = $wgMetaNamespace.":".$row_rsPages['page_title'];
			$nPriority = 0.9;
			break;
		case 5:
			$sPageName = $wgMetaNamespace."_talk:".$row_rsPages['page_title'];
			$nPriority = 0.8;
			break;
		case 6:
			$sPageName = "Image:".$row_rsPages['page_title'];
			$nPriority = 0.5;
			break;
		case 7:
			$sPageName = "Image_talk:".$row_rsPages['page_title'];
			$nPriority = 0.4;
			break;
		case 8:
			$sPageName = "MediaWiki:".$row_rsPages['page_title'];
			$nPriority = 0.4;
			break;
		case 9:
			$sPageName = "MediaWiki_talk:".$row_rsPages['page_title'];
			$nPriority = 0.3;
			break;
		case 10:
			$sPageName = "Template:".$row_rsPages['page_title'];
			$skip = 1;
			$nPriority = 0.3;
			break;
		case 11:
			$sPageName = "Template_talk:".$row_rsPages['page_title'];
			$nPriority = 0.2;
			break;
		case 12:
			$sPageName = "Help:".$row_rsPages['page_title'];
			$nPriority = 0.1;
			break;
		case 13:
			$sPageName = "Help_talk:".$row_rsPages['page_title'];
			$nPriority = 0.1;
			break;
		case 14:
			$sPageName = "Category:".$row_rsPages['page_title'];
			$nPriority = 0.6;
			break;
		case 15:
			$sPageName = "Category_talk:".$row_rsPages['page_title'];
			$nPriority = 0.5;
			break;
		default:
			$sPageName = $row_rsPages['page_title'];
			$nPriority = 1;
	}

	if ($skip || $sPageName == "OpenKore:Searching") {
		continue;
	}

# -----------------------------------------------------
# Start output
# -----------------------------------------------------

?>
	<url>
		<loc><?php echo fnXmlEncode( "http://www.openkore.com" . eregi_replace('\$1',$sPageName,$wgArticlePath) ) ?></loc>
		<lastmod><?php echo fnTimestampToIso($row_rsPages['page_touched']); ?></lastmod>
		<changefreq>weekly</changefreq>
		<priority><?php echo $nPriority ?></priority>
	</url>
<?php } while ($row_rsPages = mysql_fetch_assoc($rsPages)); ?>
</urlset>
<?php
# -----------------------------------------------------
# Clear Connection
# -----------------------------------------------------

mysql_free_result($rsPages);

# -----------------------------------------------------
# General functions
# -----------------------------------------------------

// Convert timestamp to ISO format
function fnTimestampToIso($ts) {
	# $ts is a MediaWiki Timestamp (TS_MW)
	# ISO-standard timestamp (YYYY-MM-DDTHH:MM:SS+00:00)

	return gmdate( 'Y-m-d\TH:i:s\+00:00', wfTimestamp( TS_UNIX, $ts ) );
}

// Convert string to XML safe encoding
function fnXmlEncode( $string ) {
	$string = str_replace( "\r\n", "\n", $string );
	$string = preg_replace( '/[\x00-\x08\x0b\x0c\x0e-\x1f]/', '', $string );
	return htmlspecialchars( $string );
}

?>
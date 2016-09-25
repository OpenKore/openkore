<?php 
/*
   	+-----------------------------------------------------------------------+
   	| eAccelerator control panel                                           	|
   	+-----------------------------------------------------------------------+
   	| Copyright (c) 2004-2012 eAccelerator                                 	|
	| http://eaccelerator.net                                              	|
   	+-----------------------------------------------------------------------+
   	| This source file is subject to version 3.0 of the PHP license,       	|
	| that is bundled with this package in the file LICENSE, and is        	|
	| available through the world-wide-web at the following url:           	|
	| http://www.php.net/license/3_0.txt.                                  	|
	| If you did not receive a copy of the PHP license and are unable to   	|
	| obtain it through the world-wide-web, please send a note to          	|
	| license@php.net so we can mail you a copy immediately.             	|
	+-----------------------------------------------------------------------+

	$Id: $
*/

/*** CONFIG ***/
$auth = false;		// Set to false to disable authentication
$user = "admin";
$pw = "eAccelerator";

$npp = 50;		// Number of records per page (script / key cache listings)

/*** TODO for API / reporting / this script: 
     + want script ttl from API
     + would be cool to have init_time for scripts (time of caching) - could then get hit rates etc.
*/

// Inline media
if (isset($_GET['img']) && $_GET['img']) {
    $img = strtolower($_GET['img']);
    $imgs['dnarr'][0] = 199;
    $imgs['dnarr'][1] = 'H4sIAAAAAAAAA3P3dLOwTORlEGBoZ2BYsP3Y0t0nlu85ueHQ2U1Hzu86efnguetHL968cPPBtbuPbzx4+vTV24+fv3768u3nr9+/f//59+/f////GUbBKBgWQPEnCzMDgyCDDogDyhMMHP4MyhwyHhsWHGzmENaKOSHAyMDAKMWTI/BAkYmDTU6oQuAhY2M7m4JLgcGDh40c7HJ8BQaBBw4z8bMaaOx4sPAsK7voDZ8GAadTzEqSXLJWBgoM1gBhknrUcgMAAA==';
    $imgs['uparr'][0] = 201;
    $imgs['uparr'][1] = 'H4sIAAAAAAAAA3P3dLOwTORlEGBoZ2BYsP3Y0t0nlu85ueHQ2U1Hzu86efnguetHL968cPPBtbuPbzx4+vTV24+fv3768u3nr9+/f//59+/f////GUbBKBgWQPEnCzMDgyCDDogDyhMMHIEMyhwyHhsWHGzmENaKOTFBoYWZgc/BYQVDw1EWdvGIOzsWJDAzinFHiBxIWNDMKMbv0sCR0NDMIcATofJB4RAzkxivg0OCoUNzIy9ThMuFDRqHGxisAZtUvS50AwAA';

    if (!$imgs[$img] || strpos($_SERVER['HTTP_ACCEPT_ENCODING'], 'gzip') === false) 
        exit();

    header("Expires: ".gmdate("D, d M Y H:i:s", time()+(86400*30))." GMT");
    header("Last-Modified: ".gmdate("D, d M Y H:i:s", time())." GMT");
    header('Content-Length: '.$imgs[$img][0]);
    header('Content-Type: image/gif');
    header('Content-Encoding: gzip');

    echo base64_decode($imgs[$img][1]);
    exit();
}

// Authenticate before proceeding
if ($auth && (!isset($_SERVER['PHP_AUTH_USER']) || !isset($_SERVER['PHP_AUTH_PW']) ||
        $_SERVER['PHP_AUTH_USER'] != $user || $_SERVER['PHP_AUTH_PW'] != $pw)) {
    header('WWW-Authenticate: Basic realm="eAccelerator control panel"');
    header('HTTP/1.0 401 Unauthorized');
    exit;
} 

$sec = isset($_GET['sec']) ? (int)$_GET['sec'] : 0;

// No-cache headers
header("Expires: Mon, 26 Jul 1997 05:00:00 GMT");
header("Last-Modified: " . gmdate("D, d M Y H:i:s") . " GMT");
header("Cache-Control: no-store, no-cache, must-revalidate");
header("Cache-Control: post-check=0, pre-check=0", false);
header("Pragma: no-cache");

function print_footer() {
    global $info;
?>
</div>
<div class="footer">
<?php
if (is_array($info)) {
?>
<br/><br/>
    <hr style="width:500px; color: #cdcdcd" noshade="noshade" size="1" />
    <strong>Created by the eAccelerator team &ndash; <a href="http://eaccelerator.net">http://eaccelerator.net</a></strong><br /><br />
    eAccelerator <?php echo $info['version']; ?> [shm:<?php echo $info['shm_type']?> sem:<?php echo $info['sem_type']; ?>]<br />
    PHP <?php echo phpversion();?> [ZE <?php echo zend_version(); ?>]<br />
    Using <?php echo php_sapi_name();?> on <?php echo php_uname(); ?><br />
<?php
}
?>
</div>
</body>
</html>
<?php
}

if (!function_exists('eaccelerator_info')) {
    die('eAccelerator isn\'t installed or isn\'t compiled with info support!');
}

// formats sizes
function format_size ($x) {
    $a = array('bytes', 'kb', 'mb', 'gb');
    $i = 0;
    while ($x >= 1024) {
        $i++;
        $x = $x / 1024;
    }
    return number_format($x, ($i > 0)?2:0, '.', ',').' '.$a[$i];
}

// Generates a simple & colourful horizontal bar graph. $x:$y is used:free
function space_graph ($x, $y) {
    $colr = 183; $colg = 225; $colb = 149;	// #B7E195

    $colr = base_convert($colr + floor(($x/$y)*(50+exp($x*3/$y))), 10, 16);
    $colg = base_convert($colg - floor(($x/$y)*(100+exp($x*4/$y))), 10, 16);
    $colb = base_convert($colb - floor(($x/$y)*(70+exp($x*4/$y))), 10, 16);

    $s = '<table class="hgraph"><tr>';
    $s .= '<td class="hgraph_pri" style="width:'.floor(($x/$y)*100).'%">&nbsp;</td>';
    $s .= '<td class="hgraph_sec" style="background-color: #'.$colr.$colg.$colb.'; width:'.ceil(100 - ($x/$y)*100).'%">&nbsp;</td></tr></table>';
    return $s;
}

// Messy algorithm to generate neat page selectors
function pageselstr ($pg, $pgs) {
    $pg += 1;
    $st = max(1, $pg - 2) - max(0, 2 - ($pgs - $pg));
    $nd = $pg + 2 + max(0, 3 - $pg);
    $d = $st - 1 - 1;
    if (abs($nd - $pg) > 2) $sp[] = $nd - 2;
    if (abs($pg - $st) > 2) $sp[] = $st + 2;
    if (($d-2)/3 >= 2) {
        $sp[] = (ceil($d/3)+1);
        $sp[] = (ceil($d/3)*2+1);
    }
    elseif (($d-1)/2 > 0) $sp[] = (ceil($d/2)+1);
    $d = $pgs - $nd - 1;
    if (($d-2)/3 >= 2) {
        $sp[] = (ceil($d/3)+$nd);
        $sp[] = (ceil($d/3)*2+$nd);
    }
    elseif (($d-1)/2 > 0) $sp[] = (ceil($d/2)+$nd);
    $sp[] = $st;$sp[] = $nd;$sp[] = $pg;$sp[] = 1;$sp[] = $pgs;
    $lp = 1;
    $pgstr = 'Page: ';
    if ($pgs < 1) $pgstr .= '-';
    for ($i = 1; $i <= $pgs; $i++) {
        if (in_array($i, $sp)) {
            if ($i - $lp <= 2 && $i > 2 && !in_array($i-1, $sp)) $pgstr .= '<a href="'.$_SERVER['PHP_SELF'].'?'.qstring_update(array('pg' => $i-2)).'">'.($i-1).'</a> ';
            if ($i - $lp > 2) $pgstr .= '..';
            if ($i == $pg) $pgstr .= ' ['.$i.'] ';
            else {
                $pgstr .= ' <a href="'.$_SERVER['PHP_SELF'].'?'.qstring_update(array('pg' => $i-1)).'">'.$i.'</a> ';
            }
            $lp = $i;
        }
    }
    return $pgstr;
}

// Returns qstring with updated key / value pairs.
function qstring_update ($arr) {
    $qs = '';
    $combo = array_merge($_GET, $arr);
    foreach ($combo as $a => $b) {
        if ($qs) $qs .= '&';
        $qs .= urlencode($a).'='.urlencode($b);
    }
    return $qs;
}

// Returns standard column headers for the lists
function colheadstr ($nme, $id) {
    $cursrt = isset($_GET['ordby']) ? $_GET['ordby'] : 0;
    $srtdir = isset($_GET['dir']) ? $_GET['dir'] : "";
    return '<a href="'.$_SERVER['PHP_SELF'].'?'.qstring_update(array('ordby' => $id, 'dir' => ($cursrt == $id)?1-$srtdir:0)).'">'.$nme.'&nbsp;'.(($cursrt == $id)?'<img src="'.$_SERVER['PHP_SELF'].'?img='.(($srtdir)?'dnarr':'uparr').'" width="13" height="16" border="0" alt="'.(($srtdir)?'v':'^').'"/>':'');
}

// Array sorting callback function
function arrsort ($a, $b) {
    global $ordby, $ordbystr;
    if ($ordbystr) 
        $val = strnatcmp($a[$ordby], $b[$ordby]);
    else 
        $val = ($a[$ordby] == $b[$ordby]) ? 0 : (($a[$ordby] < $b[$ordby]) ? -1: 1);
    if (isset($_GET['dir']) && $_GET['dir'])
        $val = -1*$val;
    return $val;
}

// Global info array
$info = eaccelerator_info();

?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">  
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
<head>
    <title>eAccelerator control panel</title>
    <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1" />
    <meta http-equiv="Content-Style-Type" content="text/css" />
    <meta http-equiv="Content-Language" content="en" />

    <style type="text/css" media="all">
        body {background-color: #ffffff; color: #000000;margin: 0px;}
        body, td {font-family: Tahoma, sans-serif;font-size: 12pt;}

        a:link {color: #ff0000; text-decoration: none;}
        a:visited {color: #ff0000; text-decoration: none;}
        a:active {color: #aa0000; text-decoration: none;}
        a:hover {color: #aa0000; text-decoration: none;}
        
        .head1 {background-color: #A9CFDD; width: 100%; font-size: 32px; color: #ffffff;padding-top: 20px;font-family: Tahoma, sans-serif;}
        .head1_item {padding-left: 15px;}
        .head2 {background-color: #62ADC2; width: 100%; font-size: 18px; color: #ffffff;text-align: right; font-family: Tahoma, sans-serif;border-top: #ffffff 2px solid;}
        .head2 a:link {color: #ffffff;}
        .head2 a:visited {color: #ffffff;}
        .head2 a:active {color: #ffffff;}
        .head2 a:hover {color: #000000;}

        .menuitem {padding-left: 15px;padding-right: 15px;}
        .menuitem_sel {padding-left: 15px;padding-right: 15px;background-color: #ffffff; color: #000000;}
        .menuitem_hov {padding-left: 15px;padding-right: 15px;cursor:pointer;color: #000000;}
        .mnbody {padding:15px; padding-top: 30px; margin-right: auto; margin-left: auto; text-align: center;bottom: 60px;}

        .mnbody table {border-collapse: collapse; margin-right: auto; margin-left: auto;}
        
        td {padding: 3px 10px 3px 10px; border: #ffffff 2px solid;vertical-align:top}
        .el {text-align: left;background-color: #e1eff8;}
        .er {text-align: right;background-color: #e1eff8;}
        .ec {text-align: center;background-color: #e1eff8;}

        .fl {text-align: left;background-color: #efefef;}
        .fr {text-align: right;background-color: #efefef;}

        .h {text-align: center; font-weight: bold;}
        .h a:link {color: #000000;}
        .h a:visited {color: #000000;}
        .h a:active {color: #ababab;}
        .h a:hover {color: #ababab;}

        .hgraph {width:100%;}
        .hgraph td {border: 0px;padding: 0px;}
        .hgraph_pri {background-color: #62ADC2;}
        .hgraph_sec {}
        
        
        .footer {width: 100%;text-align: center;font-size: 9pt;color: #ababab;}
        .footer a:link {color: #ababab;}
        .footer a:visited {color: #ababab;}
        .footer a:active {color: #000000;}
        .footer a:hover {color: #000000;}
        
        small {font-size: 10pt;}
        .s {color: #676767;}

    </style>
    
    <script type="text/javascript">
      function menusel(i) {
        if (i.className == "menuitem_hov") i.className = "menuitem";
        else if (i.className == "menuitem") i.className = "menuitem_hov";
      }
      function gosec(i) {
        document.location = "<?php echo $_SERVER['PHP_SELF']?>?sec="+i;
      }
    </script>
    
</head>

<body>
<div class="head1"><span class="head1_item">eAccelerator control panel</span></div>
<div class="head2">
<?php
$items = array(0 => 'Status', 1 => 'Script Cache');

foreach ($items as $i => $item) {
    echo '<span class="menuitem'.(($sec == $i)?'_sel':'').'" onmouseover="menusel(this)" onmouseout="menusel(this)" onclick="gosec('.$i.')">'.(($sec != $i)?'<a href="'.$_SERVER['PHP_SELF'].'?sec='.$i.'">'.$item.'</a>':$item).'</span>';
}  
?>
</div>
<div class="mnbody">
<?php
switch ($sec) {
    default:
    case 0:
        /******************************     STATUS / CONTROL     ******************************/

        if (isset($_POST['cachingoff'])) eaccelerator_caching(false);
        if (isset($_POST['cachingon'])) eaccelerator_caching(true);

        if (isset($_POST['optoff']) && function_exists('eaccelerator_optimizer')) eaccelerator_optimizer(false);
        if (isset($_POST['opton']) && function_exists('eaccelerator_optimizer')) eaccelerator_optimizer(true);

        if (isset($_POST['mtimeoff'])) eaccelerator_check_mtime(false);
        if (isset($_POST['mtimeon'])) eaccelerator_check_mtime(true);

        if (isset($_POST['clear'])) eaccelerator_clear();
        if (isset($_POST['clean'])) eaccelerator_clean();
        if (isset($_POST['purge'])) eaccelerator_purge();

        $info = eaccelerator_info();

?>
<table>
<tr><td>

<form action="<?php echo $_SERVER['PHP_SELF']?>?sec=0" method="post">
<table>
<tr>
    <td class="h" colspan="2">Usage statistics</td>
</tr>
<tr>
    <td class="er">Caching enabled</td> 
    <td class="fl"><?php echo $info['cache'] ? '<span style="color:green"><b>yes</b></span>&nbsp;&nbsp;&nbsp;<input type="submit" name="cachingoff" value=" Disable "/>':'<span style="color:red"><b>no</b></span>&nbsp;&nbsp;&nbsp;<input type="submit" name="cachingon" value=" Enable "/>' ?></td>
</tr>
<tr>
    <td class="er">Optimizer enabled</td>
    <td class="fl"><?php echo $info['optimizer'] ? '<span style="color:green"><b>yes</b></span>&nbsp;&nbsp;&nbsp;<input type="submit" name="optoff" value=" Disable "/>':'<span style="color:red"><b>no</b></span>&nbsp;&nbsp;&nbsp;<input type="submit" name="opton" value=" Enable "/>' ?></td>
</tr>
<tr>
    <td class="er">Check mtime enabled</td>
    <td class="fl"><?php echo $info['check_mtime'] ? '<span style="color:green"><b>yes</b></span>&nbsp;&nbsp;&nbsp;<input type="submit" name="mtimeoff" value=" Disable "/>':'<span style="color:red"><b>no</b></span>&nbsp;&nbsp;&nbsp;<input type="submit" name="mtimeon" value=" Enable "/>' ?></td>
</tr>
<tr>
    <td class="er">Total memory</td>
    <td class="fl"><?php echo format_size($info['memorySize']); ?></td>
</tr>
<tr>
    <td class="er">Memory in use</td>
    <td class="fl"><?php echo format_size($info['memoryAllocated']).' ('.number_format(100 * $info['memoryAllocated'] / max(1, $info['memorySize']), 0).'%)';?></td>
</tr>
<tr>
    <td class="er" colspan="2"><?php echo space_graph($info['memoryAllocated'], $info['memorySize']);?></td>
</tr>
<tr>
    <td class="er">Free memory</td>
    <td class="fl"><?php echo format_size($info['memoryAvailable'])?></td>
</tr>
<tr>
    <td class="er">Cached scripts</td>
    <td class="fl"><?php echo number_format($info['cachedScripts']); ?></td>
</tr>
<tr>
    <td class="er">Removed scripts</td> 
    <td class="fl"><?php echo number_format($info['removedScripts']); ?></td>
</tr>
</table>
</form>

</td><td>

<table>
<tr>
    <td class="h" colspan="2">Build information</td>
</tr>
<tr>
    <td class="er">eAccelerator version</td> 
    <td class="fl"><?php echo $info['version']; ?></td>
</tr>
<tr>
    <td class="er">Shared memory type</td> 
    <td class="fl"><?php echo $info['shm_type']; ?></td>
</tr>
<tr>
    <td class="er">Semaphore type</td> 
    <td class="fl"><?php echo $info['sem_type']; ?></td>
</tr>
</table>

</td></tr>
</table>

<br/><br/>

<form action="<?php echo $_SERVER['PHP_SELF']?>?sec=0" method="post">
<table>
<tr>
    <td class="h" colspan="2">Maintenance</td>
</tr>
<tr>
    <td class="ec"><input type="submit" name="clear" value=" Clear cache "/></td> 
    <td class="fl">Removed all scripts and data from shared memory and / or disk.</td>
</tr>
<tr>
    <td class="ec"><input type="submit" name="clean" value=" Delete expired "/></td> 
    <td class="fl">Removed all expired scripts and data from shared memory and / or disk.</td>
</tr>
<tr>
    <td class="ec"><input type="submit" name="purge" value=" Purge cache "/></td> 
    <td class="fl">Delete all 'removed' scripts from shared memory.</td>
</tr>
</table>
</form>

<?php
        break;
    case 1:
        /******************************     SCRIPT CACHE     ******************************/
    
        $scripts = eaccelerator_cached_scripts();
        $removed = eaccelerator_removed_scripts();
    
        // combine arrays
        function removedmod ($val) {
            $val['removed'] = true;
            return $val;
        }
        $scripts = array_merge($scripts, array_map('removedmod', $removed));
    
        // search
        function scriptsearch ($val) {
            $str = isset($_GET['str']) ? $_GET['str'] : '';
            return preg_match('/'.preg_quote($str, '/').'/i', $val['file']);
        }
        $scripts = array_filter($scripts, 'scriptsearch');
    
        // sort
        $ordby = isset($_GET['ordby']) ? intval($_GET['ordby']) : 0;
        switch ($ordby) {
            default:
            case 0: $ordby = 'file'; $ordbystr = true; break;
            case 1: $ordby = 'mtime'; $ordbystr = false; break;
            case 2: $ordby = 'ts'; $ordbystr = false; break;
            case 3: $ordby = 'ttl'; $ordbystr = false; break;
            case 4: $ordby = 'size'; $ordbystr = false; break;
            case 5: $ordby = 'reloads'; $ordbystr = false; break;
            case 6: $ordby = 'hits'; $ordbystr = false; break;
        }
        usort($scripts, 'arrsort');
 
        // slice
        $numtot = count($scripts);

        $pg = (isset($_GET['pg']) ? (int)$_GET['pg'] : 0); // zero-starting
        $pgs = ceil($numtot/$npp);

        if ($pg + 1 > $pgs)
            $pg = $pgs-1;
        if ($pg < 0)
            $pg = 0;

        $scripts = array_slice($scripts, $pg*$npp, $npp);
        $numres = count($scripts);
?>
<table class="center">
<tr>
    <td class="h" colspan="2">Search</td>
</tr>
<tr>
    <form action="<?php echo $_SERVER['PHP_SELF']?>" method="get"><input type="hidden" name="sec" value="1"/>
    <td class="el">Match filename:</td> 
    <td class="fl"><input type="text" name="str" size="40" value="<?php echo isset($_GET['str']) ? $_GET['str'] : '' ?>"/>&nbsp;<input type="submit" value=" Find "/></td>
    </form>
</tr>
</table>

<br/><br/>

<?php
        if (count($scripts) == 0) 
            echo '<div class="center"><i>No scripts found</i></div>';
        else {
?>
<table class="center">
<tr>
    <td colspan="1" style="text-align: left">Showing <?php echo $pg*$npp+1?> &ndash; <?php echo $pg*$npp+min($npp, $numres)?> of <?php echo $numtot?></td>
    <td colspan="4" style="text-align: right;"><small><?php echo pageselstr($pg, $pgs)?></small></td>
</tr>
<tr>
    <td class="h"><?php echo colheadstr('File', 0)?></td>
    <td class="h"><?php echo colheadstr('Last Modified', 1)?></td>
    <td class="h"><?php echo colheadstr('Added', 2)?></td>
    <td class="h"><?php echo colheadstr('TTL', 3)?></td>
    <td class="h"><?php echo colheadstr('Size', 4)?></td>
    <td class="h"><?php echo colheadstr('Reloads', 5)?></td>
    <td class="h"><?php echo colheadstr('Hits', 6)?></td>
</tr>
<?php
            $disassembler = function_exists('eaccelerator_dasm_file');
            for ($i = 0; $i < $numres; $i++) {
                $removed = (isset($scripts[$i]['removed']) && $scripts[$i]['removed']);
                if ($disassembler && !$removed) {
                    $file_col = sprintf('<a href="dasm.php?file=%s">%s</a>', $scripts[$i]['file'], $scripts[$i]['file']);
                } elseif ($removed) {
                    $file_col = sprintf('<span class="s">%s</span>', $scripts[$i]['file']);   
                } else {
                    $file_col = $scripts[$i]['file'];
                }

                if ($scripts[$i]['ttl'] != 0) {
                    $ttl_col = $scripts[$i]['ttl'] - time();
                    if ($ttl_col <= 0) {
                        $ttl_col = "expired";
                    }
                } else {
                    $ttl_col = "&infin;";
                }
?>
<tr>
    <td class="el"><small><?php echo $file_col ?></small></td>
    <td class="fl"><small><?php echo date('Y-m-d H:i:s', $scripts[$i]['mtime'])?></small></td>
    <td class="fl"><small><?php echo date('Y-m-d H:i:s', $scripts[$i]['ts'])?></small></td>
    <td class="fr"><small><?php echo $ttl_col ?></small></td>
    <td class="fr"><small><?php echo format_size($scripts[$i]['size'])?></small></td>
    <td class="fr"><small><?php echo $scripts[$i]['reloads']?> (<?php echo $scripts[$i]['usecount']?>)</small></td>
    <td class="fr"><small><?php echo number_format($scripts[$i]['hits'])?></small></td>
</tr>
<?php
      }
?>
<tr>
    <td colspan="1" style="text-align: left">&nbsp;</td>
    <td colspan="4" style="text-align: right;"><small><?php echo pageselstr($pg, ceil($numtot/$npp))?></small></td>
</tr>
</table>
<?php
            }
            break;
    }

print_footer();
?>

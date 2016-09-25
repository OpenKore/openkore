<?php
$version="";
$server_name="";
$server_port="";

 if (getenv('HOME') == ''){                       // Not set when running as service
   $root= substr($_SERVER["DOCUMENT_ROOT"],0,-4); // this alternative with limitations
 }                                                // gets path to folder UniServerZ

 else{                                            // Set when run as standard program
   $root= getenv('HOME');                         // this is the ideal method to
 }                                                // get the path to folder UniServerZ

$file="$root\home\us_config\us_config.ini" ;     // Name and path of configuration file

if (file_exists($file) && is_readable($file)){   // Check file
  $settings=parse_ini_file($file,true);          // parse file into an array
  $version=$settings["APP"]["AppVersion"];       // get parameter
}


$file="$root\home\us_config\us_user.ini" ;         // Name and path of user configuration file

if (file_exists($file) && is_readable($file)){     // Check file
  $settings=parse_ini_file($file,true);            // parse file into an array
  $server_name=$settings["USER"]["US_SERVERNAME"]; // get parameter
  $server_port=$settings["USER"]["AP_SSL_PORT"];   // get parameter
}
?>


<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
<title>Uniform Server ZeroXIII - test page</title>
<meta name="Description" content="The Uniform Server ZeroXIII 13.0.0" />
<meta name="Keywords" content="The Uniform Server, MPG, Mike, Ric, UniServer, Olajide, BobS " />
<link rel="stylesheet" type="text/css" href="css/style.css" media="screen" />
</head>

<style type="text/css">
/*****************************************/
.intro{
  margin-top:10px;
  margin-bottom:10px;
  padding:3px;
  font-size:11px;
  font-family:Verdana;
  background-color: #9AF19A;
  border-top:1px solid #4f4f97;
  border-bottom:1px solid #4f4f97;
}
/*****************************************/
</style>

<body>

<div id="wrap">
  <div id="header">
     <a href="http://www.uniformserver.com"><img src="images/logo.png" align="left" alt="The Uniform Server ZeroXIII" /></a>
       <div id="header_txt" >
         <div style="position:absolute;">
             ZeroXIII <?php print "- ".$version; ?></p>
         </div>
       </div>
  </div>


  <div id="content">
    <h1>Welcome to The Uniform Server</h1>

    <p class="intro">This test page <b>index.php</b> was served from root folder UniServerZ\<b>ssl</b>
    <span  style='display:<?php print("none")?>'><br /> No PHP module installed Apache returns php directives un-processed.</span>
    </p>

  <div align="center" >
     <img src="images/padlock.gif"  alt="Padlock" />
  </div>

  <p class="intro"><b><i>Note</i>:</b> Please read manual page: <a href="/us_docs/manual/quick_start_guide.html#Installing your Website or Test pages">Installing your Website or Test pages</a>.</p>


<!-- splash page link -->
<!-- <?php print("--" . ">");?>

  <table>
  <tr>
   <td>
     <h2>Server links</h2>
      <p> <a href="https://<?php echo($server_name.':'.$server_port) ?>/us_splash/index.php" target="_blank" >Splash page</a> - Displays server specification and useful links.</p>
      <p> <a href="https://<?php echo($server_name.':'.$server_port) ?>/us_opt1/index.php" target="_blank" >PhpMyAdmin</a>.</p>
      <p> <a href="https://<?php echo($server_name.':'.$server_port) ?>/us_opt2/?username=" target="_blank" >Adminer</a>.</p>
      <p> <a href="https://<?php echo($server_name.':'.$server_port) ?>/us_extra/phpinfo.php" target="_blank" >PHP Info</a>.</p>
   </td>
  </tr>
  </table>
<?php print("<"."!"."--")?> -->

<!-- subdirs  -->
<!-- <?php print("--" . ">");?>

  <table>
  <tr><td><h2>Served Subdirectories</h2></td></tr>
  </table>
  <table width=100%>
  <?php $n = 0; foreach (scandir("./") as $file){
    if (is_dir($file) && !in_array($file, array(".", "..", "css", "images"))){
        $n++;
        echo ($n % 3 ? (($n+1) % 3 ? "<tr><td width=33%>$n - <a href='" . $file . "' target='_blank'>" . $file . "</a></td>" : "<td width=33%>$n - <a href='" . $file . "' target='_blank'>" . $file . "</a></td>") : "<td>$n - <a href='" . $file . "' target='_blank'>" . $file . "</a></td></tr>");
    }
  }
  echo ($n == 0 ? "<tr><td style='color: red;' colspan='3'>None</td></tr>" : ($n % 2 == 0 ? "" : "<td></td></tr>"));?>
  </table>
<?php print("<"."!"."--")?> -->

<!-- php files -->
<!-- <?php print("--" . ">");?>

  <table>
  <tr><td><h2>Served PHP Files</h2></td></tr>
  </table>
  <table width=100%>
  <?php $n = 0; foreach (scandir("./") as $file){
    if (strtolower(strrchr($file, '.'))==".php" ){
        $n++;
        echo ($n % 3 ? (($n+1) % 3 ? "<tr><td width=33%>$n - <a href='" . $file . "' target='_blank'>" . $file . "</a></td>" : "<td width=33%>$n - <a href='" . $file . "' target='_blank'>" . $file . "</a></td>") : "<td>$n - <a href='" . $file . "' target='_blank'>" . $file . "</a></td></tr>");
    }
  }
  echo ($n == 0 ? "<tr><td style='color: red;' colspan='3'>None</td></tr>" : ($n % 2 == 0 ? "" : "<td></td></tr>"));?>
  </table>

<?php print("<"."!"."--")?> -->


  <div id="divider">Developed By <a href="http://www.uniformserver.com/">The Uniform Server Development Team</a></div>
</div>
</div>
</body>
</html>

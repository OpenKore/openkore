<?php
/*
####################################################
# Developed By: The Uniform Server Development Team
# Modified Last By: MPG (Ric) 
# Web: http://www.uniformserver.com
####################################################
*/

    /**************************************************************************\
        Contributors:
            http://nevstokes.com/blog/2009/06/23/a-better-phpinfo/
            http://www.page2pagepro.com/a-better-phpinfo/
    \**************************************************************************/

    $options = array('Configuration', 'Enviroment', 'Modules', 'Extensions', 'Variables', 'General', 'Credits', 'License', 'All');
    $display = (empty($_GET['display']) || !in_array($_GET['display'], $options)) ? 'ALL' : $_GET['display'];

    $navigation = array();

    foreach($options as $key=>$value) {
        $navigation[] = ($value != $display) ? '<a href="' . $_SERVER['SCRIPT_NAME'] . '?display=' . $value . '">' . $value . '</a>' : '<strong>' . $value . '</strong>';
    }

    ob_start();

    switch($display) {
        case 'Configuration':        
            phpinfo(INFO_CONFIGURATION);
            break;

        case 'Enviroment':
            phpinfo(INFO_ENVIRONMENT);
            break;

        case 'Modules':
            phpinfo(INFO_MODULES);
            break;

        case 'Variables':
            phpinfo(INFO_VARIABLES);
            break;

        case 'General':
            phpinfo(INFO_GENERAL);
            break;

       // case 'Extensions':
        case 'Credits':
          phpinfo(INFO_CREDITS);
            break;

        case 'License':
            phpinfo(INFO_LICENSE);
            break;

        case 'All': default:
            phpinfo();
            break;
    }

    $content = ob_get_clean();

    if (($display) == 'Extensions') {
        $str = '<body><div class="center">';
        $content = substr($content, 0, strpos("$content$str", $str)+strlen($str));
        ob_start();
        echo '<h2>Overview</h2>'.PHP_EOL;
        echo '<table border="0" cellpadding="3" width="600">'.PHP_EOL;
        echo '<tr><td class="e">Extensions</td><td class="v">'.PHP_EOL;
        $exts = array();
        foreach (get_loaded_extensions() as $ext) {

if (($ext !== 'mhash') and ($ext !== 'xmlreader') and ($ext !== 'Reflection')and ($ext !== 'mysqlnd')and ($ext !== 'Phar')and ($ext !== 'pdo_mysql')){
           $exts[] = $ext;
}
        }
        echo implode(', ', $exts).PHP_EOL;
        echo '</td></tr></table><br />'.PHP_EOL;
        echo '<h2>Details</h2>'.PHP_EOL;
        echo '<table border="0" cellpadding="3" width="600">'.PHP_EOL;
        foreach ($exts as $ext) {
            echo '<tr><td class="e">'.$ext.'</td><td class="v">';
                $funcs = array();
                foreach (get_extension_funcs($ext) as $func) {
                    $funcs[] = $func;
                }
                echo implode(', ', $funcs).PHP_EOL;
            echo '</td></tr>'.PHP_EOL;
        }
        echo '</table><br />'.PHP_EOL;
        echo '</div></body></html>'.PHP_EOL;
        $content .= ob_get_contents();
        ob_end_clean();        
    }

    echo str_replace('<body>', '</body><body><div class="center options"><p>' . implode(' | ', $navigation) .'</p></div>', $content);
?>

<?php
/**
 * Lъ dados binarios de um arquivo
 *
 * A leitura de dados binarios no php щ um tanto quanto estranha
 * esta funчуo foi feita para simplificar a leitura
 *	resource = recurso/manipulador retornado por fopen
 *	size = tamanho que sera lido
 *	format = formato esperado
 *			 para mais detalhes sobre os formatos suportados veja
 *			 http://www.php.net/manual/en/function.pack.php
 *
 * @package    Utils
 * @author     HwapX(aka Hacker_wap)
 * @copyright  2012 HwapX
 * @license    http://www.php.net/license/3_01.txt  PHP License 3.01
 * @version    Release: @1.0.0@
 */

function freadb($resource, $size, $format) {
	$bd = unpack($format, fread($resource, $size));//http://www.php.net/manual/en/function.unpack.php
	return($bd[1]);
}
?>
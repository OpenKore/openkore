<?php
/**
 * Lê um arquivo de sprite (*.spr)
 *
 * Essa classe cuida da leitura dos arquivos que armazenam os sprites (*.spr)
 *
 * @package    SpriteList
 * @author     HwapX(aka Hacker_wap)
 * @copyright  2012 HwapX
 * @license    http://www.php.net/license/3_01.txt  PHP License 3.01
 * @version    Release: @1.0.0@
 * @see        Sprite
 */
 
namespace RO\Sprite;

use RO\Sprite\Sprite;

require_once("/RO/Binary/functions.php");

/**
 * Representa um arquivo SPR
 */
class SpriteList {
	private $list = [];
	private $version = 0;
	private $palette = [];

	const MAGIC = "SP";

	/**
	 * Cria o objeto e caso o nome do arquivo seja infomado faz a chamada do metodo load
	 * @param $fileName
	 */
	function __construct($fileName) {
		if($fileName) {
			$this->Load($fileName);
		}
	}

	/**
	 * Faz a leitura do arquivos e popula as variaveis.
	 * @param $fileName nome do arquivo
	 */
	function load($fileName) {
		$f = fopen($fileName, "rb");

		$header['magic'] = fread($f, 2);
		$header['version'] = unpack("Cmajor/Cminor", fread($f, 2));
		$this->version = (float)($header['version']['major'] . "." . $header['version']['minor']);
		$header['count'] = freadb($f, 2, 'S');
		$header['unknown'] = freadb($f, 2, 'S');

		if($header['magic'] !== self::MAGIC) {
			throw new UnexpectedValueException("Invalid magic header, found ({$header['magic']}) expected ({self->MAGIC})");
		}

		//Faz a leitura dos sprites.
		for($i = 0; $i < $header['count']; ++$i) {
			$width = freadb($f, 2, 'S');
			$height = freadb($f, 2, 'S');
			$size = freadb($f, 2, 'S');
			$data = fread($f, $size);
			$this->list[] = new Sprite($width, $height, $data);
		}

		//Faz a leitura da paleta de cores
		for($i = 0; $i < 256; ++$i) {
			$this->palette[$i] = unpack('Cred/Cgreen/Cblue/Calpha', fread($f, 4));
		}

		//Define a paleta para da Sprite lido
		for($i = 0; $i < $header['count']; ++$i) {
			$this->list[$i]->setPalette($this->palette);
		}

		fclose($f);
	}

	/**
	 * Retorna a paleta de cores.
	 * @return array
	 */
	function getPalette() {
		return($this->palette);
	}

	/**
	 * Returna a quantidade de Sprites.
	 * @return int
	 */
	function getCount() {
		return(count($this->list));
	}

	/**
	 * Retorna o sprite correspondente ao indice.
	 * @param $index
	 * @return Sprite
	 */
	function getSprite($index) {
		if($index >= 0 and $index < count($this->list)) {
			return($this->list[$index]);
		} else {
			throw new OutOfRangeException("Invalid index, index must be between 0 and " . (count($this->list) -1));
		}
	}

	/**
	 * Retorna um array com todos os Sprites do arquivo.
	 * @return array
	 */
	function getList() {
		return($this->list);
	}

	/**
	 * Retorna a versão do arquivo
	 * @return float
	 */
	function getVersion() {
		return($this->version);
	}
}
?>
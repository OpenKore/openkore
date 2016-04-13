<?php
/**
 * Lê os arquivos ActionList (*.act)
 *
 * Essa classe cuida da leitura dos arquivos que contem dados das animações (*.act)
 *
 * @package    ActionList
 * @author     HwapX(aka Hacker_wap)
 * @copyright  2012-2013 HwapX
 * @license    http://www.php.net/license/3_01.txt  PHP License 3.01
 * @version    Release: @0.5.0@
 * @see        Action
 */

namespace RO\Action;

use RO\Action\Action;
use RO\Action\Sprite;
use RO\Action\ActionList;

require_once("/RO/Binary/functions.php");

/**
 * Representa um arquivo ACT
 */
class ActionListFile implements ActionList {
	const MAGIC = "AC";
	private $list = [];
	private $version = 0;
	private $events;
	private $delays;
	
	/**
	 * Cria o objeto e caso o nome do arquivo sejá infomado faz a chamada do metodo load
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
		$header['version'] = unpack("Cminor/Cmajor", fread($f, 2));
		$this->version = (float)($header['version']['major'] . "." . $header['version']['minor']);
		$header['count'] = freadb($f, 2, "S");
		fseek($f, 10, SEEK_CUR); //skip unknown data
		
		if($header['magic'] !== self::MAGIC) {
			throw new \UnexpectedValueException("Invalid magic header, found ({$header['magic']}) expected ({self->MAGIC})");
		}
		
		//Navega pelo arquivo e faz a leitura de todas as animações
		for($a = 0; $a < $header['count']; ++$a) {
			$action = new Action();

			$frameCount = freadb($f, 4, "V");

			for($i = 0; $i < $frameCount; ++$i) {
				fseek($f, 32, SEEK_CUR); //skip unknown data
				
				$frame = new Frame();
				$spriteCount = freadb($f, 4, "V");

				for($s = 0; $s < $spriteCount; ++$s) {
					$sprite = new Sprite();

					$sprite->setX(freadb($f, 4, "l"));
					$sprite->setY(freadb($f, 4, "l"));
					$sprite->setIndex(freadb($f, 4, "l"));
					$sprite->setMirror(freadb($f, 4, "l"));

					if($this->version >= 2.0) {
						$sprite->setColor(unpack('Cred/Cgreen/Cblue/Calpha', fread($f, 4)));
						$sprite->setScaleX(freadb($f, 4, "f"));

						if($this->version >= 2.4)
							$sprite->setScaleY(freadb($f, 4, "f"));
						else
							$sprite->setScaleY($sprite->getScaleX());

						$sprite->setRotation(freadb($f, 4, "l"));
						$sprite->setType(freadb($f, 4, "l"));

						if($this->version >= 2.5) {
							$sprite->setWidth(freadb($f, 4, "l"));
							$sprite->setHeight(freadb($f, 4, "l"));
						}
					}

					$frame->AddSprite($sprite);
				}

				if($this->version >= 2.0)
					$frame->setEventId(freadb($f, 4, "l"));

				if($this->version >= 2.3) {
					$attachPointCount = freadb($f, 4, "V");

					for($p = 0; $p < $attachPointCount; ++$p) {
						$attachPoint = new AttachPoint();

						freadb($f, 4, "v");//extra ignore
						$attachPoint->setX(freadb($f, 4, "l"));
						$attachPoint->setY(freadb($f, 4, "l"));
						$attachPoint->setAttributes(freadb($f, 4, "l"));

						$frame->addAttachPoint($attachPoint);
					}
				}

				$action->addFrame($frame);
			}

			$this->list[] = $action;
		}
		
		fclose($f);
	}
	
	/**
	 * Retorna a quantidade de ações/animações do arquivo.
	 * @return int
	 */
	function getCount() {
		return(count($this->list));
	}

	/**
	 * Retorna uma ação/animação lida do arquivo.
	 * @param $index
	 * @return Action
	 */
	function getAction($index) {
		return $this->list[$index];
	}
	
	/**
	 * Retorna a versão do arquivo.
	 * @return float
	 */
	function getVersion() {
		return($this->version);
	}
}
?>
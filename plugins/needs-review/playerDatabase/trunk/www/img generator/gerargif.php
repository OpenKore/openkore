<?php 
include_once('loginMySQL.php');

/** 
 * A leitura de dados binarios no php é um tanto quanto estranha 
 * esta função foi feita para simplificar a leitura 
 *    resource = recurso/manipulador retornado por fopen 
 *    size = tamanho que sera lido 
 *    format = formato esperado 
 *             para mais detalhes sobre os formatos suportados veja 
 *             http://www.php.net/manual/en/function.pack.php 
**/ 
function freadb($resource, $size, $format) { 
    $bd = unpack($format, fread($resource, $size));//http://www.php.net/manual/en/function.unpack.php 
    return($bd[1]); 
} 

/** 
 * Carrega o sprite e monta uma estrutura do mesmo. 
 *     fileName = nome do arquivo que vai ser carregado 
**/ 
function loadSprite($fileName) { 
    $file = fopen($fileName, "rb");//http://in.php.net/manual/en/function.fopen.php 
    /* 
    Leitura do cabeçalho 
        header 
            magic = assinatura do formato, valor esperado SP, tamanho 2 bytes 
            version = versão do arquivo 
                major = valor esperado ?, tamanho 1 byte 
                minor = valor esperado ?, tamanho 1 byte 
            count = quantidade de imagens no arquivo, tamanho 1 byte 
            unknown = desconhecido, tamanho 2 bytes 
    */ 
    $sprite['header']['magic'] = fread($file, 2);//http://in.php.net/manual/en/function.fread.php 
    $sprite['header']['version'] = unpack("Cmajor/Cminor", fread($file, 2)); 
    $sprite['header']['count'] = freadb($file, 2, 'S'); 
    $sprite['header']['unknown'] = freadb($file, 2, 'S'); 
     
    /* 
    Leitura de todas as imagens do arquivo 
        image = array com todas as imagens 
            width = largura, tamanho 2 bytes 
            height = altura, tamanho 2 bytes 
            size = tamanho dos dados da imagem comprimidos, tamanho 2 bytes 
            data = dados da imagem comprimidos, tamanho = size 
             
                Os dados da imagem estão comprimidos usando um algoritimo RLE customizado 
                somente os bytes 0x00 são comprimidos 
                00 05 FC DA 
                neste caso os dados reais seriam 
                00 00 00 00 00 FC DA 
                 
                Cada byte dos dados corresponde a uma posição na paleta de cores 
    */ 
    for($i = 0; $i < $sprite['header']['count']; $i++) { 
        $sprite['image'][$i]['width'] = freadb($file, 2, 'S'); 
        $sprite['image'][$i]['height'] = freadb($file, 2, 'S'); 
        $sprite['image'][$i]['size'] = freadb($file, 2, 'S'); 
        $sprite['image'][$i]['data'] = fread($file, $sprite['image'][$i]['size']); 
    } 
     
    /* 
    Carrego a peleta de cores 
        palette = array de 256 posições com todas as cores usadas nas imagens 
            r = nivel de cor vermelha 
            g = nivel de cor verde 			
            b = nivel de cor azul
            a = nivel de transparencia 
    */ 
    for($i = 0; $i < 256; $i++) { 
        $sprite['palette'][$i] = unpack('Cr/Cg/Cb/Ca', fread($file, 4)); 
    } 
    fclose($file);//http://in.php.net/manual/en/function.fclose.php 
    return($sprite); 
} 

/** 
 * Desenha a imagem e imprime ela na saida padrão 
 *    Sprite = estrutura retornada por loadSprite 
 *    frame = frame da imagem que sera desenhada 
 *    (...)Db = variáveis que serão usadas na consulta do banco de dados
**/ 
function drawImage($sprite, $frame, $idDb, $animationsDb, $frameDb, $subframeDb) { 
    /* 
    Verifica se o frame esta dentro dos limites 
    */ 
    if($frame < 0 || $frame >= $sprite['header']['count']) { 
        return(false); 
    } 

	/*
	Carregar as informações do ACT no banco de dados
	*/
	$actInfo = mysql_fetch_object(mysql_query('SELECT * FROM `act_list` WHERE `id` = ' . $idDb . ' AND `animations` = ' . $animationsDb . ' AND `frame` = ' . $frameDb . ' AND `subframe` = ' . $subframeDb));

	/*
	Desenhar
	*/
	if ($actInfo->width != 0) {$image['width'] = $actInfo->width;}
	if ($actInfo->height != 0) {$image['height'] = $actInfo->height;}
	
    $image = &$sprite['image'][$frame];//criação de uma referencia para simplificar o acesso 
    $img = imagecreatetruecolor($image['width'], $image['height']);//http://in.php.net/manual/en/function.imagecreatetruecolor.php 
	imagecolortransparent($img, imagecolorallocatealpha($img, $sprite['palette'][0]['r'],
														$sprite['palette'][0]['g'],
														$sprite['palette'][0]['b'],
														$sprite['palette'][0]['a']));
    $i = 0;
    $p = 0;

    while($i < $image['size']) { 
        /* 
        image->data é essencialmente uma string então pegamos o caractere da posição e usamos a função ord para pegar o seu valor ascii 
        */ 
        $b = ord($image['data'][$i]);//http://in.php.net/manual/en/function.ord.php 
        if($b == 0) { 
            /* 
            Tratamento dos bytes 00 que estão comprimidos com RLE 
            */ 
            $i++; 
            $dest = $p + ord($image['data'][$i]); 
            $color = imagecolorallocatealpha($img, $sprite['palette'][0]['r'], 
                                                   $sprite['palette'][0]['g'], 
                                                   $sprite['palette'][0]['b'], 
                                                   $sprite['palette'][0]['a']);//http://in.php.net/manual/en/function.imagecolorallocatealpha.php 
            for($p; $p < $dest; $p++) { 
                imagesetpixel($img, $p % $image['width'] + $actInfo->x, $p / $image['width'] - $actInfo->y, $color); 
            } 
        } else { 
            $color = imagecolorallocatealpha($img, $sprite['palette'][$b]['r'], 
                                                   $sprite['palette'][$b]['g'], 
                                                   $sprite['palette'][$b]['b'], 
                                                   $sprite['palette'][$b]['a']); 
            imagesetpixel($img, $p % $image['width'] + $actInfo->x, $p / $image['width'] - $actInfo->y, $color);//http://in.php.net/manual/en/function.imagesetpixel.php 
            $p++; 
        } 
        $i++; 
    }

    header('content-type: ', 'image/gif');//http://in.php.net/manual/en/function.header.php
    imagegif($img);//http://in.php.net/manual/en/function.imagegif.php 
    imagedestroy($img);//http://in.php.net/manual/en/function.imagedestroy.php 
    return(true); 
} 

if (loginMySQL()) {
	// Corpo
	$s = loadSprite('spr/oboro.spr');
	drawImage($s, $_GET['frame'], 0, 0, 0, 0);

	// Cabeça
	$s = loadSprite('spr/cabelo.spr');
	drawImage($s, $_GET['frame'], 1, 0, 0, 0);
	
	//IMPLEMENTAR AS COISAS DE CADA UM VER ULTIMOS LOG'S DA CONVERSA COM O WAP

	/*
	// Equip Top
	drawImage($s, $_GET['frame'], 0, 0, 0);

	// Equip Mid
	drawImage($s, $_GET['frame'], 0, 0, 0);

	// Equip Low
	drawImage($s, $_GET['frame'], 0, 0, 0);

	// Equip Costume Capa
	drawImage($s, $_GET['frame'], 0, 0, 0);
	*/
}
?>
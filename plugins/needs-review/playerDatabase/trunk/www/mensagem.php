<?php
	$mensagemDivAbaixo = 'Ragnarok Online © 2002-2008 Gravity Corp & Lee Myoungjin.<br>
	Este site não é endossado ou afiliado a Gravity.';

	$mensagemDivEsquerda = '<br><img src="Images/gm.png"><br>
				bROPlayer é um banco de dados dos players do Ragnarok, servidor bRO!<br>
				Isso facilita a interação entre os jogadores, planejamento em WOE\'s (tanto no lado defensor quanto no lado atacante), busca de clã...!<br>
				<i>Lembre-se: As informações sempre foram passiveis de serem recolhidas, criamos o site para que vocês possam acessar!</i><br>';

	class funcMensagem {

		function showMessage($div) {
		global $mensagemDivEsquerda, $mensagemDivAbaixo;
		if ($div == 0) echo $mensagemDivEsquerda;
		elseif($div == 1) echo $mensagemDivAbaixo;
		}
	}
		
?>
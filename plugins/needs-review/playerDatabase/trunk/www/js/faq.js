var at1 = 0;	var at2 = 0;	var at3 = 0;	var at4 = 0;
var at5 = 0;	var at6 = 0;	var at7 = 0;	var at8 = 0;
var at9 = 0;

// Parte 1
	function p1() {
		var r1 = document.getElementById("p1");
		
		if (at1 == 0){
		r1.innerHTML = 'Foi criado um sistema que recolhe as informações recebidas dos players e envia para o banco de dados desse site.<br>Não temos acesso ao banco de dados da LUG muito menos da Gravity!';
		at1 = 1;
		} else {
		r1.innerHTML = '';
		at1 = 0;
		}
	}

	function p6() {
		var r6 = document.getElementById("p6");
		
		if (at6 == 0){
		r6.innerHTML = '"Informações recebidas" são as que o Ragnarok envia para os que estiverem na sua tela, boa parte para são para exibir as animações.';
		at6 = 1;
		} else {
		r6.innerHTML = '';
		at6 = 0;
		}
	}
	
	function p2() {
		var r2 = document.getElementById("p2");
		
		if (at2 == 0){
		r2.innerHTML = 'Não, não é em tempo real. A atualização dos dados acontece a cada 12h';
		at2 = 1;
		} else {
		r2.innerHTML = '';
		at2 = 0;
		}
	}

	function p4() {
		var r4 = document.getElementById("p4");
		
		if (at4 == 0){
		r4.innerHTML = 'O sistema só recolhe em determinados mapas em determinado momento, por isso que nem todos estão aqui.';
		at4 = 1;
		} else {
		r4.innerHTML = '';
		at4 = 0;
		}
	}

// Parte 2	
	function p3() {
		var r3 = document.getElementById("p3");
		
		if (at3 == 0){
		r3.innerHTML = 'Não se preocupe. O sistema só recolhe as informações visíveis.<br>Mesmo se quissésemos, o Rangaork <b>não</b> deixa visível o seu usuário, senha e demais dados pessoais.';
		at3 = 1;
		} else {
		r3.innerHTML = '';
		at3 = 0;
		}
	}
	
	function p7() {
		var r7 = document.getElementById("p7");
		
		if (at7 == 0){
		r7.innerHTML = 'Calma... Se não quiser ter todos seus equipamentos revelados, basta desativar a opção que tem no seu Alt+Q.<br>Não tem como descobrimos os níveis das suas skills e atributos.<br>Relaxa.';
		at7 = 1;
		} else {
		r7.innerHTML = '';
		at7 = 0;
		}
	}
	
// Parte 3
	function p8() {
		var r8 = document.getElementById("p8");
		
		if (at8 == 0){
		r8.innerHTML = 'Não, mas prentendemos passar a ter ainda!';
		at8 = 1;
		} else {
		r8.innerHTML = '';
		at8 = 0;
		}
	}
	
	function p5() {
		var r5 = document.getElementById("p5");
		
		if (at5 == 0){
		r5.innerHTML = '<b>Se o servidor for oficial</b>, não se preocupe. Pretendemos fazer isso mesmo! Outros servidores oficiais terão também seu banco de dados dos players, <u>deste que a comunidade concorde</u>.<br><b>Se o servidor for privado</b>, desculpe, o trabalho é muito grande para ser implementado em um servidor privado.';
		at5 = 1;
		} else {
		r5.innerHTML = '';
		at5 = 0;
		}
	}

	function p9() {
		var r9 = document.getElementById("p9");
		
		if (at9 == 0){
		r9.innerHTML = "Trata-se das APIs que nós, desenvolvedores do bROPlayer, libermos para todos poderem usar.<br>Caso queria se aprofundar no assunto, veja na <a href=http://en.wikipedia.org/wiki/API>Wikipedia em inglês</a> ou na <a href=http://pt.wikipedia.org/wiki/API>em português</a>.";
		at9 = 1;
		} else {
		r9.innerHTML = '';
		at9 = 0;
		}
	}
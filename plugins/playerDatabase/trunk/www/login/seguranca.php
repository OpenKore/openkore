<?php*

//  Configuraчѕes do Script
// ==============================
$_SG['conectaServidor'] = true;    // Abre uma conexуo com o servidor MySQL?
$_SG['abreSessao'] = true;         // Inicia a sessуo com um session_start()?

$_SG['caseSensitive'] = false;     // Usar case-sensitive? Onde 'thiago' щ diferente de 'THIAGO'

$_SG['validaSempre'] = true;       // Deseja validar o usuсrio e a senha a cada carregamento de pсgina?
// Evita que, ao mudar os dados do usuсrio no banco de dado o mesmo contiue logado.

$_SG['servidor'] = 'localhost';    // Servidor MySQL
$_SG['usuario'] = '517532';          // Usuсrio MySQL
$_SG['senha'] = 'broplayer1!';                // Senha MySQL
$_SG['banco'] = '517532';            // Banco de dados MySQL

$_SG['paginaLogin'] = 'login.php'; // Pсgina de login

$_SG['tabela'] = 'usuarios';       // Nome da tabela onde os usuсrios sуo salvos
// ==============================


// Verifica se precisa fazer a conexуo com o MySQL
if ($_SG['conectaServidor'] == true) {
$_SG['link'] = mysql_connect($_SG['servidor'], $_SG['usuario'], $_SG['senha']) or die("MySQL: Nуo foi possэvel conectar-se ao servidor [".$_SG['servidor']."].");
mysql_select_db($_SG['banco'], $_SG['link']) or die("MySQL: Nуo foi possэvel conectar-se ao banco de dados [".$_SG['banco']."].");
}

// Verifica se precisa iniciar a sessуo
if ($_SG['abreSessao'] == true) {
session_start();
}

/**
* Funчуo que valida um usuсrio e senha
*
*
* @return bool - Se o usuсrio foi validado ou nуo (true/false)
*/
function validaUsuario($usuario, $senha) {
global $_SG;

$cS = ($_SG['caseSensitive']) ? 'BINARY' : '';

// Usa a funчуo addslashes para escapar as aspas
$nusuario = addslashes($usuario);
$nsenha = addslashes($senha);

// Monta uma consulta SQL (query) para procurar um usuсrio
$sql = "SELECT `id`, `nome` FROM `".$_SG['tabela']."` WHERE ".$cS." `usuario` = '".$nusuario."' AND ".$cS." `senha` = '".$nsenha."' LIMIT 1";
$query = mysql_query($sql);
$resultado = mysql_fetch_assoc($query);

// Verifica se encontrou algum registro
if (empty($resultado)) {
// Nenhum registro foi encontrado => o usuсrio щ invсlido
return false;

} else {
// O registro foi encontrado => o usuсrio щ valido

// Definimos dois valores na sessуo com os dados do usuсrio
$_SESSION['usuarioID'] = $resultado['id']; // Pega o valor da coluna 'id do registro encontrado no MySQL
$_SESSION['usuarioNome'] = $resultado['nome']; // Pega o valor da coluna 'nome' do registro encontrado no MySQL

// Verifica a opчуo se sempre validar o login
if ($_SG['validaSempre'] == true) {
// Definimos dois valores na sessуo com os dados do login
$_SESSION['usuarioLogin'] = $usuario;
$_SESSION['usuarioSenha'] = $senha;
}

return true;
}
}

/**
* Funчуo que protege uma pсgina
*/
function protegePagina() {
global $_SG;

if (!isset($_SESSION['usuarioID']) OR !isset($_SESSION['usuarioNome'])) {
// Nуo hс usuсrio logado, manda pra pсgina de login
expulsaVisitante();
} else if (!isset($_SESSION['usuarioID']) OR !isset($_SESSION['usuarioNome'])) {
// Hс usuсrio logado, verifica se precisa validar o login novamente
if ($_SG['validaSempre'] == true) {
// Verifica se os dados salvos na sessуo batem com os dados do banco de dados
if (!validaUsuario($_SESSION['usuarioLogin'], $_SESSION['usuarioSenha'])) {
// Os dados nуo batem, manda pra tela de login
expulsaVisitante();
}
}
}
}

/**
* Funчуo para expulsar um visitante
*/
function expulsaVisitante() {
global $_SG;

// Remove as variсveis da sessуo (caso elas existam)
unset($_SESSION['usuarioID'], $_SESSION['usuarioNome'], $_SESSION['usuarioLogin'], $_SESSION['usuarioSenha']);

// Manda pra tela de login
header("Location: ".$_SG['paginaLogin']);
}
?>
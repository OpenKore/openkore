<html>
<head>
<link rel="stylesheet" href="style.css" type="text/css" media="screen">
		<script src="js/ajaxscript.js"> </script>
		<script src="js/jquery.js"> </script>
		<script src="js/jscript.js"> </script>
</head>
	<body>
		<div id="container">
			
<?php
	include_once ("functions.php");
	$func = new functions;

	$charName = isset($_GET['charName']) ?$_GET['charName'] : null;
	$sex = isset($_GET['sex']) ?$_GET['sex'] : null;
	$lvl = isset($_GET['lvl']) ?$_GET['lvl'] : null;
	$job = isset($_GET['job']) ?$_GET['job'] : null;
	$accountId = isset($_GET['accountId']) ?$_GET['accountId'] : null;
	$flagCla = isset($_GET['flagCla']) ?$_GET['flagCla'] : null;
	$guildName = isset($_GET['guildName']) ?$_GET['guildName'] : null;
	$page = isset($_GET['page']) ?$_GET['page'] : null;
	$limit = isset($_GET['limit']) ?$_GET['limit'] : null;
	$baby = isset($_GET['baby']) ?$_GET['baby'] : null;
	$charId = isset($_GET['charId']) ?$_GET['charId'] : null;
	$eq = isset($_GET['eq']) ?$_GET['eq'] : null;
	
	if($accountId == null) {
		$paccountId = 'accountId=';
		$accountId = ' accountId = accountId';
	} else {
		$paccountId = 'accountId='.$accountId;
		$accountId = ' accountId = '.$accountId;
	}
	
	if($baby == 'true') {
		$aprendiz = 0;
		$superAprendiz = 23;
		$pbaby = '&baby=true';
		if($job>= $aprendiz && $job<=$superAprendiz ) {
				$job = $func->convertToBaby($job);
		} else {		
			echo 'Nao foi possivel converter para baby, utilizando classe original<br>';
		}
	}
		
	//echo 'Pesquisando com Base em: <br>';
	
	if($charId == null) {
		$charId = '';
		$pchaId = '&charId=';
	} else {
		$pchaId = '&charId='.$charId;
		//echo 'charId: '.$charId.'<br>';
		$charId = ' AND charId = '.$charId;
	}
	
	if($charName == null) {
		$pcharName = '&charName=';
		$charname = '';
	} else {
		$pcharName = '&charName='.charName;
		//echo 'Nome: ' .$charName.'<br>';
		$charName = ' AND charName LIKE \'%'.$charName.'%\'';
	}
	
	if($sex == null || $sex == -1) {
		$psex = '&sex=';
		$sex = '';
	} else {
		$psex= '&sex='.$sex;
		//echo 'sexo: ' .$sex.'<br>';
		$sex = ' AND sex = '.$sex;
	}
	
	if($lvl == null) {
		$plvl = '&lvl=';
		$lvl = '';
	}else {
		$plvl = '&lvl='.$lvl;
		//echo 'level: '.$lvl.'<br>';
		$lvl = ' AND lvl '.$lvl;
	}
	
	if($job == null || $job == -1) {
		$pjob = '&job=';
		$job = '';
	} else {
			$pjob = '&job='.$job;
			//echo 'Classe: ' .$job.'<br>';
			switch($job) {
			case 9911: $job = ' AND job BETWEEN 1 AND 6'; break;
			case 9912: $job = ' AND job BETWEEN 23 AND 25 OR job BETWEEN 4046 AND 4049'; break;
			case 9921: $job = ' AND job BETWEEN 7 AND 12'; break;
			case 9922: $job = ' AND job BETWEEN 14 AND 20'; break;
			case 9931: $job = ' AND job BETWEEN 4060 AND 4065'; break;
			case 9932: $job = ' AND job BETWEEN 4073 AND 4079'; break;
			case 9940: $job = ' AND job BETWEEN 4001 AND 4007'; break;
			case 9941: $job = ' AND job BETWEEN 4008 AND 4014'; break;
			case 9942: $job = ' AND job BETWEEN 4015 AND 4022'; break;
			case 9951: $job = ' AND job BETWEEN 4001 AND 4007';break;
			default:$job = ' AND job = '.$job; break;
			}
		}
	
	if($flagCla == 1) {
		$pguildName = '&guildName=';
		$guildName = '';
	} else {
		if($flagCla == 3) {
			$pguildName = '&guildName=';
			$guildName = ' AND guildName=guildName';
		} else {
			if($guildName == null) {
				$pguildName = '&guildName=';
				$guildName = '';
			} else {
				$pguildName = '&guildName='.$guildName;
				//echo 'guild: ' .$guildName.'<br>';
				$guildName = ' AND guildName LIKE \'%'.$guildName.'%\'';
			}
		}	
	}
		$pflagcla = '&flagcla='.$flagCla;
	
	if($limit == null) {
		$plimit = '&limit=';
		$limit = 20;
	} else {
		$plimit='&limit='.$limit;
	}
	
	if($page == null) {
		$ppage = '&page=';
		$page = 1;
		$limitp = 0;
	} else {
		$pageOriginal = $page - 1;
		$limitp = $pageOriginal * $limit;
		$ppage='&page='.$page;
	}
	
	
	$limitq = ' LIMIT ' .$limitp. ',' .$limit;
	
	$queryUnlimited = 'SELECT * FROM personagem WHERE ' .$accountId .$charId .$sex .$job .$lvl .$charName .$guildName;
	$queryLimited = 'SELECT * FROM personagem WHERE ' .$accountId .$charId .$sex .$job .$lvl .$charName .$guildName .$limitq;
	
	if($eq == null || $eq != 1) {
		$result = $func->showPlayersPage($queryUnlimited, $queryLimited); 
		
		echo $result;
		
		$params = $paccountId .$charId .$psex .$pjob .$plvl .$pcharName .$pflagcla .$pguildName .$plimit;
		
		$players = $func->searchTotalPlayers($queryUnlimited);
		
		$totalPages = round($players/$limit);
		$func->listPages($page, $totalPages, $params);
	}
	
	if($eq == 1) {
		$data = $func->executeQuery($queryUnlimited);
		echo $func->showPlayerEquipament($data);
	}
	
	?>
		</div>
	</body>
</html>
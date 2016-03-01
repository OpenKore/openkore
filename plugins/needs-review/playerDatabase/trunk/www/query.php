<?php
	//Class to Connect and List tha database information
	class functions {
		
		//Database Information
		private $ipAdressDataBase = '127.0.0.1';
		private $dataBase = 'broplayer';
		private $loginDataBase = 'root';
		private $passwordDataBase = '';


		//Queries		
		//List Jobs
		private $queryAprendice = 'SELECT * FROM classes WHERE idClass BETWEEN -1 and 0 ORDER BY idClass';
		private $queryJobs1_1 = 'SELECT * FROM classes WHERE idClass BETWEEN 1 and 6 ORDER BY idClass';
		private $queryJobs2_1 = 'SELECT * FROM classes WHERE idClass BETWEEN 7 and 12 ORDER BY idClass';
		private $queryJobs2_2 = 'SELECT * FROM classes WHERE idClass BETWEEN 14 and 20 ORDER BY idClass';
		private $queryJobs3_1 = 'SELECT * FROM classes WHERE idClass BETWEEN 4060 and 4065 ORDER BY idClass';
		private $queryJobs3_2 = 'SELECT * FROM classes WHERE idClass BETWEEN 4073 and 4079 ORDER BY idClass';
		private $queryJobsTrans_1_1 = 'SELECT * FROM classes WHERE idClass BETWEEN 4001 and 4007 ORDER BY idClass';
		private $queryJobsTrans_1 = 'SELECT * FROM classes WHERE idClass BETWEEN 4008 and 4014 ORDER BY idClass';
		private $queryJobsTrans_2  = 'SELECT * FROM classes WHERE idClass BETWEEN 4015 and 4022 ORDER BY idClass';
		private $queryJobsExpansives1 = 'SELECT * FROM classes WHERE idClass BETWEEN 23 and 25 ORDER BY idClass';
		private $queryJobsExpansives2 = 'SELECT * FROM classes WHERE idClass BETWEEN 4046 and 4049  ORDER BY idClass'; 
		private $queryAllJobsWitdoutBaby = 'SELECT * FROM classes WHERE idClass NOT BETWEEN 4023 and 4043 ORDER BY idClass';
	
		//List Level
		private $queryLevels = 'SELECT * FROM flagLevel ORDER BY id';

		//List Flag Cla
		private $queryCla = 'SELECT * FROM flagCla ORDER BY id';
		
		//List Flag Results
		private $queryResults = 'SELECT * FROM resultados ORDER BY id';
		
		//List Number of Player
		private $queryNumberOfPlayers = 'select count(charName) as total from personagem';

		//List Random Player
		private $queryRandomPlayer = 'SELECT * FROM personagem ORDER BY RAND() LIMIT 1';
		
		//List Sex
		private $querySex = 'SELECT * FROM flagSex ORDER BY idSex';

		//List Item Name
		private $queryItem = 'SELECT * FROM item_db WHERE id=';
		
		//Others
		private $aspa = '"';
		private $numberPagesDisplay = 3;
		
		//Link to Function JavaScript
		private $adressStart = "javascript:makeRequest('";
		private $adressFinish = "')";
		private $adressStart2 = "javascript:show_eq('";
		private $adressFinish2 = "')";
		
		//Button GoToPage
		private $startBtn =  '<input type="submit" name="goToPage" id="goToPage" value="GO!" onClick="goToPage(';
		private $finishBtn = ')">';	
		private $adressStartGoToPage = "javascript:makeRequest('searchplayer.php?";
		private $adressFinishGoToPage = "','content')";		
		
		
		function openConnectionDatabase() {
			$connection = mysql_connect($this->ipAdressDataBase, $this->loginDataBase, $this->passwordDataBase);
			$selectDataBase = mysql_select_db($this->dataBase, $connection);
			
			if (!$connection) {
				die('Erro ao conectar no Banco de Dados: ' . mysql_error());
			} else {
				if (!$selectDataBase) {
					die ('Erro ao conectar no DataBase: ' . mysql_error());
				}
			}
		}


		function executeQuery($query) {
			self::openConnectionDatabase();
			$resultSet = mysql_query($query);
			return $resultSet;
		}
		

		function listJobs() {
			self::subListJobs($this->queryAprendice);
			
			echo '<option value ="9911">-- Classes 1-1 --</option>';
			self::subListJobs($this->queryJobs1_1);
			
			echo '<option value ="9912">-- Classes Expandiveis --</option>';
			self::subListJobs($this->queryJobsExpansives1);
			self::subListJobs($this->queryJobsExpansives2);

			echo '<option value ="9921">-- Classes 2-1 --</option>';
			self::subListJobs($this->queryJobs2_1);

			echo '<option value ="9922">-- Classes 2-2 --</option>';
			self::subListJobs($this->queryJobs2_2);

			echo '<option value ="9940">-- Classes Trans --</option>';
			self::subListJobs($this->queryJobsTrans_1_1);
			
			echo '<option value ="9941">-- Classes Trans-1 --</option>';
			self::subListJobs($this->queryJobsTrans_1);
			
			echo '<option value ="9942">-- Classes Trans-2 --</option>';
			self::subListJobs($this->queryJobsTrans_2);
			
			echo '<option value ="9931">-- Classes 3-1 --</option>';
			self::subListJobs($this->queryJobs3_1);
			
			echo '<option value ="9932">-- Classes 3-2 --</option>';
			self::subListJobs($this->queryJobs3_2);			
		}
		
	
		function subListJobs($queryJob) {
			$result = self::executeQuery($queryJob);
			
			while($data = mysql_fetch_array($result)){
				echo '<option value ="'.$data['idClass'].'">'.$data['nameClass'].'</option>';
				
			}
		}
		
		
		function listLevels() {
			$result = self::executeQuery($this->queryLevels);
			
			while($data = mysql_fetch_array($result)){
				echo '<option value ="BETWEEN ' .$data['lvlMin'].' AND ' .$data['lvlMax']. '">'.$data['lvlMin']. ' - '.$data['lvlMax'].'</option>';
			}
		}	
	
	
		function listFlagCla() {
			$result = mysql_query($this->queryCla);
			
			while($data = mysql_fetch_array($result)){
				echo '<option value ="'.$data['id'].'">'.$data['flag'].'</option>';
			}
		}	
		
		
		function listResults() {
			$result = mysql_query($this->queryResults);
			
			while($data = mysql_fetch_array($result)){
				echo '<option value ="'.$data['num'].'">'.$data['num'].'</option>';
			}
		}
		
		
		function listMenu() {
	
			echo '<div id="underlinemenu">
				<ul>
					<li><a href="index.php">Home</a></li>
					<li><a href="'.$this->adressStart.'faq.html'.$this->adressFinishGoToPage.'">FAQ</a></li>
					<li><a href="'.$this->adressStart.'graficos.php'.$this->adressFinishGoToPage.'">Graficos</a></li>
					<li>';
			if (!isset($_SESSION['usuarioID']) OR !isset($_SESSION['usuarioNome'])) {
				echo '<a href="javascript:LoginPopUp()">Login</a></li>';
			} else {
				echo '<a href="/">Conta</a></li>';
			}
			
			echo '</ul>
				</div>';	
		}
		
		
		function listFlagSex() {
			$result = self::executeQuery($this->querySex);
			
			while($data = mysql_fetch_array($result)){
				echo '<option value ="'.$data['idSex'].'">'.$data['nameSex'].'</option>';
			}
		}	
		

		function convertToBaby($job) {
			$idBaby = 4023;
			$idClass = $job + $idBaby;
			return $idClass;
			
		}

		function showCountPlayer() {
			$result = self::executeQuery($this->queryNumberOfPlayers);
			
			if(mysql_fetch_array($result)) {
				while($data=mysql_fetch_array($result)) {
					echo '<br>';
					echo ('Total de Players Registrados: ' .$data['total']);
				}
			} else {
				echo ('Nenhum player foi encontrado!');
			}
		}
	
		
		function showRandomPlayer() {
			$result = self::executeQuery($this->queryRandomPlayer);

			while($data=mysql_fetch_array($result)){
				self::showPlayerData($data);
			}	

		}
		
		function showPlayerData($data) {

			if(isset($data['accountId'])) {
				$urlAccount = '<a href="'.$this->adressStart.'accountId='.$this->adressFinish.'"><img src="Images/a.png"></a>';
			} else {
				$urlAccount = ' ';		
			}
			
			if(isset($data['charId'])) {
				$urlEquip = '<a href="'.$this->adressStart2.$data['charId'].$this->adressFinish.'"><img src="Images/e.png">';
			} else {
				$urlEquip = ' ';
			}
			
			if(isset($data['partyId'])) { 
				$urlParty = $this->adressStart.'partyId='.$data['partyId'].$this->adressFinish;
			} else {
				$urlParty = ' ';
			}
			
			if(isset($data['guildId'])) {	
				$urlGuild = $this->adressStart.'guildId='.$data['guildId'].$this->adressFinish;
			} else {
				$urlGuild = ' ';
			}
			
			echo '<div class="personagem" id="'.$data['charId'].'">
				<table class = "pTable">
					<tr>
					<td>'.$urlAccount.'</td>
					<td>'.$urlEquip.'</a></td>
					<td><a href="'.$urlParty.'"><img src="Images/p.png"></a></td>
					<td><a href="'.$urlGuild.'"><img src="Images/g.png"></a></td>
					<td><img src="Images/o.png"></td>
					</tr>
					<tr>
						<td>lv.'.$data['lvl'].'</td>
					<td colspan=4 class="p"><image src="Images/gm.png"></td>
					</tr>
					<tr>
						<td rowspan=2>EBM</td>
						<td colspan=4 class="name">'.$data['charName'].' '.$data['partyName'].'</td>
					</tr>
						<td colspan=4 class="name">'.$data['guildName'].' '.$data['guildPosition'].'</td>
					</tr>
				</table>
				</div>';
		}
		
		
		function showPlayerEquipament($data) {
					echo '<div class="personagem" id="'.$data['$charId'].'">';
					echo '<table class = "pTable">';
					echo '<tr>
								<td>'.self::showEqImage($data['$equipHeadTop']).'</td> <td>'.self::showEqName($data['equipHeadTop']).'</td>
								<td rowspan="5"><image src="Images/gm.png"></td>
								<td>'.self::showEqName($data['equipHeadMid']).'</td> <td>'.self::showEqImage($data['equipHeadMid']).'<td>
							</tr>
							<tr>
								<td>'.self::showEqImage($data['$equipHeadLow']).'</td> <td>'.self::showEqName($data['equipHeadLow']).'</td> 
								<td>'.self::showEqName($data['equipBody']).'</td> <td>'.self::showEqImage($data['$equipBody']).'</td>
							</tr>
							<tr>
								<td>'.self::showEqImage($data['$equipBodyWeapon']).'</td> <td>'.self::showEqName($data['equipBodyWeapon']).'</td> 
								<td>'.self::showEqName($data['equipBodyShield']).'</td> <td>'.self::showEqImage($data['equipBodyShield']).'</td>
							</tr>										
							<tr>
								<td>'.self::showEqImage($data['$equipBodyRobe']).'</td> <td>'.self::showEqName($data['equipBodyRobe']).'</td> 
								<td>'.self::showEqName($data['equipBodyShoes']).'</td> <td>'.self::showEqImage($data['$equipBodyShoes']).'</td>
							</tr>										
							<tr>
								<td>'.self::showEqImage($data['$acessoryLeft']).'</td> <td>'.self::showEqName($data['acessoryLeft']).'</td> 
								<td>'.self::showEqName($data['acessoryRight']).'</td> <td>'.self::showEqImage($data['$acessoryRight']).'</td>
							</tr>';
					echo '</table>';
					echo '</div>';
		}
		
		
		function showUserName() {
			if (!isset($_SESSION['usuarioID']) OR !isset($_SESSION['usuarioNome'])) {
				echo 'Bem Vindo, visitante!';
			} else {
				echo 'Bem Vindo, ' .$_SESSION['usuarioNome'].'!';	
			}
		}
		
		
		function searchTotalPlayers($queryUnlimited) {
			$total = self::executeQuery($queryUnlimited);
			$total = mysql_num_rows($total);
			return $total;	
		}


		function searchPlayerLimited($queryLimited) {			
			$total = self::executeQuery($queryLimited);
			return $total;	
		}
		
		
		function showPlayersPage($queryUnlimited, $queryLimited) {
			$cont = 1;
			$total = self::searchTotalPlayers($queryUnlimited);
			$result = self::searchPlayerLimited($queryLimited);
			echo '<br>';

			
			echo '<br>';	
			if($total == 0) echo '<label>Nenhum Player Encontrado</label>';
			if($total == 1) echo '<label>Player Encontrado: '.$total.'</label>';
			if($total > 1) echo '<label>Players Encontrados: '.$total.'</label>';
	
			if($total != 0 ) {
				while($data=mysql_fetch_array($result)) {
					if($cont == 1)  {
						echo '<div class="jump">.</div>';
						print("<tr>");
					}
						self::showPlayerData($data);
										
					  if($cont == 3) {
							print("</tr>");
							$cont = 1;
					  } else {
						$cont++;
					  }
				}
			}
			
		}
		
		
		function listPages($page, $totalPages, $params) {
			$auxP = $page + $this->numberPagesDisplay;
			$auxN = $page - $this->numberPagesDisplay;
			$aux = $page;
			$aux2 = $page;
			$adressStartGoToPage = $this->adressStartGoToPage.$params;
			$paramsBtn = "'".$params."','".$totalPages."'";
			
			echo '<div class="pagination">';
			//show first page 
			if($auxN > 1 && $page > 1) {
				echo '<a href="'.$adressStartGoToPage.'&page=1'.$this->adressFinishGoToPage.'"> Primeira </a>';
			}
			
			//show pages before
			while($auxN < $page) {
				if($auxN >= 1 && $auxN < $page) {
					echo '<a href="'.$adressStartGoToPage.'&page='.$auxN.$this->adressFinishGoToPage.'"> '.$auxN.' </a>';
				}
				$auxN++;
			}
			
			
			//show this page
			echo $page;
		
			//show pages after
			if($auxP < $totalPages) {
				while($aux < $auxP) {
					$aux++;
					echo '<a href="'.$adressStartGoToPage.'&page='.$aux.$this->adressFinishGoToPage.'"> '.$aux.' </a>';
				}
			} else {
				while($aux2 < $totalPages) {
					$aux2++;
					echo '<a href="'.$adressStartGoToPage.'&page='.$aux2.$this->adressFinishGoToPage.'"> '.$aux2.'</a>';
				}
			}
				
			
			//show last Page
			if($auxP < $totalPages && $page != $totalPages) {
				echo '<a href="'.$adressStartGoToPage.'&page='.$totalPages.$this->adressFinishGoToPage.'"> Ultima </a>';
			}
			
			//show go to page
			echo 'Pagina: ';
			echo '<input type="text" maxlength=4 size=4 id="goPage">';
			echo $this->startBtn.$paramsBtn.$this->finishBtn;
			echo '<label id="msgmPg"></label>';
			echo '</div>';
		}
		
		/*
		TUDO ISSO SERÁ PASSADO PARA O gerarnomeequipamentos.php
		function showEq($queryUnlimited) {
			$queryLimited = $queryUnlimited;
			$result = self::searchPlayerLimited($queryLimited);
			
			while($data=mysql_fetch_array($result))  {
				self::showPlayerEquipament($data);
			}
		}
		

		function showEqName($itemId) {

			if($itemId != 0 && $itemId != NULL) {
				$queryItem = $queryItem.$itemId;
				$result = self::executeQuery($queryItem);

				while($data=mysql_fetch_array($result))  {
					$name = $data['name_japanese'];
				}
				
				$newtext = wordwrap($name, 24, '<br/>', true);
				echo $newtext;
			}
		}
		*/
		
		function showEqImage($itemId) {
			if($itemId != 0 && $itemId != NULL) {
				echo '<img src="http://www3.worldrag.com/database/media/item/'.$itemId.'.gif"> ';
			}
		}
		
	}
?>
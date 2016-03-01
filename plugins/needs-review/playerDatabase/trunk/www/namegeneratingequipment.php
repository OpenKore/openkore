<html>
<?php
$get_item_id = isset($_GET['item_id']) ?$_GET['item_id'] : null;
$get_slot1 = isset($_GET['slot1']) ?$_GET['slot1'] : null;
$get_slot2 = isset($_GET['slot2']) ?$_GET['slot2'] : null;
$get_slot3 = isset($_GET['slot3']) ?$_GET['slot3'] : null;
$get_slot4 = isset($_GET['slot4']) ?$_GET['slot4'] : null;
$get_refine = isset($_GET['refine']) ?$_GET['refine'] : null;
echo('get_item_id: ' . $get_item_id . ' - get_slot1: ' . $get_slot1 . ' - get_slot2: ' . $get_slot2 . ' - get_slot3: ' . $get_slot3 . ' - get_slot4: ' . $get_slot4 . ' - get_refine: ' . $get_refine . '<br><br>');

include_once('loginMySQL.php');

function nameGeneratingEquipment($item_id, $slot1, $slot2, $slot3, $slot4, $refine) {
	if (loginMySQL()) {
		// Defining variables
			$slotText = '';

		// Take the name of your equipment through its ID in the database 'item_db'
			$nome = mysql_fetch_object(mysql_query('SELECT * FROM `item_db` WHERE `id` = ' . $item_id));

		// Treat slots
		$slotArray = array($slot1, $slot2, $slot3, $slot4); // Array with all 4 slots

		if (count(array_filter($slotArray, function ($val) {return $val > 0;}) > 0)) { // Enable if you have at least one slot that is greater than 0
			if ($slot1 == 255) { // Equipment created by a player (Practically the same idea misc.pm line ~ 1756)
			// slot1 -> 255					|	slot3 -> Id with of the char
			// slot2 -> Element of weapon	|	slot4 -> Force Weapon
			
				$textElement = array(0 => ' ', 1 => 'Glacial', 2 => 'Mineral', 3 => 'Flamejante', 4 => 'Trovejante'); // Array with the names of the elements weapon (msgstringtable.txt line 451 ~ 455)
				$textForce = array(1 => 'Forte', 2 => 'Muito Forte', 3 => 'Fortíssima'); // Array with the names of the forces weapon (msgstringtable.txt line 460 ~ 462)
				$query = mysql_fetch_object(mysql_query('SELECT * FROM `list_id_nick` WHERE `id` = ' . $slot3));
				
				$slotText = $textElement[$slot2] . ' ' . $textForce[$slot4] . ' <font color="#564f9c">' . $query->nick . '</font>';
			} else {
				$textRate = array(1 => '', 2 => ' Bi', 3 => ' Trip', 4 => ' Quád');	// Array with the names of the repetition the cards (msgstringtable.txt line 447 ~ 449)
				$cardRead = array();												// Array that will store the cards that have already been added to the $slotText, not to repeat them
				$rate = array_count_values($slotArray);								// Array that returns the frequency of times each term appears in $cardArray

				// Start loop
				for ($i = 0; $i < 4; $i++) {
					if ($slotArray[$i] != 0 && !in_array($slotArray[$i], $cardRead)) {
					$query = mysql_fetch_object(mysql_query('SELECT * FROM `card_prefix` WHERE `id` = ' . $slotArray[$i]));

					$slotText = $slotText . ' ' . $query->textPrefix . $textRate[$rate[$slotArray[$i]]];
					$cardRead[$i] = $slotArray[$i];
					}
				}
				// End loop
			}
		}

		// Treating refine
		if ($refine != '0') {
			$refine = '+ ' . $refine . ' ';
		} else {
			$refine = '';
		}

		// Return the name of the equipment
		echo($refine);
		echo($nome->name_japanese);
		echo(' ' . $slotText);
	}
}

nameGeneratingEquipment($get_item_id, $get_slot1, $get_slot2, $get_slot3, $get_slot4, $get_refine);
?>
</html>
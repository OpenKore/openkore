<?php 
/************************************************************* 
* MOD Title:   Prune users
* MOD Version: 1.4.2
* Translation: English
* Rev date:    19/12/2003 
* 
* Translator:  Niels < ncr@db9.dk > (Niels Chr. Rød) http://mods.db9.dk 
* 
**************************************************************/

// add to prune inactive
$lang['X_Days'] = '%d Days';
$lang['X_Weeks'] = '%d Weeks';
$lang['X_Months'] = '%d Months';
$lang['X_Years'] = '%d Years';

$lang['Prune_no_users']="No users deleted";
$lang['Prune_users_number']="The following %d users were deleted:";

$lang['Prune_user_list'] = 'Users who will be deleted';
$lang['Prune_on_click'] = 'You are about to delete %d users. Are you sure?';
$lang['Prune_Action'] = 'Click link below to execute';
$lang['Prune_users_explain'] = 'From this page you can prune users. You can choose one of three links: delete old users who have never posted, delete old users who have never logged in, delete users who have never activated their account.<p/><b>Note:</b> There is no undo function.';
$lang['Prune_commands'] = array();

// here you can make more entries if needed
$lang['Prune_commands'][0] = 'Prune non-posting users';
$lang['Prune_explain'][0] = 'Who have never posted, <b>excluding</b> new users from the past %d days';
$lang['Prune_commands'][1] = 'Prune inactive users';
$lang['Prune_explain'][1] = 'Who have never logged in, <b>excluding</b> new users from the past %d days';
$lang['Prune_commands'][2] = 'Prune non-activate users';
$lang['Prune_explain'][2] = 'Who have never been activated, <b>excluding</b> new users from the past %d days';
$lang['Prune_commands'][3] = 'Prune long-time-since users';
$lang['Prune_explain'][3] = 'Who have not visited for 60 days, <b>excluding</b> new users from the past %d days';
$lang['Prune_commands'][4] = 'Prune not posting so often users';
$lang['Prune_explain'][4] = 'Who have less than an avarage of 1 post for every 10 days while registered, <b>excluding</b> new users from the past %d days'; 

?>

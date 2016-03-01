AUTHOR: hakore
Ported to 2.1 by Kissa2k
Version 2.1

Настройки плагина в config.txt:

    reactOnKillSteal (boolean flag)
    - enables/disables the plugin.
    reactOnKillSteal_timeout (seconds)
    - specifies the minimum time to wait before reacting again.
    reactOnKillSteal_timeout (seconds)
    - specifies the minimum time to wait before reacting again.
    reactOnKillSteal_timeoutSeed (seconds)
    - if this is set, the timeout will be increased by a random value less than or equal to the specified time (in seconds). Use this to prevent Kore from reacting in fixed time intervals, which makes it more suspicious.
    reactOnKillSteal_forgetReactions (seconds)
    - if this option is set, the number of reactions you executed for a certain player will be forgotten if the specified number of seconds has elapsed since the last reaction to that player was executed.
    reactOnKillSteal (commands)
    commands: a double semi-colon ;; separated list of console commands.
    A random command out of this list will be executed if the conditions are met for this block. This command will be executed the first time you detect a kill steal hit to a monster.

    reactOnKillSteal Attributes:
        reactions (range)
        - if this option is set, only react if the total number of your reactions to the player due to kill stealing is within the specified range. This is useful for choosing the right flavor of reactions based on how many times you have already reacted. Use this to switch between reactOnKillSteal blocks.
        attackTargetOnly (boolean flag)
        - by default, Kore will react when all monsters who are currently attacking Kore (aggressives) is kill stealed. Set this option to 1 to ignore kill stealing of monsters that you are not attacking.
        damage (range)
        - if this option is set, only react when the damage done to monster due to the kill steal attack is within the specified range. If this is not set Kore will react on kill steals regardless of the damage. If you want to react only on misses, set this to "0".
        isSkill (boolean flag)
        - if this option is not specified, Kore will react regardless of the type of action done to kill steal your monster. Set this to 1 if you want to react only if a skill is used. Otherwise set this to 0 if you don't want to react on skills.
        skills (list of skills)
        skills: a comma-separated list of skill names.
        - if this option is set, only react when the skill used againts our monster is in this list.
        notSkills (list of skills)
        skills: a comma-separated list of skill names.
        - if this option is set, never react when the skill used againts our monster is in this list.
        notTankModeTarget (name)
        - if this option is set, Kore will not react on beeing kill stealed by player that specified as tank.
        isCasting (boolean flag)
        - if this option is not specified, Kore will react whether a skill is being cast or not. Set this to 1 if you want to react only if a skill is being cast. Otherwise set this to 0 if you don't want to react on skill casting.

        monster_name (list of names)
        - if this option is set, Kore will react only if the name of the monster being kill stealed is in this list.
        monster_notName (list of names)
        - if this option is set, Kore will never react if the name of the monster being kill stealed is in this list.
        monster_whenStatusActive (list of statuses)
        - if this option is set, Kore will react only if one of the statuses in this list is currently active on the monster being kill stealed.
        monster_whenStatusInactive (list of statuses)
        - if this option is set, Kore will react only if all statuses in this list is not active on the monster being kill stealed.
        monster_whenGround (list of ground spells)
        - if this option is set, Kore will react only if one of the ground spells in this list is currently active on the ground where the monster is standing.
        monster_whenNotGround (list of ground spells)
        - if this option is set, Kore will react only if all ground spells in this list is not active on the ground where the monster is standing.
        monster_dist (range)
        - if this option is set, Kore will react only if the distance between you and the monster being kill stealed is within the specified range.

        player_id (list of IDs)
        - if this option is set, Kore will react only if the ID of the kill stealer is in this list.
        player_notId (list of IDs)
        - if this option is set, Kore will never react if the ID of the kill stealer is in this list.
        player_name (list of names)
        - if this option is set, Kore will react only if the name of the kill stealer is in this list.
        player_notName (list of names)
        - if this option is set, Kore will never react if the name of the kill stealer is in this list.
        player_whenStatusActive (list of statuses)
        - if this option is set, Kore will react only if one of the statuses in this list is currently active on the kill stealer.
        player_whenStatusInactive (list of statuses)
        - if this option is set, Kore will react only if all statuses in this list is not active on the kill stealer.
        player_whenGround (list of ground spells)
        - if this option is set, Kore will react only if one of the ground spells in this list is currently active on the ground where the kill stealer is standing.
        player_whenNotGround (list of ground spells)
        - if this option is set, Kore will react only if all ground spells in this list is not active on the ground where the kill stealer is standing.
        player_lvl (range)
        - if this option is set, Kore will react only if the level of the kill stealer is within the specified range.
        player_dist (range)
        - if this option is set, Kore will react only if the distance between you and the kill stealer is within the specified range.
        player_isJob (list of job classes)
        - if this option is set, Kore will react only if the job of the kill stealer is in this list.
        player_isNotJob (list of job classes)
        - if this option is set, Kore will never react if the job of the kill stealer is in this list.
        player_inGuild (list of guild names)
        - if this option is set, Kore will react only if the name of the guild of the kill stealer is in this list.
        player_notInGuild (list of guild names)
        - if this option is set, Kore will never react if the name of the guild of the kill stealer is in this list.
        player_sex (flag)
        flag: 1 = Boy, 0 = Girl
        - if this option is set, Kore will react only if the kill stealer is of the specified sex.
        player_damage (range)
        - if this option is set, only react when the total damage done by the kill stealer to the monster is within the specified range.
        player_misses (range)
        - if this option is set, only react when the total number of misses by the kill stealer to the monster is within the specified range.
        player_ksCount (range)
        - only react if the number of unique monsters kill stealed by this player from you is within the given range. This is useful to determine how you will react on players who keep on kill stealing your monster no matter how you react. For example, if this count reaches 5 or more, you may conclude that the kill stealer is a ks-bot who just ignores your warnings. You may also configure the intensity of your reactions on such events.


Special keywords for commands
To be able to maximize the power offered by console commands used in this plugin, some keywords can be used with commands. These are useful when using the "pm" command, as well as skill use commands.

    @monsterNum - this keyword will be replaced by the number of monster being kill stealed.
    @monsterName - this keyword will be replaced by the name of monster being kill stealed.
    @playerNum - this keyword will be replaced by the player number of kill stealer.
    @playerName - this keyword will be replaced by the player name of kill stealer.

Examples:
reactOnKillSteal e omg;;c this is my monster {
	reactions 0
	player_ksCount < 3
	attackTargetOnly 1
}

reactOnKillSteal c my monster!;;pm @playerName killstiller! {
	reactions 1
	player_ksCount < 3
	attackTargetOnly 1
	notSkills Lex Aeterna, Decrease AGI
}
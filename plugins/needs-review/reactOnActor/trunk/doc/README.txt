AUTHOR: hakore
Ported to 2.1 by Kissa2k
Version 2.1
see: http://rofan.ru/viewtopic.php?p=90243#p90243

Settings in config.txt:

	reactOnActor (command)
	This option specifies the command to use if all conditions are met for this block. Special keywords can be used on the specified commands (see below)

	Block conditions:
		timeout (seconds)
		- specifies the minimum time to wait before reacting again.

	Actor conditions:
		actor_id (list of numbers)
		actor_type (player|monster|pet|npc|portal)
		actor_whenStatusActive (list of status names)
		actor_whenStatusInactive (list of status names)
		actor_name (list of names)
		actor_notName (list of names)
		Note: name and notName may not work well for players and npcs. It is still experimental. I have this assumption that it will work, but not instantly. This however will NEVER work on portals.
		actor_lvl (range)
		actor_x (range)
		actor_y (range)
		actor_dist (range)
		actor_walkSpeed (range)

	Player conditions:
	Note: The following conditions will only work if the actor is a player.
		actor_isJob (list of job classes)
		actor_isNotJob (list of job classes)
		actor_isGuild (list of guild names)
		actor_isNotGuild (list of guild names)
		actor_isParty (list of party names)
		actor_isNotParty (list of party names)
		Note: isGuild, isNotGuild, isParty, and isNotParty may not work well. It is still experimental. I have this assumption that it will work, but not instantly.
		actor_topHead (list of headgears)
		actor_midHead (list of headgears)
		actor_lowHead (list of headgears)
		actor_weapon (list of equipments)
		actor_shield (list of equipments)
		Note: topHead, midHead, lowHead, weapon, and shield should be specified as simple item names (without the card slots)..
		actor_sex (0|1)
		Note: For sex, use 0 for girls and 1 for boys.
		actor_isDead (boolean flag)
		actor_isSitting (boolean flag)
		Shared self conditions
		This block uses the shared self conditions (see the openkore manual).


	Special command keywords:
		$actor->{ID|binID|name|type|x|y}
		This keywords are replaced with their internal equivalent
			IDthe packed Actor ID (use this only on eval commands)
			binIDthe index of the actor. This can be used for commands like sp or sm (e.g. sp 28 $actor->{binID})
			namethe name of the actor (may not properly work for players and npcs)
			typethe type of the actor (player, monster, pet, npc, or portal)
			x
			x
			the x- and y-coordinates of the actor, respectively.

Example:

reactOnActor c heal please {
   actor_type player
   actor_isJob Acolyte, Priest
   actor_dist < 8
   actor_lvl > 20
   actor_isDead 0
   actor_timeout 300
   hp < 50%
   inLockOnly 1
}
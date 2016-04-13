AUTHOR: 4epT
Version 4

alertSound($event)
$event: unique event name

Plays a sound if plugin alertSound is enabled (see sys.txt), and if a sound is specified for the event.

The config option "alertSound_#_eventList" should have a comma seperated list of all the desired events.

Supported events:
	death, emotion, teleport, map change, monster <monster name>, player <player name>, player *, GM near,
	private GM chat, private chat, public GM chat, npc chat, public chat, system message

example config.txt:

alertSound - {
	eventList public gm chat
	notInTown 0
	inLockOnly 0
	play sounds\alarm.wav
}
alertSound - {
	eventList private chat
	notInTown 0
	inLockOnly 0
	play sounds\phone.wav
}
alertSound - {
	eventList death
	notInTown 0
	inLockOnly 0
	play sounds\blip2.wav
}
alertSound - {
	eventList monster Poring, player 4epT
	notInTown 1
	inLockOnly 1
	play sounds\birds.wav
}
alertSound - {
	eventList teleport, public chat, emotion
	notInTown 1
	inLockOnly 0
	play sounds\birds.wav
}
alertSound - {
	eventList private GM chat, map change
	notInTown 0
	inLockOnly 0
	play sounds\alarm.wav
}
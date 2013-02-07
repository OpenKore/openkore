# Updated by Windham Wong (DrKNa)
# Updated by Snoopy
# original code from Joseph
# original code from MessyKoreXP
# licensed under GPL

#   Methods (choose one)
#   0 - Random position outside <avoidSkill_#_radius> by <avoidSkill_#_step>
#   1 - Move to opposite side by <avoidSkill_#_step>
#   2 - Move nearest enemy.
#   3 - Teleport
#   4 - Attack (monsters only)
#   5 - Use skill. (monsters only)

Put these lines into config.txt:

avoidSkill 0
avoidSkill_domain info

avoidSkill {
	radius 5
	step 5
	source
	method 0
	skill
	isSelfSkill
	lvl
	maxCastTime
	minCastTime
	domain
}
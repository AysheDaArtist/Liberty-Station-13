/mob/living/carbon/superior_animal/roach/tazntz
	name = "Eldritch Roach"
	icon_state = "tzantz"
	desc = "A mass of twitching and squirming limbs, the seemingly apperent abomination of a frog and roach melded together."
	meat_amount = 2
	turns_per_move = 4
	maxHealth = 100
	health = 100
	move_to_delay = 4
	mob_size = MOB_MEDIUM
	density = TRUE
	knockdown_odds = 1

	melee_damage_lower = 8
	melee_damage_upper = 12

	armor = list(melee = 15, bullet = 10, energy = 5, bomb = 5, bio = 20, rad = 0, agony = 0)
	armor_penetration = 35

// frogs dont slip over on water or soap.
/mob/living/carbon/superior_animal/roach/tazntz/slip(slipped_on,stun_duration=8)
	return FALSE

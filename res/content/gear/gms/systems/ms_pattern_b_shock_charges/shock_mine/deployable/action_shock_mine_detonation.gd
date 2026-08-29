# Copyright (c) 2026 Wickworks ♡ Lancer Tactics v1.2.4
extends ActionSystemMineDetonation

func activate_detonation_effects(all_targets:Array[Unit], forcing_action:SpecificAction, blast_tiles:Array[Vector2i], activation:EventCore) -> void:

	await CommonActionUtil.queue_damage_events_with_save_for_half(activation, forcing_action, all_targets, 4, Lancer.DAMAGE_TYPE.HEAT, Lancer.HASE.ENG,
	#FAILURE
	func(failed_target:Unit) -> void:
			UnitCondition.apply_status(activation, failed_target, Lancer.STATUS.JAMMED, Lancer.UNTIL.END_OF_NEXT_TURN, activation.context.gear.persistent_id)
			)

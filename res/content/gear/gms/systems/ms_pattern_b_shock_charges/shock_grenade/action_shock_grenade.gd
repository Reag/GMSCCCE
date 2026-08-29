# Copyright (c) 2026 Wickworks ♡ Lancer Tactics v1.2.4
extends ActionSystemGrenade

func do_grenade_effect(activation:EventCore, specific:SpecificAction, aoe_tiles:Array[Vector2i], target_units:Array[Unit]) -> void:

	await CommonActionUtil.queue_damage_events_with_save_for_half(activation, specific, target_units, 2, Lancer.DAMAGE_TYPE.HEAT, Lancer.HASE.ENG,
	#FAILURE
	func(failed_target:Unit) -> void:
			UnitCondition.apply_status(activation, failed_target, Lancer.STATUS.IMPAIRED, Lancer.UNTIL.END_OF_NEXT_TURN, activation.context.gear.persistent_id)
			)

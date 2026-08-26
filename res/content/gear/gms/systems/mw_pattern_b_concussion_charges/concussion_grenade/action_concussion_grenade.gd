# Copyright (c) 2026 Wickworks ♡ Lancer Tactics v1.2.4
extends ActionSystemGrenade

func do_grenade_effect(activation:EventCore, specific:SpecificAction, aoe_tiles:Array[Vector2i], target_units:Array[Unit]) -> void:

	# queue up unit damage events
	await CommonActionUtil.queue_damage_events_with_save_for_half(
		activation, specific, target_units, 0, Lancer.DAMAGE_TYPE.EXPLOSIVE, Lancer.HASE.HULL,
		# FAILURE
		func(failed_target:Unit) -> void:
				activation.queue_events(CommonActionUtil.generate_knockback_events(
					failed_target,
					2,
					SpecificAction.from_context(activation.context)
				)),
		# SUCCESS
		func(failed_target:Unit) -> void:
				activation.queue_events(CommonActionUtil.generate_knockback_events(
					failed_target,
					1,
					SpecificAction.from_context(activation.context)
				))
	)

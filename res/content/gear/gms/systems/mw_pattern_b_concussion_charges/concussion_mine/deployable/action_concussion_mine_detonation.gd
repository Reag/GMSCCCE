# Copyright (c) 2026 Wickworks ♡ Lancer Tactics v1.2.4
extends ActionSystemMineDetonation

func activate_detonation_effects(all_targets:Array[Unit], forcing_action:SpecificAction, blast_tiles:Array[Vector2i], activation:EventCore) -> void:
	var damage_amount = Action.roll_damage('2d6', forcing_action.unit)

	# queue up unit damage events
	await CommonActionUtil.queue_damage_events_with_save_for_half(
		activation, forcing_action, all_targets, damage_amount, Lancer.DAMAGE_TYPE.EXPLOSIVE, Lancer.HASE.AGI
	)

	activation.queue_event(&'event_map_damage', {
		target_tiles = blast_tiles,
		number = damage_amount,
		flags = [EventMapDamage.FLAG.BURN],
	})

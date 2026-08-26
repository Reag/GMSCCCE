# Copyright (c) 2026 Wickworks ♡ Lancer Tactics v1.2.4
extends ActionSystemGrenade

func do_grenade_effect(activation:EventCore, specific:SpecificAction, aoe_tiles:Array[Vector2i], target_units:Array[Unit]) -> void:
	# roll for damage
	var damage_amount:int = Action.roll_damage('1d6', specific.unit)

	# queue up map damage events
	activation.queue_event(&'event_map_damage', {
		target_tiles = aoe_tiles,
		number = damage_amount,
		flags = [EventMapDamage.FLAG.BURN]
	})

	# queue up unit damage events
	await CommonActionUtil.queue_damage_events_with_save_for_half(
		activation, specific, target_units, damage_amount, Lancer.DAMAGE_TYPE.EXPLOSIVE, Lancer.HASE.AGI
	)

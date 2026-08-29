# Copyright (c) 2026 Wickworks ♡ Lancer Tactics v1.2.4
extends ActionSystemGrenade

func do_grenade_effect(activation:EventCore, specific:SpecificAction, aoe_tiles:Array[Vector2i], target_units:Array[Unit]) -> void:

	for target:Unit in target_units:
		if not Unit.is_valid(target): continue

		var passed_save:bool = await UnitHasecheck.make_save(activation, target, specific, Lancer.HASE.HULL)
		var knockback_amount:int = 1 if passed_save else 2
		await activation.queue_events(CommonActionUtil.generate_knockback_events(
					target,
					knockback_amount,
					SpecificAction.from_context(activation.context),
					specific.unit.occupied_tiles(),
					[EventUnitPickMove.FLAG.AUTO_FURTHEST]
				))

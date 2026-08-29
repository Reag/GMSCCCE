# Copyright (c) 2026 Wickworks ♡ Lancer Tactics v1.2.4
extends ActionSystemMineDetonation

func activate_detonation_effects(all_targets:Array[Unit], forcing_action:SpecificAction, blast_tiles:Array[Vector2i], activation:EventCore) -> void:

	for target:Unit in all_targets:
		if not Unit.is_valid(target): continue

		var passed_save := await UnitHasecheck.make_hull_save(activation, target, forcing_action, [Lancer.FLAG.PRONE])
		if not passed_save:
			UnitCondition.apply_status(activation, target, Lancer.STATUS.PRONE, Lancer.UNTIL.MANUAL, forcing_action.gear.persistent_id)
		await activation.queue_events(CommonActionUtil.generate_knockback_events(
					target,
					2,
					SpecificAction.from_context(activation.context),
					forcing_action.unit.occupied_tiles(),
					[EventUnitPickMove.FLAG.AUTO_FURTHEST]
				))

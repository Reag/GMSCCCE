extends ActionSystemTargetUnit

@export var buff: Buff

func can_target_unit(potential_target:Unit, specific:SpecificAction) -> bool:
	if not potential_target.is_mech(): return false
	return super.can_target_unit(potential_target, specific)

func activate_for_target(context:Context, activation:EventCore, target_unit:Unit) -> void:
	var unit := context.unit
	await activation.execute_event(&"event_unit_overshield", {
		unit = target_unit,
		number = 3
	})
	UnitCondition.apply_buff(activation, target_unit, buff, context.gear)

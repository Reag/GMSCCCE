extends ActionReaction
# DEBUG STUB: Field Supply. Currently only proves the trigger chain fires when the
# Denali's pilot uses Stabilize; the real effect is not implemented yet.

const TRIGGERING_GEAR_ID := &'ms_stabilize'

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.gear]

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	var triggering_context:Context = triggering_event.context
	if not triggering_context.unit == unit: return false
	if not GearCore.is_valid(triggering_context.gear): return false
	if not triggering_context.gear.kit.compcon_id == TRIGGERING_GEAR_ID: return false
	print('[mt_field_supply] TRIGGER matched: %s used %s' % [unit, TRIGGERING_GEAR_ID])
	return true

func activate(context:Context, activation:EventCore) -> void:
	print('[mt_field_supply] ACTIVATE: reaction fired for %s' % context.unit)

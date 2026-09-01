extends Buff
## Force Multiplier - Buffer. "Whenever they take damage, they first gain 2 overshield."
##
## Fires on EVERY incoming damage instance for the buff's duration, not just the first, so
## is_onetime stays false. trigger_timing is PRE (see buff_fm_buffer.tres) so the overshield is
## already granted before event_unit_damage.damage() subtracts from it - confirmed by reading
## content/events/event_unit_damage/event_unit_damage.gd: execute_preblock() fires the PRE
## reaction trigger, and only afterwards does execute() call damage(), which spends overshield.

const FmUtil := preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_force_multiplier/fm_util.gd')

const OVERSHIELD_AMOUNT:int = 2

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	# the trigger loop calls this for every unit's buffs against every damage event on the map -
	# only react when WE are the one taking the damage
	if triggering_event.context.unit != unit: return false
	return FmUtil.is_buff_maintained(core, unit.map)

## OVERRIDE: fires on every qualifying damage instance. Deliberately does NOT call
## UnitCondition.clear_buff (Buff.activate's default), so the buff survives to trigger again.
func activate(core:BuffCore, activation:EventCore) -> void:
	var unit:Unit = activation.context.unit
	if not Unit.is_valid(unit): return
	activation.queue_event(&'event_unit_overshield', {
		unit = unit,
		number = OVERSHIELD_AMOUNT
	})

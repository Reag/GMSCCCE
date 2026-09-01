extends Buff
## Force Multiplier - Firewall, tech half (PRE roller). "Hostile tech actions have a 50% chance
## to fail against them, granting them immunity to all its effects."


const FmUtil := preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_force_multiplier/fm_util.gd')

const FLAG_KEY:String = 'fm_firewall_active'
const FAIL_CHANCE:float = 0.5

## Gates the passive to = tech_immunity lookup. Immunity stands only while a winning roll is
## live for the action in flight AND the ally is still in the Denali's sensors and line of sight.
func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not core.get_state(FLAG_KEY, false): return false
	return FmUtil.is_buff_maintained(core, X.map())

## Fire only for a hostile tech action aimed at our holder, while still in range.
func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	if not is_hostile_tech_against(triggering_event, unit): return false
	return FmUtil.is_buff_maintained(core, triggering_event.context.map)

## Roll the 50%. Clears first, so a previous action's result is never inherited.
func activate(core:BuffCore, activation:EventCore) -> void:
	core.set_state(FLAG_KEY, false)
	var roll := Dice.roll_d20()
	if roll > roundi(20 * FAIL_CHANCE): return
	core.set_state(FLAG_KEY, true)

## Is the event in flight a hostile tech action aimed at our holder?
func is_hostile_tech_against(event:EventCore, unit:Unit) -> bool:
	var context:Context = event.context
	if not Unit.is_valid(context.unit): return false
	if context.unit == unit: return false
	if not UnitRelation.are_enemies(context.unit, unit): return false
	if not GearCore.is_valid(context.gear): return false
	if not UnitAction.is_tech(context.gear): return false
	# UNIT_ACTION's virtual event core mirrors the real activation's target_units
	# (event_gear_activate.gd's create_virtual_event_unit_action) - use it to confirm
	# our holder is actually among the targets, not just anywhere on the map.
	return context.target_units.has(unit)

## Optimizer (GMS Denali) shared helpers.
##
## Static-only, and deliberately WITHOUT a class_name: Godot #83542 makes script extensions
## unreliable on scripts that declare one, and this lives inside a mod. Consumers preload it by
## absolute path. Mirrors fm_util.gd next door.
extends RefCounted

const FmUtil := preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_force_multiplier/fm_util.gd')

# ================= RECIPIENTS =================

## Everyone the mass effect reaches.
##
## The Denali is included UNCONDITIONALLY: it is the source, it cannot be outside its own sensors,
## and its own core power should not be stopped by its own tech immunity. Every other recipient
## must be an allied mech, within sensors and line of sight, and reachable by a tech action.
static func gather_recipients(denali:Unit) -> Array[Unit]:
	var recipients:Array[Unit] = []
	if not Unit.is_valid(denali): return recipients
	recipients.append(denali)
	if denali.map == null: return recipients

	for other:Unit in denali.map.get_all_units():
		if other == denali: continue
		if not Unit.is_valid(other): continue
		if not other.is_mech(): continue # "allied MECH characters": no pilots, drones or objects
		if not UnitRelation.are_allies(denali, other): continue
		if not FmUtil.is_maintained(denali, other): continue
		if not is_tech_reachable(other): continue
		recipients.append(other)
	return recipients

## Optimizer is is_tech = true, so tech immunity blocks it - except an immunity that is only our
## own Force Multiplier Firewall, which would otherwise let the core power lock itself out of the
## ally it just buffed.
static func is_tech_reachable(unit:Unit) -> bool:
	if not Unit.is_valid(unit): return false
	if not UnitCondition.is_immune_to_tech(unit): return true
	return FmUtil.is_immune_only_via_our_firewall(unit)

# ================= HOSTILE EFFECTS =================

## Both BuffCore.from_gear and StatusCondition.source are gear persistent ids, and
## MapState.get_unit_from_source_id resolves either back to the unit that owns that gear. An
## effect is hostile when that unit is an enemy of the one carrying the effect.
##
## An empty source means environmental, weather, or otherwise unattributed. Those are deliberately
## left alone: "hostile" is a claim about a unit, and there is no unit to make it about.
static func is_hostile_source(source:StringName, to_unit:Unit, map:MapState) -> bool:
	if source.is_empty(): return false
	if map == null or not Unit.is_valid(to_unit): return false
	var source_unit := map.get_unit_from_source_id(source)
	if not Unit.is_valid(source_unit): return false
	return UnitRelation.are_enemies(source_unit, to_unit)

## Would clear_hostile_effects do anything? Keeps the purge branch off the menu, and out of AI
## consideration, when it would be a no-op.
static func has_hostile_effects(unit:Unit) -> bool:
	if not Unit.is_valid(unit): return false
	var map:MapState = unit.map
	for core:BuffCore in unit.state.buffs:
		if is_hostile_source(core.from_gear, unit, map): return true
	for condition:StatusCondition in unit.state.statuses:
		if is_hostile_source(condition.source, unit, map): return true
	return false

## "End all ongoing hostile effects on that character." Returns how many were removed, so the
## caller can decide whether the result is worth a battle log line.
##
## Both loops walk DUPLICATED arrays: clear_buff and clear_specific_status mutate the live
## state.buffs / state.statuses out from under an iterator.
static func clear_hostile_effects(event:EventCore, unit:Unit) -> int:
	if not Unit.is_valid(unit): return 0
	var map:MapState = unit.map
	var cleared := 0

	for core:BuffCore in unit.state.buffs.duplicate():
		if not is_hostile_source(core.from_gear, unit, map): continue
		UnitCondition.clear_buff(event, unit, core)
		cleared += 1

	for condition:StatusCondition in unit.state.statuses.duplicate():
		if not is_hostile_source(condition.source, unit, map): continue
		UnitCondition.clear_specific_status(event, unit, condition)
		cleared += 1

	return cleared

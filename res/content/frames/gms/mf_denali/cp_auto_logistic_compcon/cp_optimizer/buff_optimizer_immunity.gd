extends BuffStatusImmunity
## Optimizer (GMS Denali) - "clear all conditions from outside sources and gain immunity to them
## until the end of their next turn."
##
## One resource for both halves of that sentence: on_application does the clearing, and
## check_if_passive_applies does the blocking. The stock BuffStatusImmunity archetype does neither
## with any regard for WHERE a condition came from, and "from outside sources" is the whole point.

## OVERRIDE. The archetype clears with UnitCondition.clear_status, which does not care who applied
## the condition. UnitCondition.ability_can_clear already encodes exactly the rule we want -
## counts_as_condition, not self-owned, not the underwater pseudo-source - and
## clear_status_via_ability is the call that applies it.
func on_application(event:EventCore, core:BuffCore, unit:Unit) -> void:
	for status:StringName in immune_to_statuses:
		UnitCondition.clear_status_via_ability(event, unit, status)

## OVERRIDE. Same rule going forward: a condition the holder applies to ITSELF still lands, so this
## never blocks an ally's own self-debuffing gear.
##
## context.string is the applying gear's persistent id (see
## UnitCondition.has_gained_immunity_to_status, which builds the context). Resolving it against the
## holder's own loadout mirrors StatusCondition.is_unit_owner. Mirrored rather than reused: that is
## an instance method on an existing condition, and here we are asked about a hypothetical one.
func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	var source := StringName(context.string)
	if source.is_empty(): return true # unattributed: treat as outside
	var holder := core.get_holder_unit(context.map)
	if not Unit.is_valid(holder): return true
	return not GearCore.is_valid(holder.core.loadout.get_by_persistent_id(source))

## Force Multiplier (GMS Denali) shared helpers.
##
## Static-only, and deliberately WITHOUT a class_name: Godot #83542 makes script extensions
## unreliable on scripts that declare one, and this lives inside a mod. Consumers preload it
## by absolute path.
##
## This file is the single definition of "within sensors and line of sight" - the design's
## decision A. Every effect buff checks it at proc time rather than expiring early, so an ally
## who steps out of sight goes inert and recovers the benefit on returning.
extends RefCounted

const OPTION_UPLINK:StringName = &'uplink'
const OPTION_BUFFER:StringName = &'buffer'
const OPTION_FIREWALL:StringName = &'firewall'

## Menu order, matching the rulebook's bullet order.
const DISPLAY_ORDER:Array[StringName] = [OPTION_UPLINK, OPTION_BUFFER, OPTION_FIREWALL]

const MARKER_IDS:Dictionary[StringName, StringName] = {
	OPTION_UPLINK: &'buff_fm_used_uplink',
	OPTION_BUFFER: &'buff_fm_used_buffer',
	OPTION_FIREWALL: &'buff_fm_used_firewall',
}

## Is the ally still within the Denali's sensors and line of sight?
##
## Fails closed the moment the granting Denali is dead OR merely no longer a valid actor -
## Unit.is_valid alone only catches full removal from the game (is_alive flips false); it stays
## true for a Denali that is simply incapacitated, e.g. SHUTDOWN, which is still very much
## Unit.is_valid but should not go on providing sensor coverage. is_actor() is the real predicate
## for "still an active combatant" (requires is_character(), health > 0, not SHUTDOWN, not EXILED -
## see unit.gd's is_active()/is_actor()). This matters most for the Firewall tech-immunity buffs,
## which are applied with from_gear = null and so have NO owner-death cleanup path at all
## (clear_buffs_owned_by/clear_outgoing_buffs_from_unit both match on core.from_gear == gear_id) -
## is_maintained is the only gate standing between an incapacitated Denali and a benefit that
## outlives it.
static func is_maintained(denali:Unit, ally:Unit) -> bool:
	if not Unit.is_valid(denali) or not Unit.is_valid(ally): return false
	if not denali.is_actor(): return false
	if not UnitRelation.can_see(denali, ally): return false
	return UnitRelation.distance_between(denali, ally) <= denali.get_sensor_range()

## State key for buffs that can't use from_gear to find their granting Denali (see
## action_force_multiplier.gd's apply_firewall_tech_safe - the Firewall tech-immunity roller is
## applied with no from_gear to avoid a Buff.check_if_prohibited <-> UnitCondition.is_immune_to_tech
## recursion, so its granter is stashed here directly instead).
const DENALI_ID_KEY:String = 'fm_denali_id'

## The Denali who granted this buff, or null if they are gone.
static func resolve_denali(core:BuffCore, map:MapState) -> Unit:
	if not BuffCore.is_valid(core): return null
	var stashed_id:String = core.get_state(DENALI_ID_KEY, '')
	if stashed_id != '':
		if map == null: return null # get_owner_unit tolerates a null map; get_unit_by_id does not
		return map.get_unit_by_id(stashed_id)
	return core.get_owner_unit(map)

## Convenience for buff scripts: is this buff's holder still in range of its granter?
static func is_buff_maintained(core:BuffCore, map:MapState) -> bool:
	var denali := resolve_denali(core, map)
	var holder := core.get_holder_unit(map)
	return is_maintained(denali, holder)

static func marker_id_for(option:StringName) -> StringName:
	return MARKER_IDS.get(option, &'')

## Has this character already received this effect this scene?
static func has_used(ally:Unit, option:StringName) -> bool:
	if not Unit.is_valid(ally): return false
	var marker_id := marker_id_for(option)
	if marker_id == &'': return false
	return ally.state.buffs.any(func(buff_core:BuffCore) -> bool:
		return buff_core.base.compcon_id == marker_id
	)

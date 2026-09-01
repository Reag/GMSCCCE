extends Buff
## Force Multiplier - Firewall, tech half (POST resetter). Clears the sibling PRE buff's flag
## once the hostile tech action has resolved, so the immunity does not linger between actions.
## Exists as a separate buff purely because a buff subscribes to one timing (reaction_bus.gd:134).
##
## Like its sibling, activate() must not call UnitCondition.clear_buff - it has to keep resetting
## for the whole duration.

const FirewallTech := preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_force_multiplier/buff_fm_firewall_tech.gd')

## Always fire on a resolved unit action - clearing an already-clear flag is harmless, and this
## way an aborted or unusual action still gets tidied up.
func triggers_on_event(_core:BuffCore, _unit:Unit, _triggering_event:EventCore) -> bool:
	return true

func activate(core:BuffCore, activation:EventCore) -> void:
	var holder := core.get_holder_unit(activation.context.map)
	if not Unit.is_valid(holder): return
	for buff_core:BuffCore in holder.state.buffs:
		if buff_core.base is FirewallTech:
			buff_core.set_state(FirewallTech.FLAG_KEY, false)

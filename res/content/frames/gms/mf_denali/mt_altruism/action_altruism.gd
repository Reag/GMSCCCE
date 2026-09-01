extends ActionReactionSelf
## Altruism (GMS Denali).
## When the Denali performs a barrage or a Full Tech Action, each adjacent allied character may
## Stabilize, even if they could not normally take reactions. 1/Scene.

## Player and NPC mechs do not carry the same Stabilize; only ms_stabilize is in
## basic_loadout_mech_player.tres, only npcf_stabilize is in basic_loadout_mech_npc.tres.
const STABILIZE_PLAYER := &'ms_stabilize'
const STABILIZE_NPC := &'npcf_stabilize'

## Two actions make the pair. The one that just resolved is already counted, because unit_action
## POST is emitted after activation - so the threshold is >=, not >.
const PAIR := 2

# ================= TRIGGER =================

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.gear, Context.PROP.action]

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	# ActionReactionSelf already rejects events whose acting unit is not us.
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	# Only the Denali's own turn actions count.
	if not unit.state.is_taking_turn: return false

	var triggering_context:Context = triggering_event.context
	# Freebies are not turn actions. They also never reach the usage counters, so letting one
	# through here would fire on an attack that the count itself does not acknowledge.
	if triggering_context.flags.has(Action.FLAG.AS_FREEBIE): return false
	# Don't re-trigger off the ally Stabilize we are in the middle of running.
	if CommonActionUtil.is_choose_and_use_with_gear_in_progress(gear): return false

	var triggering := SpecificAction.from_context(triggering_context)
	if not SpecificAction.is_valid(triggering): return false
	if not (is_barrage(triggering) or is_full_tech_action(triggering)): return false

	# 1/Scene: never burn the use - or show its prompt - when nobody could receive the offer.
	return not get_eligible_allies(unit).is_empty()

# ================= BARRAGE / FULL TECH ACTION =================

## A barrage: a FULL-cost weapon attack (i.e. a superheavy), or two weapon attacks in one turn.
## Counted over get_all_weapons() - mounted and integrated weapons - deliberately NOT over all
## gear. That excludes the basic Ram, Grapple and Improvised Attack, which are quick actions in
## their own right rather than part of a barrage, and it matches cp_tritton_fusillade in
## fateofman-imi_alt_frames so both mods mean the same thing by "barrage".
func is_barrage(triggering:SpecificAction) -> bool:
	if not is_weapon_attack(triggering.action): return false
	if triggering.action.get_action_type(triggering) == Lancer.ACTION.FULL: return true
	return count_uses_this_turn(
		triggering.unit.core.loadout.get_all_weapons(), is_weapon_attack
	) >= PAIR

## A Full Tech Action: a FULL-cost tech action, or two tech actions in one turn. ANY tech action
## counts - Scan and Lock On as much as a tech attack - so this walks all gear rather than
## loadout.get_all_tech_attacks(), which is scoped to tech attacks only and whose basic-gear
## filter is broken anyway: `has_tech_attack() or (include_lock_on and id != ms_lock_on)` matches
## every basic gear that is not Lock On.
func is_full_tech_action(triggering:SpecificAction) -> bool:
	if not is_tech_action(triggering.action): return false
	if triggering.action.get_action_type(triggering) == Lancer.ACTION.FULL: return true
	return count_uses_this_turn(
		triggering.unit.core.loadout.get_all_gear(true), is_tech_action
	) >= PAIR

## Sums the engine's per-turn usage counters over every action `matches` accepts. Usage groups are
## deduped per gear: several actions on one kit can share a group and would otherwise double-count.
func count_uses_this_turn(gear_list:Array[GearCore], matches:Callable) -> int:
	var total := 0
	for gear:GearCore in gear_list:
		if not GearCore.is_valid(gear): continue
		var counted_groups:Array[StringName] = []
		for action:Action in gear.kit.actions:
			if not matches.call(action): continue
			var usage_group := gear.get_usage_group_for_action(action)
			if counted_groups.has(usage_group): continue
			counted_groups.append(usage_group)
			total += gear.get_uses_this_turn_alt(usage_group)
	return total

func is_weapon_attack(action:Action) -> bool:
	return action is ActionAttackWeapon

## Mirrors UnitAction.is_tech's per-action test.
func is_tech_action(action:Action) -> bool:
	return (action is ActionAttackTech) or (action is ActionSystem and action.is_tech)

# ================= ELIGIBILITY =================

func get_eligible_allies(unit:Unit) -> Array[Unit]:
	var allies:Array[Unit] = UnitRelation.adjacent_characters(unit)
	Util.filter(allies, func(adjacent_unit:Unit) -> bool:
		if not UnitRelation.are_allies(unit, adjacent_unit): return false
		# No Stabilize of any kind means there is nothing we could offer them.
		return GearCore.is_valid(get_stabilize_gear(adjacent_unit))
	)
	return allies

func get_stabilize_gear(ally:Unit) -> GearCore:
	var player_stabilize := ally.get_gear(STABILIZE_PLAYER)
	if GearCore.is_valid(player_stabilize): return player_stabilize
	return ally.get_gear(STABILIZE_NPC)

# ================= ACTIVATE =================

func activate(context:Context, activation:EventCore) -> void:
	var denali:Unit = context.unit
	var specific := SpecificAction.from_context(context)
	var allies := get_eligible_allies(denali)
	if allies.is_empty(): return # never spend the scene use on nobody

	if not await confirm_with(denali, specific): return
	if activation.abort_without_unit(denali): return

	# Past here the 1/Scene is spent. spend_actions is what increments uses_this_scene, and nothing
	# in event_gear_activate does it on our behalf - which is exactly why declining above is free.
	spend_actions(activation)

	await choice_bus.telegraph_trait(denali, context.gear, allies)
	if activation.abort_without_unit(denali): return

	for ally:Unit in allies:
		if activation.abort_without_unit(denali): return
		if not Unit.is_valid(ally): continue

		if not is_offered_to(ally): continue

		await offer_stabilize(activation, specific, ally)

## A player ally is NOT asked whether they want the offer: CommonActionUtil.choose_and_use defers
## the reaction spend until the ally's own Stabilize actually commits (see its deferred_spend), so
## cancelling that gear's own popup already declines for free. An Altruism offer in front of it
## would be a second popup asking the same question with the same cost.
##
## An AI ally has no popup to cancel, so the "nothing to gain" case has to be answered here or its
## reaction is spent on a Stabilize that does nothing.
func is_offered_to(ally:Unit) -> bool:
	if ally.is_player_controlled(): return true
	return stabilize_would_do_something(ally)

func confirm_with(denali:Unit, specific:SpecificAction) -> bool:
	if not denali.is_player_controlled(): return true
	choice_bus.show_using_action(specific)
	var accepted:bool = await choice_bus.quick_yesno(
		denali.tile(),
		tr('gear.mt_altruism.confirm'),
		tr('gear.mt_altruism.confirm.desc')
	)
	choice_bus.hide_using_action()
	return accepted

## "Nothing to do" cannot be asked the same way for both Stabilizes, so this is only used for
## AI allies - a player is always offered the choice and can decline for themselves.
func stabilize_would_do_something(ally:Unit) -> bool:
	var gear := get_stabilize_gear(ally)
	if not GearCore.is_valid(gear): return false

	if gear.kit.compcon_id == STABILIZE_PLAYER:
		return UnitAction.can_activate_gear(
			SpecificAction.create(ally, gear, gear.get_solo_action()), true
		)

	return (
		ally.core.current.heat > 0 or
		ally.has_status(Lancer.STATUS.EXPOSED) or
		not UnitAction.get_unloaded_weapons(ally).is_empty()
	)

## Runs the ally's OWN Stabilize - variant UI and all for a player, the no-choice NPC version
## otherwise - rather than reimplementing it, so another mod replacing either kit supplies its
## semantics instead of ours.
func offer_stabilize(activation:EventCore, specific:SpecificAction, ally:Unit) -> bool:
	var gear := get_stabilize_gear(ally)
	if not GearCore.is_valid(gear): return false

	var stabilize := SpecificAction.create(ally, gear, gear.get_solo_action())
	if not SpecificAction.is_valid(stabilize): return false

	var options:Array[SpecificAction] = [stabilize]
	return await CommonActionUtil.choose_and_use(
		activation,
		specific,
		options,
		CommonActionUtil.choose_and_use_spend_reaction.bind(ally),
		[],
		[],
	)

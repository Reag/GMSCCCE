extends ActionReaction
## Field Supply (GMS Denali).
## When the Denali Stabilizes, each adjacent allied character may take ONE of Stabilize's three
## secondary effects. They are NOT Stabilizing: nothing here emits ReactionBus.TRIGGER.STABILIZE.
## The effects are delegated to the live ms_stabilize action rather than reimplemented, so they
## stay correct if the base game changes how they work (clear_burn is a TODO stub upstream).

const TRIGGERING_GEAR_ID := &'ms_stabilize'

const OPTION_BURN := &'burn'
const OPTION_CONDITION := &'condition'
const OPTION_RELOAD := &'reload'

## Menu order, matching the rulebook wording.
const DISPLAY_ORDER:Array[StringName] = [OPTION_BURN, OPTION_CONDITION, OPTION_RELOAD]
## NPC auto-pick order, best first.
const NPC_PRIORITY:Array[StringName] = [OPTION_CONDITION, OPTION_BURN, OPTION_RELOAD]

const MOD_ID := 'Reag-CrisisCoreCatalogEvolved'

# ================= TRIGGER =================

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.gear]

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	var triggering_context:Context = triggering_event.context
	if not triggering_context.unit == unit: return false
	if not GearCore.is_valid(triggering_context.gear): return false
	if not triggering_context.gear.kit.compcon_id == TRIGGERING_GEAR_ID: return false
	# fires whenever anyone is adjacent, even if nobody can benefit - a silent trait reads as broken
	return not get_eligible_allies(unit).is_empty()

# ================= ACTIVATE =================

func activate(context:Context, activation:EventCore) -> void:
	var denali:Unit = context.unit
	var specific := SpecificAction.from_context(context)
	var allies := get_eligible_allies(denali)

	await choice_bus.telegraph_trait(denali, context.gear, allies)
	if activation.abort_without_unit(denali): return

	for ally:Unit in allies:
		if not Unit.is_valid(ally): continue

		var picked := await pick_option_for(ally, specific)
		if activation.abort_without_unit(denali): return
		if picked == &'' or not Unit.is_valid(ally): continue

		var effects := await apply_option(ally, picked, specific, activation)
		if activation.abort_without_unit(denali): return

		effects = Util.filter_empty(effects)
		if not effects.is_empty():
			battle_log.log_unit('gear.mt_field_supply.log', ally, {effect_list = ', '.join(effects)})

# ================= ELIGIBILITY =================

func get_eligible_allies(unit:Unit) -> Array[Unit]:
	var allies:Array[Unit] = UnitRelation.adjacent_characters(unit)
	Util.filter(allies, func(adjacent_unit:Unit) -> bool:
		return UnitRelation.are_allies(unit, adjacent_unit)
	)
	return allies

func is_option_available(ally:Unit, option:StringName) -> bool:
	match option:
		OPTION_BURN: return ally.state.burn > 0
		OPTION_CONDITION: return not UnitCondition.get_ability_clearable_conditions_on(ally).is_empty()
		OPTION_RELOAD: return not UnitAction.get_unloaded_weapons(ally).is_empty()
	return false

func option_label_key(option:StringName) -> String:
	match option:
		OPTION_BURN: return 'gear.ms_stabilize.burn'
		OPTION_CONDITION: return 'gear.ms_stabilize.condition.self'
		OPTION_RELOAD: return 'gear.ms_stabilize.reload'
	return ''

# ================= CHOICE =================

func pick_option_for(ally:Unit, specific:SpecificAction) -> StringName:
	if not ally.is_player_controlled():
		for option:StringName in NPC_PRIORITY:
			if is_option_available(ally, option): return option
		return &'' # nothing useful, and no dialog to show an NPC

	# The menu is shown even when every option is unavailable, so the ally is visibly
	# accounted for rather than silently passed over.
	var choices:Array[InformationalBrochure.MultipleChoiceOption] = []
	for option:StringName in DISPLAY_ORDER:
		var label_key := option_label_key(option)
		var disabled_reason := '' if is_option_available(ally, option) else tr('%s.unavailable' % label_key)
		choices.append(InformationalBrochure.MultipleChoiceOption.create(tr(label_key), disabled_reason))
	choices.append(InformationalBrochure.MultipleChoiceOption.create(tr('gear.mt_field_supply.skip')))

	var index := await choice_bus.choose_from_multiple_choice(
		choices,
		tr('gear.mt_field_supply.name'),
		'gear.mt_field_supply.pick.desc', # a key: the brochure relies on Label auto-translate
		ally.core.get_pilot_or_mech_name(), # plain text - Subtitle is a Label, BBCode would render literally
		false # must explicitly Skip
	)
	if index < 0 or index >= DISPLAY_ORDER.size(): return &'' # skipped or cancelled
	return DISPLAY_ORDER[index]

# ================= EFFECTS (delegated) =================

func apply_option(ally:Unit, option:StringName, specific:SpecificAction, activation:EventCore) -> PackedStringArray:
	var stabilize := get_stabilize_action()
	match option:
		OPTION_BURN:
			if not has_delegate(stabilize, &'clear_burn'): return PackedStringArray()
			return stabilize.clear_burn(ally)

		OPTION_RELOAD:
			if not has_delegate(stabilize, &'reload_weapons'): return PackedStringArray()
			return stabilize.reload_weapons(ally, activation)

		OPTION_CONDITION:
			if not has_delegate(stabilize, &'clear_condition'): return PackedStringArray()
			var clearable := UnitCondition.get_ability_clearable_conditions_on(ally)
			var condition := await CommonActionUtil.pick_condition_to_clear(clearable, specific, ally)
			if condition == &'' or not Unit.is_valid(ally): return PackedStringArray()
			# cleared_on_ally = false: the log line is filed under the ally, so "cleared X on <ally>"
			# would repeat their name. We want the bare "cleared X".
			return stabilize.clear_condition(ally, condition, false, activation)

	return PackedStringArray()

## The live ms_stabilize action. Deliberately looked up rather than preloaded, so another mod
## replacing ms_stabilize supplies its semantics instead of ours.
static func get_stabilize_action() -> Action:
	var kit := ContentLibrary.get_kit(TRIGGERING_GEAR_ID)
	if not Kit.is_valid(kit) or kit.actions.is_empty(): return null
	return kit.actions[0]

## Fails loudly by design. There is no fallback implementation to drift out of date.
static func has_delegate(stabilize:Action, method:StringName) -> bool:
	if is_instance_valid(stabilize) and stabilize.has_method(method): return true
	var message := 'mt_field_supply: cannot delegate to ms_stabilize.%s — the vanilla helper is missing or renamed. Effect skipped.' % method
	push_error(message)
	ModLoaderLog.error(message, MOD_ID)
	return false

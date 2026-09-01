extends ActionSystemApplyBuff
## Force Multiplier (GMS Denali).
## Choose an adjacent allied character; they gain ONE of three benefits until the end of their
## next turn, for as long as they stay within the Denali's sensors and line of sight.
##
## Extends ActionSystemApplyBuff for its targeting, action spending, fx and apply_buff plumbing,
## but overrides apply_buffs_to_targets outright: FM chooses WHICH buffs to apply per target,
## so the archetype's fixed `buffs` array is left empty.
##
## Each effect is 1/scene per character, tracked by a hidden marker buff on the recipient.
## The archetype's own once_per_scene_per_target cannot express this - it is per action, not
## per effect - and must stay false.

const FmUtil := preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_force_multiplier/fm_util.gd')

const BUFF_UPLINK_ACCURACY:Buff = preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_force_multiplier/buff_fm_uplink_accuracy.tres')
const BUFF_UPLINK_INVISIBLE:Buff = preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_force_multiplier/buff_fm_uplink_invisible.tres')
const BUFF_UPLINK_HIDDEN:Buff = preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_force_multiplier/buff_fm_uplink_hidden.tres')

const BUFF_BUFFER:Buff = preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_force_multiplier/buff_fm_buffer.tres')

const BUFF_FIREWALL_SAVES:Buff = preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_force_multiplier/buff_fm_firewall_saves.tres')
const BUFF_FIREWALL_TECH:Buff = preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_force_multiplier/buff_fm_firewall_tech.tres')
const BUFF_FIREWALL_TECH_RESET:Buff = preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_force_multiplier/buff_fm_firewall_tech_reset.tres')

const LOC_ROOT := 'gear.cp_auto_logistic_compcon.action_force_multiplier'

## NPC auto-pick order, best first. Buffer is the safest generic pick; Firewall only matters
## against tech, which an NPC cannot predict.
const NPC_PRIORITY:Array[StringName] = [FmUtil.OPTION_BUFFER, FmUtil.OPTION_UPLINK, FmUtil.OPTION_FIREWALL]

# ================= OPTIONS =================

## Filled in by Tasks 3-5. Returns the buffs that make up one option.
func buffs_for_option(option:StringName) -> Array[Buff]:
	match option:
		FmUtil.OPTION_UPLINK:
			return [BUFF_UPLINK_ACCURACY, BUFF_UPLINK_INVISIBLE, BUFF_UPLINK_HIDDEN]
		FmUtil.OPTION_BUFFER:
			return [BUFF_BUFFER]
		FmUtil.OPTION_FIREWALL:
			return [BUFF_FIREWALL_SAVES, BUFF_FIREWALL_TECH, BUFF_FIREWALL_TECH_RESET]
	return []

func is_option_available(ally:Unit, option:StringName) -> bool:
	if not Unit.is_valid(ally): return false
	return not FmUtil.has_used(ally, option)

func option_label_key(option:StringName) -> String:
	if not FmUtil.DISPLAY_ORDER.has(option): return ''
	return '%s.%s' % [LOC_ROOT, option]

## The option's DESCRIPTION text, for the choice menu entry - distinct from option_label_key's
## short name, which is still what the disabled reason ('.unavailable') and the battle log use.
func option_desc_key(option:StringName) -> String:
	if not FmUtil.DISPLAY_ORDER.has(option): return ''
	return '%s.%s.desc' % [LOC_ROOT, option]

# ================= CHOICE =================

func pick_option_for(ally:Unit, specific:SpecificAction) -> StringName:
	if not ally.is_player_controlled():
		for option:StringName in NPC_PRIORITY:
			if is_option_available(ally, option): return option
		return &''

	# Look at the ally this menu is about. The subtitle names them, but text alone does not tell
	# the player WHICH mech on the field that is. Plain slide, no rotate or zoom change - see
	# action_altruism.gd's offer_stabilize for why.
	camera_bus.focus_on_unit(ally, false, false)

	# The menu is shown even when every option is spent, so the target is visibly accounted
	# for rather than silently passed over.
	var choices:Array[InformationalBrochure.MultipleChoiceOption] = []
	for option:StringName in FmUtil.DISPLAY_ORDER:
		var label_key := option_label_key(option)
		var disabled_reason := '' if is_option_available(ally, option) else tr('%s.unavailable' % label_key)
		# The menu entry shows the option's DESCRIPTION, not its short name - option_label_key is
		# still used above for the disabled reason, and separately in apply_buffs_to_targets for
		# the battle log, so neither of those reads out the full description.
		choices.append(InformationalBrochure.MultipleChoiceOption.create(tr(option_desc_key(option)), disabled_reason))
	choices.append(InformationalBrochure.MultipleChoiceOption.create(tr('%s.skip' % LOC_ROOT)))

	var index := await choice_bus.choose_from_multiple_choice(
		choices,
		tr('%s.name' % LOC_ROOT),
		'%s.pick.desc' % LOC_ROOT, # a key: the brochure relies on Label auto-translate
		ally.core.get_pilot_or_mech_name(), # plain text - Subtitle is a Label, BBCode renders literally
		false # must explicitly Skip
	)
	if index < 0 or index >= FmUtil.DISPLAY_ORDER.size(): return &'' # skipped or cancelled
	return FmUtil.DISPLAY_ORDER[index]

# ================= APPLY =================

## OVERRIDE. The archetype applies a fixed `buffs` list to every target; we pick per target.
func apply_buffs_to_targets(
	activation:EventCore,
	specific:SpecificAction,
	target_units:Array[Unit],
	_target_tiles:Array[Vector2i]
) -> void:
	for target_unit:Unit in target_units:
		if not Unit.is_valid(target_unit): continue

		var option := await pick_option_for(target_unit, specific)
		if activation.abort_without_unit(specific.unit): return
		if option == &'' or not Unit.is_valid(target_unit): continue

		for buff:Buff in buffs_for_option(option):
			apply_option_buff(activation, specific, target_unit, buff)

		var marker_id := FmUtil.marker_id_for(option)
		if marker_id != &'': apply_buff_id(activation, target_unit, marker_id)

		battle_log.log_unit('%s.log' % LOC_ROOT, target_unit, {
			effect = tr(option_label_key(option))
		})


const BUFFS_EXPOSED_TO_TECH_IMMUNITY:Array[Buff] = [
	BUFF_BUFFER,
	BUFF_UPLINK_ACCURACY, BUFF_UPLINK_INVISIBLE, BUFF_UPLINK_HIDDEN,
	BUFF_FIREWALL_SAVES, BUFF_FIREWALL_TECH, BUFF_FIREWALL_TECH_RESET,
]

## Dispatcher for every option buff (Uplink/Buffer/Firewall alike). Applies a buff exactly like
## Action.apply_buff, EXCEPT for the buffs listed in BUFFS_EXPOSED_TO_TECH_IMMUNITY above, which are
## applied with no from_gear and instead have the granting Denali recorded directly on their own
## BuffCore state (see the block comment above for why).
func apply_option_buff(activation:EventCore, specific:SpecificAction, target_unit:Unit, buff:Buff) -> void:
	if buff in BUFFS_EXPOSED_TO_TECH_IMMUNITY:
		var buff_core := UnitCondition.apply_buff(activation, target_unit, buff, null)
		# String, not StringName - BuffCore.set_state's own state dict is serialized, and
		# buff_core.gd warns "no StringNames; they don't serialize well" (get_state_string_array).
		# A StringName here would come back empty after a save/load, and FmUtil.is_buff_maintained
		# would then silently and permanently return false for this buff.
		if BuffCore.is_valid(buff_core): buff_core.set_state(FmUtil.DENALI_ID_KEY, String(specific.unit.core.persistent_id))
	else:
		apply_buff(activation, target_unit, buff)

# ================= ACTIVATION =================


func activate(context:Context, activation:EventCore) -> void:
	await super.activate(context, activation)
	var specific := SpecificAction.from_context(context)
	if GearCore.is_valid(specific.gear): specific.gear.set_state(OPTIMIZER_INVOCATION_FLAG, NOT_INVOKED_ROUND)

# ================= TARGETING OVERRIDES =================

## Set when Optimizer invokes us, which reaches further than adjacent.
const OPTIMIZER_INVOCATION_FLAG:StringName = &'fm_from_optimizer'

## Sentinel stored in OPTIMIZER_INVOCATION_FLAG when Optimizer has not (currently) invoked us.
##
## The flag holds the ROUND it was invoked in, not a bool, so it is self-expiring rather than
## relying on activate()'s own clear above always running. If the queued freebie is rejected
## before activate() ever executes - UnitAction.get_gear_unavailable_reason still rejects a
## freebie for SHUTDOWN, EXILED, DAZED, WEAPONS_LOCKED or destroyed gear - that clear never runs,
## and a plain bool would silently widen every ordinary Force Multiplier for the rest of the scene.
## Comparing the stamped round against FmUtil.current_round instead means a stale stamp from an
## earlier round can never read as "invoked" - both actions are FULL actions, so Optimizer can
## never stamp a round and have that same round still be current later without this action having
## already run to completion (and cleared it) in between.
const NOT_INVOKED_ROUND:int = -1

## Call on our shared gear before kickstarting us via ActionSystemApplyBuff.kickstart_sibling_action.
## `round` is the current combat round (FmUtil.current_round(specific.unit)) - passed in rather
## than resolved here, since a bare GearCore has no way to reach the map.
static func mark_invoked_by_optimizer(gear:GearCore, round:int) -> void:
	if GearCore.is_valid(gear): gear.set_state(OPTIMIZER_INVOCATION_FLAG, round)

## OVERRIDE. Adjacent normally; the Denali's sensor range when Optimizer invoked us this round.
func get_target_range(specific:SpecificAction) -> int:
	if was_invoked_by_optimizer(specific): return specific.unit.get_sensor_range()
	return super.get_target_range(specific)

func was_invoked_by_optimizer(specific:SpecificAction) -> bool:
	if not is_instance_valid(specific): return false
	if GearCore.is_valid(specific.gear):
		var invoked_round:int = specific.gear.get_state(OPTIMIZER_INVOCATION_FLAG, NOT_INVOKED_ROUND)
		if invoked_round != NOT_INVOKED_ROUND and invoked_round == FmUtil.current_round(specific.unit):
			return true
	return specific.has_meta(OPTIMIZER_INVOCATION_FLAG) and specific.get_meta(OPTIMIZER_INVOCATION_FLAG)

## OVERRIDE. ActionSystemApplyBuff rejects tech-immune targets, and Force Multiplier is tech -
## so an ally holding a live Firewall would be untargetable by the very action that granted it.
## Re-admit a target whose only tech immunity is our own Firewall.
func can_target_unit(potential_target:Unit, specific:SpecificAction) -> bool:
	if super.can_target_unit(potential_target, specific): return true
	if not Unit.is_valid(potential_target): return false
	if not is_immune_only_via_our_firewall(potential_target): return false
	# Re-run the archetype's other rejections (action_system_apply_buff.gd's can_target_unit)
	# with the tech-immunity check neutralised.
	if potential_target == specific.unit and not can_apply_to_self: return false
	if UnitRelation.is_hidden_from(potential_target, specific.unit): return false
	if not potential_target.is_actor(): return false
	if not can_reapply and already_has_our_buff(potential_target): return false
	if (
		(not skip_save(specific.unit, potential_target)) and
		specific.gear.state_has_id_in(USED_ON_KEY, potential_target.core.persistent_id)
	): return false
	if apply_only_to_self: return specific.unit == potential_target
	if apply_only_to_enemies: return UnitRelation.are_enemies(specific.unit, potential_target)
	if apply_only_to_allies: return UnitRelation.are_allies(specific.unit, potential_target)
	return true

func is_immune_only_via_our_firewall(potential_target:Unit) -> bool:
	return FmUtil.is_immune_only_via_our_firewall(potential_target)

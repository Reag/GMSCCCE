extends ActionSystem
## Optimizer (GMS Denali). The frame's core power, and a FULL tech action.
##
## Extends plain ActionSystem rather than ActionSystemApplyBuff. That archetype's activate()
## gathers either self alone or one picked tile - neither is "every allied mech in sensors and
## line of sight" - so its activate would have to be overridden wholesale anyway, and its
## kickstart_sibling_action fires unconditionally where Optimizer's final clause is a branch.
## The one thing it would have given us, buff application, is Action.apply_buff on the base class.
##
## ActionSystem.get_target_requirements already defaults to count = 0 (self-targeting), so no
## target picker appears for the mass effect and action_optimizer.tres needs no overrides.

const OptimizerUtil := preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_optimizer/optimizer_util.gd')

## Preloaded directly rather than relied on transitively through ActionForceMultiplier: DISPLAY_ORDER
## and has_used are FmUtil's own, and a chain of "it happens to also expose FmUtil's statics" is not
## a contract worth depending on.
const FmUtil := preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_force_multiplier/fm_util.gd')

const BUFF_IMMUNITY:Buff = preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_optimizer/buff_optimizer_immunity.tres')

const LOC_ROOT := 'gear.cp_auto_logistic_compcon.action_optimizer'

# ================= RECIPIENTS =================

## Thin passthrough so specs and AI scoring can ask the action directly.
func gather_recipients(denali:Unit) -> Array[Unit]:
	return OptimizerUtil.gather_recipients(denali)

# ================= ACTIVATE =================

func activate(context:Context, activation:EventCore) -> void:
	var denali:Unit = context.unit
	var specific := SpecificAction.from_context(context)
	var recipients := gather_recipients(denali)

	var confirmed:bool = await CommonActionUtil.confirm_use(context, recipients)
	if activation.abort_when(not confirmed): return
	if activation.abort_without_unit(denali): return

	# Past here the core power is spent: spend_actions is what calls spend_core_power (via
	# UnitAction.spend), so declining above costs nothing.
	spend_actions(activation)

	await run_system_fxgs(denali, recipients)
	if activation.abort_without_unit(denali): return

	for recipient:Unit in recipients:
		if not Unit.is_valid(recipient): continue
		clear_heat_and_exposed(activation, recipient)

	# The immunity buff's own on_application clears every condition from an outside source, so
	# this single call covers both halves of "clear all conditions from outside sources and gain
	# immunity to them". Applied BEFORE the Stabilize in Task 5, deliberately: otherwise an ally
	# spends their Stabilize secondary clearing a condition we are about to clear for free.
	for recipient:Unit in recipients:
		if not Unit.is_valid(recipient): continue
		apply_buff(activation, recipient, BUFF_IMMUNITY)

	# Recipients Stabilize AFTER the clears above, so heat, exposed and every outside-source
	# condition are already gone and the Stabilize menu offers only what we do not already cover.
	# Note this leaves Stabilize's Cool option disabled (it gates on heat > 0 or EXPOSED, both of
	# which we just cleared) and its Burn option live - the mirror of how it read before the rule
	# was corrected from "clear all burn" to "clear all heat".
	for recipient:Unit in recipients:
		if activation.abort_without_unit(denali): return
		if not Unit.is_valid(recipient): continue
		await run_stabilize(activation, specific, recipient)

	await run_final_clause(activation, specific)
	if activation.abort_without_unit(denali): return

	battle_log.log_unit('%s.log' % LOC_ROOT, denali, {})

# ================= EFFECTS =================

## "clear all heat and exposed" - the same pair action_stabilize.gd's Cool option does, and the
## same two calls it makes for them (clear_heat_and_exposed there).
##
## Heat goes through event_unit_cool rather than being zeroed directly, because clearing heat is a
## reactable event: the event runs the CLEAR_HEAT reaction trigger and refuses outright for a unit
## holding a Buff.TO.CANNOT_COOL. Writing core.current.heat = 0 would silently bypass both.
func clear_heat_and_exposed(activation:EventCore, recipient:Unit) -> void:
	if recipient.core.current.heat > 0:
		activation.queue_event(&'event_unit_cool', {
			unit = recipient,
			number = recipient.core.current.heat
		})
	if recipient.has_status(Lancer.STATUS.EXPOSED):
		UnitCondition.clear_status(activation, recipient, Lancer.STATUS.EXPOSED)

# ================= STABILIZE =================

## Player and NPC mechs do not carry the same Stabilize; only ms_stabilize is in
## basic_loadout_mech_player.tres, only npcf_stabilize is in basic_loadout_mech_npc.tres.
## Duplicated from action_altruism.gd rather than shared: four lines over two constants, and the
## two actions sit in different folders with no natural common home short of a third util file.
const STABILIZE_PLAYER := &'ms_stabilize'
const STABILIZE_NPC := &'npcf_stabilize'

func get_stabilize_gear(unit:Unit) -> GearCore:
	if not Unit.is_valid(unit): return null
	var player_stabilize := unit.get_gear(STABILIZE_PLAYER)
	if GearCore.is_valid(player_stabilize): return player_stabilize
	return unit.get_gear(STABILIZE_NPC)

## Runs the recipient's OWN Stabilize - variant UI and all for a player, the no-choice NPC version
## otherwise - rather than reimplementing it, so another mod replacing either kit supplies its
## semantics instead of ours.
##
## choose_and_use_no_spend, not Altruism's choose_and_use_spend_reaction: this Stabilize is part of
## the Denali's own full action and must not cost the recipient their reaction. With exactly one
## possible action, choose_and_use auto-picks for a player rather than showing a "which gear?"
## menu, so the recipient goes straight into Stabilize's own variant UI and cancelling there
## declines for free.
func run_stabilize(activation:EventCore, specific:SpecificAction, recipient:Unit) -> bool:
	var gear := get_stabilize_gear(recipient)
	if not GearCore.is_valid(gear): return false

	var stabilize := SpecificAction.create(recipient, gear, gear.get_solo_action())
	if not SpecificAction.is_valid(stabilize): return false

	# Look at whoever is Stabilizing, so the whole sequence of recipient Stabilize prompts is not
	# read against a camera parked on the Denali. Panned for AI recipients too, so the sweep does
	# not skip units.
	pan_to_after_frame(recipient)

	var options:Array[SpecificAction] = [stabilize]
	return await CommonActionUtil.choose_and_use(
		activation,
		specific,
		options,
		CommonActionUtil.choose_and_use_no_spend,
		[],
		[],
	)

# ================= FINAL CLAUSE =================

const ActionForceMultiplier := preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_force_multiplier/action_force_multiplier.gd')

const FM_ACTION_ID:StringName = &'action_force_multiplier'

const BRANCH_FORCE_MULTIPLIER := 0
const BRANCH_PURGE := 1
const BRANCH_SKIP := 2

## "one allied character in line of sight and sensors" - the same gate as the mass effect, minus
## the Denali itself, which the clause excludes by saying "allied".
func eligible_for_final_clause(denali:Unit) -> Array[Unit]:
	var eligible := gather_recipients(denali)
	eligible.erase(denali)
	return eligible

## Does `ally` still have at least one of Force Multiplier's three effects it hasn't received yet
## this scene? Separate from fm_action_on(specific).can_target_unit, which only checks range/LOS/
## tech-immunity and knows nothing about FmUtil's per-effect 1/scene markers.
func has_unused_fm_effect(ally:Unit) -> bool:
	return FmUtil.DISPLAY_ORDER.any(func(option:StringName) -> bool: return not FmUtil.has_used(ally, option))

func run_final_clause(activation:EventCore, specific:SpecificAction) -> void:
	var denali:Unit = specific.unit
	var eligible := eligible_for_final_clause(denali)

	# can_target_unit alone knows nothing of Force Multiplier's per-effect 1/scene markers, so an
	# ally who has already received all three benefits would otherwise still count as a valid
	# target - offering a branch whose menu shows nothing but three greyed-out options.
	var fm_targets := eligible.filter(func(ally:Unit) -> bool:
		if not fm_action_on(specific).can_target_unit(ally, specific_fm(specific)): return false
		return has_unused_fm_effect(ally)
	)
	var purge_targets := eligible.filter(func(ally:Unit) -> bool: return OptimizerUtil.has_hostile_effects(ally))

	# Never show a menu whose only live entry is Skip.
	if fm_targets.is_empty() and purge_targets.is_empty(): return

	var branch := await pick_branch(specific, fm_targets, purge_targets)
	match branch:
		BRANCH_FORCE_MULTIPLIER: invoke_force_multiplier(activation, specific)
		BRANCH_PURGE: await run_purge(activation, specific, purge_targets)

## Force Multiplier lives on the same gear, so it is reachable by id.
func fm_action_on(specific:SpecificAction) -> Action:
	return specific.gear.get_action(FM_ACTION_ID)

## FM's can_target_unit wants a SpecificAction describing FM, not us.
func specific_fm(specific:SpecificAction) -> SpecificAction:
	return SpecificAction.create(specific.unit, specific.gear, fm_action_on(specific))

func pick_branch(specific:SpecificAction, fm_targets:Array, purge_targets:Array) -> int:
	if not specific.unit.is_player_controlled():
		# Force Multiplier first: its benefit is guaranteed, where the purge is situational and
		# may strip very little.
		if not fm_targets.is_empty(): return BRANCH_FORCE_MULTIPLIER
		if not purge_targets.is_empty(): return BRANCH_PURGE
		return BRANCH_SKIP

	# Back to the Denali. This menu is the Denali's own choice, not any recipient's, and the camera
	# has just swept through every recipient's Stabilize - so without this the branch prompt appears
	# over whichever ally happened to go last.
	camera_bus.focus_on_unit(specific.unit, false, false)

	var choices:Array[InformationalBrochure.MultipleChoiceOption] = []
	choices.append(InformationalBrochure.MultipleChoiceOption.create(
		tr('%s.force_multiplier.desc' % LOC_ROOT),
		'' if not fm_targets.is_empty() else tr('%s.force_multiplier.unavailable' % LOC_ROOT)
	))
	choices.append(InformationalBrochure.MultipleChoiceOption.create(
		tr('%s.purge.desc' % LOC_ROOT),
		'' if not purge_targets.is_empty() else tr('%s.purge.unavailable' % LOC_ROOT)
	))
	choices.append(InformationalBrochure.MultipleChoiceOption.create(tr('%s.skip' % LOC_ROOT)))

	var index := await choice_bus.choose_from_multiple_choice(
		choices,
		tr('%s.name' % LOC_ROOT),
		'%s.pick.desc' % LOC_ROOT, # a key: the brochure relies on Label auto-translate
		'',
		false # must explicitly Skip
	)
	if index < 0: return BRANCH_SKIP
	return index

## "You may then use Force Multiplier on one allied character in line of sight and sensors."
##
## Reproduces what ActionSystemApplyBuff.kickstart_sibling_action does, rather than extending that
## archetype: the kickstart there is unconditional, and this is a branch. FM widens its own range
## off the flag, runs its own target picker and per-ally benefit menu, respects its own
## 1/scene-per-effect markers, and clears the flag at the end of its own activate.
##
## AS_FREEBIE keeps the ally-facing action economy from being charged twice. It does NOT stop the
## core power from being spent - UnitAction.spend calls spend_core_power outside its freebie block
## - but Force Multiplier has consumes_cp unset, so there is nothing to double-spend.
func invoke_force_multiplier(activation:EventCore, specific:SpecificAction) -> void:
	ActionForceMultiplier.mark_invoked_by_optimizer(specific.gear, FmUtil.current_round(specific.unit))
	activation.queue_event(&'event_gear_activate', {
		unit = specific.unit,
		gear = specific.gear,
		action = fm_action_on(specific),
		event = activation, # reactions need events
		flags = [Action.FLAG.AS_FREEBIE]
	}, Priority.ACTIVATE.early_followup)

## "...or end all ongoing hostile effects on that character."
func run_purge(activation:EventCore, specific:SpecificAction, purge_targets:Array) -> void:
	if purge_targets.is_empty(): return

	var target:Unit = purge_targets.front()
	if specific.unit.is_player_controlled():
		# Frame every candidate rather than panning to one: this prompt is a choice BETWEEN units,
		# so the player needs to see them all. choice_bus.choose_unit is called without a
		# SpecificAction, and tilepicker_unit only moves the camera when it is given one - so
		# nothing else does this for us here.
		var target_tiles:Array[Vector2i] = []
		for candidate:Unit in purge_targets:
			if Unit.is_valid(candidate): target_tiles.append(candidate.tile())
		# (tiles, rotate_to_clear_view = false, slide_to_center = true, change_zoom = false),
		# matching the plain-slide treatment used at the other prompts.
		if not target_tiles.is_empty(): camera_bus.show_all_tiles(target_tiles, false, true, false)

		choice_bus.show_informational_brochure(
			'%s.name' % LOC_ROOT,
			'%s.purge.pick' % LOC_ROOT,
			'',
			false
		)
		target = await choice_bus.choose_unit(purge_targets)
	if activation.abort_without_unit(target): return

	var cleared := OptimizerUtil.clear_hostile_effects(activation, target)
	if cleared > 0: battle_log.log_unit('%s.purge.log' % LOC_ROOT, target, {})

## Pan the camera onto `unit` one frame from now, WITHOUT awaiting.
##
## Duplicated from action_altruism.gd, for the same reason get_stabilize_gear is: the two actions
## sit in different folders with no common home short of a third util file.
##
## CommonActionUtil.choose_and_use opens with `camera_bus.focus_on_unit(using.unit, false)` -
## `using` is ours, so `using.unit` is the Denali - and that runs synchronously the instant we hand
## control over. A pan issued before the call is therefore always overridden, and the recipient's
## own Stabilize prompt then plays out with the camera on the Denali. Stabilize's confirm only
## calls ensure_unit_onscreen, which no-ops while the recipient is still anywhere on screen, so
## nothing downstream corrects it either.
##
## Deferring by one frame puts our pan AFTER that call: by then choose_and_use is parked on its own
## await and the prompt is what the player is looking at. Deliberately not awaited by the caller -
## this is a camera nicety, and blocking the action on it would change the action's timing.
##
## (unit, reset_zoom_to_default = false, rotate_to_clear_view = false) - a plain slide. Rotating per
## recipient is disorienting across a run of them and overrides the player's own camera angle.
func pan_to_after_frame(unit:Unit) -> void:
	await X.process_frame()
	if Unit.is_valid(unit): camera_bus.focus_on_unit(unit, false, false)

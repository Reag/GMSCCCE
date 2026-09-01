# Optimizer (GMS Denali) - Reag-CrisisCoreCatalogEvolved
#
# You and all allied mech characters in sensors and line of sight immediately clear all heat and
# exposed, and then stabilize. Allied characters affected by this action clear all conditions from
# outside sources and gain immunity to them until the end of their next turn. You may then use
# Force Multiplier on one allied character in line of sight and sensors, or end all ongoing
# hostile effects on that character.
#
# Design: D:\DEV\lancer-tactics-claude\specs\2026-09-01-optimizer-design.md
extends GutTest

const FmUtil := preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_force_multiplier/fm_util.gd')
const OptimizerUtil := preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_optimizer/optimizer_util.gd')
const ModChoiceResponder := preload('res://testkit/mod_choice_responder.gd')

const CORE_POWER_ID := &'cp_auto_logistic_compcon'
const DENALI_TILE := Vector2i(2,2)

var game:Gamemaster
var denali:Unit
var responder:ModChoiceResponder

func before_each():
	# add_responder = false: we install our own, which can answer a *sequence* of prompts.
	game = SpecFactory.setup_gamemaster(self, false, null, {}, false)
	responder = add_child_autoqfree(ModChoiceResponder.new())
	denali = SpecFactory.create_unit(game.map, DENALI_TILE)
	denali.core.equip_system(CORE_POWER_ID)
	denali.core.full_repair()

func ally_at(tile:Vector2i) -> Unit:
	var ally := SpecFactory.create_unit(game.map, tile, Faction.PLAYER)
	ally.core.full_repair()
	return ally

func enemy_at(tile:Vector2i) -> Unit:
	var enemy := SpecFactory.create_unit(game.map, tile, Faction.SIDE.AI_ENEMY)
	enemy.core.frame.stat.evasion = 100 # always miss; specs here never care about the roll
	enemy.core.frame.stat.health = 100  # never structure, which would derail the event chain
	enemy.core.full_repair()
	UnitTile.move_to(enemy, tile)
	return enemy

# ==================== TASK 2: RECIPIENT GATHERING ====================

func test_gather_recipients_always_includes_the_denali():
	var recipients := OptimizerUtil.gather_recipients(denali)
	assert_has(recipients, denali, 'the Denali is always a recipient of its own core power')

func test_gather_recipients_includes_an_allied_mech_in_sensors_and_line_of_sight():
	var ally := ally_at(Vector2i(2,3))
	assert_has(OptimizerUtil.gather_recipients(denali), ally, 'a nearby allied mech is reached')

func test_gather_recipients_excludes_an_enemy():
	var enemy := enemy_at(Vector2i(2,3))
	assert_does_not_have(OptimizerUtil.gather_recipients(denali), enemy, 'enemies are never recipients')

func test_gather_recipients_excludes_an_ally_beyond_sensor_range():
	denali.core.frame.stat.sensor_range = 1
	var sensor_range:int = denali.get_sensor_range()
	var far_ally := ally_at(Vector2i(2 + sensor_range + 1, 2))
	assert_eq(
		UnitRelation.distance_between(denali, far_ally), sensor_range + 1,
		'precondition: ally is exactly one tile beyond sensor range'
	)
	assert_does_not_have(OptimizerUtil.gather_recipients(denali), far_ally, 'out of sensors is out of reach')

func test_gather_recipients_excludes_an_ally_with_blocked_line_of_sight():
	var ally := ally_at(Vector2i(2,4))
	SpecFactory.set_blocks_to_height(game.get_landscape_node(), 2, [
		Vector2i(0,3), Vector2i(1,3), Vector2i(2,3), Vector2i(3,3), Vector2i(4,3),
	])
	assert_false(UnitRelation.can_see(denali, ally), 'precondition: wall blocks line of sight')
	assert_does_not_have(OptimizerUtil.gather_recipients(denali), ally, 'no line of sight is out of reach')

func test_gather_recipients_excludes_a_non_mech_ally():
	var drone := ally_at(Vector2i(2,3))
	drone.core.frame.is_drone = true
	assert_false(drone.is_mech(), 'precondition: a drone is not a mech character')
	assert_does_not_have(OptimizerUtil.gather_recipients(denali), drone, 'the text says allied MECH characters')

func test_gather_recipients_excludes_a_tech_immune_ally():
	var ally := ally_at(Vector2i(2,3))
	ally.core.frame.is_biological = true
	assert_true(UnitCondition.is_immune_to_tech(ally), 'precondition: biological frames are tech-immune')
	assert_does_not_have(OptimizerUtil.gather_recipients(denali), ally, 'Optimizer is tech and cannot reach them')

func test_is_tech_reachable_is_true_for_an_ordinary_ally():
	var ally := ally_at(Vector2i(2,3))
	assert_true(OptimizerUtil.is_tech_reachable(ally), 'nothing is blocking our tech')

# ==================== TASK 2: HOSTILE EFFECT PURGE ====================
#
# The purge identifies "hostile" by resolving a buff's from_gear or a status's source - both gear
# persistent ids - back to the owning unit, and asking whether that unit is an enemy of the holder.

func test_is_hostile_source_is_false_for_an_empty_source():
	var ally := ally_at(Vector2i(2,3))
	assert_false(
		OptimizerUtil.is_hostile_source(&'', ally, game.map),
		'environmental and unattributed effects have no source and are not ours to strip'
	)

func test_is_hostile_source_is_true_for_enemy_gear():
	var ally := ally_at(Vector2i(2,3))
	var enemy := enemy_at(Vector2i(3,3))
	var enemy_gear := enemy.core.equip_system(&'ms_neurospike')
	assert_true(
		OptimizerUtil.is_hostile_source(enemy_gear.persistent_id, ally, game.map),
		'gear belonging to an enemy of the holder is a hostile source'
	)

func test_is_hostile_source_is_false_for_allied_gear():
	var ally := ally_at(Vector2i(2,3))
	var friend := ally_at(Vector2i(1,2))
	var friendly_gear := friend.core.equip_system(&'ms_neurospike')
	assert_false(
		OptimizerUtil.is_hostile_source(friendly_gear.persistent_id, ally, game.map),
		'gear belonging to an ally is not a hostile source'
	)

func test_is_hostile_source_is_false_for_the_holders_own_gear():
	var ally := ally_at(Vector2i(2,3))
	var own_gear := ally.core.equip_system(&'ms_neurospike')
	assert_false(
		OptimizerUtil.is_hostile_source(own_gear.persistent_id, ally, game.map),
		'a unit is not its own enemy'
	)

func test_has_hostile_effects_is_false_on_a_clean_ally():
	var ally := ally_at(Vector2i(2,3))
	assert_false(OptimizerUtil.has_hostile_effects(ally), 'nothing to purge on a fresh ally')

func test_purge_clears_enemy_sourced_effects_and_spares_an_allied_one():
	# The one function here with a side effect, and the true branch of has_hostile_effects.
	# Buffs and statuses are seeded directly rather than by activating enemy gear: this task is
	# about the source-resolution predicate, not about any particular weapon's behaviour.
	var ally := ally_at(Vector2i(2,3))
	var friend := ally_at(Vector2i(1,2))
	var enemy := enemy_at(Vector2i(4,4))
	var enemy_gear := enemy.core.equip_system(&'ms_neurospike')
	var friendly_gear := friend.core.equip_system(&'ms_neurospike')

	SpecFactory.apply_buff(ally, &'buff_shrike_code', enemy_gear)
	SpecFactory.apply(ally, Lancer.STATUS.IMPAIRED, Lancer.UNTIL.MANUAL, String(enemy_gear.persistent_id))
	SpecFactory.apply_buff(ally, &'buff_shrike_code', friendly_gear)

	assert_true(OptimizerUtil.has_hostile_effects(ally), 'an enemy-sourced buff and status are visible')

	var cleared := OptimizerUtil.clear_hostile_effects(SpecFactory.dummy_event(), ally)
	assert_eq(cleared, 2, 'exactly the enemy-sourced buff and the enemy-sourced status')
	assert_false(OptimizerUtil.has_hostile_effects(ally), 'nothing hostile remains')
	assert_false(ally.has_status(Lancer.STATUS.IMPAIRED), 'the enemy-sourced status is gone')

	var from_friend := ally.state.buffs.any(func(buff_core:BuffCore) -> bool:
		return buff_core.from_gear == friendly_gear.persistent_id
	)
	assert_true(from_friend, 'a buff from an ALLY is not a hostile effect and must survive')

# ==================== TASK 3: THE IMMUNITY BUFF ====================

const IMMUNITY_BUFF_ID := &'buff_optimizer_immunity'

## The seven statuses with counts_as_condition = true in content/statuses/.
const ALL_CONDITIONS:Array[StringName] = [
	&'impaired', &'jammed', &'slowed', &'shredded', &'immobilized', &'stunned', &'lockon',
]

func immunity_buff() -> Buff:
	return ContentLibrary.get_buff(IMMUNITY_BUFF_ID)

func test_immunity_buff_is_registered_in_the_content_library():
	assert_not_null(immunity_buff(), 'a buff_-prefixed .tres lands in resgrp_buffs and is indexed by id')

func test_immunity_buff_covers_every_condition():
	var buff := immunity_buff()
	for condition:StringName in ALL_CONDITIONS:
		assert_true(
			buff.immune_to_statuses.has(condition),
			'%s is one of the seven conditions and must be covered' % condition
		)

func test_immunity_buff_covers_nothing_that_is_not_a_condition():
	var buff := immunity_buff()
	for status:StringName in buff.immune_to_statuses:
		assert_true(
			StatusType.get_counts_as_condition(status),
			'%s is not a condition; the text grants immunity to conditions only' % status
		)

func test_immunity_buff_lasts_until_the_end_of_the_next_turn():
	assert_eq(
		immunity_buff().until, Lancer.UNTIL.END_OF_NEXT_TURN,
		'"until the end of their next turn"'
	)

func test_immunity_buff_is_a_status_immunity():
	assert_eq(immunity_buff().to, Buff.TO.STATUS_IMMUNITY, 'it hooks the status-immunity query')

func test_immunity_buff_tooltip_resolves_to_its_own_text_not_the_whole_optimizer_action():
	# Finding 3 regression guard: localization_key_override pointing at the ACTION's own key
	# (rather than an .immunity sub-key) resolves without error - Translate.buff does not fall back
	# to the key on a miss - so a mistyped override is a silently EMPTY tooltip, not a loud failure.
	# Same shape as test_force_multiplier.gd's test_firewall_tech_buff_name_and_effect_resolve_to_real_text.
	var ally := ally_at(Vector2i(2,3))
	await use_optimizer()
	var buff_core := buff_core_with_id(ally, IMMUNITY_BUFF_ID)
	assert_not_null(buff_core, 'precondition: the immunity buff is actually on the ally')
	assert_eq(Translate.buff(buff_core, 'name', false), 'Optimized', "immunity buff name must resolve to its own text")
	assert_ne(Translate.buff(buff_core, 'effect', false), '', 'immunity buff effect must resolve to real text')
	assert_false(
		Translate.buff(buff_core, 'effect', false).contains('Force Multiplier'),
		"the tooltip must be the immunity buff's own text, not the whole four-sentence Optimizer action"
	)

# ==================== TASK 4: THE MASS EFFECT ====================

const OPTIMIZER_ACTION_ID := &'action_optimizer'

func core_power_gear() -> GearCore:
	return denali.get_gear(CORE_POWER_ID)

func optimizer_action() -> Action:
	return core_power_gear().get_action(OPTIMIZER_ACTION_ID)

func specific_optimizer() -> SpecificAction:
	return SpecificAction.create(denali, core_power_gear(), optimizer_action())

## Optimizer is actions[1] on the core power, so use_solo (which fires get_solo_action, i.e.
## Force Multiplier) is the wrong door. use_specific names the action outright.
func use_optimizer() -> void:
	await SpecFactory.use_specific(game, specific_optimizer())

func buff_ids_on(unit:Unit) -> Array:
	var ids := []
	for buff_core:BuffCore in unit.state.buffs: ids.append(buff_core.base.compcon_id)
	return ids

func buff_core_with_id(unit:Unit, compcon_id:StringName) -> BuffCore:
	for buff_core:BuffCore in unit.state.buffs:
		if buff_core.base.compcon_id == compcon_id: return buff_core
	return null

func test_optimizer_action_carries_our_script():
	assert_true(
		optimizer_action().has_method(&'gather_recipients'),
		'action_optimizer.tres must have action_optimizer.gd attached'
	)

func test_optimizer_is_a_full_tech_action_that_spends_the_core_power():
	var action := optimizer_action()
	assert_eq(action.get_action_type(specific_optimizer()), Lancer.ACTION.FULL, 'a FULL action')
	assert_true(action.is_tech, 'a tech action')
	# consumes_core_power() is declared "-> int" on the base engine's Action/ActionSystem, so its
	# return value is TYPE_INT even though consumes_cp is a bool - GUT's assert_true only accepts
	# TYPE_BOOL and fails any other type outright ("Cannot convert 1 to boolean"). Cast rather than
	# touch the base engine.
	assert_true(bool(action.consumes_core_power()), 'it spends the core power')

## The rule is "clear all heat", not burn - an earlier draft of the localization said burn.
##
## There is deliberately NO "and does not clear burn" counterpart: burn is not observable at this
## action's boundary. The recipient's own Stabilize runs inside the same activation and its
## secondary can legitimately clear burn, so a post-activation burn assertion cannot tell the two
## mechanisms apart. The positive heat assertion is what pins the rule.
func test_mass_effect_clears_heat_on_the_denali_and_a_nearby_ally():
	var ally := ally_at(Vector2i(2,3))
	denali.core.current.heat = 5
	ally.core.current.heat = 3
	await use_optimizer()
	assert_eq(denali.core.current.heat, 0, 'the Denali clears its own heat')
	assert_eq(ally.core.current.heat, 0, 'a nearby allied mech clears its heat')


func test_mass_effect_clears_exposed():
	var ally := ally_at(Vector2i(2,3))
	SpecFactory.apply(ally, Lancer.STATUS.EXPOSED)
	assert_true(ally.has_status(Lancer.STATUS.EXPOSED), 'precondition: the ally is exposed')
	await use_optimizer()
	assert_false(ally.has_status(Lancer.STATUS.EXPOSED), 'exposed is cleared')

func test_mass_effect_leaves_an_out_of_range_ally_alone():
	denali.core.frame.stat.sensor_range = 1
	var sensor_range:int = denali.get_sensor_range()
	var far_ally := ally_at(Vector2i(2 + sensor_range + 1, 2))
	far_ally.core.current.heat = 3
	await use_optimizer()
	assert_eq(far_ally.core.current.heat, 3, 'an ally beyond sensors keeps its heat')
	assert_false(buff_ids_on(far_ally).has(IMMUNITY_BUFF_ID), 'and gains no immunity')

func test_mass_effect_applies_the_immunity_buff_to_every_recipient():
	var ally := ally_at(Vector2i(2,3))
	await use_optimizer()
	assert_has(buff_ids_on(denali), IMMUNITY_BUFF_ID, 'the Denali is a recipient too')
	assert_has(buff_ids_on(ally), IMMUNITY_BUFF_ID, 'so is the nearby ally')

func test_mass_effect_spends_the_core_power_exactly_once():
	assert_true(denali.core.has_core_power, 'precondition: the core power is unspent')
	await use_optimizer()
	assert_false(denali.core.has_core_power, 'the core power is spent')
	assert_eq(core_power_gear().get_uses_this_scene(), 1, 'and spent exactly once')

# -------- conditions and immunity, the behaviour Task 3 could only configure --------

## Apply `status` to `unit`, sourced from a piece of gear belonging to `from_unit`. Both
## StatusCondition.source and the immunity buff's own source check work off a gear persistent id,
## so "who applied this" is expressed by whose loadout the source gear sits in.
##
## SpecFactory.apply routes through UnitCondition.apply_status, which consults
## is_immune_to_status first - which is exactly the path the immunity buff hooks.
func apply_status_from(unit:Unit, status:StringName, from_unit:Unit) -> void:
	var source_gear := from_unit.core.equip_system(&'ms_neurospike')
	SpecFactory.apply(unit, status, Lancer.UNTIL.MANUAL, String(source_gear.persistent_id))

func test_mass_effect_clears_a_condition_from_an_outside_source():
	var ally := ally_at(Vector2i(2,3))
	var enemy := enemy_at(Vector2i(4,4))
	apply_status_from(ally, Lancer.STATUS.IMPAIRED, enemy)
	assert_true(ally.has_status(Lancer.STATUS.IMPAIRED), 'precondition: the ally is impaired')
	await use_optimizer()
	assert_false(ally.has_status(Lancer.STATUS.IMPAIRED), 'a condition from an outside source is cleared')

func test_mass_effect_leaves_a_self_applied_condition_alone():
	var ally := ally_at(Vector2i(2,3))
	apply_status_from(ally, Lancer.STATUS.IMPAIRED, ally)
	assert_true(ally.has_status(Lancer.STATUS.IMPAIRED), 'precondition: the ally impaired itself')
	await use_optimizer()
	assert_true(
		ally.has_status(Lancer.STATUS.IMPAIRED),
		'"from outside sources" - a self-applied condition survives'
	)

func test_immunity_blocks_a_later_condition_from_an_outside_source():
	var ally := ally_at(Vector2i(2,3))
	var enemy := enemy_at(Vector2i(4,4))
	await use_optimizer()
	apply_status_from(ally, Lancer.STATUS.IMPAIRED, enemy)
	assert_false(ally.has_status(Lancer.STATUS.IMPAIRED), 'the immunity blocked it')

func test_immunity_allows_a_later_self_applied_condition():
	var ally := ally_at(Vector2i(2,3))
	await use_optimizer()
	apply_status_from(ally, Lancer.STATUS.IMPAIRED, ally)
	assert_true(
		ally.has_status(Lancer.STATUS.IMPAIRED),
		'the immunity never blocks the holder\'s own gear'
	)

func test_immunity_covers_every_condition_and_does_not_recurse():
	# A source-aware check_if_passive_applies that re-entered the immunity query would blow the
	# stack here. GUT counts engine errors as failures, so completing this loop IS the assertion.
	var ally := ally_at(Vector2i(2,3))
	var enemy := enemy_at(Vector2i(4,4))
	await use_optimizer()
	for condition:StringName in ALL_CONDITIONS:
		apply_status_from(ally, condition, enemy)
		assert_false(ally.has_status(condition), '%s from an enemy is blocked' % condition)

func test_immunity_expires_at_the_end_of_the_recipients_next_turn():
	# end_turn_for_statuses clears an END_OF_NEXT_TURN buff once turn_count >= 1, and turn_count
	# increments in new_turn_for_statuses - so exactly one start/end cycle on the holder.
	var ally := ally_at(Vector2i(2,3))
	await use_optimizer()
	assert_has(buff_ids_on(ally), IMMUNITY_BUFF_ID, 'precondition: the ally has the immunity')
	await SpecFactory.start_turn(game, ally)
	await SpecFactory.end_turn(game, ally)
	assert_false(buff_ids_on(ally).has(IMMUNITY_BUFF_ID), 'gone by the end of their next turn')

# ==================== TASK 5: THE MASS STABILIZE ====================
#
# SpecFactory frames are mf_standard_pattern_i_everest, and LoadoutCore picks the basic loadout
# off Frame.is_player_mech() - which is just `compcon_id.begins_with('mf_')` - so every spec unit
# gets the PLAYER basic loadout and its ms_stabilize. An AI ally in the real game carries
# npcf_stabilize instead; give it a frame id that fails that test to reach the NPC path.
func ai_ally_at(tile:Vector2i) -> Unit:
	var ally := SpecFactory.create_unit(game.map, tile, Faction.SIDE.AI_ALLY)
	ally.core.frame.compcon_id = &'npcc_spec_dummy'
	ally.core.full_repair()
	return ally

## How many times has `unit` activated its own Stabilize this scene?
##
## Heat is NOT usable as the "did they Stabilize?" signal: the mass effect clears heat itself, so a
## heat assertion would pass whether or not the Stabilize ran. This counter is incremented by
## UnitAction.spend inside the recipient's own Stabilize activation, so it proves the gear ran and
## is indifferent to which primary/secondary options the menu happened to pick.
func stabilize_uses(unit:Unit) -> int:
	var gear:GearCore = optimizer_action().get_stabilize_gear(unit)
	if not GearCore.is_valid(gear): return -1
	return gear.get_uses_this_scene()

func test_recipients_run_their_own_stabilize():
	var ally := ally_at(Vector2i(2,3))
	# Burn, because Optimizer does NOT clear it: a recipient whose primary AND secondary groups are
	# both entirely disabled picks skip/skip, and action_stabilize.gd aborts before spend_actions -
	# so it would never record a use. Every recipient needs real work for this to mean anything.
	ally.set_current_burn(2)
	denali.set_current_burn(2)
	assert_eq(stabilize_uses(ally), 0, 'precondition: the ally has not Stabilized yet')
	await use_optimizer()
	assert_eq(stabilize_uses(ally), 1, 'the ally ran its own Stabilize')
	assert_eq(stabilize_uses(denali), 1, 'so did the Denali')

func test_the_stabilize_costs_the_ally_no_reaction():
	var ally := ally_at(Vector2i(2,3))
	ally.set_current_burn(2)
	var reactions_before:int = ally.core.current.reactions
	await use_optimizer()
	assert_eq(stabilize_uses(ally), 1, 'precondition: the Stabilize actually ran')
	assert_eq(
		ally.core.current.reactions, reactions_before,
		'Optimizer passes choose_and_use_no_spend; the mass Stabilize is free'
	)

func test_an_ai_ally_stabilizes_without_being_asked():
	var ai_ally := ai_ally_at(Vector2i(2,3))
	ai_ally.set_current_burn(2)
	await use_optimizer()
	assert_eq(stabilize_uses(ai_ally), 1, 'the NPC Stabilize has no menu and just runs')

func test_an_out_of_range_ally_does_not_stabilize():
	denali.core.frame.stat.sensor_range = 1
	var sensor_range:int = denali.get_sensor_range()
	var far_ally := ally_at(Vector2i(2 + sensor_range + 1, 2))
	far_ally.set_current_burn(2)
	await use_optimizer()
	assert_eq(stabilize_uses(far_ally), 0, 'out of sensors, out of reach')

func test_get_stabilize_gear_prefers_the_player_stabilize():
	var ally := ally_at(Vector2i(2,3))
	var gear:GearCore = optimizer_action().get_stabilize_gear(ally)
	assert_true(GearCore.is_valid(gear), 'a player mech has a Stabilize')
	assert_eq(gear.kit.compcon_id, &'ms_stabilize', 'and it is the player one')

# ==================== TASK 6: THE FINAL CLAUSE ====================

# Menu order built by run_final_clause. Pointed at the action's own constants rather than
# duplicated as literals, so a menu reorder fails this suite loudly instead of silently mis-asserting.
const ActionOptimizerScript := preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_optimizer/action_optimizer.gd')
const BRANCH_FM := ActionOptimizerScript.BRANCH_FORCE_MULTIPLIER
const BRANCH_PURGE := ActionOptimizerScript.BRANCH_PURGE
const BRANCH_SKIP := ActionOptimizerScript.BRANCH_SKIP

const FM_ACTION_ID := &'action_force_multiplier'

func fm_action() -> Action:
	return core_power_gear().get_action(FM_ACTION_ID)

## Run Optimizer, answering the final-clause menu with `branch`. The Stabilize prompts before it
## are answered by the responder's default index, so only the final answer needs queueing - but
## queue a leading default for each recipient's Stabilize confirm so the branch answer lands on
## the branch menu and not on a Stabilize.
func use_optimizer_choosing(branch:int, leading_defaults:int = 0) -> void:
	var queue:Array[int] = []
	for i:int in leading_defaults: queue.append(0)
	queue.append(branch)
	responder.multiple_choice_queue = queue
	await use_optimizer()

func test_every_branch_label_resolves_to_real_text():
	for key:String in [
		'gear.cp_auto_logistic_compcon.action_optimizer.force_multiplier',
		'gear.cp_auto_logistic_compcon.action_optimizer.force_multiplier.desc',
		'gear.cp_auto_logistic_compcon.action_optimizer.force_multiplier.unavailable',
		'gear.cp_auto_logistic_compcon.action_optimizer.purge',
		'gear.cp_auto_logistic_compcon.action_optimizer.purge.desc',
		'gear.cp_auto_logistic_compcon.action_optimizer.purge.unavailable',
		'gear.cp_auto_logistic_compcon.action_optimizer.purge.pick',
		'gear.cp_auto_logistic_compcon.action_optimizer.skip',
	]:
		assert_ne(tr(key), key, '%s must resolve to real text, not echo itself' % key)

func test_eligible_for_final_clause_excludes_the_denali_and_out_of_range_allies():
	denali.core.frame.stat.sensor_range = 1
	var sensor_range:int = denali.get_sensor_range()
	var near_ally := ally_at(Vector2i(2,3))
	var far_ally := ally_at(Vector2i(2 + sensor_range + 1, 2))
	var eligible:Array[Unit] = optimizer_action().eligible_for_final_clause(denali)
	assert_has(eligible, near_ally, 'a nearby ally is eligible')
	assert_does_not_have(eligible, far_ally, 'an ally beyond sensors is not')
	assert_does_not_have(eligible, denali, 'the clause says "one ALLIED character"')

func mark_every_fm_effect_used(ally:Unit) -> void:
	for option:StringName in FmUtil.DISPLAY_ORDER:
		SpecFactory.apply_buff(ally, FmUtil.marker_id_for(option))

func test_has_unused_fm_effect_is_false_once_every_effect_is_spent():
	# Finding 2 regression guard, unit level: can_target_unit alone knows nothing about Force
	# Multiplier's per-effect 1/scene markers.
	var ally := ally_at(Vector2i(2,3))
	assert_true(optimizer_action().has_unused_fm_effect(ally), 'precondition: a fresh ally has every effect available')
	mark_every_fm_effect_used(ally)
	assert_false(optimizer_action().has_unused_fm_effect(ally), 'every effect spent leaves nothing unused')

func test_final_clause_is_not_offered_when_the_only_ally_has_used_every_force_multiplier_effect():
	# Finding 2 regression guard, end to end: with no hostile effects to purge either, offering the
	# branch menu here would show three greyed-out Force Multiplier options and nothing else live -
	# a no-op the player could pick their way into. Assert the menu never appears at all.
	var ally := ally_at(Vector2i(2,3))
	mark_every_fm_effect_used(ally)
	assert_false(OptimizerUtil.has_hostile_effects(ally), 'precondition: nothing to purge either')

	await use_optimizer()

	var branch_menu_shown := responder.multiple_choice_prompts.any(func(prompt:Dictionary) -> bool:
		return String(prompt.title) == tr('gear.cp_auto_logistic_compcon.action_optimizer.name')
	)
	assert_false(branch_menu_shown, 'the final-clause menu must not appear when every live branch would be a no-op')

## Give `ally` a real hostile effect by having an enemy land a tech attack on them.
## ms_neurospike applies buff_shrike_code, whose from_gear is the enemy's gear.
func land_hostile_effect_on(ally:Unit) -> Unit:
	ally.core.frame.stat.edef = 1 # tech attacks roll against e-defense; guarantee the hit
	var enemy := enemy_at(Vector2i(3,3))
	var enemy_gear := enemy.core.equip_system(&'ms_neurospike')
	await game.execute_event(&'event_gear_activate', {
		action = enemy_gear.kit.actions[0],
		unit = enemy,
		gear = enemy_gear,
		target_tiles = [ally.tile()],
		target_unit = ally,
	})
	return enemy

func test_has_hostile_effects_sees_an_enemy_applied_buff():
	var ally := ally_at(Vector2i(2,3))
	await land_hostile_effect_on(ally)
	assert_true(OptimizerUtil.has_hostile_effects(ally), 'the enemy tech attack left something behind')

func test_purge_branch_clears_an_enemy_sourced_effect():
	var ally := ally_at(Vector2i(2,3))
	await land_hostile_effect_on(ally)
	assert_true(OptimizerUtil.has_hostile_effects(ally), 'precondition: there is something to purge')
	responder.chosen_unit = ally
	await use_optimizer_choosing(BRANCH_PURGE, 0)
	assert_false(OptimizerUtil.has_hostile_effects(ally), 'the purge stripped it')

func test_purge_leaves_an_ally_sourced_buff_alone():
	var ally := ally_at(Vector2i(2,3))
	await land_hostile_effect_on(ally)
	# The immunity buff Optimizer itself applies comes from the Denali - an ally - and must survive.
	responder.chosen_unit = ally
	await use_optimizer_choosing(BRANCH_PURGE, 0)
	assert_has(buff_ids_on(ally), IMMUNITY_BUFF_ID, 'our own buff is not a hostile effect')

func test_force_multiplier_branch_reaches_a_non_adjacent_ally():
	var ally := ally_at(Vector2i(2,4))
	assert_gt(UnitRelation.distance_between(denali, ally), 1, 'precondition: the ally is not adjacent')
	assert_true(FmUtil.is_maintained(denali, ally), 'precondition: but is within sensors and line of sight')
	await use_optimizer_choosing(BRANCH_FM, 0)
	var ids := buff_ids_on(ally)
	var got_an_fm_buff := ids.any(func(id:StringName) -> bool: return String(id).begins_with('buff_fm_'))
	assert_true(got_an_fm_buff, 'Force Multiplier ran at sensor range and applied one of its benefits')

func test_the_optimizer_invocation_flag_does_not_survive_the_activation():
	var ally := ally_at(Vector2i(2,4))
	await use_optimizer_choosing(BRANCH_FM, 0)
	assert_eq(
		core_power_gear().get_state(fm_action().OPTIMIZER_INVOCATION_FLAG, fm_action().NOT_INVOKED_ROUND),
		fm_action().NOT_INVOKED_ROUND,
		'a leaked flag would silently widen the next ordinary Force Multiplier to sensor range'
	)

func test_a_stale_invocation_flag_from_an_earlier_round_does_not_widen_force_multiplier():
	# Finding 1 regression guard. If the freebie Force Multiplier activation Optimizer queues is
	# rejected BEFORE Force Multiplier's own activate() ever runs - UnitAction.get_gear_unavailable_
	# reason still rejects a freebie for SHUTDOWN, EXILED, DAZED, WEAPONS_LOCKED or destroyed gear -
	# that action's own end-of-activate clear never executes, and under the old plain-bool flag that
	# would silently widen every ordinary Force Multiplier for the rest of the scene. Stamp a PAST
	# round directly (bypassing the real invocation path, the same way the leaked flag would have
	# been left behind) and confirm the stale stamp is inert now that the flag is self-expiring.
	var gear := core_power_gear()
	game.map.game_core.round_count = 2
	fm_action().mark_invoked_by_optimizer(gear, 1) # stamped in an earlier round, never cleared
	var specific := SpecificAction.create(denali, gear, fm_action())
	assert_false(
		fm_action().was_invoked_by_optimizer(specific),
		'a stamp from an earlier round must not read as invoked in the current round'
	)
	assert_eq(
		fm_action().get_target_range(specific), 1,
		'and Force Multiplier must stay adjacent-only, not widen to sensor range'
	)

func test_skipping_the_final_clause_does_nothing_further():
	var ally := ally_at(Vector2i(2,4))
	await land_hostile_effect_on(ally)
	await use_optimizer_choosing(BRANCH_SKIP, 0)
	assert_true(OptimizerUtil.has_hostile_effects(ally), 'skip means skip; the hostile effect stays')

func test_the_force_multiplier_freebie_does_not_double_spend_the_core_power():
	# The core power is a single boolean on the unit, cleared by UnitAction.spend_core_power.
	# Optimizer has consumes_cp = true; Force Multiplier does not, so the kickstarted freebie
	# cannot spend a second one.
	#
	# has_core_power alone would prove nothing here - Optimizer's own activation clears it
	# whichever branch runs - so this first asserts that Force Multiplier ACTUALLY RAN, and only
	# then that it had no core power of its own to spend. A boolean cannot be observably
	# double-cleared; the real guarantee is that static invariant plus evidence that the freebie
	# path was actually taken.
	#
	# Deliberately NOT asserted via gear.get_uses_this_scene(): increment_action_usage bumps the
	# per-scene counter unconditionally (AS_FREEBIE gates only the per-TURN counter), and both
	# actions fall back to the same usage group - the kit's compcon_id - because neither declares
	# its own. That counter therefore reads 2 here, correctly.
	var ally := ally_at(Vector2i(2,4))
	assert_true(denali.core.has_core_power, 'precondition: the core power is unspent')

	await use_optimizer_choosing(BRANCH_FM, 0)

	var ran_fm := buff_ids_on(ally).any(func(id:StringName) -> bool:
		return String(id).begins_with('buff_fm_')
	)
	assert_true(ran_fm, 'the Force Multiplier freebie actually ran - without this the rest is vacuous')
	assert_false(denali.core.has_core_power, 'the core power is spent')
	assert_false(
		bool(fm_action().consumes_core_power()),
		'Force Multiplier has no core power of its own, so the freebie cannot spend a second one'
	)

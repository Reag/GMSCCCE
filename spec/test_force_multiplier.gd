# Force Multiplier (GMS Denali) - Reag-CrisisCoreCatalogEvolved
#
# Choose an adjacent allied character; they gain one of three benefits until the end of their
# next turn, as long as they remain within the Denali's sensors and line of sight.
#
# Design: D:\DEV\lancer-tactics-claude\specs\2026-09-01-force-multiplier-design.md
extends GutTest

const FmUtil := preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_force_multiplier/fm_util.gd')

const CORE_POWER_ID := &'cp_auto_logistic_compcon'

var game:Gamemaster
var denali:Unit
var responder:ModChoiceResponder

func before_each():
	game = SpecFactory.setup_gamemaster(self, false, null, {}, false)
	denali = SpecFactory.create_unit(game.map, Vector2i(2,2))
	denali.core.equip_system(CORE_POWER_ID)

func ally_at(tile:Vector2i) -> Unit:
	return SpecFactory.create_unit(game.map, tile, Faction.PLAYER)

func test_is_maintained_true_for_adjacent_ally():
	var ally := ally_at(Vector2i(2,3))
	assert_true(FmUtil.is_maintained(denali, ally), 'adjacent ally should be maintained')

func test_is_maintained_false_for_invalid_units():
	assert_false(FmUtil.is_maintained(denali, null), 'null ally must not be maintained')
	assert_false(FmUtil.is_maintained(null, denali), 'null denali must not be maintained')

func test_marker_ids_are_distinct_per_option():
	var ids := []
	for option:StringName in FmUtil.DISPLAY_ORDER:
		ids.append(FmUtil.marker_id_for(option))
	assert_eq(ids.size(), 3, 'three options')
	assert_false(ids[0] == ids[1] or ids[1] == ids[2] or ids[0] == ids[2], 'marker ids must be distinct')
	assert_false(ids.has(&''), 'every option maps to a real marker id')

func test_has_used_is_false_before_any_effect_is_applied():
	var ally := ally_at(Vector2i(2,3))
	for option:StringName in FmUtil.DISPLAY_ORDER:
		assert_false(FmUtil.has_used(ally, option), 'fresh ally has not used %s' % option)

func test_is_maintained_false_for_ally_beyond_sensor_range():
	# shrink sensor range so the default 5x5 test board has room for a tile beyond it
	denali.core.frame.stat.sensor_range = 1
	var sensor_range:int = denali.get_sensor_range()
	var ally := ally_at(Vector2i(2 + sensor_range + 1, 2))
	assert_eq(UnitRelation.distance_between(denali, ally), sensor_range + 1, 'precondition: ally should be exactly one tile beyond sensor range')
	assert_false(FmUtil.is_maintained(denali, ally), 'ally beyond sensor range should not be maintained')

func test_is_maintained_true_for_ally_exactly_at_sensor_range():
	# pins the <= boundary in fm_util.is_maintained: a regression to < must fail this test
	denali.core.frame.stat.sensor_range = 1
	var sensor_range:int = denali.get_sensor_range()
	var ally := ally_at(Vector2i(2 + sensor_range, 2))
	assert_eq(UnitRelation.distance_between(denali, ally), sensor_range, 'precondition: ally should be exactly at sensor range')
	assert_true(FmUtil.is_maintained(denali, ally), 'ally exactly at sensor range should be maintained')

func test_is_maintained_false_for_ally_with_blocked_line_of_sight():
	var ally := ally_at(Vector2i(2,4))
	# raise a wall between denali and ally, same pattern as test/gamemaster/test_map_sightlines.gd
	SpecFactory.set_blocks_to_height(game.get_landscape_node(), 2, [
		Vector2i(0,3), Vector2i(1,3), Vector2i(2,3), Vector2i(3,3), Vector2i(4,3),
	])
	assert_true(UnitRelation.distance_between(denali, ally) <= denali.get_sensor_range(), 'precondition: ally should be within sensor range')
	assert_false(UnitRelation.can_see(denali, ally), 'precondition: wall should block line of sight')
	assert_false(FmUtil.is_maintained(denali, ally), 'ally with blocked line of sight should not be maintained')

const ModChoiceResponder := preload('res://testkit/mod_choice_responder.gd')

const FM_ACTION_ID := &'action_force_multiplier'

# Menu order from FmUtil.DISPLAY_ORDER, plus the trailing Skip entry.
const PICK_UPLINK := 0
const PICK_BUFFER := 1
const PICK_FIREWALL := 2
const PICK_SKIP := 3

func fm_action() -> Action:
	var kit := ContentLibrary.get_kit(CORE_POWER_ID)
	for action:Action in kit.actions:
		if action.has_method(&'buffs_for_option'): return action
	return null

func test_action_script_is_attached():
	assert_not_null(fm_action(), 'force multiplier action should carry our script')

func test_every_option_is_available_on_a_fresh_ally():
	var ally := ally_at(Vector2i(2,3))
	var action := fm_action()
	for option:StringName in FmUtil.DISPLAY_ORDER:
		assert_true(action.is_option_available(ally, option), '%s available on fresh ally' % option)

func test_every_option_has_a_translated_label():
	var action := fm_action()
	for option:StringName in FmUtil.DISPLAY_ORDER:
		var key:String = action.option_label_key(option)
		assert_ne(key, '', '%s has a label key' % option)
		assert_ne(tr(key), key, 'label key %s must resolve to real text, not echo itself' % key)

# ==================== MENU SHOWS DESCRIPTIONS, NOT NAMES ====================
#
# The choice menu currently shows each option's short NAME ("Uplink"), which tells the player
# nothing about what it does. option_desc_key must resolve to the option's DESCRIPTION text -
# distinct from the name - while option_label_key keeps resolving to the name, since it is also
# used to build the '.unavailable' key and the battle-log line, neither of which should read out
# the full description.

func test_every_option_has_a_translated_description_distinct_from_its_name():
	var action := fm_action()
	for option:StringName in FmUtil.DISPLAY_ORDER:
		var desc_key:String = action.option_desc_key(option)
		assert_ne(desc_key, '', '%s has a description key' % option)
		var desc_text := tr(desc_key)
		assert_ne(desc_text, desc_key, 'description key %s must resolve to real text, not echo itself' % desc_key)
		assert_false(desc_text.is_empty(), 'description text for %s must not be empty' % option)

		var name_text := tr(action.option_label_key(option))
		assert_ne(desc_text, name_text, 'description text for %s must differ from its name text - a test that only checked non-emptiness would pass if desc accidentally pointed at the name row' % option)

func test_option_desc_key_differs_from_option_label_key_for_the_same_option():
	var action := fm_action()
	for option:StringName in FmUtil.DISPLAY_ORDER:
		assert_ne(
			action.option_desc_key(option), action.option_label_key(option),
			'%s: option_desc_key and option_label_key must return different keys' % option
		)

func test_option_label_key_still_resolves_to_the_short_name_unchanged():
	# Guards the two OTHER callers of option_label_key: the disabled reason ('%s.unavailable') and
	# the battle log line both must keep resolving off the NAME, not the description.
	var action := fm_action()
	for option:StringName in FmUtil.DISPLAY_ORDER:
		var label_key:String = action.option_label_key(option)
		assert_ne(tr(label_key), label_key, 'label key %s must still resolve to real text' % label_key)

		var unavailable_key := '%s.unavailable' % label_key
		assert_ne(
			tr(unavailable_key), unavailable_key,
			'the disabled-reason key built from option_label_key must still resolve - it would break if option_label_key started returning the desc key'
		)

func buff_ids_on(unit:Unit) -> Array:
	var ids := []
	for buff_core:BuffCore in unit.state.buffs:
		ids.append(buff_core.base.compcon_id)
	return ids

func test_uplink_returns_three_buffs():
	var buffs:Array[Buff] = fm_action().buffs_for_option(FmUtil.OPTION_UPLINK)
	assert_eq(buffs.size(), 3, 'uplink is accuracy + ignore_invisible + ignore_hidden')

func test_uplink_buffs_cover_the_three_required_hooks():
	var hooks := []
	for buff:Buff in fm_action().buffs_for_option(FmUtil.OPTION_UPLINK):
		hooks.append(buff.to)
	assert_has(hooks, Buff.TO.ATTACK_ROLL, 'uplink grants an attack roll bonus')
	assert_has(hooks, Buff.TO.IGNORE_INVISIBLE, 'uplink ignores invisibility')
	assert_has(hooks, Buff.TO.IGNORE_HIDDEN, 'uplink ignores hidden')

func test_uplink_accuracy_buff_is_one_shot_but_the_others_are_not():
	for buff:Buff in fm_action().buffs_for_option(FmUtil.OPTION_UPLINK):
		if buff.to == Buff.TO.ATTACK_ROLL:
			assert_true(buff.is_onetime, 'the accuracy bonus is consumed by one attack')
		else:
			assert_false(buff.is_onetime, '%s lasts the whole duration' % buff.to)

func test_uplink_buffs_expire_at_end_of_next_turn():
	for buff:Buff in fm_action().buffs_for_option(FmUtil.OPTION_UPLINK):
		assert_eq(buff.until, Lancer.UNTIL.END_OF_NEXT_TURN, '%s expires end of next turn' % buff.to)

func test_buffer_returns_one_buff_that_triggers_on_damage():
	var buffs:Array[Buff] = fm_action().buffs_for_option(FmUtil.OPTION_BUFFER)
	assert_eq(buffs.size(), 1, 'buffer is a single triggered buff')
	var buff:Buff = buffs[0]
	assert_has(buff.triggers_on, ReactionBus.TRIGGER.DAMAGE, 'buffer reacts to damage')
	assert_eq(buff.trigger_timing, ReactionBus.TIMING.PRE, 'overshield must land BEFORE the damage')

func test_buffer_grants_two_overshield():
	var buff:Buff = fm_action().buffs_for_option(FmUtil.OPTION_BUFFER)[0]
	assert_eq(buff.OVERSHIELD_AMOUNT, 2, 'the rulebook says 2')

func test_buffer_is_not_consumed_by_one_damage_instance():
	var buff:Buff = fm_action().buffs_for_option(FmUtil.OPTION_BUFFER)[0]
	assert_false(buff.is_onetime, 'buffer fires on EVERY damage instance, not just the first')

func test_buffer_expires_at_end_of_next_turn():
	var buff:Buff = fm_action().buffs_for_option(FmUtil.OPTION_BUFFER)[0]
	assert_eq(buff.until, Lancer.UNTIL.END_OF_NEXT_TURN, 'buffer expires end of next turn')

func test_firewall_returns_saves_plus_a_tech_roller_and_resetter():
	# A buff subscribes to exactly one trigger timing (reaction_bus.gd:134), so the tech half
	# is a PRE roller (which also carries the immunity) plus a POST resetter.
	var buffs:Array[Buff] = fm_action().buffs_for_option(FmUtil.OPTION_FIREWALL)
	assert_eq(buffs.size(), 3, 'firewall is saves + tech roller + tech resetter')
	var hooks := []
	for buff:Buff in buffs:
		hooks.append(buff.to)
	assert_has(hooks, Buff.TO.SAVE, 'firewall improves checks and saves')
	assert_has(hooks, Buff.TO.TECH_IMMUNITY, 'firewall can negate hostile tech')

func test_firewall_tech_roller_and_resetter_take_opposite_timings():
	var timings := {}
	for buff:Buff in fm_action().buffs_for_option(FmUtil.OPTION_FIREWALL):
		if not buff.triggers_on.has(ReactionBus.TRIGGER.UNIT_ACTION): continue
		timings[buff.trigger_timing] = true
	assert_true(timings.has(ReactionBus.TIMING.PRE), 'something rolls on PRE')
	assert_true(timings.has(ReactionBus.TIMING.POST), 'something clears on POST')

func test_firewall_saves_buff_covers_all_save_types_at_plus_one_accuracy():
	for buff:Buff in fm_action().buffs_for_option(FmUtil.OPTION_FIREWALL):
		if buff.to != Buff.TO.SAVE: continue
		assert_true(buff.all_save_types, 'all checks and saves, not one HASE')
		assert_eq(buff.mod, 1, '+1')
		assert_eq(buff.bonus_subtype, Buff.BONUS_SUBTYPE.ACCURACY, 'accuracy, not a flat bonus')

func test_firewall_saves_buff_is_not_onetime():
	# roll_check calls UnitCondition.consume_buffs on the save buffs it gathered; a onetime
	# buff would be eaten by the very first check.
	for buff:Buff in fm_action().buffs_for_option(FmUtil.OPTION_FIREWALL):
		if buff.to != Buff.TO.SAVE: continue
		assert_false(buff.is_onetime, 'the saves bonus must survive its first check')

func test_firewall_tech_buff_listens_for_unit_actions():
	var found := false
	for buff:Buff in fm_action().buffs_for_option(FmUtil.OPTION_FIREWALL):
		if buff.to != Buff.TO.TECH_IMMUNITY: continue
		found = true
		assert_has(buff.triggers_on, ReactionBus.TRIGGER.UNIT_ACTION, 'rolls per hostile tech action')
		assert_eq(buff.trigger_timing, ReactionBus.TIMING.PRE, 'the roll happens before resolution')
		assert_false(buff.is_onetime, 'must survive to judge every hostile tech action')
	assert_true(found, 'a tech_immunity buff exists to assert on')

func test_firewall_tech_immunity_is_inactive_until_a_roll_sets_the_flag():
	var ally := ally_at(Vector2i(2,3))
	var tech_buff:Buff = null
	for buff:Buff in fm_action().buffs_for_option(FmUtil.OPTION_FIREWALL):
		if buff.to == Buff.TO.TECH_IMMUNITY: tech_buff = buff
	assert_not_null(tech_buff, 'firewall has a tech buff')
	assert_false(tech_buff.FLAG_KEY.is_empty(), 'the roller exposes its flag key')
	# A freshly applied Firewall must NOT make the ally blanket tech-immune - that would be the
	# "drop the 50%" design we explicitly rejected.
	assert_false(UnitCondition.is_immune_to_tech(ally), 'no standing immunity before a roll')

func firewall_tech_buff() -> Buff:
	for buff:Buff in fm_action().buffs_for_option(FmUtil.OPTION_FIREWALL):
		if buff.to == Buff.TO.TECH_IMMUNITY: return buff
	return null

# Regression: is_hostile_tech_against used to only check that the actor was an enemy using tech
# gear ANYWHERE on the map - it never checked that our holder was actually among the action's
# targets. event_gear_activate.gd's create_virtual_event_unit_action mirrors the real activation's
# target_units onto the UNIT_ACTION virtual event core, so that's what the fix keys off.
func test_firewall_tech_buff_ignores_hostile_tech_not_aimed_at_holder():
	var holder := ally_at(Vector2i(2,3))
	var bystander := ally_at(Vector2i(2,4))
	var enemy := SpecFactory.create_unit(game.map, Vector2i(3,3), Faction.AI_ENEMY)
	var enemy_gear := enemy.core.equip_system(&'ms_neurospike')
	assert_true(UnitAction.is_tech(enemy_gear), 'precondition: ms_neurospike is tech gear')

	var tech_buff := firewall_tech_buff()
	assert_not_null(tech_buff, 'firewall has a tech buff')

	var event := EventCore.create(&'event_unit_action', {
		unit = enemy,
		gear = enemy_gear,
		target_units = [bystander], # aimed at someone else, NOT at `holder`
	})
	assert_false(tech_buff.is_hostile_tech_against(event, holder), 'a hostile tech action aimed at someone else must not count against the firewall holder')

func test_firewall_tech_buff_recognizes_hostile_tech_aimed_at_holder():
	var holder := ally_at(Vector2i(2,3))
	var enemy := SpecFactory.create_unit(game.map, Vector2i(3,3), Faction.AI_ENEMY)
	var enemy_gear := enemy.core.equip_system(&'ms_neurospike')
	assert_true(UnitAction.is_tech(enemy_gear), 'precondition: ms_neurospike is tech gear')

	var tech_buff := firewall_tech_buff()
	assert_not_null(tech_buff, 'firewall has a tech buff')

	var event := EventCore.create(&'event_unit_action', {
		unit = enemy,
		gear = enemy_gear,
		target_units = [holder], # aimed squarely at our holder
	})
	assert_true(tech_buff.is_hostile_tech_against(event, holder), 'a hostile tech action actually aimed at the holder must still count')

# ==================== TARGETING OVERRIDES (Task 6) ====================

func specific_fm() -> SpecificAction:
	return SpecificAction.create(denali, denali.get_gear(CORE_POWER_ID), fm_action())

func test_targets_an_adjacent_ally():
	var ally := ally_at(Vector2i(2,3))
	assert_true(fm_action().can_target_unit(ally, specific_fm()), 'adjacent ally is targetable')

func test_does_not_target_an_enemy():
	var enemy := SpecFactory.create_unit(game.map, Vector2i(2,3), Faction.AI_ENEMY)
	assert_false(fm_action().can_target_unit(enemy, specific_fm()), 'enemies are not valid targets')

func test_does_not_target_self():
	assert_false(fm_action().can_target_unit(denali, specific_fm()), 'cannot force multiply yourself')

## Run a real Force Multiplier activation, answering the option menu with `pick`.
## Force Multiplier is actions[0] on cp_auto_logistic_compcon.tres (Optimizer is actions[1]),
## so get_solo_action() - what use_solo fires - resolves to Force Multiplier. Mirrors how
## spec/test_mt_field_supply.gd drives its own menu via ModChoiceResponder.
func use_force_multiplier(pick:int) -> void:
	responder = add_child_autoqfree(ModChoiceResponder.new())
	responder.multiple_choice_queue = [pick]
	await SpecFactory.use_solo(game, denali, CORE_POWER_ID)

func test_still_targets_an_ally_made_tech_immune_by_our_own_firewall():
	# ActionSystemApplyBuff.can_target_unit rejects tech-immune targets, and FM is tech. Without
	# the override, an ally holding a live Firewall would be untargetable by Force Multiplier.
	var ally := ally_at(Vector2i(2,3))
	await use_force_multiplier(PICK_FIREWALL)

	# Force the flag on directly: the roll only fires against a hostile tech action, and this
	# test is about targeting, not about the roll.
	var tech_buff := firewall_tech_buff()
	for buff_core:BuffCore in ally.state.buffs:
		if buff_core.base.compcon_id == tech_buff.compcon_id:
			buff_core.set_state(tech_buff.FLAG_KEY, true)

	assert_true(UnitCondition.is_immune_to_tech(ally), 'precondition: the ally now reads tech-immune')
	assert_true(
		fm_action().can_target_unit(ally, specific_fm()),
		'our own firewall must not block force multiplier'
	)

func test_target_range_is_adjacent_by_default():
	assert_eq(fm_action().get_target_range(specific_fm()), 1, 'standalone FM is adjacent only')

func test_target_range_widens_to_sensors_via_meta_fallback():
	# was_invoked_by_optimizer's SECONDARY path only: Object metadata on the SpecificAction
	# instance. SpecificAction is rebuilt at every engine layer between Optimizer's kickstart
	# and here (from_context/clone/from_id copy only unit, gear and action - never metadata), so
	# this is NOT the mechanism that ships; it's kept as a fallback in case something still sets
	# it this way. See test_target_range_widens_via_real_optimizer_entry_point below for the
	# actual shipped path (GearCore state via mark_invoked_by_optimizer).
	var specific := specific_fm()
	specific.set_meta(fm_action().OPTIMIZER_INVOCATION_FLAG, true)
	assert_eq(
		fm_action().get_target_range(specific),
		denali.get_sensor_range(),
		'optimizer invokes FM at sensors + line of sight (meta fallback)'
	)

func test_target_range_widens_via_real_optimizer_entry_point():
	# Drives the mechanism Optimizer will actually use: mark_invoked_by_optimizer sets state on
	# the shared GearCore, which survives the SpecificAction rebuilds between Optimizer's
	# kickstart and get_target_range - unlike the set_meta fallback exercised above.
	var specific := specific_fm()
	fm_action().mark_invoked_by_optimizer(specific.gear)
	assert_eq(
		fm_action().get_target_range(specific),
		denali.get_sensor_range(),
		'optimizer invokes FM at sensors + line of sight, via real gear state'
	)

func test_optimizer_flag_is_false_before_any_activation():
	var gear := denali.get_gear(CORE_POWER_ID)
	assert_false(
		gear.get_state(fm_action().OPTIMIZER_INVOCATION_FLAG, false),
		'a fresh Denali has never been invoked by Optimizer'
	)

func test_optimizer_flag_cleared_after_a_completed_activation():
	# The flag must not survive a full, successful Force Multiplier activation either - not
	# just the abort path below - or the NEXT ordinary use would silently widen to sensor range.
	var ally := ally_at(Vector2i(2,3))
	var gear := denali.get_gear(CORE_POWER_ID)
	fm_action().mark_invoked_by_optimizer(gear)
	await use_force_multiplier(PICK_BUFFER)
	assert_false(
		gear.get_state(fm_action().OPTIMIZER_INVOCATION_FLAG, false),
		'flag must be cleared after a normal, completed activation'
	)

func test_optimizer_flag_does_not_leak_when_activation_aborts_before_applying_buffs():
	# The leak case: ActionSystemApplyBuff.activate has early returns (abort_when(not
	# confirmed), abort_without_targeting_plan(plan), abort_without_units(target_units)) before
	# apply_buffs_to_targets is ever reached. A flag cleared only inside apply_buffs_to_targets
	# would survive any of those and silently widen the Denali's NEXT, ordinary use.
	#
	# Staging this needs an ally to exist SOMEWHERE on the map (or ActionSystemApplyBuff's own
	# is_available_to_activate rejects the whole activation before event_gear_activate ever
	# calls Action.activate - a leak our fix, or any fix confined to this action script, cannot
	# reach, since our code never runs at all; confirmed empirically with no ally present, where
	# the log shows "[ Gear not available ] reason : specific" and the flag - unsurprisingly -
	# stays set). So: shrink sensor_range to 1 (same trick as test_is_maintained_false_for_ally_
	# beyond_sensor_range) and place the ally exactly ONE tile beyond it. is_available_to_activate
	# is satisfied (an ally exists on the map at all - it doesn't check range), so
	# event_gear_activate dispatches to Action.activate normally. But get_target_range, widened
	# to sensors by the Optimizer flag, still can't reach that ally, so ask_for_targets finds no
	# valid target tile or unit, CompconPlan.is_valid_with_targets_alt returns false, and
	# ActionSystemApplyBuff.activate aborts via abort_without_targeting_plan BEFORE
	# apply_buffs_to_targets runs - proving the clear does not depend on reaching that method.
	denali.core.frame.stat.sensor_range = 1
	var sensor_range:int = denali.get_sensor_range()
	var out_of_range_ally := ally_at(Vector2i(2 + sensor_range + 1, 2))
	assert_eq(UnitRelation.distance_between(denali, out_of_range_ally), sensor_range + 1, 'precondition: ally is exactly one tile beyond sensor range')

	var gear := denali.get_gear(CORE_POWER_ID)
	fm_action().mark_invoked_by_optimizer(gear)
	responder = add_child_autoqfree(ModChoiceResponder.new())
	await SpecFactory.use_solo(game, denali, CORE_POWER_ID)
	assert_false(
		gear.get_state(fm_action().OPTIMIZER_INVOCATION_FLAG, false),
		'the flag must not survive an aborted activation, or the next ordinary use would widen to sensor range'
	)

# ==================== TASK 7: BEHAVIOURAL COVERAGE ====================
#
# Tasks 1-6 assert mostly on CONFIGURATION - that a buff carries the right `to`, `until` and
# flags. That proves the wiring, not the behaviour. These tests run real activations end to end.

# ============ 1/scene, per effect, per character ============

func test_an_effect_becomes_unavailable_on_that_ally_after_use():
	var ally := ally_at(Vector2i(2,3))
	await use_force_multiplier(PICK_UPLINK)
	assert_true(FmUtil.has_used(ally, FmUtil.OPTION_UPLINK), 'uplink is marked as used')
	assert_false(fm_action().is_option_available(ally, FmUtil.OPTION_UPLINK), 'uplink now unavailable')

func test_the_other_two_effects_remain_available_on_the_same_ally():
	var ally := ally_at(Vector2i(2,3))
	await use_force_multiplier(PICK_UPLINK)
	assert_true(fm_action().is_option_available(ally, FmUtil.OPTION_BUFFER), 'buffer still available')
	assert_true(fm_action().is_option_available(ally, FmUtil.OPTION_FIREWALL), 'firewall still available')

func test_the_same_effect_remains_available_on_a_different_ally():
	var first := ally_at(Vector2i(2,3))
	await use_force_multiplier(PICK_UPLINK)
	var second := ally_at(Vector2i(3,2))
	assert_false(fm_action().is_option_available(first, FmUtil.OPTION_UPLINK), 'spent on the first ally')
	assert_true(fm_action().is_option_available(second, FmUtil.OPTION_UPLINK), 'the limit is per character')

# ============ maintenance: suspend and resume, never expire ============

func test_an_effect_is_inert_while_the_ally_is_out_of_sensor_range():
	var ally := ally_at(Vector2i(2,3))
	await use_force_multiplier(PICK_UPLINK)
	var far_tile := Vector2i(2 + denali.get_sensor_range() + 3, 2)
	UnitTile.move_to(ally, far_tile)
	assert_false(FmUtil.is_maintained(denali, ally), 'out of sensors, the benefit is inert')

func test_the_buff_is_not_expired_by_going_out_of_range_and_recovers_on_return():
	var ally := ally_at(Vector2i(2,3))
	await use_force_multiplier(PICK_UPLINK)
	var buff_count_before := ally.state.buffs.size()

	UnitTile.move_to(ally, Vector2i(2 + denali.get_sensor_range() + 3, 2))
	assert_eq(ally.state.buffs.size(), buff_count_before, 'the buff must SUSPEND, not expire')

	UnitTile.move_to(ally, Vector2i(2,3))
	assert_true(FmUtil.is_maintained(denali, ally), 'the benefit returns on coming back into range')

# ============ buffer fires repeatedly ============

## Queues a real event_unit_damage through the running Gamemaster - mirrors
## content/talents/support/t_drone_commander/rank_3/action_invigorate.gd's own event_unit_damage
## call site (unit, number, category).
func damage_unit(unit:Unit, amount:int) -> void:
	await game.execute_event(&'event_unit_damage', {
		unit = unit,
		number = amount,
		category = Lancer.DAMAGE_TYPE.KINETIC,
	})

## NOTE on the numbers below: the brief's literal scaffold asserted overshield == 2 straight after
## a 1-point damage instance. That contradicts event_unit_damage.gd's own damage() (line 217-220:
## `overshield_takes = mini(amount, overshield); overshield -= overshield_takes`) - overshield is a
## depleting resource, not a flat shield that coexists untouched with the hit it blocks. buff_fm_
## buffer.gd's own doc comment agrees: the PRE grant lands BEFORE damage() spends it, not instead of
## it. So a fresh 2 overshield absorbing 1 damage correctly ends at 1, confirmed by the game's own
## log during Task 7's first run ("...and now has 1 overshield" for exactly this sequence). The
## corrected assertions below check that value instead, and add a health-unchanged assertion to
## prove the grant is what absorbed the hit, not a coincidence of the numbers involved.
func test_buffer_refreshes_overshield_on_a_second_damage_instance():
	var ally := ally_at(Vector2i(2,3))
	await use_force_multiplier(PICK_BUFFER)
	var health_before := ally.core.current.health

	await damage_unit(ally, 1)
	assert_eq(ally.state.overshield, 1, 'buffer granted 2 overshield, which absorbed 1 of the incoming damage')
	assert_eq(ally.core.current.health, health_before, 'the granted overshield, not health, took the hit')

	ally.state.overshield = 0 # the first shield absorbed what it absorbed
	await damage_unit(ally, 1)
	assert_eq(ally.state.overshield, 1, 'buffer fires again - it is not one-shot')
	assert_eq(ally.core.current.health, health_before, 'the second grant absorbed the second hit too')

func test_buffer_does_not_reduce_overshield_that_is_already_higher():
	var ally := ally_at(Vector2i(2,3))
	await use_force_multiplier(PICK_BUFFER)
	ally.state.overshield = 6
	await damage_unit(ally, 1)
	# maxi(6, 2) keeps the grant at 6 - 2 must not overwrite/lower it - and THEN the incoming 1
	# damage spends 1 of that 6 the same way it would spend any other overshield, leaving 5.
	assert_eq(ally.state.overshield, 5, 'overshield takes the max (2 must not overwrite 6); the hit still spends normally from it')

# ============ firewall: the full PRE roll -> immunity -> POST clear cycle ============
#
# These are the most important tests in this task. Everything Firewall does was proven only
# structurally in Task 5 - that the buffs carry the right flags - never that the cycle runs.
# Three separate things are unproven and each would fail silently in play:
#   1. context.target_units is populated for a REAL hostile tech activation. It is populated on
#      the NPC path (ai_npc.gd:52-57 -> event_gear_activate.gd:126), which is the case that
#      matters, but that has never been executed in a test.
#   2. The POST resetter's `buff_core.base is FirewallTech` actually matches at runtime.
#   3. A winning roll genuinely makes the ally read tech-immune mid-action.

var flag_was_set_during_last_action:bool = false

## Runs a genuine hostile NPC tech action (GMS Neurospike's Shrike Code, ActionAttackTech) against
## `ally` through the REAL event_gear_activate pipeline - unlike the synthetic event_unit_action
## built by test_firewall_tech_buff_ignores/recognizes_hostile_tech above, this actually exercises
## event_gear_activate.gd's create_virtual_event_unit_action mirroring context.target_units onto
## the UNIT_ACTION virtual event, and the real reaction bus resolving triggers_on_event against it.
##
## Shrike Code applies buff_shrike_code to its target ON HIT (via on_hit_effects, resolved through
## event_unit_attack_declared -> event_unit_attack). We use presence/absence of that debuff as the
## observable, per the brief's "assert the negated outcome" preference - it is the strongest proof
## available, because a winning Firewall roll must exclude the ally from
## ActionAttack.get_attacked_tiles_and_units_from_plan's can_target_unit filter (action_attack_tech.
## gd:66, UnitCondition.is_immune_to_tech) BEFORE any accuracy roll happens, so the debuff can never
## land - not merely that a dictionary flag briefly flipped. ally's e-defense (NOT evasion - Shrike
## Code is a TECH attack: action_attack_tech.gd's get_against_attack_type returns ATTACK_TYPE.TECH,
## and AttackRoll.PreAttack.create maps that to e_defense via AttackUtil.calculate_target_defense -
## evasion is never consulted) is dropped to 1 first so a NON-immune ally is hit deterministically
## and the "not immune -> debuff lands" half of the proof holds too. (An earlier version of this
## helper set evasion = 1 instead, a no-op against a tech attack - see
## test_firewall_losing_roll_grants_no_immunity for how that produced the flake.)
##
## The enemy is AI-controlled (Faction.AI_ENEMY), so ActionAttack.activate's
## confirm_friendly_fire/confirm_aoe_no_targets gates both short-circuit true immediately
## (target_action_util.gd: `if not context.unit.is_player_controlled(): return true`) - no
## interactive choice_bus prompt to stall on, on either the hit or the immune/no-targets path.
func hostile_tech_against(ally:Unit) -> void:
	ally.core.frame.stat.edef = 1 # guarantee a hit when NOT immune (tech attacks roll vs e_defense, not evasion)
	var enemy := SpecFactory.create_unit(game.map, Vector2i(3,3), Faction.AI_ENEMY)
	var enemy_gear := enemy.core.equip_system(&'ms_neurospike')
	var shrike_code:Action = enemy_gear.kit.actions[0]

	var had_debuff_before := ally.state.buffs.any(func(buff_core:BuffCore) -> bool:
		return buff_core.base.compcon_id == &'buff_shrike_code'
	)

	await game.execute_event(&'event_gear_activate', {
		action = shrike_code,
		unit = enemy,
		gear = enemy_gear,
		target_tiles = [ally.tile()],
		target_unit = ally,
	})

	var has_debuff_after := ally.state.buffs.any(func(buff_core:BuffCore) -> bool:
		return buff_core.base.compcon_id == &'buff_shrike_code'
	)
	flag_was_set_during_last_action = (not had_debuff_before) and (not has_debuff_after)

func test_firewall_roll_fires_against_a_real_hostile_npc_tech_action():
	var ally := ally_at(Vector2i(2,3))
	await use_force_multiplier(PICK_FIREWALL)
	var tech_buff := firewall_tech_buff()

	Dice.CHEAT_ROLL_QUEUE.append(1) # 1..10 wins on d20 <= 10
	await hostile_tech_against(ally)

	# The flag is cleared again by the POST resetter, so assert on the effect having been live
	# during the action rather than on the flag afterwards - see the next test for the clear.
	assert_true(
		flag_was_set_during_last_action,
		'a winning roll must set the immunity flag while the hostile tech action resolves'
	)

func test_firewall_post_resetter_clears_the_flag_after_the_action():
	var ally := ally_at(Vector2i(2,3))
	await use_force_multiplier(PICK_FIREWALL)
	var tech_buff := firewall_tech_buff()

	Dice.CHEAT_ROLL_QUEUE.append(1) # winning roll
	await hostile_tech_against(ally)

	# NOTE: `found` must be asserted - without it, a buff that's gone missing entirely makes this
	# loop assert nothing at all and the test passes having proven nothing (finding 4).
	var found := false
	for buff_core:BuffCore in ally.state.buffs:
		if buff_core.base.compcon_id != tech_buff.compcon_id: continue
		found = true
		assert_false(
			buff_core.get_state(tech_buff.FLAG_KEY, false),
			'the POST resetter must clear the flag, or the ally stays tech-immune between actions'
		)
	assert_true(found, 'the firewall tech buff must still be present on the ally to assert on')
	assert_false(UnitCondition.is_immune_to_tech(ally), 'no standing immunity after the action')

# ==================== FINAL REVIEW FINDINGS ====================

# ---- Finding 1: the 1/scene marker must survive the granting Denali's death ----
#
# The markers are applied via apply_buff_id, which sets from_gear = the Denali's core power gear
# (action.gd:365). Buff.is_cleared_on_owner_death() defaults to true (buff.gd:184), and
# event_service.gd's remove_unit_from_game calls clear_outgoing_buffs_from_unit(..., true) on
# death (event_service.gd:60), which wipes every buff owned by the dying unit's gear off every
# other unit - including these markers - unless the marker overrides that default. Without the
# override, the Denali dying silently resets the 1/scene limit on every ally it ever touched.
func test_marker_buff_survives_the_granting_denalis_death():
	var ally := ally_at(Vector2i(2,3))
	await use_force_multiplier(PICK_UPLINK)
	assert_true(FmUtil.has_used(ally, FmUtil.OPTION_UPLINK), 'precondition: uplink is marked as used')

	await game.execute_event(&'event_unit_die', {unit = denali})

	assert_true(FmUtil.has_used(ally, FmUtil.OPTION_UPLINK), 'the 1/scene marker must survive the granting Denali dying')
	assert_false(fm_action().is_option_available(ally, FmUtil.OPTION_UPLINK), 'uplink must stay unavailable on that ally after the Denali dies')

# ---- Finding 2: a dead-or-incapacitated Denali must stop maintaining its buffs ----
#
# is_maintained already fails closed once the Denali is fully removed from the game (Unit.is_valid
# checks is_alive). But a SHUTDOWN Denali is still Unit.is_valid (is_alive stays true - it's simply
# incapacitated, not destroyed) - "no longer a valid actor", per Unit.is_actor(), which additionally
# requires not SHUTDOWN and health > 0. This matters most for the Firewall tech-immunity buffs,
# which are deliberately applied with from_gear = null (see action_force_multiplier.gd's
# apply_option_buff doc comment on the check_if_prohibited <-> is_immune_to_tech recursion) and so
# CANNOT be cleared by clear_buffs_owned_by/clear_outgoing_buffs_from_unit, which match on
# core.from_gear == gear_id. Those buffs have no owner-death cleanup path at all; is_maintained is
# the only gate standing between an incapacitated Denali and a benefit that outlives it.
func test_firewall_stops_being_maintained_while_the_denali_is_shutdown():
	var ally := ally_at(Vector2i(2,3))
	await use_force_multiplier(PICK_FIREWALL)
	assert_true(FmUtil.is_maintained(denali, ally), 'precondition: maintained while the Denali is active')

	SpecFactory.apply(denali, Lancer.STATUS.SHUTDOWN, Lancer.UNTIL.MANUAL)
	assert_true(Unit.is_valid(denali), 'precondition: a shutdown Denali is still Unit.is_valid (not dead, just disabled)')
	assert_false(denali.is_actor(), 'precondition: a shutdown Denali is no longer a valid actor')

	assert_false(FmUtil.is_maintained(denali, ally), 'a shutdown Denali must not maintain force multiplier benefits')

func test_firewall_immunity_stops_applying_once_the_denali_is_shutdown():
	var ally := ally_at(Vector2i(2,3))
	await use_force_multiplier(PICK_FIREWALL)
	var tech_buff := firewall_tech_buff()
	for buff_core:BuffCore in ally.state.buffs:
		if buff_core.base.compcon_id == tech_buff.compcon_id:
			buff_core.set_state(tech_buff.FLAG_KEY, true) # force the flag on, same trick as the targeting test above
	assert_true(UnitCondition.is_immune_to_tech(ally), 'precondition: ally reads tech-immune while the Denali is up')

	SpecFactory.apply(denali, Lancer.STATUS.SHUTDOWN, Lancer.UNTIL.MANUAL)

	assert_false(UnitCondition.is_immune_to_tech(ally), 'a shutdown Denali must not keep the ally tech-immune')

# ---- Finding 3: behavioural coverage the design promised but nothing ever executed ----

## Uplink's accuracy is consumed by the one attack it boosts; the ignores survive it.
func test_uplink_accuracy_bonus_is_consumed_by_one_attack_but_ignores_survive():
	var ally := ally_at(Vector2i(2,3))
	var enemy := SpecFactory.create_unit(game.map, Vector2i(4,4), Faction.AI_ENEMY)
	enemy.core.frame.stat.evasion = 1 # guarantee the attack hits

	await use_force_multiplier(PICK_UPLINK)
	var uplink_buffs:Array[Buff] = fm_action().buffs_for_option(FmUtil.OPTION_UPLINK)
	var accuracy_id:StringName; var ignore_invis_id:StringName; var ignore_hidden_id:StringName
	for buff:Buff in uplink_buffs:
		if buff.to == Buff.TO.ATTACK_ROLL: accuracy_id = buff.compcon_id
		elif buff.to == Buff.TO.IGNORE_INVISIBLE: ignore_invis_id = buff.compcon_id
		elif buff.to == Buff.TO.IGNORE_HIDDEN: ignore_hidden_id = buff.compcon_id

	var ids_before := buff_ids_on(ally)
	assert_has(ids_before, accuracy_id, 'precondition: accuracy buff present before attacking')
	assert_has(ids_before, ignore_invis_id, 'precondition: ignore-invisible present before attacking')
	assert_has(ids_before, ignore_hidden_id, 'precondition: ignore-hidden present before attacking')

	var weapon := ally.core.equip_system(&'mw_assault_rifle')
	await game.execute_event(&'event_gear_activate', {
		action = weapon.kit.get_action(&'mw_assault_rifle'),
		unit = ally,
		gear = weapon,
		target_tiles = [enemy.tile()],
		target_unit = enemy,
	})

	var ids_after := buff_ids_on(ally)
	assert_false(ids_after.has(accuracy_id), 'the accuracy bonus is consumed by the one attack it boosted')
	assert_has(ids_after, ignore_invis_id, 'ignore-invisible must survive the attack')
	assert_has(ids_after, ignore_hidden_id, 'ignore-hidden must survive the attack')

## The single most load-bearing engine assumption in the whole design: UnitHasecheck.roll_check is
## the common funnel for both checks and saves, and applies Buff.TO.SAVE bonuses regardless of its
## is_save flag. Proven through a CONTESTED HULL CHECK - a check, not a save - exactly the case
## content/gear/basic/ms_grapple_end/action_grapple_break.gd exercises via make_contested_hull_check.
## The ally's raw d20 roll is rigged to land exactly one short of the enemy's number to beat; only
## firewall's +1 accuracy (itself pinned to its minimum, via CHEAT_ROLL_QUEUE) can close that gap.
func test_firewall_accuracy_applies_to_a_contested_hull_check_not_just_a_save():
	var ally := ally_at(Vector2i(2,3))
	ally.core.frame.stat.evasion = 1 # guarantee the enemy's grapple attack connects
	var enemy := SpecFactory.create_unit(game.map, Vector2i(2,4), Faction.AI_ENEMY)

	await use_force_multiplier(PICK_FIREWALL)

	var grapple_gear:GearCore = enemy.core.loadout.get_by_compcon_id(&'mw_grapple')
	await game.execute_event(&'event_gear_activate', {
		unit = enemy,
		gear = grapple_gear,
		action = grapple_gear.get_action(&'action_grapple'),
		target_unit = ally,
	})
	assert_true(ally.has_status(Lancer.STATUS.GRAPPLED), 'precondition: ally is grappled by the enemy')

	var enemy_d20 := 10
	var number_to_beat := enemy_d20 + enemy.core.get_hull()
	var ally_d20 := number_to_beat - 1 - ally.core.get_hull()
	assert_between(ally_d20, 1, 20, 'precondition: the rigged ally roll must be a legal d20 result')

	var end_grapple_gear:GearCore = ally.core.loadout.get_by_compcon_id(&'ms_grapple_end')
	var end_grapple_action := end_grapple_gear.get_action(&'action_grapple_break')
	ally.state.overcharge_actions = 10 # afford the check regardless of what FM already spent

	# order matches make_contested_hull_check: unit2 (enemy) rolls first for the number to beat,
	# then unit1 (ally) rolls - d20 then, because firewall's accuracy_bonus is nonzero, one more
	# pop for the accuracy d6 (pinned to 1, its minimum, via roll_d6_accuracy's MAX-of-N summary).
	Dice.CHEAT_ROLL_QUEUE.append_array([enemy_d20, ally_d20, 1])
	await game.execute_event(&'event_gear_activate', {
		unit = ally,
		gear = end_grapple_gear,
		action = end_grapple_action,
	})

	assert_false(
		ally.has_status(Lancer.STATUS.GRAPPLED),
		"the ally's raw roll fell exactly one short of the target - only firewall's +1 accuracy can have closed the gap and broken the grapple"
	)

func test_firewall_losing_roll_grants_no_immunity():
	# Root cause of the flake this pins down: CHEAT_ROLL_QUEUE is a single shared queue popped by
	# EVERY d20 roll in order, and a hostile tech activation rolls twice - buff_fm_firewall_tech's
	# own PRE roll first (execute_preblock runs before the action's activate, per
	# content/events/event_gear_activate.gd), then, IF that roll loses (as here), Shrike Code's own
	# attack roll (AttackRoll.roll_attack -> Dice.roll_d20_with_player_interventions) against the
	# ally's e-defense. Queuing only the firewall's losing roll left that second roll un-pinned, so
	# it fell through to a real random roll (attack_roll.gd:67) - about half the time it missed, the
	# Shrike Code debuff never landed, and `flag_was_set_during_last_action`'s (not had_debuff_before
	# and not has_debuff_after) proxy misread "the attack simply missed" as "immunity was granted",
	# spuriously failing the assert_false below roughly one run in three (matches the win chance of
	# a d20 miss against the ally's e_defense, which hostile_tech_against pins to 1).
	#
	# Fix: queue BOTH rolls, in the order they're consumed - the firewall's losing roll first, then
	# a guaranteed-hit d20 for the attack itself - so the debuff lands deterministically whenever the
	# ally is not immune, restoring the proxy's validity regardless of the real RNG.
	var ally := ally_at(Vector2i(2,3))
	await use_force_multiplier(PICK_FIREWALL)

	Dice.CHEAT_ROLL_QUEUE.append_array([
		20, # firewall's own PRE roll: 11..20 loses on d20 <= 10, so no immunity is granted
		20, # Shrike Code's own attack roll: forces a hit against edef=1 regardless of the miss above
	])
	await hostile_tech_against(ally)

	assert_false(
		flag_was_set_during_last_action,
		'a losing roll must not grant immunity'
	)

# ---- Regression: Buffer must not go silent while Firewall's immunity flag is live ----
#
# Buff.check_if_prohibited (buff.gd:215-226) prohibits ANY buff whose owner gear is tech,
# whenever the buff's holder is currently tech-immune. Force Multiplier is a tech action, so
# every buff it grants has a tech owner gear by default. Uplink/Buffer/Firewall are three
# separate 1/scene-per-character options, so one ally can legitimately hold both Buffer and a
# live Firewall at once (Buffer this round, Firewall next, say) - and a winning Firewall roll
# must not silently suppress Buffer's damage trigger for as long as the immunity flag is up.
# That is exactly the failure this pins: before the fix, Buffer's owner gear reads tech and the
# holder reads tech-immune, so check_if_prohibited returns true and Buffer's PRE reaction never
# fires - the ally takes the hit with no overshield at all, precisely when they're under fire.
func test_buffer_still_grants_overshield_while_firewall_immunity_is_live():
	var ally := ally_at(Vector2i(2,3))
	var specific := specific_fm()

	# apply_option_buff directly, bypassing a full use_force_multiplier() activation twice: Force
	# Multiplier is a core power, and real play only allows ONE core power use per turn - a second
	# full activation in the same turn aborts on REASON.NO_CORE_POWER (unit_action.gd:120) before
	# ever reaching the code under test (confirmed empirically: attempting two use_force_multiplier
	# calls in a row aborts the second with "specific: invalid"). This calls the exact dispatcher
	# (action_force_multiplier.gd's apply_option_buff) that a real Buffer-then-Firewall sequence
	# across two separate turns would reach, without the turn-economy gate getting in the way of
	# what this test is actually about.
	var event := EventCore.create(&'event_gear_activate', {unit = denali, gear = specific.gear, action = specific.action})
	fm_action().apply_option_buff(event, specific, ally, fm_action().buffs_for_option(FmUtil.OPTION_BUFFER)[0])
	fm_action().apply_option_buff(event, specific, ally, firewall_tech_buff())

	# Force the flag on directly - same trick as test_still_targets_an_ally_made_tech_immune_by_
	# our_own_firewall and test_firewall_immunity_stops_applying_once_the_denali_is_shutdown. The
	# roll itself is proven elsewhere (test_firewall_roll_fires_against_a_real_hostile_npc_tech_
	# action); this test is only about whether Buffer survives the flag being live.
	var tech_buff := firewall_tech_buff()
	for buff_core:BuffCore in ally.state.buffs:
		if buff_core.base.compcon_id == tech_buff.compcon_id:
			buff_core.set_state(tech_buff.FLAG_KEY, true)
	assert_true(UnitCondition.is_immune_to_tech(ally), 'precondition: the ally now reads tech-immune from our own Firewall')

	var health_before := ally.core.current.health
	await damage_unit(ally, 1)
	assert_eq(ally.state.overshield, 1, 'Buffer must still grant 2 overshield (which absorbs 1 of the 1 incoming damage) even while Firewall immunity is live')
	assert_eq(ally.core.current.health, health_before, 'the granted overshield, not health, must take the hit')

# ---- Regression: Firewall's own saves bonus must not go silent while ITS OWN immunity flag is live ----
#
# BUFF_FIREWALL_SAVES (to=save, passive-lookup) goes through the exact same UnitCondition.
# does_buff_apply -> Buff.check_if_prohibited path as the Uplink buffs above (traced via
# UnitHasecheck.roll_check -> UnitCondition.get_buffs_to(unit, Buff.TO.SAVE, ...) at
# unit_hasecheck.gd:178, which calls does_buff_apply per buff at unit_condition.gd:803, which
# calls check_if_prohibited at unit_condition.gd:823). Force Multiplier is tech, so this buff's
# owner gear reads tech too - and unlike Buffer/Uplink, Firewall's OWN winning roll is what sets
# the tech-immunity flag on the SAME holder. Without BUFF_FIREWALL_SAVES in
# BUFFS_EXPOSED_TO_TECH_IMMUNITY, the instant Firewall's tech half succeeds, check_if_prohibited
# sees a tech owner gear + a tech-immune holder and silently suppresses the saves half - the
# benefit disabling half of itself at exactly the moment it's working. Modeled on
# test_firewall_accuracy_applies_to_a_contested_hull_check_not_just_a_save above: same contested
# hull check via action_grapple_break -> UnitHasecheck.make_contested_hull_check -> roll_check,
# but with the tech-immunity flag forced on first (same trick as
# test_still_targets_an_ally_made_tech_immune_by_our_own_firewall).
func test_firewall_saves_bonus_still_applies_while_its_own_tech_immunity_is_live():
	var ally := ally_at(Vector2i(2,3))
	ally.core.frame.stat.evasion = 1 # guarantee the enemy's grapple attack connects
	var enemy := SpecFactory.create_unit(game.map, Vector2i(2,4), Faction.AI_ENEMY)

	await use_force_multiplier(PICK_FIREWALL)

	var grapple_gear:GearCore = enemy.core.loadout.get_by_compcon_id(&'mw_grapple')
	await game.execute_event(&'event_gear_activate', {
		unit = enemy,
		gear = grapple_gear,
		action = grapple_gear.get_action(&'action_grapple'),
		target_unit = ally,
	})
	assert_true(ally.has_status(Lancer.STATUS.GRAPPLED), 'precondition: ally is grappled by the enemy')

	# Force the flag on directly, same trick as test_still_targets_an_ally_made_tech_immune_by_
	# our_own_firewall - the roll mechanics are proven elsewhere; this test is only about whether
	# the saves buff survives the flag being live. Done AFTER the grapple attack above (itself a
	# unit_action) and IMMEDIATELY before the check below: buff_fm_firewall_tech_reset's POST
	# reaction fires on EVERY resolved unit action, not just hostile-tech ones, so setting the
	# flag any earlier would have it silently cleared by the grapple attack's own POST before the
	# contested check ever ran.
	var tech_buff := firewall_tech_buff()
	for buff_core:BuffCore in ally.state.buffs:
		if buff_core.base.compcon_id == tech_buff.compcon_id:
			buff_core.set_state(tech_buff.FLAG_KEY, true)
	assert_true(UnitCondition.is_immune_to_tech(ally), 'precondition: the ally now reads tech-immune from its own Firewall')

	var enemy_d20 := 10
	var number_to_beat := enemy_d20 + enemy.core.get_hull()
	var ally_d20 := number_to_beat - 1 - ally.core.get_hull()
	assert_between(ally_d20, 1, 20, 'precondition: the rigged ally roll must be a legal d20 result')

	var end_grapple_gear:GearCore = ally.core.loadout.get_by_compcon_id(&'ms_grapple_end')
	var end_grapple_action := end_grapple_gear.get_action(&'action_grapple_break')
	ally.state.overcharge_actions = 10 # afford the check regardless of what FM already spent

	# order matches make_contested_hull_check: unit2 (enemy) rolls first for the number to beat,
	# then unit1 (ally) rolls d20, then, because firewall's accuracy_bonus is nonzero (IF the
	# buff still applies despite the immunity flag), one more pop for the accuracy d6 (pinned to
	# 1, its minimum, via roll_d6_accuracy's MAX-of-N summary).
	Dice.CHEAT_ROLL_QUEUE.append_array([enemy_d20, ally_d20, 1])
	await game.execute_event(&'event_gear_activate', {
		unit = ally,
		gear = end_grapple_gear,
		action = end_grapple_action,
	})

	assert_false(
		ally.has_status(Lancer.STATUS.GRAPPLED),
		"the ally's raw roll fell exactly one short of the target - only firewall's +1 accuracy can have closed the gap, and it must still apply while the ally is tech-immune from its own Firewall roll"
	)

# ==================== LOCALIZATION (the two reported root causes) ====================
#
# Root cause 1: Translate.action (translate.gd:19) builds its lookup key from Action.get_id(),
# which returns the .tres FILE'S basename ('action_force_multiplier' - action.gd:86-88), but
# localizations.csv keyed the whole family off the FOLDER name ('cp_force_multiplier') instead.
# The lookup misses, and Translate.action silently falls back to the KIT's own name/effect keys
# (gear.cp_auto_logistic_compcon.name / .effect) - "AUTO-LOGISTIC COMP/CON" for name, blank for
# effect - which is why the tooltip showed no effect text at all.
#
# Root cause 2: Translate.buff (translate.gd:49) does Translate.key(['gear', override, property])
# - it PREPENDS 'gear' itself. Every Force Multiplier buff's localization_key_override already
# included a leading 'gear.', producing 'gear.gear....' keys that match nothing in the CSV.
#
# These assert on the RESOLVED TEXT (exact strings, or non-empty where text is long/BBCode-heavy),
# not merely `tr(key) != key` - a CSV row whose value happened to equal the key string would pass
# the weaker check while still being wrong. Do NOT "fix" this by setting localization_key_override
# on the action itself - Action.show_in_tooltip (action.gd:332-345) returns false whenever that
# override is non-empty, which would hide Force Multiplier from the kit tooltip entirely.

func test_force_multiplier_action_name_resolves_to_its_own_text_not_the_kit_fallback():
	var kit := ContentLibrary.get_kit(CORE_POWER_ID)
	var text := Translate.action(kit, fm_action(), 'name', false)
	# Pre-fix this silently resolves to the KIT's name ("AUTO-LOGISTIC COMP/CON") instead of
	# falling back to blank, because the kit-level name key is non-empty - a plain non-empty
	# check would not catch that misattribution, so assert the exact expected string instead.
	assert_eq(text, 'Force Multiplier', "the action's OWN name must resolve, not the kit's fallback name")

func test_force_multiplier_action_effect_resolves_to_real_text():
	var kit := ContentLibrary.get_kit(CORE_POWER_ID)
	var text := Translate.action(kit, fm_action(), 'effect', false)
	assert_ne(text, '', 'the action effect text must resolve, not fall back to the blank kit-level key')
	assert_true(text.begins_with('Choose an adjacent allied character'), 'expect the real Force Multiplier effect text')

func test_force_multiplier_shows_in_kit_tooltip():
	# This is the assertion that would have caught the whole class of bug: show_in_tooltip returns
	# false whenever the action's own effect text is blank (falls back to the kit's, which is also
	# blank) - exactly the pre-fix state. It also guards against anyone "fixing" root cause 1 later
	# by setting localization_key_override on the action, which forces show_in_tooltip to false.
	var kit := ContentLibrary.get_kit(CORE_POWER_ID)
	assert_true(fm_action().show_in_tooltip(kit), 'force multiplier must appear in the kit tooltip')
	assert_true(fm_action().localization_key_override.is_empty(), 'the action itself must never carry an override - action.gd would then hide it from the tooltip')

func buff_core_with_id(unit:Unit, compcon_id:StringName) -> BuffCore:
	for buff_core:BuffCore in unit.state.buffs:
		if buff_core.base.compcon_id == compcon_id: return buff_core
	return null

## Player-visible buffs only: buff_fm_uplink_hidden/invisible are hide_from_player = true (never
## shown in any tooltip, so their text is moot), and buff_fm_firewall_tech_reset is internal POST
## plumbing with no localization_key_override at all (it was never part of either root cause).
## The four buffs below are exactly the ones a player can see: Uplink's accuracy half, Buffer, and
## both halves of Firewall (saves + the tech roller, which together show the same "Firewall" text).

func test_uplink_accuracy_buff_name_and_effect_resolve_to_real_text():
	var ally := ally_at(Vector2i(2,3))
	await use_force_multiplier(PICK_UPLINK)
	var accuracy_buff:Buff = null
	for buff:Buff in fm_action().buffs_for_option(FmUtil.OPTION_UPLINK):
		if buff.to == Buff.TO.ATTACK_ROLL: accuracy_buff = buff
	assert_not_null(accuracy_buff, 'precondition: uplink grants an accuracy buff')
	var buff_core := buff_core_with_id(ally, accuracy_buff.compcon_id)
	assert_not_null(buff_core, 'precondition: the accuracy buff is actually on the ally')
	assert_eq(Translate.buff(buff_core, 'name', false), 'Uplink', 'uplink buff name must resolve to real text')
	assert_ne(Translate.buff(buff_core, 'effect', false), '', 'uplink buff effect must resolve to real text')

func test_buffer_buff_name_and_effect_resolve_to_real_text():
	var ally := ally_at(Vector2i(2,3))
	await use_force_multiplier(PICK_BUFFER)
	var buffer_buff:Buff = fm_action().buffs_for_option(FmUtil.OPTION_BUFFER)[0]
	var buff_core := buff_core_with_id(ally, buffer_buff.compcon_id)
	assert_not_null(buff_core, 'precondition: the buffer buff is actually on the ally')
	assert_eq(Translate.buff(buff_core, 'name', false), 'Buffer', 'buffer buff name must resolve to real text')
	assert_ne(Translate.buff(buff_core, 'effect', false), '', 'buffer buff effect must resolve to real text')

func test_firewall_saves_buff_name_and_effect_resolve_to_real_text():
	var ally := ally_at(Vector2i(2,3))
	await use_force_multiplier(PICK_FIREWALL)
	var saves_buff:Buff = null
	for buff:Buff in fm_action().buffs_for_option(FmUtil.OPTION_FIREWALL):
		if buff.to == Buff.TO.SAVE: saves_buff = buff
	assert_not_null(saves_buff, 'precondition: firewall grants a saves buff')
	var buff_core := buff_core_with_id(ally, saves_buff.compcon_id)
	assert_not_null(buff_core, 'precondition: the saves buff is actually on the ally')
	assert_eq(Translate.buff(buff_core, 'name', false), 'Firewall', 'firewall saves buff name must resolve to real text')
	assert_ne(Translate.buff(buff_core, 'effect', false), '', 'firewall saves buff effect must resolve to real text')

func test_firewall_tech_buff_name_and_effect_resolve_to_real_text():
	var ally := ally_at(Vector2i(2,3))
	await use_force_multiplier(PICK_FIREWALL)
	var tech_buff := firewall_tech_buff()
	var buff_core := buff_core_with_id(ally, tech_buff.compcon_id)
	assert_not_null(buff_core, 'precondition: the tech buff is actually on the ally')
	assert_eq(Translate.buff(buff_core, 'name', false), 'Firewall', 'firewall tech buff name must resolve to real text')
	assert_ne(Translate.buff(buff_core, 'effect', false), '', 'firewall tech buff effect must resolve to real text')

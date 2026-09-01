# Altruism (GMS Denali) - Reag-CrisisCoreCatalogEvolved
#
# When the Denali performs a barrage or a Full Tech Action, each adjacent allied character may
# Stabilize, even if they could not normally take reactions. 1/Scene.
#
# Neither "barrage" nor "Full Tech Action" exists in Lancer Tactics. See the design doc for how
# both are read off the engine's own per-turn usage counters:
# D:\DEV\lancer-tactics-claude\specs\2026-08-31-altruism-design.md
extends GutTest

const ModChoiceResponder := preload('res://testkit/mod_choice_responder.gd')

const TRAIT_ID := &'mt_altruism'

const DENALI_TILE := Vector2i(2,2)
const ALLY_TILE := Vector2i(2,3)
const ENEMY_TILE := Vector2i(2,0)
const ENEMY_TILE_B := Vector2i(3,0)

# Two MAIN weapons, so a pair of attacks is reachable: Action.get_per_turn_soft_limit is 1, so the
# same weapon cannot fire twice without Overcharge. Both have to be MAIN (or smaller) so they fit
# either mount below - mount_heavy.legal_primary_sizes is [AUX, MAIN, HEAVY, SUPERHEAVY] and
# mount_flex.legal_primary_sizes is [AUX, MAIN] - see before_each for why mount 0 is a mount_heavy
# rather than the real Denali's mount_flex.
const WEAPON_A := &'mw_assault_rifle'   # MAIN, quick
const WEAPON_B := &'mw_shotgun' # MAIN, quick
const WEAPON_SUPERHEAVY := &'mw_cyclone_pulse_rifle' # SUPERHEAVY, full

var game:Gamemaster
var responder:ModChoiceResponder
var denali:Unit
var enemy:Unit

func before_each():
	# add_responder = false: we install our own, which can answer a *sequence* of prompts.
	game = SpecFactory.setup_gamemaster(self, false, null, {}, false)
	responder = add_child_autoqfree(ModChoiceResponder.new())

	denali = SpecFactory.create_unit(game.map, DENALI_TILE)
	denali.core.equip_system(TRAIT_ID)
	# The real Denali (mf_denali.tres) has mount_types = [mount_flex, mount_flex], and
	# mount_flex.legal_primary_sizes is [AUX, MAIN] only - no superheavy weapon can ever be legally
	# equipped there. That's a real limit of the frame, not something this test is about: the FULL-cost
	# weapon-attack branch of the trait fires for any FULL-cost weapon attack, not only a superheavy on
	# this frame, so we deliberately give the spec Denali a mount_heavy (legal_primary_sizes
	# [AUX, MAIN, HEAVY, SUPERHEAVY]) at index 0 to make that branch reachable through a legal mount,
	# and a mount_flex at index 1 for the second MAIN weapon.
	denali.core.frame.mount_types.append(ContentLibrary.get_mount(&'mount_heavy'))
	denali.core.frame.mount_types.append(ContentLibrary.get_mount(&'mount_flex'))
	denali.core.full_repair()

	enemy = spawn_enemy(ENEMY_TILE)

	# Altruism only fires on the Denali's own turn, so the turn has to actually be running.
	await SpecFactory.start_turn(game, denali)

func spawn_enemy(tile:Vector2i) -> Unit:
	var target := SpecFactory.create_unit(game.map, tile, Faction.SIDE.AI_ENEMY)
	target.core.frame.stat.evasion = 100 # always miss; we only care that the attack happened
	target.core.frame.stat.health = 100  # never structure, which would derail the event chain
	target.core.full_repair()
	UnitTile.move_to(target, tile)
	return target

func adjacent_ally(faction:Faction.SIDE = Faction.PLAYER) -> Unit:
	var ally := SpecFactory.create_unit(game.map, ALLY_TILE, faction)
	# SpecFactory frames are always mf_standard_pattern_i_everest, so every spec unit would
	# otherwise get the PLAYER basic loadout and its ms_stabilize. An AI ally in the real game
	# carries npcf_stabilize instead; LoadoutCore picks the list off Frame.is_player_mech(), which
	# is just `compcon_id.begins_with('mf_')`, and full_repair regenerates derived gear.
	if faction != Faction.PLAYER:
		ally.core.frame.compcon_id = &'npcc_spec_dummy'
		ally.core.full_repair()
	ally.core.current.heat = 4 # something for Stabilize to actually do
	return ally

func equip(mount_index:int, weapon_id:StringName) -> void:
	# mount 0 is the mount_heavy from before_each, which legally accepts WEAPON_SUPERHEAVY (as well
	# as the MAIN weapons), so this is just the normal equip path for every weapon in this suite -
	# no special-casing needed, and MountCore.is_legal holds for whatever ends up in mount 0.
	denali.core.loadout.mounts[mount_index].equip_primary(weapon_id)
	denali.core.full_repair()

func attack_with(weapon_id:StringName, flags:Array = []) -> void:
	await SpecFactory.use_solo(game, denali, weapon_id, enemy, flags)

func altruism_gear() -> GearCore:
	return denali.get_gear(TRAIT_ID)

func times_fired() -> int:
	# activate() calls spend_actions, which is what increments uses_this_scene. So this is 1 exactly
	# when Altruism ran to completion, and 0 when it never triggered or was declined.
	return altruism_gear().get_uses_this_scene()

func assert_fired(message:String) -> void:
	assert_eq(times_fired(), 1, message)

func assert_did_not_fire(message:String) -> void:
	assert_eq(times_fired(), 0, message)

# ==================== LOCALIZATION ====================

func test_effect_text_says_full_tech_action():
	var effect := tr('gear.mt_altruism.effect')
	assert_true(effect.contains('Full Tech Action'), 'The effect text uses the corrected keyword.')
	assert_false(
		effect.contains('|full action| |tech attack|'),
		'The mis-transcribed "full action tech attack" wording is gone.'
	)

func test_effect_text_links_full_tech_action_to_the_glossary():
	# There is no glossary term for "Full Tech Action" - GlossaryItem.find_key_from_label searches
	# assets/localization/word_lists/glossary_terms.json and would not resolve it - so the row has
	# to use the explicit |Label=key| form or the phrase renders coloured but unclickable.
	assert_true(
		tr('gear.mt_altruism.effect').contains('|Full Tech Action=lancer.actiontype.tech|'),
		'Full Tech Action is explicitly linked to the Tech glossary entry.'
	)

func test_trigger_text_states_the_trigger_not_the_usage_limit():
	# uses_per_scene renders its own lancer.geartag.per_scene tag (Kit.get_general_tags), so the
	# trigger line saying "1/Scene" was both wrong and a duplicate.
	var trigger_text := tr('gear.mt_altruism.trigger')
	assert_ne(trigger_text, '1/Scene', 'The trigger line is no longer the usage limit.')
	assert_true(trigger_text.contains('barrage'), 'The trigger line names the barrage condition.')

func test_prompt_rows_exist():
	for key:String in [
		'gear.mt_altruism.confirm',
		'gear.mt_altruism.confirm.desc',
	]:
		assert_ne(tr(key), key, 'Translation row %s exists.' % key)

# ==================== BARRAGE DETECTION ====================

func test_two_weapon_attacks_fire_it():
	adjacent_ally()
	equip(0, WEAPON_A)
	equip(1, WEAPON_B)

	await attack_with(WEAPON_A)
	assert_did_not_fire('One attack is not a barrage.')

	await attack_with(WEAPON_B)
	assert_fired('Two weapon attacks in a turn are a barrage.')

func test_one_weapon_attack_does_not_fire_it():
	adjacent_ally()
	equip(0, WEAPON_A)

	await attack_with(WEAPON_A)

	assert_did_not_fire('A single quick weapon attack is not a barrage.')

func test_a_full_cost_superheavy_attack_fires_it_alone():
	adjacent_ally()
	# A superheavy also needs a bracing mount (LoadoutCore.regenerate_derived_gear: "if we lost our
	# bracing mount, clear the superheavy") - without one full_repair() strips it right back out even
	# though mount_heavy's own legal_primary_sizes allows it. Mount 1 (mount_flex) can brace and is
	# otherwise unused in this test, so make it the brace.
	denali.core.loadout.mounts[1].is_bracing = true
	equip(0, WEAPON_SUPERHEAVY)
	assert_true(denali.core.loadout.mounts[0].is_legal(), 'The superheavy is actually legally equipped, not just present.')

	await attack_with(WEAPON_SUPERHEAVY)

	assert_fired('A superheavy attack costs a FULL action and is a barrage on its own.')

func test_freebie_attacks_do_not_count_toward_the_pair():
	# AS_FREEBIE activations do not increment uses_this_turn (UnitAction, "RECORD THE USAGE"),
	# which is what keeps off-turn overwatch out of the count.
	adjacent_ally()
	equip(0, WEAPON_A)
	equip(1, WEAPON_B)

	await attack_with(WEAPON_A, [Action.FLAG.AS_FREEBIE])
	await attack_with(WEAPON_B)

	assert_did_not_fire('A freebie attack plus a real one is not a barrage.')

func test_the_pair_does_not_carry_across_turns():
	adjacent_ally()
	equip(0, WEAPON_A)
	equip(1, WEAPON_B)

	await attack_with(WEAPON_A)
	await SpecFactory.end_turn(game, denali)
	await SpecFactory.start_turn(game, denali)
	await attack_with(WEAPON_B)

	assert_did_not_fire('uses_this_turn is cleared at every turn boundary, so the pair resets.')

# ==================== FULL TECH ACTION ====================

func test_a_full_cost_tech_action_fires_it_alone():
	adjacent_ally()
	denali.core.equip_system(&'ms_systems_override') # this mod's own FULL-cost tech attack
	denali.core.full_repair()

	await SpecFactory.use_solo(game, denali, &'ms_systems_override', enemy)

	assert_fired('ms_systems_override is action_type = FULL, so it is a Full Tech Action alone.')

func test_two_quick_tech_actions_fire_it():
	# Scan and Lock On are ActionSystems with is_tech = true - not tech attacks. Both count.
	adjacent_ally()

	await SpecFactory.use_solo(game, denali, &'ms_scan', enemy)
	assert_did_not_fire('One quick tech action is not a Full Tech Action.')

	await SpecFactory.use_solo(game, denali, &'ms_lock_on', enemy)
	assert_fired('Scan then Lock On is two tech actions in a turn.')

func test_scanning_two_targets_fires_it():
	# Two separate targets, because ActionScan.is_available_to_activate refuses to fire when there
	# is nothing left to learn - and Scanpedia.is_anything_unscanned keys off frame compcon_id, not
	# per-unit identity, so two default spec dummies (both Frame.EVEREST_ID) would look identical
	# and the second scan would find nothing new. Give the second target its own frame id so it
	# reads as a genuinely different, still-unscanned target.
	adjacent_ally()
	var second_enemy := spawn_enemy(ENEMY_TILE_B)
	second_enemy.core.frame.compcon_id = &'mf_test_scan_target_b'

	await SpecFactory.use_solo(game, denali, &'ms_scan', enemy)
	await SpecFactory.use_solo(game, denali, &'ms_scan', second_enemy)

	assert_fired('Scanning twice in a turn is a Full Tech Action.')

func test_a_weapon_attack_and_a_tech_action_do_not_mix():
	adjacent_ally()
	equip(0, WEAPON_A)

	await attack_with(WEAPON_A)
	await SpecFactory.use_solo(game, denali, &'ms_scan', enemy)

	assert_did_not_fire('The two counts are separate; neither half reaches two.')

# ==================== ELIGIBILITY AND THE SCENE LIMIT ====================

func test_it_does_not_fire_with_no_adjacent_ally():
	equip(0, WEAPON_A)
	equip(1, WEAPON_B)

	await attack_with(WEAPON_A)
	await attack_with(WEAPON_B)

	assert_did_not_fire('With nobody adjacent there is nothing to offer.')
	assert_eq(responder.yesno_prompts.size(), 0, 'And no prompt is shown at all.')

func test_an_adjacent_enemy_does_not_make_it_eligible():
	spawn_enemy(ALLY_TILE)
	equip(0, WEAPON_A)
	equip(1, WEAPON_B)

	await attack_with(WEAPON_A)
	await attack_with(WEAPON_B)

	assert_did_not_fire('An adjacent hostile is not an adjacent ally.')

func test_declining_the_confirmation_does_not_burn_the_scene_use():
	adjacent_ally()
	equip(0, WEAPON_A)
	equip(1, WEAPON_B)
	responder.yesno_queue = [false]

	await attack_with(WEAPON_A)
	await attack_with(WEAPON_B)

	assert_eq(responder.yesno_prompts.size(), 1, 'The Denali was asked.')
	assert_did_not_fire('Declining costs nothing, because spend_actions is never reached.')

func test_it_only_fires_once_per_scene():
	adjacent_ally()
	equip(0, WEAPON_A)
	equip(1, WEAPON_B)

	await attack_with(WEAPON_A)
	await attack_with(WEAPON_B)
	assert_fired('First barrage fires it.')

	await SpecFactory.end_turn(game, denali)
	await SpecFactory.start_turn(game, denali)
	await attack_with(WEAPON_A)
	await attack_with(WEAPON_B)

	assert_eq(times_fired(), 1, 'A second barrage in the same scene does not fire it again.')

func test_one_scene_use_covers_both_halves():
	# A barrage and a Full Tech Action in one scene yield one trigger between them, not one each.
	adjacent_ally()
	equip(0, WEAPON_A)
	equip(1, WEAPON_B)

	await attack_with(WEAPON_A)
	await attack_with(WEAPON_B)
	assert_fired('The barrage fired it.')

	await SpecFactory.end_turn(game, denali)
	await SpecFactory.start_turn(game, denali)
	await SpecFactory.use_solo(game, denali, &'ms_scan', enemy)
	await SpecFactory.use_solo(game, denali, &'ms_lock_on', enemy)

	assert_eq(times_fired(), 1, 'The tech half does not get its own separate use.')

# ==================== THE ALLY STABILIZES ====================

## Sets up an ordinary two-weapon barrage and runs it. yesno_queue answers the Denali's
## confirmation first, then one prompt per player-controlled ally - that ally's OWN Stabilize
## confirm. Altruism deliberately does not add an offer prompt in front of it; see
## test_a_declining_ally_is_left_alone for why that second popup would be redundant.
func barrage(answers:Array[bool]) -> void:
	equip(0, WEAPON_A)
	equip(1, WEAPON_B)
	responder.yesno_queue = answers
	await attack_with(WEAPON_A)
	await attack_with(WEAPON_B)

func test_an_accepting_ally_is_cooled():
	var ally := adjacent_ally()

	# Denali confirm, then the ally's own Stabilize confirm ("Use Stabilize?").
	await barrage([true, true])

	assert_eq(ally.core.current.heat, 0, 'The ally Stabilized and cleared its heat.')

## This is the test that earns the absence of a separate Altruism offer prompt. Cancelling the
## ally's OWN Stabilize popup has to cost them nothing at all - not the heat, and crucially not the
## reaction - because that popup IS the offer. CommonActionUtil.choose_and_use only calls its
## spend_actions_callable from the deferred_spend that runs when the chosen action commits, so a
## cancel never reaches choose_and_use_spend_reaction. If this test ever fails, the free decline is
## gone and Altruism owes the ally a real offer prompt of its own before it costs them anything.
func test_a_declining_ally_is_left_alone():
	var ally := adjacent_ally()
	var reactions_before := ally.core.current.reactions
	assert_gt(reactions_before, 0, 'Precondition: the ally has a reaction that could be wasted.')

	await barrage([true, false])

	assert_eq(ally.core.current.heat, 4, 'The ally declined and kept its heat.')
	assert_eq(
		ally.core.current.reactions, reactions_before,
		'Cancelling the Stabilize popup is a free decline - no reaction is spent.'
	)
	assert_fired('The scene use is still spent - the Denali offered.')

func test_the_ally_spends_their_reaction():
	var ally := adjacent_ally()
	var reactions_before := ally.core.current.reactions
	assert_gt(reactions_before, 0, 'Precondition: the ally has a reaction to spend.')

	# Denali confirm, then the ally's own Stabilize confirm.
	await barrage([true, true])

	assert_eq(ally.core.current.reactions, reactions_before - 1, 'Stabilizing spent their reaction.')

func test_an_ally_with_no_reaction_left_still_stabilizes():
	# "even if they would not normally be able to take reactions" - nothing filters on
	# UnitAction.can_take_reactions, and spend_reaction floors at zero rather than failing.
	var ally := adjacent_ally()
	ally.core.current.reactions = 0

	# Denali confirm, then the ally's own Stabilize confirm.
	await barrage([true, true])

	assert_eq(ally.core.current.heat, 0, 'The ally Stabilized with no reaction available.')
	assert_eq(ally.core.current.reactions, 0, 'And their reaction count stayed floored at zero.')

func test_every_adjacent_player_ally_is_offered():
	adjacent_ally()
	var second_ally := SpecFactory.create_unit(game.map, Vector2i(1,2), Faction.PLAYER)
	second_ally.core.current.heat = 3

	# Denali confirm, then each ally's own Stabilize confirm, run to completion for ally 1 before
	# ally 2 is even asked (activate() awaits offer_stabilize in the loop) - so the order is
	# [denali, ally1_stabilize_confirm, ally2_stabilize_confirm].
	await barrage([true, true, true])

	assert_eq(
		responder.yesno_prompts.size(), 3,
		'The Denali, and both allies own Stabilize confirms - one popup per ally, not two.'
	)
	assert_eq(second_ally.core.current.heat, 0, 'The second ally Stabilized too.')

func test_a_distant_ally_is_not_offered():
	var far_ally := SpecFactory.create_unit(game.map, Vector2i(4,4), Faction.PLAYER)
	far_ally.core.current.heat = 3
	adjacent_ally()

	# Denali confirm, then the adjacent ally's own Stabilize confirm.
	await barrage([true, true])

	assert_eq(far_ally.core.current.heat, 3, 'A non-adjacent ally is untouched.')
	assert_eq(responder.yesno_prompts.size(), 2, 'And is never prompted.')

func test_an_ai_ally_auto_accepts():
	var ai_ally := adjacent_ally(Faction.SIDE.AI_ALLY)

	await barrage([true])

	assert_eq(ai_ally.core.current.heat, 0, 'The AI ally Stabilized without being asked.')
	assert_eq(responder.yesno_prompts.size(), 1, 'Only the Denali was prompted.')

func test_an_ai_ally_with_nothing_to_gain_is_skipped():
	var ai_ally := adjacent_ally(Faction.SIDE.AI_ALLY)
	ai_ally.core.current.heat = 0
	var reactions_before := ai_ally.core.current.reactions

	await barrage([true])

	assert_eq(
		ai_ally.core.current.reactions, reactions_before,
		'A healthy AI ally is skipped, so its reaction is not spent on nothing.'
	)

## Regression test for the finding this file was changed for: offer_stabilize used to pass
## Action.FLAG.SKIP_PLAYER_DECISIONS, which event_gear_activate.gd (lines 82-86) also reads to mean
## "skip the variant picker and auto-compose the DEFAULT variant" - so a player-controlled ally who
## accepted was silently auto-defaulted to Cool, never able to choose Repair. Every OTHER test in
## this suite gives the ally only heat, so Cool and "auto-defaulted to Cool" are indistinguishable -
## this is the one test that can tell them apart. Give the ally BOTH heat and structure damage, then
## drive the choice to Repair via the response harness and assert Repair - not Cool - actually
## happened.
##
## Group key and index derived from content/gear/basic/ms_stabilize/action_stabilize.gd
## get_alternate_actions: the primary group's key is &'stabilize_primary' (line 37), it is created
## non-blankable (5th arg `false`, line 41-42), and with heat > 0 `cool_disabled` is false (line 45)
## so no &'skip_primary' entry is inserted at index 0 (line 67-68) - the list is built as
## [cool, repair] (lines 46-65), making Repair index 1.
func test_choosing_repair_is_not_silently_auto_defaulted_to_cool():
	var ally := adjacent_ally() # gives the ally heat, so Cool is available and would be the default
	ally.core.current.health -= 2 # give the ally structure damage too, so Repair has something to do
	assert_gt(ally.current_damage(), 0, 'Precondition: the ally has structure damage to repair.')
	assert_gt(UnitAction.get_available_repairs(ally), 0, 'Precondition: the ally can afford a repair.')

	responder.chosen_variants = {&'stabilize_primary': 1} # 1 = repair; see doc comment above

	# Denali confirm, then the ally's own Stabilize confirm.
	await barrage([true, true])

	assert_eq(
		ally.core.current.health, ally.core.get_health_max(),
		'Repair was actually chosen and actually ran - the ally healed back to full.'
	)
	assert_eq(
		ally.core.current.heat, 4,
		'Cool did NOT run instead - if this were 0, the ally was auto-defaulted, not offered a real choice.'
	)

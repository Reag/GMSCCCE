# Field Supply (GMS Denali) - Reag-CrisisCoreCatalogEvolved
#
# When the Denali Stabilizes, each adjacent allied character may take ONE of Stabilize's three
# secondary effects. They are NOT stabilizing.
#
# Design: D:\DEV\lancer-tactics-claude\specs\2026-08-31-field-supply-design.md
extends GutTest

const ModChoiceResponder := preload('res://testkit/mod_choice_responder.gd')

const TRAIT_ID := &'mt_field_supply'

# Menu order from action_field_supply.gd DISPLAY_ORDER, plus the trailing Skip entry.
const PICK_BURN := 0
const PICK_CONDITION := 1
const PICK_RELOAD := 2
const PICK_SKIP := 3

# Vanilla Stabilize's own secondary variant group, from action_stabilize.get_alternate_actions.
const SECONDARY_RELOAD := 0
const SECONDARY_BURN := 1
const SECONDARY_CONDITION_SELF := 2
const SECONDARY_CONDITION_ALLY := 3

var game:Gamemaster
var responder:ModChoiceResponder
var denali:Unit

func before_each():
	# add_responder = false: we install our own, which can answer a *sequence* of prompts.
	game = SpecFactory.setup_gamemaster(self, false, null, {}, false)
	responder = add_child_autoqfree(ModChoiceResponder.new())

	denali = SpecFactory.create_unit(game.map, Vector2i(2,2))
	denali.core.equip_system(TRAIT_ID)
	# Stabilize aborts if it would do nothing, and an aborted activation never emits the
	# unit_action trigger - so the Denali needs a real reason to stabilize.
	denali.core.current.heat = 4

func adjacent_unit(faction:Faction.SIDE = Faction.PLAYER) -> Unit:
	return SpecFactory.create_unit(game.map, Vector2i(2,3), faction)

func stabilize() -> void:
	await SpecFactory.use_solo(game, denali, &'ms_stabilize')

# ==================== THE TRAIT FIRES AT ALL ====================

func test_denali_still_stabilizes_normally():
	await stabilize()
	assert_eq(denali.core.current.heat, 0, 'The Denali cooled its own heat as usual.')

func test_adjacent_ally_burn_is_cleared():
	var ally := adjacent_unit()
	ally.set_current_burn(3)
	responder.multiple_choice_queue = [PICK_BURN]

	await stabilize()

	assert_eq(ally.state.burn, 0, 'Adjacent ally had all burn cleared.')
	assert_eq(denali.core.current.heat, 0, 'The Denali still cooled its own heat.')

func test_ally_can_decline():
	var ally := adjacent_unit()
	ally.set_current_burn(3)
	responder.multiple_choice_queue = [PICK_SKIP]

	await stabilize()

	assert_eq(ally.state.burn, 3, 'Skipping left the burn alone.')

# ==================== ELIGIBILITY ====================

func test_no_prompt_when_nobody_is_adjacent():
	await stabilize()
	assert_eq(responder.multiple_choice_prompts.size(), 0, 'No ally menu with nobody adjacent.')

func test_enemies_are_not_eligible():
	var enemy := adjacent_unit(Faction.AI_ENEMY)
	enemy.set_current_burn(3)

	await stabilize()

	assert_eq(enemy.state.burn, 3, 'An adjacent enemy gets nothing.')
	assert_eq(responder.multiple_choice_prompts.size(), 0, 'No menu was shown for an enemy.')

func test_distant_allies_are_not_eligible():
	var far_ally := SpecFactory.create_unit(game.map, Vector2i(0,0))
	far_ally.set_current_burn(3)

	await stabilize()

	assert_eq(far_ally.state.burn, 3, 'A non-adjacent ally gets nothing.')

# ==================== THE MENU IS SHOWN EVEN WHEN USELESS ====================
# Design decision: a trait that silently does nothing is indistinguishable from a broken one.

func test_menu_is_shown_to_an_ally_who_cannot_benefit():
	var ally := adjacent_unit() # no burn, no conditions, nothing unloaded
	responder.multiple_choice_queue = [PICK_SKIP]

	await stabilize()

	assert_eq(responder.multiple_choice_prompts.size(), 1, 'The ally still got a menu.')
	if responder.multiple_choice_prompts.is_empty(): return
	var prompt:Dictionary = responder.multiple_choice_prompts[0]
	gut.p('prompt: %s' % [prompt])
	assert_ne(prompt.disabled_reasons[PICK_BURN], '', 'Burn was greyed out with a reason.')
	assert_ne(prompt.disabled_reasons[PICK_CONDITION], '', 'Condition was greyed out with a reason.')
	assert_ne(prompt.disabled_reasons[PICK_RELOAD], '', 'Reload was greyed out with a reason.')
	assert_eq(prompt.disabled_reasons[PICK_SKIP], '', 'Skip stayed selectable.')
	assert_string_contains(prompt.subtitle, ally.core.get_pilot_or_mech_name(), 'The menu names the ally.')

# ==================== TWO PROMPTS IN A ROW ====================

func test_clearing_a_condition_takes_a_second_prompt():
	var ally := adjacent_unit()
	SpecFactory.apply(ally, Lancer.STATUS.IMPAIRED)
	assert_true(ally.has_status(Lancer.STATUS.IMPAIRED), 'Precondition: the ally is impaired.')

	# An impaired adjacent ally also enables vanilla Stabilize's OWN 'condition_ally' variant, and
	# VariantActionGroup.get_chosen_variant_for_group falls through to the first *enabled* variant -
	# so the Denali would clear the ally's condition itself, before Field Supply ever runs. Give the
	# Denali its own burn and pick that, to keep the two effects from overlapping.
	denali.set_current_burn(2)
	responder.chosen_variants[&'stabilize_secondary'] = SECONDARY_BURN

	# First prompt: which effect. Second prompt: which condition (only one, so index 0).
	responder.multiple_choice_queue = [PICK_CONDITION, 0]

	await stabilize()

	assert_eq(denali.state.burn, 0, 'The Denali cleared its own burn, not the ally condition.')

	gut.p('prompts seen: %s' % [responder.multiple_choice_prompts.size()])
	assert_eq(responder.multiple_choice_prompts.size(), 2, 'Two prompts: the effect, then the condition.')
	assert_false(ally.has_status(Lancer.STATUS.IMPAIRED), 'The impaired condition was cleared.')

# ==================== NPC ALLIES ====================

func test_npc_ally_is_auto_resolved_without_a_prompt():
	var npc_ally := adjacent_unit(Faction.AI_ALLY)
	npc_ally.set_current_burn(3)

	await stabilize()

	assert_eq(responder.multiple_choice_prompts.size(), 0, 'No menu was shown to an NPC ally.')
	assert_eq(npc_ally.state.burn, 0, 'The NPC ally auto-picked burn.')

# ==================== THE DEFINING CONSTRAINT ====================
# Allies benefiting are NOT stabilizing: nothing may key off them having stabilized.

func test_ally_does_not_count_as_having_stabilized():
	var ally := adjacent_unit()
	ally.set_current_burn(3)
	# cb_adaptive_reactor reacts to its OWNER stabilizing by repairing stress for two repairs.
	ally.core.equip_system(&'cb_adaptive_reactor')
	ally.core.current.repairs = 3
	ally.core.current.stress = 3
	responder.multiple_choice_queue = [PICK_BURN]

	await stabilize()

	assert_eq(ally.state.burn, 0, 'Precondition: the ally did benefit from Field Supply.')
	assert_eq(ally.core.current.repairs, 3, 'The ally spent no repairs - it did not stabilize.')
	assert_eq(ally.core.current.stress, 3, 'The ally repaired no stress - it did not stabilize.')

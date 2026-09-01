# Content integrity for GMS Crisis Core Catalog Evolved.
#
# Cheap, broad checks that every resource this mod adds is wired into the game correctly. These
# catch the failure modes that are silent at load and invisible while playing - a resource filed
# under the wrong ContentLibrary index, a frame with no statblock, a missing localization row.
extends GutTest

const ModContentAudit := preload('res://testkit/mod_content_audit.gd')
const ModResources := preload('res://testkit/mod_resources.gd')

const MOD_ID := 'Reag-CrisisCoreCatalogEvolved'

func test_the_mod_is_actually_loaded():
	# Everything below is vacuously true if the mod did not load, so check it first.
	assert_true(ModLoaderMod.is_mod_active(MOD_ID), '%s is loaded and active.' % MOD_ID)

func test_no_resource_is_filed_under_the_wrong_index():
	# ContentLibrary sorts by filename prefix, not script class. See mod_content_audit.gd.
	var problems := ModContentAudit.find_misfiled_resources(MOD_ID)
	for problem:String in problems: gut.p('  %s' % problem)
	assert_eq(problems.size(), 0, 'Every resource landed in the right ContentLibrary index.')

func test_denali_frame_is_registered_with_a_statblock():
	var frame:Frame = ContentLibrary.get_mech_frame(&'mf_denali')
	assert_true(is_instance_valid(frame), 'mf_denali is in the frames index.')
	if not is_instance_valid(frame): return
	# statblock_denali.tres was once named mf_denali_statblock.tres, which matched the frames
	# glob "**/mf_*.tres" and was indexed as a Frame. Regression guard for that rename.
	assert_true(is_instance_valid(frame.stat), 'The Denali has a statblock.')
	if is_instance_valid(frame.stat): assert_gt(frame.stat.health, 0, 'The statblock has real numbers.')

func test_denali_gear_is_registered():
	for kit_id:StringName in [&'mt_field_supply', &'mt_altruism', &'cp_auto_logistic_compcon']:
		assert_true(Kit.is_valid(ContentLibrary.get_kit(kit_id)), '%s is in the kits index.' % kit_id)

func test_auto_logistic_compcon_offers_both_of_its_actions():
	# Force Multiplier and Optimizer are ACTIONS on this core power, not kits of their own. Their
	# .tres files were once named cp_*, which matched the kits glob and pushed two ActionSystems
	# into the kits index. Regression guard for the rename to action_*.tres.
	var kit:Kit = ContentLibrary.get_kit(&'cp_auto_logistic_compcon')
	assert_true(Kit.is_valid(kit), 'The core power is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_eq(kit.actions.size(), 2, 'Both actions are wired onto the core power.')
	for action:Action in kit.actions:
		assert_true(is_instance_valid(action), 'Each action resource resolved.')

func test_weapon_tags_match_their_numbers():
	# A weapon tagged Accurate or Inaccurate must actually carry the accuracy it advertises,
	# otherwise the tooltip promises a modifier the attack never applies. mw_fraglauncher and
	# mw_grenadelauncher were both tagged inaccurate with no penalty at all.
	# ModResources.load_ours, NOT ContentLibrary.get_all(&'kits'): get_all calls load_all(), which
	# loads every installed mod's kits before this loop can filter anything. One of them
	# (fateofman-ssc_atlas) ships a script that will not parse against this modkit version, and GUT
	# counts the resulting engine error as a failure of whatever test happens to be running - so this
	# spec used to fail for a bug in a mod nobody here wrote. Scoping the LOAD, rather than the
	# result, is the fix; the old filter below ran too late to help.
	for kit:Kit in ModResources.load_ours(MOD_ID, &'kits'):
		for action:Action in kit.actions:
			if not action is ActionAttackWeapon: continue
			if action.tags.has(Lancer.WEAPON_TAG.ACCURATE):
				assert_gt(Util.get_tiered_int(action.attack_accuracy, 1), 0, '(%s) Accurate weapon has an accuracy bonus.' % kit.compcon_id)
			if action.tags.has(Lancer.WEAPON_TAG.INACCURATE):
				assert_lt(Util.get_tiered_int(action.attack_accuracy, 1), 0, '(%s) Inaccurate weapon has an accuracy penalty.' % kit.compcon_id)

func test_gear_names_are_localized():
	# A missing CSV row renders the raw translation key in game.
	for kit_id:StringName in [&'mt_field_supply', &'mt_altruism', &'cp_auto_logistic_compcon']:
		var key := 'gear.%s.name' % kit_id
		assert_ne(tr(key), key, '%s resolves to real text.' % key)

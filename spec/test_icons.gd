# Icon wiring for GMS Crisis Core Catalog Evolved.
#
# Design: lancer-tactics-claude/specs/2026-10-04-ccc-icons-design.md, section 4. Each icon is read
# through the call the game itself makes, so a row that INHERITS a glyph is tested the way it is
# drawn: Action.get_icon(kit) for the gear bar (specific_action.gd:107), Kit.icon_and_flavor() for
# the loadout card (kit.gd:181), and a buff's raw `icon` for the status chip - BuffCore.get_icon
# (buff_core.gd:81) reads base.icon first and never calls Buff.get_icon(), so BuffBonus's
# accuracy-svg fallback is not what the chip shows.
extends GutTest

const ICONS := 'res://unpacked/Reag-CrisisCoreCatalogEvolved/res/assets/icons/'
const DENALI := 'res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/'
const FM := DENALI + 'cp_auto_logistic_compcon/cp_force_multiplier/'
const OPTIMIZER := DENALI + 'cp_auto_logistic_compcon/cp_optimizer/'

## [kit id, action .tres basename, the icon file it must show]
const CHARGE_ACTIONS := [
	[&'ms_pattern_b_concussion_charges', 'action_concussion_grenade', 'action_concussion_grenade.svg'],
	[&'ms_pattern_b_concussion_charges', 'action_concussion_mine', 'action_concussion_mine.svg'],
	[&'ms_pattern_b_shock_charges', 'action_shock_grenade', 'action_shock_grenade.svg'],
	[&'ms_pattern_b_shock_charges', 'action_shock_mine', 'action_shock_mine.svg'],
]

## [buff .tres basename, the icon file its status chip must show]
const CHIPS := [
	['buff_fm_uplink_accuracy', 'buff_fm_uplink.svg'],
	['buff_fm_buffer', 'buff_fm_buffer.svg'],
	['buff_fm_firewall_saves', 'buff_fm_firewall.svg'],
	['buff_fm_firewall_tech', 'buff_fm_firewall.svg'],
]

func get_kit(id:StringName) -> Kit:
	var kit:Kit = ContentLibrary.get_kit(id)
	assert_true(Kit.is_valid(kit), '%s is in the kits index.' % id)
	return kit

## The action on `kit` loaded from `<basename>.tres`, or null (and a failure) if it has none.
func action_on(kit:Kit, basename:String) -> Action:
	for action:Action in kit.actions:
		if action.resource_path.get_file().get_basename() == basename: return action
	fail_test('%s carries no action %s.' % [kit.resource_path.get_file(), basename])
	return null

func path_of(texture:Texture2D) -> String:
	return texture.resource_path if texture != null else '<null>'

## What the gear bar draws for `basename` on `kit`.
func gear_bar_icon(kit:Kit, basename:String) -> String:
	var action := action_on(kit, basename)
	return path_of(action.get_icon(kit)) if action != null else '<missing>'

func test_each_charge_action_wears_its_own_glyph():
	var seen := {}
	for row:Array in CHARGE_ACTIONS:
		var kit := get_kit(row[0])
		if not Kit.is_valid(kit): continue
		var path := gear_bar_icon(kit, row[1])
		assert_eq(path, ICONS + row[2], '%s shows %s on the gear bar.' % [row[1], row[2]])
		seen[path] = true
	assert_eq(seen.size(), 4, 'Concussion and Shock grenades and mines are four different pictures.')

func test_each_charge_kit_shows_its_grenade():
	# No icon_override on the Kit, exactly like vanilla's Hex Charges: icon_and_flavor falls through
	# to the first action, which is the grenade.
	for row:Array in [[&'ms_pattern_b_concussion_charges', 'action_concussion_grenade.svg'],
			[&'ms_pattern_b_shock_charges', 'action_shock_grenade.svg']]:
		var kit := get_kit(row[0])
		if not Kit.is_valid(kit): continue
		assert_null(kit.icon_override, '%s has no icon_override of its own.' % row[0])
		assert_eq(path_of(kit.icon_and_flavor().icon), ICONS + row[1], '%s shows its grenade.' % row[0])

func test_each_single_action_system_shares_its_kits_glyph():
	for row:Array in [[&'ms_mm_suite', 'action_mm_suite', 'ms_mm_suite.svg'],
			[&'ms_systems_override', 'action_systems_override', 'ms_systems_override.svg']]:
		var kit := get_kit(row[0])
		if not Kit.is_valid(kit): continue
		assert_eq(path_of(kit.icon_and_flavor().icon), ICONS + row[2], '%s shows %s.' % [row[0], row[2]])
		var action := action_on(kit, row[1])
		if action == null: continue
		assert_null(action.icon_override, '%s carries no override; it inherits the Kit glyph.' % row[1])
		assert_eq(path_of(action.get_icon(kit)), ICONS + row[2], '%s shows the Kit glyph on the gear bar.' % row[1])

func test_each_force_multiplier_chip_wears_its_glyph():
	for row:Array in CHIPS:
		var buff:Buff = load(FM + row[0] + '.tres')
		assert_false(buff.hide_from_player, '%s is a visible chip.' % row[0])
		assert_eq(path_of(buff.icon), ICONS + row[1], '%s wears %s.' % [row[0], row[1]])

func test_the_two_firewall_chips_share_one_texture():
	var saves:Buff = load(FM + 'buff_fm_firewall_saves.tres')
	var tech:Buff = load(FM + 'buff_fm_firewall_tech.tres')
	assert_not_null(saves.icon, 'The Firewall saves chip has an icon.')
	assert_true(saves.icon == tech.icon, 'Both Firewall chips are one texture resource.')

func test_the_five_kept_glyphs_are_unchanged():
	# The author ruled these need no work (design section 2). Pinned so no later pass sweeps them up.
	var altruism := get_kit(&'mt_altruism')
	if Kit.is_valid(altruism):
		assert_eq(path_of(altruism.icon_and_flavor().icon), ICONS + 'mt_altruism_icon.png', 'Altruism keeps its PNG.')
	var field_supply := get_kit(&'mt_field_supply')
	if Kit.is_valid(field_supply):
		assert_eq(path_of(field_supply.icon_and_flavor().icon), 'res://assets/icons/actions/systems/ms_stabilize.svg',
			'Field Supply keeps vanilla Stabilize.')
	var compcon := get_kit(&'cp_auto_logistic_compcon')
	if Kit.is_valid(compcon):
		assert_eq(path_of(compcon.icon_and_flavor().icon), 'res://assets/talents/bonded.svg', 'The core Kit keeps bonded.')
		assert_eq(gear_bar_icon(compcon, 'action_force_multiplier'), ICONS + 'force_mult.svg', 'Force Multiplier is kept.')
		assert_eq(gear_bar_icon(compcon, 'action_optimizer'), ICONS + 'optimizer.svg', 'Optimizer is kept.')
	var optimized:Buff = load(OPTIMIZER + 'buff_optimizer_immunity.tres')
	assert_eq(path_of(optimized.icon), ICONS + 'optimizer.svg', 'The Optimized chip keeps the Optimizer glyph.')

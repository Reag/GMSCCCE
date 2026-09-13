# The GMS license must grant everything this mod adds to GMS. There was no spec for this until the
# 1.4.0 unstable modkit silently stopped applying every .tres_ext.gd (extend_resource strips the
# wrong suffix), which would have shipped a Crisis Core Catalog with no Denali and no weapons.
#
# It earns its keep a second time on 1.4.x, where two mods extending one resource knock each other
# out: ModApplier folds every mod's queued extensions into one Dictionary keyed by target path and
# merges rather than concatenates, so only the first-installed mod's callable survives. mod_main.gd
# steps out of that queue and applies this license itself; test_other_gms_mods_also_land below is
# what proves the other mod still gets its turn.
extends GutTest

const Compat := preload('res://testkit/modkit_compat.gd')

const LICENSE_ID := &'li_gms'
const GRANTED_FRAME := &'mf_denali'
const GRANTED_KITS:Array[StringName] = [
	# weapons
	&'mw_autocannon', &'mw_antishipmissile', &'mw_nexusapexhunter', &'mw_heavyslugshotgun',
	&'mw_recoilessrifle', &'mw_antitankmissile', &'mw_heliosnexus', &'mw_fraglauncher',
	&'mw_grenadelauncher', &'mw_combatmaul', &'mw_delugemissiles',
	# systems
	&'ms_pattern_b_concussion_charges', &'ms_pattern_b_shock_charges', &'ms_mm_suite', &'ms_systems_override',
]

## Other published mods that extend this same license, and the frames each of them grants. Only
## checked when the mod is actually installed, so the suite is identical with or without them.
const OTHER_GMS_MODS := {
	'gavstarb-gms_1st_party': [&'mf_chomolungma', &'mf_sagarmatha'],
	'fateofman-imi_alt_frames': [&'mf_sierra'],
}

func _rank_1_ids(property:String) -> Array[StringName]:
	var license:UnlockTree = ContentLibrary.get_license_tree(LICENSE_ID)
	assert_not_null(license, 'sanity: the GMS license exists.')
	var ids:Array[StringName] = []
	if license == null or license.rank_1 == null: return ids
	for granted in license.rank_1.get(property): ids.append(granted.compcon_id)
	return ids

func test_rank_1_grants_every_ccc_kit():
	var ids := _rank_1_ids('granted_gear')
	for kit_id:StringName in GRANTED_KITS:
		assert_has(ids, kit_id, '%s is granted by GMS rank 1.' % kit_id)

func test_rank_1_grants_the_denali():
	assert_has(_rank_1_ids('granted_frames'), GRANTED_FRAME, '%s is granted by GMS rank 1.' % GRANTED_FRAME)

## Co-existence, in the only direction a spec of ours can observe it: another mod's GMS frames have
## to be in the license too. Standing down from the shared queue is what allows that (mod_main.gd);
## putting our callable back in it would take whichever of these mods is installed straight out of
## the game, and this is the only test that would notice.
func test_other_gms_mods_also_land():
	var granted := _rank_1_ids('granted_frames')
	var checked := 0
	for mod_id:String in OTHER_GMS_MODS:
		if not Compat.is_mod_active(mod_id): continue
		checked += 1
		for frame_id:StringName in OTHER_GMS_MODS[mod_id]:
			assert_has(granted, frame_id, '%s is still granted by GMS rank 1 alongside ours.' % frame_id)
	if checked == 0:
		gut.p('No other li_gms extender installed; nothing to co-exist with.')
		pass_test('No other li_gms extender installed.')

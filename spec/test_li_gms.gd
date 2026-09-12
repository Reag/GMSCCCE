# The GMS license must grant everything this mod adds to GMS. There was no spec for this until the
# 1.4.0 unstable modkit silently stopped applying every .tres_ext.gd (extend_resource strips the
# wrong suffix), which would have shipped a Crisis Core Catalog with no Denali and no weapons.
extends GutTest

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

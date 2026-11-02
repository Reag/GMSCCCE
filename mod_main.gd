extends Node
const MOD_ID := "Reag-CrisisCoreCatalogEvolved" ## Name of the directory that this file is in

const LICENSE_PATH := 'res://content/licenses/gms/li_gms.tres'
const LICENSE_EXTENSION := 'res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/licenses/gms/li_gms.tres_ext.gd'
const MOD_LIBRARY_140 := 'res://engine/mod/mod_library.gd' 
const APPLIED_META := &'reag_ccce_li_gms_applied' 
var _retained_license:Resource 


func _init() -> void:
	ModLoaderLog.info("Activating.", MOD_ID)

	# Adds the translations from your localization/localizations.csv
	LancerTacticsMod.add_translations(MOD_ID)
	LancerTacticsMod.add_overwrite_extend_mod_resources(MOD_ID)
	apply_license_extension_directly()


func apply_license_extension_directly() -> void:
	if not ResourceLoader.exists(MOD_LIBRARY_140): return
	var library = load(MOD_LIBRARY_140)
	if not library.is_mod_being_installed(MOD_ID): return ## Fixes the multiple frame in modules bug

	_retained_license = load(LICENSE_PATH)
	if _retained_license == null:
		ModLoaderLog.error('Could not load "%s"; this mod grants nothing.' % LICENSE_PATH, MOD_ID)
		return

	library.get_mod_being_installed().queued_resource_modifications.erase(LICENSE_PATH)

	if _retained_license.has_meta(APPLIED_META): return
	var extender = load(LICENSE_EXTENSION).new()
	extender.modify_resource(_retained_license)
	_retained_license.set_meta(APPLIED_META, true)
	ModLoaderLog.info('Applied li_gms.tres_ext.gd directly, outside the shared extension queue.', MOD_ID)

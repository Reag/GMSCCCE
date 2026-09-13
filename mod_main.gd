extends Node
const MOD_ID := "Reag-CrisisCoreCatalogEvolved" ## Name of the directory that this file is in

const LICENSE_PATH := 'res://content/licenses/gms/li_gms.tres'
const LICENSE_EXTENSION := 'res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/licenses/gms/li_gms.tres_ext.gd'
const MOD_LIBRARY_140 := 'res://engine/mod/mod_library.gd' # class_name ModLibrary exists only on 1.4.x; never name it here
const APPLIED_META := &'reag_ccce_li_gms_applied' ## stamped on the license instance we edited, so we never edit it twice
var _retained_license:Resource # keeps our edits alive in the resource cache; see apply_license_extension_directly

# Runs when this mod is activated (whenever active mods are changed). Kept as _init rather than the
# 1.4.0 template's _ready: on 1.4.0 the applier marks the mod "installing" before instantiating this
# script and "installed" only after adding it to the tree, so both hooks run inside the install
# window, and _init is what has worked on 1.3.3 all along.
func _init() -> void:
	ModLoaderLog.info("Activating.", MOD_ID)

	# Adds the translations from your localization/localizations.csv
	LancerTacticsMod.add_translations(MOD_ID)

	# Automatically scans everything in your mod's res/ directory, and:
	# 1. Adds any new RESOURCES (.tres, .tscn, images) or SCRIPTS (.gd) to the virtual
	#    filesystem if there was no vanilla corresponding file.
	# 2. Overwrites any RESOURCES that already existed at those corresponding locations
	# 3. Installs any SCRIPTS (.gd) that already existed as a script_extension. (Warning: cannot extend class_name scripts)
	LancerTacticsMod.add_overwrite_extend_mod_resources(MOD_ID)

	apply_license_extension_directly()

## Applies li_gms.tres_ext.gd ourselves instead of letting the engine apply it, and takes our entry
## back out of the queue the engine would have applied it from.
##
## WHY: on 1.4.x that queue cannot hold two mods at once. ModApplier.apply_installed_queued_extensions
## (engine/mod/mod_applier.gd:219-220) folds every installed mod's queued_resource_modifications into
## one Dictionary keyed by TARGET RESOURCE PATH:
##
##     all_queued_resource_modifications.merge(mod.queued_resource_modifications)
##
## Dictionary.merge does not concatenate values - with overwrite left false it keeps the first value
## for a key and throws the rest away. So when two mods both extend res://content/licenses/gms/li_gms.tres,
## the mod installed FIRST keeps the key and every later mod's modify_resource callable is discarded
## silently: no warning, no log line. Since this license extension is the only thing that puts the
## Denali and our 15 GMS kits into a license a player can buy from, losing that coin toss ships a
## Crisis Core Catalog that appears not to have activated at all.
##
## That is not hypothetical. gavstarb-gms_1st_party (v4.2.0) and fateofman-imi_alt_frames both extend
## this same license, and gavstarb-gms_1st_party installs before us, so before this workaround we lost
## every time both were enabled. Verified 2026-09-13: with it unpacked alongside us, li_gms rank 1
## granted mf_chomolungma and mf_sagarmatha and no mf_denali. The same engine bug hits .tscn_ext.gd
## (line 219) - if two mods ever extend one scene, only the first-installed one runs. Report upstream.
##
## THE FIX: erase our own key, so the contended dictionary sees only the OTHER mod's entry and applies
## it normally, and edit the license here instead. Order does not matter - whoever runs second calls
## load(LICENSE_PATH), gets this same cached instance, and appends to it - as long as the instance
## stays in the resource cache, which is what _retained_license is for.
##
## That retention is load-bearing for a SECOND upstream bug: 1.4.x's
## _ModLoaderResourceExtension._save_resource no longer keeps the extended resource alive (1.3.3
## appended it to ModLoaderStore.extended_resources), so once the last local reference goes out of
## scope the cache entry evaporates and the next load() reads the vanilla license off disk.
## gavstarb-gms_1st_party holds its own reference for the same reason. (Reag-ThyHubris' mod_main.gd
## has the scene-extension twin of that one.)
##
## Self-disabling on 1.3.3: that engine has no ModLibrary script, applies each mod's extensions
## without merging them, and needs nothing from us - so we return at once and its own path runs.
func apply_license_extension_directly() -> void:
	if not ResourceLoader.exists(MOD_LIBRARY_140): return # 1.3.3 applies extensions per-mod; no collision to dodge
	var library = load(MOD_LIBRARY_140)
	if not library.is_mod_being_installed(MOD_ID): return

	_retained_license = load(LICENSE_PATH)
	if _retained_license == null:
		ModLoaderLog.error('Could not load "%s"; this mod grants nothing.' % LICENSE_PATH, MOD_ID)
		return

	# Stand down from the shared queue whether or not the engine got as far as filling it.
	library.get_mod_being_installed().queued_resource_modifications.erase(LICENSE_PATH)

	# The meta rides on the instance, not on this node: a license still in cache from a previous
	# activation already has our gear on it, and a freshly reloaded vanilla one does not.
	if _retained_license.has_meta(APPLIED_META): return
	var extender = load(LICENSE_EXTENSION).new()
	extender.modify_resource(_retained_license)
	_retained_license.set_meta(APPLIED_META, true)
	ModLoaderLog.info('Applied li_gms.tres_ext.gd directly, outside the shared extension queue.', MOD_ID)

# Runs when this mod's node is added to the tree (whenever active mods are changed)
#func _ready() -> void:
	#ModLoaderLog.info("Activating (ready)", MOD_ID)

# Runs when this mod is deactivated due to user input or the normal mod reset/reactivate sequence.
# Should undo any non-standard stuff you've done in _init or _ready.
#func deactivate() -> void:
	#ModLoaderLog.info("Deactivating", MOD_ID)

extends Node
const MOD_ID := "Reag-CrisisCoreCatalogEvolved" ## Name of the directory that this file is in

# 1.4.0 workaround (see queue_license_extension_if_engine_skipped_it below)
const LICENSE_PATH := 'res://content/licenses/gms/li_gms.tres'
const LICENSE_EXTENSION := 'res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/licenses/gms/li_gms.tres_ext.gd'
const MOD_LIBRARY_140 := 'res://engine/mod/mod_library.gd' # class_name ModLibrary exists only on 1.4.0; never name it here
var _retained_license:Resource # 1.4.0: see queue_license_extension_if_engine_skipped_it

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

	queue_license_extension_if_engine_skipped_it()

## 1.4.0 unstable's LancerTacticsMod.extend_resource (lancer_tactics_mod.gd:180) strips the SCENE
## suffix instead of the RESOURCE one, so it looks for "li_gms.tres_ext.gd" on disk, prints
## "Skipped extending resource", and never queues the extension. li_gms.tres_ext.gd is the only
## thing that puts the Denali and this mod's 15 GMS kits into the GMS license, so without this the
## mod ships nothing a player can buy.
##
## Queue it ourselves, exactly as the fixed engine would: ModApplier.apply_installed_queued_extensions
## applies every mod's queue after every mod is installed, in load order, so this composes with any
## other mod extending the same license. Self-disabling: on 1.3.3 there is no ModLibrary script and
## this returns at once; once Wickworks fixes the typo the engine will have queued it already and
## the has() check returns. Reported upstream 2026-09-08.
##
## Second 1.4.0 bug in the same path: _ModLoaderResourceExtension._save_resource no longer keeps the
## extended resource alive (1.3.3 appended it to ModLoaderStore.extended_resources), so once the
## applier's local reference goes out of scope the resource-cache entry evaporates and the next
## load() reads the vanilla license off disk. Holding the license from HERE, before the queue is
## applied, means the extension mutates the very object this node keeps, so the entry cannot die.
## (The sibling mod hit the scene-extension twin of this: see Reag-ThyHubris mod_main.gd.)
func queue_license_extension_if_engine_skipped_it() -> void:
	if not ResourceLoader.exists(MOD_LIBRARY_140): return
	var library = load(MOD_LIBRARY_140)
	if not library.is_mod_being_installed(MOD_ID): return
	_retained_license = load(LICENSE_PATH) # retention: needed whether or not the engine queues the extension itself
	var mod = library.get_mod_being_installed()
	if mod.queued_resource_modifications.has(LICENSE_PATH): return # the engine did its job

	var extender = load(LICENSE_EXTENSION).new()
	mod.queued_resource_modifications.get_or_add(LICENSE_PATH, []).append(extender.modify_resource)
	mod.queued_modification_objects.append(extender) # keep the callable's object alive until applied
	ModLoaderLog.info('Queued li_gms.tres_ext.gd by hand: 1.4.0 extend_resource skipped it.', MOD_ID)

# Runs when this mod's node is added to the tree (whenever active mods are changed)
#func _ready() -> void:
	#ModLoaderLog.info("Activating (ready)", MOD_ID)

# Runs when this mod is deactivated due to user input or the normal mod reset/reactivate sequence.
# Should undo any non-standard stuff you've done in _init or _ready.
#func deactivate() -> void:
	#ModLoaderLog.info("Deactivating", MOD_ID)

extends RefCounted
# Modifies the resource at: res://content/licenses/gms/li_gms.tres

func sload(file: String):
	if(ResourceLoader.exists(file)):
		return ResourceLoader.load(file)
	else:
		return ResourceLoader.load('res://'+file.split('/res/')[1])

# Apply any changes to the given resource here and they'll be saved in the virtual filesystem over the original.
# Must return the changed resource.
func modify_resource(resource:Resource) -> Resource:
	var license: UnlockTree = resource
	
	license.rank_1.granted_gear.append(sload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/gear/gms/weapons/mw_autocannon.tres'))
	license.rank_1.granted_gear.append(sload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/gear/gms/weapons/mw_antishipmissile.tres'))
	license.rank_1.granted_gear.append(sload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/gear/gms/weapons/mw_nexusapexhunter.tres'))
	license.rank_1.granted_gear.append(sload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/gear/gms/weapons/mw_heavyslugshotgun.tres'))
	license.rank_1.granted_gear.append(sload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/gear/gms/weapons/mw_recoilessrifle.tres'))
	license.rank_1.granted_gear.append(sload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/gear/gms/weapons/mw_antitankmissile.tres'))
	license.rank_1.granted_gear.append(sload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/gear/gms/weapons/mw_heliosnexus.tres'))
	license.rank_1.granted_gear.append(sload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/gear/gms/weapons/mw_fraglauncher.tres'))
	license.rank_1.granted_gear.append(sload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/gear/gms/weapons/mw_grenadelauncher.tres'))
	license.rank_1.granted_gear.append(sload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/gear/gms/weapons/mw_combatmaul.tres'))
	license.rank_1.granted_gear.append(sload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/gear/gms/weapons/mw_delugemissiles.tres'))
	
	return resource

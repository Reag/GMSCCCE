extends BuffBonus
## BuffBonus with the Force Multiplier maintenance gate. See buff_fm_maintained.gd.

const FmUtil := preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_force_multiplier/fm_util.gd')

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	return FmUtil.is_buff_maintained(core, X.map())

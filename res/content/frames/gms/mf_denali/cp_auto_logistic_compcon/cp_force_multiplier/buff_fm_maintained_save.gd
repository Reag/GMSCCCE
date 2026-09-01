extends BuffSkillSave
## BuffSkillSave with the Force Multiplier maintenance gate. See buff_fm_maintained.gd.
##
## UnitHasecheck.roll_check is the single funnel for both checks AND saves and applies
## Buff.TO.SAVE bonuses either way - its is_save flag only picks the battle-log string. So this
## covers "all checks and saves", including grapple's contested hull checks.

const FmUtil := preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_force_multiplier/fm_util.gd')

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	return FmUtil.is_buff_maintained(core, X.map())

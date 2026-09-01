extends Buff
## Base for Force Multiplier effect buffs that need no archetype beyond plain Buff.
## Gates the effect on the holder still being within the granting Denali's sensors and
## line of sight - the design's decision A, checked at proc time rather than expiring early.

const FmUtil := preload('res://unpacked/Reag-CrisisCoreCatalogEvolved/res/content/frames/gms/mf_denali/cp_auto_logistic_compcon/cp_force_multiplier/fm_util.gd')

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	return FmUtil.is_buff_maintained(core, X.map())

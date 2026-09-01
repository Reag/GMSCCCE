extends Buff
## Hidden 1/scene marker for Force Multiplier's three options. The rule is per character per
## scene, so these must survive the granting Denali's death - the default Buff behaviour clears
## buffs whose owner dies (buff.gd:184, event_service.gd:60), which would silently void the limit.

func is_cleared_on_owner_death() -> bool: return false

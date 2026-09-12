# Compatibility layer between the 1.3.3 and 1.4.0 choice-bus APIs for the prompts this mod makes.
# A deliberate copy of the matching functions in Reag-ThyHubris' reag_compat.gd: the mods ship
# independently, so they cannot share a file. Keep the two in step.
# Design: D:\DEV\lancer-tactics-claude\specs\2026-09-08-modkit-140-dual-compat-design.md
#
# RULE: no version-specific class is ever NAMED here - BrochureCore (1.4.0) and
# InformationalBrochure (1.3.3) would each fail to PARSE on the other engine, taking every action
# that preloads this file down silently. They are reached via load() on a script path, and the bus
# is kept UNTYPED so member access resolves at runtime.
extends RefCounted

const BUS_140 := 'res://engine/choices/choice_bus.tres'
const BUS_133 := 'res://ui/choice_controller/choice_bus.tres'
const BROCHURE_CORE_140 := 'res://engine/choices/brochure_core.gd'
const INFO_BROCHURE_133 := 'res://ui/choice_controller/informational_brochure/informational_brochure.gd'

static var _bus = null # untyped on purpose

## -1 = not yet tested, 0 = 1.3.3, 1 = 1.4.0. Cached after the first call: ResourceLoader.exists
## never changes mid-run, and this is called from hot paths (every prompt through this file).
static var _is_140:int = -1

static func is_140() -> bool:
	if _is_140 == -1: _is_140 = 1 if ResourceLoader.exists(BUS_140) else 0
	return _is_140 == 1

static func bus():
	if _bus == null: _bus = load(BUS_140 if is_140() else BUS_133)
	return _bus

## Shows a menu and returns the chosen index, or -1 if the player cancelled / skipped.
## `choices` items are either a String or {text:String, disabled_reason:String} (a non-empty
## disabled_reason greys the option out and shows the reason). `desc` may be a translation key: both
## brochures auto-translate it. 1.4.0 requires the SpecificAction; 1.3.3 ignores it.
static func multiple_choice(specific:SpecificAction, choices:Array, title:String, desc:String = 'battle.multiple_choice.prompt', subtitle:String = '', can_cancel:bool = true) -> int:
	if is_140():
		var brochure = load(BROCHURE_CORE_140).create({title = title, description = desc, subtitle = subtitle, choices = choices})
		return await bus().choose_from_multiple_choice_for({brochure = brochure, using = specific, can_voluntarily_cancel = can_cancel})
	var option_class = load(INFO_BROCHURE_133).MultipleChoiceOption
	var options:Array = []
	for choice in choices:
		if choice is Dictionary: options.append(option_class.create(str(choice.get('text', '')), str(choice.get('disabled_reason', ''))))
		else: options.append(choice) # the 1.3.3 brochure accepts plain Strings
	return await bus().choose_from_multiple_choice(options, title, desc, subtitle, can_cancel)

## Yes/no with the two info panels: `using` lights the action panel, `whois` the unit panel. On
## 1.4.0 those are request parameters; on 1.3.3 they are the show_/hide_ bracket around the prompt.
static func yesno(tile:Vector2i, title:String, desc:String = '', using:SpecificAction = null, whois:Unit = null, encourage_yes:bool = true) -> bool:
	if is_140():
		return await bus().quick_yesno_for({
			tile = tile, title = title, description = desc, encourage_yes = encourage_yes,
			using = using, whois = whois,
		})
	if using != null: bus().show_using_action(using)
	if whois != null: bus().show_whois(whois)
	var answer:bool = await bus().quick_yesno(tile, title, desc, encourage_yes)
	if using != null: bus().hide_using_action()
	if whois != null: bus().hide_whois()
	return answer

# ------------------------------------------------------------------ unit pick with an explanatory panel

## Pick one unit while an information panel explains why. `title`/`desc` may be translation keys.
## 1.4.0: the panel is the request's own brochure, so it closes with the pick. 1.3.3: the info
## brochure is opened un-awaited and the targeting request that follows ends it (request piles).
static func choose_unit_with_brochure(specific:SpecificAction, units:Array, title:String, desc:String, can_cancel:bool = true) -> Unit:
	if is_140():
		var brochure = load(BROCHURE_CORE_140).create({title = title, description = desc, show_continue = false})
		return await bus().choose_unit_for({units = units, brochure = brochure, using = specific, can_voluntarily_cancel = can_cancel})
	bus().show_informational_brochure(title, desc, '', false)
	# No `specific` on 1.3.3: tilepicker_unit.gd:42-45 recentres the camera on specific.unit when given one,
	# discarding whatever framing the caller just set up (1.4.0 commented that block out).
	return await bus().choose_unit(units, can_cancel)

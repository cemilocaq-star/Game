extends RefCounted
## One look for the whole interface: colours, type, shapes and the shared Theme.
##
## Direction: dark glass plates with chamfered corners, a thin accent edge, condensed squared type
## (Rajdhani, SIL OFL), white glyph icons tinted by meaning (game-icons.net, CC BY 3.0). Colours carry
## meaning and are used the same way everywhere: cyan = interface / neutral, amber = reward and
## warning, red = damage and danger, green = healing and success, purple = progression.

const ACCENT := Color("#27D7E7")
const ACCENT_DIM := Color("#1B8E9A")
const WARM := Color("#FFB84D")
const DANGER := Color("#FF536B")
const OK := Color("#5BE39A")
const XP := Color("#B18CFF")
const INK := Color("#E8F8FF")
const MUTED := Color("#8FA9B8")
const FAINT := Color("#5B7384")
const PANEL := Color(0.028, 0.062, 0.1, 0.86)
const PANEL_DEEP := Color(0.012, 0.028, 0.05, 0.99)
const PANEL_HOVER := Color(0.07, 0.15, 0.21, 0.94)
const TEAM_RED := Color("#FF5B6E")
const TEAM_BLUE := Color("#4DA3FF")

const RARITY_COLORS := {
	"Common": Color("#9FB6C6"), "Uncommon": Color("#5BE39A"), "Rare": Color("#4DA3FF"),
	"Legendary": Color("#FFB84D"), "Secret": Color("#FF6BD6"),
}

const FONT_PATHS := {
	"medium": "res://assets/ui/fonts/Rajdhani-Medium.ttf",
	"semibold": "res://assets/ui/fonts/Rajdhani-SemiBold.ttf",
	"bold": "res://assets/ui/fonts/Rajdhani-Bold.ttf",
}

## Type scale (logical pixels at UI scale 1). Rajdhani runs small for its size, so these are larger
## than they would be for a default font.
const SIZE_XS := 13
const SIZE_S := 15
const SIZE_M := 18
const SIZE_L := 24
const SIZE_XL := 34
const SIZE_HERO := 54

const SPACE_XS := 4
const SPACE_S := 8
const SPACE_M := 12
const SPACE_L := 20
const CHAMFER := 8.0

static var _fonts: Dictionary = {}


## A UI font by weight ("medium", "semibold", "bold"). Glyphs the font does not have (for example the
## Azerbaijani schwa) fall back to the engine's default font, so no text ever shows empty boxes.
static func font(weight: String = "semibold") -> Font:
	if _fonts.has(weight):
		return _fonts[weight] as Font
	var path: String = FONT_PATHS.get(weight, FONT_PATHS["semibold"])
	var result: Font = null
	if ResourceLoader.exists(path):
		var loaded := load(path) as FontFile
		if loaded != null:
			loaded.fallbacks = [ThemeDB.fallback_font]
			result = loaded
	if result == null:
		result = ThemeDB.fallback_font
	_fonts[weight] = result
	return result


static func team_color(team_id: String) -> Color:
	match team_id:
		"red":
			return TEAM_RED
		"blue":
			return TEAM_BLUE
	return INK


static func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, INK) as Color


## The outline of a plate: a rectangle with the top-left and bottom-right corners cut.
static func chamfer_points(rect: Rect2, cut: float) -> PackedVector2Array:
	var c := minf(cut, minf(rect.size.x, rect.size.y) * 0.5)
	var p := rect.position
	var s := rect.size
	return PackedVector2Array([
		Vector2(p.x + c, p.y), Vector2(p.x + s.x, p.y), Vector2(p.x + s.x, p.y + s.y - c),
		Vector2(p.x + s.x - c, p.y + s.y), Vector2(p.x, p.y + s.y), Vector2(p.x, p.y + c),
	])


## A flat style for the standard controls (line edits, option lists) so they match the plates.
static func box_style(fill: Color, border: Color, radius: int = 4, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


## The Theme for every screen. Labels and the controls that are not custom-drawn.
static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = font("semibold")
	theme.default_font_size = SIZE_M
	for control in ["Label", "Button", "CheckBox", "LineEdit", "OptionButton", "RichTextLabel"]:
		theme.set_font("font", control, font("semibold"))
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", FAINT)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", FAINT)
	theme.set_color("caret_color", "LineEdit", ACCENT)
	theme.set_color("font_color", "CheckBox", INK)
	theme.set_color("font_color", "OptionButton", INK)
	var states := {
		"normal": [Color(0.06, 0.12, 0.18, 0.95), Color("#2C5266")],
		"hover": [Color(0.1, 0.2, 0.28, 0.98), ACCENT_DIM],
		"pressed": [Color("#126B72"), ACCENT],
		"disabled": [Color(0.05, 0.09, 0.13, 0.8), Color("#1D3140")],
	}
	for state in states:
		var style := box_style(states[state][0], states[state][1])
		for control in ["Button", "OptionButton", "CheckBox"]:
			theme.set_stylebox(state, control, style)
	var focus := box_style(Color.TRANSPARENT, ACCENT, 4, 2)
	for control in ["Button", "OptionButton", "CheckBox", "LineEdit"]:
		theme.set_stylebox("focus", control, focus)
	theme.set_stylebox("normal", "LineEdit", box_style(Color(0.02, 0.05, 0.08, 0.95), Color("#2C5266")))
	theme.set_stylebox("read_only", "LineEdit", box_style(Color(0.02, 0.05, 0.08, 0.7), Color("#1D3140")))
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.02, 0.05, 0.08, 0.9)
	track.set_corner_radius_all(3)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = ACCENT_DIM
	grabber.set_corner_radius_all(3)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", grabber)
	theme.set_stylebox("grabber_area_highlight", "HSlider", grabber)
	theme.set_constant("separation", "HBoxContainer", SPACE_S)
	theme.set_constant("separation", "VBoxContainer", SPACE_S)
	return theme

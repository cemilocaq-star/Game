extends RefCounted
## The icon library. Every icon is a white glyph on transparent (assets/ui/icons/*.svg, from
## game-icons.net, CC BY 3.0, see assets/ui/ICON_CREDITS.md), tinted where it is drawn so the same
## glyph can be cyan in a menu, red on a damage event and amber on a reward.
##
## Names: weapons are "w_<weapon id>", events are "e_<event id lower case>", the rest are plain
## ("jump", "health", "settings" ...).

const DIR := "res://assets/ui/icons/"

static var _cache: Dictionary = {}
static var _warned: Dictionary = {}


static func has(icon_name: String) -> bool:
	return ResourceLoader.exists(DIR + icon_name + ".svg")


## The texture for an icon, or null (with one warning) when the name is unknown.
static func texture(icon_name: String) -> Texture2D:
	if _cache.has(icon_name):
		return _cache[icon_name] as Texture2D
	var result: Texture2D = null
	if has(icon_name):
		result = load(DIR + icon_name + ".svg") as Texture2D
	if result == null and not _warned.has(icon_name):
		_warned[icon_name] = true
		push_warning("UI icon not found: " + icon_name)
	_cache[icon_name] = result
	return result


static func weapon_name(weapon_id: String) -> String:
	return "w_" + weapon_id


static func event_name(event_id: String) -> String:
	return "e_" + event_id.to_lower()


## An icon as a control of `pixels` x `pixels`, tinted.
static func make(icon_name: String, pixels: float, tint: Color = Color.WHITE) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture(icon_name)
	rect.custom_minimum_size = Vector2(pixels, pixels)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate = tint
	rect.name = "Icon_" + icon_name
	return rect


## Every icon name in the library (works in the editor and in an exported game).
static func all_names() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return result
	for file_name in dir.get_files():
		var clean := file_name.trim_suffix(".import").trim_suffix(".remap")
		if clean.ends_with(".svg") and not result.has(clean.trim_suffix(".svg")):
			result.append(clean.trim_suffix(".svg"))
	result.sort()
	return result

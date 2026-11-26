extends RefCounted
## Parses servers.json ({"servers": ["wss://host", "host:port"]}) and keeps only well-formed addresses.

static func parse(text: String) -> PackedStringArray:
	var result := PackedStringArray()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("servers", null)) != TYPE_ARRAY:
		return result
	var matcher := RegEx.new()
	matcher.compile("^(wss://)?[A-Za-z0-9.-]{3,190}(:[0-9]{2,5})?$")
	for item in parsed["servers"]:
		if typeof(item) != TYPE_STRING:
			continue
		var value := (item as String).strip_edges()
		if matcher.search(value) != null and not result.has(value) and result.size() < 8:
			result.append(value)
	return result

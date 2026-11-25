extends RefCounted
## The emotes a player can pick. One list, used by the keyboard, the touch wheel, the network (which
## only relays ids from this list) and the character rig, so adding an emote is one entry plus its pose.

## Order is the order on the radial wheel, clockwise from the top.
const IDS := ["griddy", "goofy", "robot", "wave", "salute", "clap", "flex", "spin"]

const LABELS := {
	"griddy": "Dance", "goofy": "Goofy", "robot": "Robot", "wave": "Wave",
	"salute": "Salute", "clap": "Clap", "flex": "Flex", "spin": "Spin",
}

## Keyboard keys (B N M J were the original four).
const KEYS := {
	"griddy": KEY_B, "goofy": KEY_N, "robot": KEY_M, "wave": KEY_J,
	"salute": KEY_Z, "clap": KEY_K, "flex": KEY_L, "spin": KEY_U,
}

## Icon names in assets/ui/icons. The new emotes share the generic party-hat icon; their caption tells them apart.
const ICONS := {
	"griddy": "emote_dance", "goofy": "emote_goofy", "robot": "emote_robot", "wave": "emote_wave",
	"salute": "emote", "clap": "emote", "flex": "emote", "spin": "emote",
}


static func is_valid(emote_id: String) -> bool:
	return IDS.has(emote_id)


## The id when it is a known emote, otherwise "" (no emote). Used on everything that arrives from the network.
static func sanitize(emote_id: String) -> String:
	return emote_id if IDS.has(emote_id) else ""


static func action_name(emote_id: String) -> String:
	return "emote_" + emote_id

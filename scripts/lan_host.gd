extends Node
## Hosts a room on this device, with no server and no address to type.
##
## The authoritative OxenWar server (the same script a dedicated server runs) is started inside this
## game process in "open" mode. It gets its own MultiplayerAPI for this node's subtree, so the game's own
## network node keeps using the default API and connects to it like to any other server. Friends on the same
## Wi-Fi (or on a phone hotspot) find it by room code through LAN discovery, see lan_discovery.gd.
##
## The server node is built at "<this node>/Main/OxenWarNet" so its RPC path relative to the API root is
## "Main/OxenWarNet", exactly the path every client has for its network node ("/root/Main/OxenWarNet").

const NETWORK_SCRIPT := preload("res://scripts/oxenwar_network.gd")

var server: Node
var running := false


func start() -> bool:
	if running:
		return true
	if not is_inside_tree():
		return false
	var api := SceneMultiplayer.new()
	get_tree().set_multiplayer(api, get_path())
	var stand_in := Node.new()
	stand_in.name = "Main"
	add_child(stand_in)
	server = NETWORK_SCRIPT.new()
	server.name = "OxenWarNet"
	stand_in.add_child(server)
	running = server.start_server(true)
	if not running:
		stand_in.queue_free()
		server = null
	return running


## Room codes the hosted server currently has.
func room_codes() -> Array:
	var codes: Array = []
	if server != null:
		for code in server._rooms.keys():
			codes.append(str(code))
	return codes

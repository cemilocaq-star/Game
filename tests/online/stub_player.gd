extends "res://scripts/oxenwar_server_player.gd"
## A client-side predicted player for the online test: it runs the same movement code as the server
## (as the real player does) and has the `pitch` the network layer reads.

var pitch := 0.0

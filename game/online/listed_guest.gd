class_name ListedGuest
extends RefCounted
## Another Guest as the Lobby lists them.

var guest_id: String
var nickname: String
## True while they wait for a Quick Match.
var waiting: bool = false


func _init(id: String, name: String, is_waiting: bool) -> void:
	guest_id = id
	nickname = name
	waiting = is_waiting

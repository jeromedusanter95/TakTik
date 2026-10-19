class_name VersionLabel
extends Label
## Identifies the version bundled with this player's copy of the game.


func _ready() -> void:
	text = "v%s" % ProjectSettings.get_setting("application/config/version", "")

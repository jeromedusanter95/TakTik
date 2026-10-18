class_name ConfigFilePreferenceStore
extends PreferenceStore
## Keeps the player's choices in a settings file on the device (browser
## storage on the web).

const _SECTION: String = "display"

var _path: String = ""


func _init(path: String) -> void:
	_path = path


func load_value(key: String) -> String:
	var file: ConfigFile = ConfigFile.new()
	if file.load(_path) != OK:
		return ""
	var value: Variant = file.get_value(_SECTION, key, "")
	if value is not String:
		return ""
	var text: String = value
	return text


## Keeps any other settings already in the file.
func save_value(key: String, value: String) -> void:
	var file: ConfigFile = ConfigFile.new()
	if FileAccess.file_exists(_path) and file.load(_path) != OK:
		push_error("Could not read the settings in %s" % _path)
		return
	file.set_value(_SECTION, key, value)
	var error: Error = file.save(_path)
	if error != OK:
		push_error("Could not save %s to %s: %s" % [key, _path, error_string(error)])

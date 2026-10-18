class_name ConfigFileLanguageStore
extends LanguageStore
## Keeps the chosen language in a settings file on the device (browser storage
## on the web).

const _SECTION: String = "display"
const _KEY: String = "language"

var _path: String = ""


func _init(path: String) -> void:
	_path = path


func load_language() -> String:
	var file: ConfigFile = ConfigFile.new()
	if file.load(_path) != OK:
		return ""
	var value: Variant = file.get_value(_SECTION, _KEY, "")
	if value is not String:
		return ""
	var code: String = value
	return code


## Keeps any other settings already in the file.
func save_language(code: String) -> void:
	var file: ConfigFile = ConfigFile.new()
	if FileAccess.file_exists(_path) and file.load(_path) != OK:
		push_error("Could not read the settings in %s" % _path)
		return
	file.set_value(_SECTION, _KEY, code)
	var error: Error = file.save(_path)
	if error != OK:
		push_error("Could not save the language to %s: %s" % [_path, error_string(error)])

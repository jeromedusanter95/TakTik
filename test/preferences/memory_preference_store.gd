extends PreferenceStore
## A PreferenceStore that keeps values in memory, for tests.

var values: Dictionary[String, String] = {}


func load_value(key: String) -> String:
	return values.get(key, "")


func save_value(key: String, value: String) -> void:
	values[key] = value

extends GutTest
## The chosen language survives between two visits.

const PATH: String = "user://test_language_store.cfg"


func before_each() -> void:
	_delete_file()


func after_each() -> void:
	_delete_file()


func test_nothing_is_saved_at_first() -> void:
	assert_eq(ConfigFileLanguageStore.new(PATH).load_language(), "")


func test_a_saved_language_is_read_back_by_a_new_store() -> void:
	ConfigFileLanguageStore.new(PATH).save_language("fr")
	assert_eq(ConfigFileLanguageStore.new(PATH).load_language(), "fr")


func test_saving_keeps_the_other_settings() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("audio", "mode", "loud")
	file.save(PATH)
	ConfigFileLanguageStore.new(PATH).save_language("fr")
	var reloaded: ConfigFile = ConfigFile.new()
	reloaded.load(PATH)
	assert_eq(str(reloaded.get_value("audio", "mode")), "loud")


func _delete_file() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)

extends GutTest
## The player's choices survive between two visits.

const PATH: String = "user://test_preference_store.cfg"


func before_each() -> void:
	_delete_file()


func after_each() -> void:
	_delete_file()


func test_nothing_is_saved_at_first() -> void:
	assert_eq(ConfigFilePreferenceStore.new(PATH).load_value("language"), "")


func test_a_saved_value_is_read_back_by_a_new_store() -> void:
	ConfigFilePreferenceStore.new(PATH).save_value("language", "fr")
	assert_eq(ConfigFilePreferenceStore.new(PATH).load_value("language"), "fr")


func test_the_language_saved_by_earlier_versions_is_still_read() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("display", "language", "fr")
	file.save(PATH)
	assert_eq(ConfigFilePreferenceStore.new(PATH).load_value("language"), "fr")


func test_saving_keeps_the_other_settings() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("audio", "mode", "loud")
	file.save(PATH)
	ConfigFilePreferenceStore.new(PATH).save_value("language", "fr")
	var reloaded: ConfigFile = ConfigFile.new()
	reloaded.load(PATH)
	assert_eq(str(reloaded.get_value("audio", "mode")), "loud")


func _delete_file() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)

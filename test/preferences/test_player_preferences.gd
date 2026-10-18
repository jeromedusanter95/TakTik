extends GutTest
## The player's choices start from what was saved, else from the device, and
## every change is saved.

const MemoryPreferenceStore: GDScript = preload("res://test/preferences/memory_preference_store.gd")

var _store: MemoryPreferenceStore = null


func before_each() -> void:
	_store = MemoryPreferenceStore.new()


func test_a_first_visit_follows_the_device() -> void:
	var preferences: PlayerPreferences = PlayerPreferences.new(_store, "fr", true)
	assert_eq(preferences.language, "fr")
	assert_true(preferences.reduced_motion)
	assert_false(preferences.adapted_colours)
	assert_eq(preferences.nickname, "")
	assert_eq(preferences.difficulty, 1, "Medium is the default Difficulty")


func test_saved_choices_win_over_the_device() -> void:
	_store.values = {"language": "en", "reduced_motion": "no", "difficulty": "2", "nickname": "Jeje z"}
	var preferences: PlayerPreferences = PlayerPreferences.new(_store, "fr", true)
	assert_eq(preferences.language, "en")
	assert_false(preferences.reduced_motion)
	assert_eq(preferences.difficulty, 2)
	assert_eq(preferences.nickname, "Jeje z")


func test_each_change_is_saved_and_reported() -> void:
	var preferences: PlayerPreferences = PlayerPreferences.new(_store, "en", false)
	watch_signals(preferences)
	preferences.set_language("fr")
	preferences.set_difficulty(0)
	preferences.set_reduced_motion(true)
	preferences.set_adapted_colours(true)
	assert_eq(_store.values, {
		"language": "fr", "difficulty": "0", "reduced_motion": "yes", "adapted_colours": "yes",
	} as Dictionary[String, String])
	assert_signal_emit_count(preferences, "changed", 4)


func test_a_nickname_is_kept_trimmed_and_a_bad_one_refused() -> void:
	var preferences: PlayerPreferences = PlayerPreferences.new(_store, "en", false)
	assert_true(preferences.set_nickname("  Bob  "))
	assert_eq(preferences.nickname, "Bob")
	assert_false(preferences.set_nickname("x".repeat(Nickname.MAX_LENGTH + 1)))
	assert_eq(preferences.nickname, "Bob")


func test_an_unsupported_language_is_ignored() -> void:
	var preferences: PlayerPreferences = PlayerPreferences.new(_store, "en", false)
	preferences.set_language("xx")
	assert_eq(preferences.language, "en")

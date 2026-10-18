extends GutTest
## Which language the game starts in and which one the switch goes to.


func test_a_saved_language_wins_over_the_device() -> void:
	assert_eq(Languages.initial("fr", "en"), "fr")


func test_the_device_language_is_used_when_nothing_is_saved() -> void:
	assert_eq(Languages.initial("", "fr"), "fr")


func test_english_when_neither_is_supported() -> void:
	assert_eq(Languages.initial("de", "ja"), Languages.ENGLISH)


func test_the_switch_cycles_through_every_language() -> void:
	assert_eq(Languages.next("en"), "fr")
	assert_eq(Languages.next("fr"), "en")


func test_an_unknown_language_switches_to_the_first_one() -> void:
	assert_eq(Languages.next("de"), Languages.ENGLISH)


func test_each_language_is_named_in_itself() -> void:
	assert_eq(Languages.native_name("en"), "English")
	assert_eq(Languages.native_name("fr"), "Français")

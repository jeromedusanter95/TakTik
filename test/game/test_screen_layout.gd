extends GutTest
## The layout follows the screen's width, at the handoff's breakpoints.


func test_breakpoints() -> void:
	assert_eq(ScreenLayout.for_width(1440.0), ScreenLayout.Id.WIDE)
	assert_eq(ScreenLayout.for_width(1280.0), ScreenLayout.Id.WIDE)
	assert_eq(ScreenLayout.for_width(1279.0), ScreenLayout.Id.MEDIUM)
	assert_eq(ScreenLayout.for_width(1024.0), ScreenLayout.Id.MEDIUM)
	assert_eq(ScreenLayout.for_width(1023.0), ScreenLayout.Id.NARROW)
	assert_eq(ScreenLayout.for_width(700.0), ScreenLayout.Id.NARROW)
	assert_eq(ScreenLayout.for_width(699.0), ScreenLayout.Id.PHONE)


func test_wide_and_phone_use_the_design_sizes_and_tablets_their_own() -> void:
	assert_eq(ScreenLayout.content_size(ScreenLayout.Id.WIDE, Vector2(1920, 1080)), Vector2i(1440, 900))
	assert_eq(ScreenLayout.content_size(ScreenLayout.Id.PHONE, Vector2(390, 700)), Vector2i(390, 844))
	assert_eq(ScreenLayout.content_size(ScreenLayout.Id.NARROW, Vector2(820, 1180)), Vector2i(820, 1180))

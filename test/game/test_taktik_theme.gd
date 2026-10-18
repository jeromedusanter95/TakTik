extends GutTest
## The Theme gives every look of the UI handoff, built from UiTokens.

var _theme: Theme = null


func before_all() -> void:
	_theme = TaktikTheme.build()


func test_every_button_look_is_a_button_variation() -> void:
	for look: StringName in [
		&"GoldButton", &"GoldButtonHero", &"WoodButton", &"OutlineButton",
		&"GhostButton", &"IconButton", &"Chip", &"SegmentButton",
	]:
		assert_true(_theme.is_type_variation(look, &"Button"), "%s should vary Button" % look)
	assert_true(_theme.is_type_variation(&"TabButton", &"SegmentButton"))


func test_the_gold_button_has_a_gold_face_and_a_deep_gold_edge() -> void:
	var style: StyleBox = _theme.get_stylebox(&"normal", &"GoldButton")
	assert_true(style is StyleBoxFlat)
	var flat: StyleBoxFlat = style
	assert_eq(flat.bg_color, UiTokens.GOLD_500)
	assert_eq(flat.border_color, UiTokens.GOLD_SHADOW)
	assert_eq(flat.border_width_bottom, 6)
	assert_eq(_theme.get_color(&"font_color", &"GoldButton"), UiTokens.TEXT_ON_GOLD)


func test_a_disabled_button_fades_and_loses_its_edge() -> void:
	var style: StyleBox = _theme.get_stylebox(&"disabled", &"GoldButton")
	assert_true(style is StyleBoxFlat)
	var flat: StyleBoxFlat = style
	assert_almost_eq(flat.bg_color.a, 0.4, 0.001)
	assert_eq(flat.border_width_bottom, 0)
	assert_eq(flat.shadow_size, 0)


func test_every_button_has_the_gold_focus_ring() -> void:
	for look: StringName in [&"Button", &"GoldButton", &"Chip", &"IconButton"]:
		var style: StyleBox = _theme.get_stylebox(&"focus", look)
		assert_true(style is StyleBoxFlat)
		var ring: StyleBoxFlat = style
		assert_eq(ring.border_color, UiTokens.GOLD_FOCUS)
		assert_eq(ring.border_width_top, 3)
		assert_false(ring.draw_center)


func test_type_scale_uses_lilita_for_titles_and_nunito_for_body() -> void:
	assert_eq(_theme.get_font_size(&"font_size", &"DisplayXL"), 136)
	assert_eq(_theme.get_font_size(&"font_size", &"TitleM"), 26)
	assert_eq(_theme.get_font_size(&"font_size", &"Body"), 15)
	assert_eq(_theme.get_font(&"font", &"TitleM"), UiFonts.display())
	assert_eq(_theme.get_font(&"font", &"Body"), UiFonts.nunito(700))


func test_panels_use_their_surface() -> void:
	var expected: Dictionary[StringName, Color] = {
		&"SidePanel": UiTokens.SURFACE_1,
		&"CardSelf": UiTokens.SURFACE_2,
		&"CardChallenge": UiTokens.SURFACE_3,
		&"Row": UiTokens.SURFACE_ROW,
		&"Sunken": UiTokens.SURFACE_SUNKEN,
	}
	for look: StringName in expected:
		var style: StyleBox = _theme.get_stylebox(&"panel", look)
		assert_true(style is StyleBoxFlat)
		var flat: StyleBoxFlat = style
		assert_eq(flat.bg_color, expected[look], "%s fill" % look)


func test_the_text_field_turns_gold_when_focused() -> void:
	var style: StyleBox = _theme.get_stylebox(&"focus", &"LineEdit")
	assert_true(style is StyleBoxFlat)
	var flat: StyleBoxFlat = style
	assert_eq(flat.border_color, UiTokens.GOLD_500)


func test_neutral_avatars_never_change_for_a_guest() -> void:
	assert_eq(UiTokens.neutral_avatar("guest-7"), UiTokens.neutral_avatar("guest-7"))
	assert_true(UiTokens.neutral_avatar("guest-7") in UiTokens.NEUTRAL_AVATARS)

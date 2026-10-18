class_name TaktikTheme
extends RefCounted
## Builds the one Theme every screen uses: the walnut and gold look of the
## UI handoff. Screens pick a look by type variation, such as GoldButton or
## TitleM, and never set a colour or a size themselves.

const FONT_COLOUR_STATES: Array[StringName] = [
	&"font_color",
	&"font_hover_color",
	&"font_pressed_color",
	&"font_focus_color",
	&"font_hover_pressed_color",
]

const _PILL_PADDING: Vector4i = Vector4i(12, 4, 12, 4)


static func build() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font = UiFonts.nunito(700)
	theme.default_font_size = UiTokens.BODY
	_add_labels(theme)
	_add_panels(theme)
	_add_buttons(theme)
	_add_line_edit(theme)
	_add_bars(theme)
	_add_scroll(theme)
	_add_popups(theme)
	_add_separators(theme)
	return theme


static func _font(name: StringName) -> Font:
	if name == &"display":
		return UiFonts.display()
	return UiFonts.nunito(int(String(name)))


static func _add_labels(theme: Theme) -> void:
	theme.set_color(&"font_color", &"Label", UiTokens.TEXT_PRIMARY)
	var display: Font = UiFonts.display()
	_label(theme, &"DisplayXL", display, UiTokens.DISPLAY_XL, UiTokens.GOLD_TEXT)
	_label(theme, &"DisplayL", display, UiTokens.DISPLAY_L, UiTokens.GOLD_TEXT)
	_label(theme, &"DisplayM", display, UiTokens.DISPLAY_M, UiTokens.TEXT_PRIMARY)
	_label(theme, &"TitleL", display, UiTokens.TITLE_L, UiTokens.TEXT_PRIMARY)
	_label(theme, &"TitleLGold", display, UiTokens.TITLE_L, UiTokens.GOLD_TEXT)
	_label(theme, &"TitleM", display, UiTokens.TITLE_M, UiTokens.TEXT_PRIMARY)
	_label(theme, &"TitleMGold", display, UiTokens.TITLE_M, UiTokens.GOLD_TEXT)
	_label(theme, &"DisplayMOnGold", display, UiTokens.DISPLAY_M, UiTokens.TEXT_ON_GOLD)
	_label(theme, &"CaptionOnGold", UiFonts.nunito(800), UiTokens.LABEL, Color(UiTokens.TEXT_ON_GOLD, 0.75))
	_label(theme, &"LogoPhone", display, UiTokens.DISPLAY_PHONE, UiTokens.GOLD_TEXT)
	_label(theme, &"LogoTablet", display, UiTokens.DISPLAY_TABLET, UiTokens.GOLD_TEXT)
	_label(theme, &"TitleMOnGold", display, UiTokens.TITLE_M, UiTokens.TEXT_ON_GOLD)
	_label(theme, &"DisplayLPrimary", display, UiTokens.DISPLAY_L, UiTokens.TEXT_PRIMARY)
	_label(theme, &"TitleS", display, UiTokens.TITLE_S, UiTokens.TEXT_PRIMARY)
	_label(theme, &"TitleSGold", display, UiTokens.TITLE_S, UiTokens.GOLD_TEXT)
	_label(theme, &"BodyL", UiFonts.nunito(800), UiTokens.BODY_L, UiTokens.TEXT_PRIMARY)
	_label(theme, &"Tagline", UiFonts.nunito(800), 21, UiTokens.TEXT_SECONDARY)
	_label(theme, &"Body", UiFonts.nunito(700), UiTokens.BODY, UiTokens.TEXT_PRIMARY)
	_label(theme, &"BodySecondary", UiFonts.nunito(700), UiTokens.BODY, UiTokens.TEXT_SECONDARY)
	_label(theme, &"BodyMuted", UiFonts.nunito(700), UiTokens.BODY, UiTokens.TEXT_MUTED)
	_label(theme, &"LabelStrong", UiFonts.nunito(800), UiTokens.LABEL, UiTokens.TEXT_PRIMARY)
	_label(theme, &"LabelMuted", UiFonts.nunito(800), UiTokens.LABEL, UiTokens.TEXT_MUTED)
	_label(theme, &"LabelError", UiFonts.nunito(800), UiTokens.CAPTION, UiTokens.RED_TEXT)
	_label(theme, &"Caption", UiFonts.nunito(700), UiTokens.CAPTION, UiTokens.TEXT_MUTED)
	_label(theme, &"CaptionStrong", UiFonts.nunito(900), UiTokens.CAPTION, UiTokens.TEXT_SECONDARY)
	_label(theme, &"CaptionFaint", UiFonts.nunito(700), UiTokens.CAPTION, UiTokens.TEXT_FAINT)
	_label(theme, &"CaptionGold", UiFonts.nunito(800), UiTokens.CAPTION, UiTokens.GOLD_TEXT)
	_label(theme, &"CaptionAttack", UiFonts.nunito(900), UiTokens.CAPTION, UiTokens.RED_TEXT)
	_label(theme, &"CaptionDefense", UiFonts.nunito(900), UiTokens.CAPTION, UiTokens.DEF_TEXT)
	_label(theme, &"CaptionGreen", UiFonts.nunito(900), UiTokens.CAPTION, UiTokens.GREEN_TEXT)
	_label(theme, &"Overline", UiFonts.nunito(800), UiTokens.OVERLINE, UiTokens.TEXT_MUTED)
	_label(theme, &"OverlineGold", UiFonts.nunito(800), UiTokens.OVERLINE, Color(UiTokens.GOLD_TEXT, 0.85))
	for logo: StringName in [&"DisplayXL", &"DisplayL", &"LogoPhone", &"LogoTablet"]:
		theme.set_color(&"font_shadow_color", logo, UiTokens.GOLD_DEEP)
		theme.set_constant(&"shadow_offset_x", logo, 0)
	theme.set_constant(&"shadow_offset_y", &"DisplayXL", 7)
	theme.set_constant(&"shadow_offset_y", &"DisplayL", 5)
	theme.set_constant(&"shadow_offset_y", &"LogoPhone", 4)
	theme.set_constant(&"shadow_offset_y", &"LogoTablet", 5)
	theme.set_constant(&"line_spacing", &"Body", 4)
	theme.set_constant(&"line_spacing", &"BodySecondary", 4)


static func _label(theme: Theme, name: StringName, font: Font, font_size: int, colour: Color) -> void:
	theme.set_type_variation(name, &"Label")
	theme.set_font(&"font", name, font)
	theme.set_font_size(&"font_size", name, font_size)
	theme.set_color(&"font_color", name, colour)


static func _add_panels(theme: Theme) -> void:
	theme.set_type_variation(&"SidePanel", &"PanelContainer")
	theme.set_stylebox(
		&"panel", &"SidePanel",
		UiStyles.panel(UiTokens.SURFACE_1, UiTokens.BORDER_1, UiTokens.RADIUS_2XL, UiTokens.SPACE_XL)
	)
	_panel(theme, &"Card", UiTokens.SURFACE_1, UiTokens.BORDER_1, 1, UiTokens.RADIUS_XL, 18)
	_panel(theme, &"CardSelf", UiTokens.SURFACE_2, UiTokens.BORDER_2, 1, UiTokens.RADIUS_XL, 18)
	_panel(theme, &"CardChallenge", UiTokens.SURFACE_3, UiTokens.GOLD_500, 2, UiTokens.RADIUS_L, UiTokens.SPACE_L)
	_panel(theme, &"Row", UiTokens.SURFACE_ROW, Color.TRANSPARENT, 0, UiTokens.RADIUS_L, UiTokens.SPACE_M)
	_panel(theme, &"RowSelf", UiTokens.SURFACE_2, UiTokens.BORDER_2, 1, UiTokens.RADIUS_L, UiTokens.SPACE_M)
	_panel(theme, &"RowNewest", UiTokens.SURFACE_3, Color.TRANSPARENT, 0, UiTokens.RADIUS_M, UiTokens.SPACE_S)
	_panel(theme, &"RowJournal", UiTokens.SURFACE_ROW, Color.TRANSPARENT, 0, UiTokens.RADIUS_M, UiTokens.SPACE_S)
	_panel(theme, &"Sunken", UiTokens.SURFACE_SUNKEN, Color.TRANSPARENT, 0, UiTokens.RADIUS_M, UiTokens.SPACE_M)
	_panel(theme, &"LossBox", UiTokens.SURFACE_ROW, UiTokens.BORDER_1, 1, UiTokens.RADIUS_L, UiTokens.SPACE_M)
	_panel(theme, &"BubbleThem", UiTokens.SURFACE_SUNKEN, Color.TRANSPARENT, 0, UiTokens.RADIUS_L, UiTokens.SPACE_M)
	_panel(theme, &"BubbleYou", UiTokens.RED_BUBBLE, Color.TRANSPARENT, 0, UiTokens.RADIUS_L, UiTokens.SPACE_M)
	_panel(theme, &"Veil", Color(0.0, 0.0, 0.0, 0.6), Color.TRANSPARENT, 0, 0, 0)
	_active_card(theme, &"CardActive", UiTokens.SURFACE_1)
	_active_card(theme, &"CardSelfActive", UiTokens.SURFACE_2)
	_panel(theme, &"Strip", UiTokens.SURFACE_1, UiTokens.BORDER_1, 1, UiTokens.RADIUS_L, UiTokens.SPACE_S)
	_panel(theme, &"StripSelf", UiTokens.SURFACE_2, UiTokens.BORDER_2, 1, UiTokens.RADIUS_L, UiTokens.SPACE_S)
	_active_card(theme, &"StripActive", UiTokens.SURFACE_1, UiTokens.SPACE_S, UiTokens.RADIUS_L)
	_active_card(theme, &"StripSelfActive", UiTokens.SURFACE_2, UiTokens.SPACE_S, UiTokens.RADIUS_L)
	var ribbon: StyleBoxFlat = UiStyles.gold_button(UiTokens.RADIUS_M, Vector4i(56, 10, 56, 10))
	theme.set_type_variation(&"GoldRibbon", &"PanelContainer")
	theme.set_stylebox(&"panel", &"GoldRibbon", ribbon)
	_pill(theme, &"Pill", UiTokens.SURFACE_SUNKEN, UiTokens.BORDER_2)
	_pill(theme, &"PillGreen", UiTokens.GREEN_700, UiTokens.GREEN_500)
	_pill(theme, &"PillSelf", UiTokens.RED_700, UiTokens.RED_400)
	_pill(theme, &"PillGold", Color(UiTokens.GOLD_500, 0.14), UiTokens.GOLD_500)
	var them: StyleBoxFlat = theme.get_stylebox(&"panel", &"BubbleThem")
	them.corner_radius_top_left = UiTokens.SPACE_XS
	var you: StyleBoxFlat = theme.get_stylebox(&"panel", &"BubbleYou")
	you.corner_radius_top_right = UiTokens.SPACE_XS
	theme.set_type_variation(&"TopBar", &"PanelContainer")
	var top_bar: StyleBoxFlat = UiStyles.box(
		Color(UiTokens.BG_BOTTOM, 0.55), 0, Vector4i(UiTokens.SPACE_2XL, 0, UiTokens.SPACE_2XL, 0)
	)
	top_bar.border_color = UiTokens.BORDER_1
	top_bar.border_width_bottom = 1
	theme.set_stylebox(&"panel", &"TopBar", top_bar)
	theme.set_type_variation(&"BoardFrame", &"PanelContainer")
	var frame: StyleBoxFlat = UiStyles.box(
		UiTokens.FRAME_TOP, UiTokens.RADIUS_XL, UiStyles.even(UiTokens.SPACE_M),
		UiTokens.BOARD_TRIM, 2
	)
	frame.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	frame.shadow_size = 26
	frame.shadow_offset = Vector2(0.0, 14.0)
	theme.set_stylebox(&"panel", &"BoardFrame", frame)
	theme.set_type_variation(&"Modal", &"PanelContainer")
	var modal: StyleBoxFlat = UiStyles.box(
		UiTokens.SURFACE_1, UiTokens.RADIUS_MODAL, Vector4i(40, 92, 40, 34), UiTokens.BOARD_TRIM, 2
	)
	modal.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	modal.shadow_size = 40
	modal.shadow_offset = Vector2(0.0, 20.0)
	theme.set_stylebox(&"panel", &"Modal", modal)
	theme.set_type_variation(&"Sheet", &"PanelContainer")
	var sheet: StyleBoxFlat = UiStyles.box(
		UiTokens.SURFACE_1, 0, Vector4i(UiTokens.SPACE_L, UiTokens.SPACE_M, UiTokens.SPACE_L, UiTokens.SPACE_L),
		UiTokens.BORDER_1, 1
	)
	sheet.corner_radius_top_left = UiTokens.RADIUS_2XL
	sheet.corner_radius_top_right = UiTokens.RADIUS_2XL
	theme.set_stylebox(&"panel", &"Sheet", sheet)


static func _panel(
		theme: Theme,
		name: StringName,
		fill: Color,
		border: Color,
		border_width: int,
		radius: int,
		padding: int,
) -> void:
	theme.set_type_variation(name, &"PanelContainer")
	theme.set_stylebox(&"panel", name, UiStyles.box(fill, radius, UiStyles.even(padding), border, border_width))


## A card whose player is to move: a 2 px green-400 outline with a glow.
static func _active_card(
		theme: Theme,
		name: StringName,
		fill: Color,
		padding: int = 18,
		radius: int = UiTokens.RADIUS_XL,
) -> void:
	theme.set_type_variation(name, &"PanelContainer")
	var style: StyleBoxFlat = UiStyles.box(fill, radius, UiStyles.even(padding - 1), UiTokens.GREEN_400, 2)
	style.shadow_color = Color(UiTokens.GREEN_400, 0.3)
	style.shadow_size = 14
	theme.set_stylebox(&"panel", name, style)


static func _pill(theme: Theme, name: StringName, fill: Color, border: Color) -> void:
	theme.set_type_variation(name, &"PanelContainer")
	theme.set_stylebox(&"panel", name, UiStyles.box(fill, UiTokens.RADIUS_PILL, _PILL_PADDING, border, 1))


static func _add_buttons(theme: Theme) -> void:
	_add_button_base(theme)
	var gold_padding: Vector4i = Vector4i(24, 8, 24, 8)
	_add_button_look(
		theme, &"GoldButton", UiStyles.gold_button(UiTokens.RADIUS_L, gold_padding),
		UiTokens.TEXT_ON_GOLD, UiFonts.display(), 24, UiTokens.RADIUS_L
	)
	_add_button_look(
		theme, &"GoldButtonSmall", UiStyles.gold_button(UiTokens.RADIUS_M, Vector4i(18, 6, 18, 6)),
		UiTokens.TEXT_ON_GOLD, UiFonts.display(), 20, UiTokens.RADIUS_M
	)
	_add_button_look(
		theme, &"GoldButtonHero", UiStyles.gold_button(UiTokens.RADIUS_XL, Vector4i(28, 10, 28, 10)),
		UiTokens.TEXT_ON_GOLD, UiFonts.display(), UiTokens.DISPLAY_M, UiTokens.RADIUS_XL
	)
	_add_button_look(
		theme, &"WoodButton", UiStyles.wood_button(UiTokens.RADIUS_L, Vector4i(20, 6, 20, 6)),
		UiTokens.TEXT_PRIMARY, UiFonts.display(), 22, UiTokens.RADIUS_L
	)
	_add_button_look(
		theme, &"WoodButtonSmall", UiStyles.wood_button(UiTokens.RADIUS_M, Vector4i(16, 4, 16, 4)),
		UiTokens.TEXT_PRIMARY, UiFonts.nunito(800), UiTokens.LABEL, UiTokens.RADIUS_M
	)
	var danger: StyleBoxFlat = UiStyles.raised(
		UiTokens.RED_400, UiTokens.RED_700, 5, UiTokens.RADIUS_L, Vector4i(20, 6, 20, 6)
	)
	_add_button_look(
		theme, &"DangerButton", danger, UiTokens.TEXT_PRIMARY, UiFonts.display(), 22, UiTokens.RADIUS_L
	)
	var outline: StyleBoxFlat = UiStyles.box(
		Color.TRANSPARENT, UiTokens.RADIUS_M, Vector4i(16, 4, 16, 4), UiTokens.GOLD_500, 2
	)
	_add_flat_look(
		theme, &"OutlineButton", outline, Color(UiTokens.GOLD_500, 0.12),
		UiTokens.GOLD_TEXT, UiFonts.nunito(800), UiTokens.LABEL, UiTokens.RADIUS_M
	)
	var ghost: StyleBoxFlat = UiStyles.box(
		Color.TRANSPARENT, UiTokens.RADIUS_M, Vector4i(16, 4, 16, 4), UiTokens.BORDER_1, 1
	)
	_add_flat_look(
		theme, &"GhostButton", ghost, UiTokens.SURFACE_SUNKEN,
		UiTokens.TEXT_SECONDARY, UiFonts.nunito(800), UiTokens.LABEL, UiTokens.RADIUS_M
	)
	var icon: StyleBoxFlat = UiStyles.box(UiTokens.SURFACE_SUNKEN, UiTokens.RADIUS_M, UiStyles.even(10))
	_add_flat_look(
		theme, &"IconButton", icon, UiTokens.SURFACE_2,
		UiTokens.TEXT_SECONDARY, UiFonts.nunito(800), UiTokens.LABEL, UiTokens.RADIUS_M
	)
	var chip: StyleBoxFlat = UiStyles.box(
		Color.TRANSPARENT, UiTokens.RADIUS_PILL, Vector4i(14, 4, 14, 4), UiTokens.BORDER_3, 1
	)
	_add_flat_look(
		theme, &"Chip", chip, UiTokens.SURFACE_SUNKEN,
		UiTokens.TEXT_SECONDARY, UiFonts.nunito(800), UiTokens.CAPTION, UiTokens.RADIUS_PILL
	)
	_add_segment_look(theme)


static func _add_button_base(theme: Theme) -> void:
	theme.set_font(&"font", &"Button", UiFonts.nunito(800))
	theme.set_font_size(&"font_size", &"Button", UiTokens.LABEL)
	theme.set_constant(&"h_separation", &"Button", UiTokens.SPACE_S)
	theme.set_constant(&"icon_max_width", &"Button", 22)
	var wood: StyleBoxFlat = UiStyles.wood_button(UiTokens.RADIUS_M, Vector4i(16, 4, 16, 4))
	_set_states(theme, &"Button", wood)
	_set_font_colours(theme, &"Button", UiTokens.TEXT_PRIMARY)
	theme.set_stylebox(&"focus", &"Button", UiStyles.focus_ring(UiTokens.RADIUS_M))


static func _add_button_look(
		theme: Theme,
		name: StringName,
		style: StyleBoxFlat,
		text: Color,
		font: Font,
		font_size: int,
		radius: int,
) -> void:
	theme.set_type_variation(name, &"Button")
	_set_states(theme, name, style)
	_set_font_colours(theme, name, text)
	theme.set_font(&"font", name, font)
	theme.set_font_size(&"font_size", name, font_size)
	theme.set_stylebox(&"focus", name, UiStyles.focus_ring(radius))


## A look without an edge, whose fill turns to [param hover_fill] under the
## mouse.
static func _add_flat_look(
		theme: Theme,
		name: StringName,
		style: StyleBoxFlat,
		hover_fill: Color,
		text: Color,
		font: Font,
		font_size: int,
		radius: int,
) -> void:
	_add_button_look(theme, name, style, text, font, font_size, radius)
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = hover_fill
	theme.set_stylebox(&"hover", name, hover)
	theme.set_stylebox(&"hover_pressed", name, hover)


## One option of a segmented control: plain on the sunken track, gold when
## chosen (the toggle's pressed state).
static func _add_segment_look(theme: Theme) -> void:
	var name: StringName = &"SegmentButton"
	theme.set_type_variation(name, &"Button")
	var plain: StyleBoxFlat = UiStyles.box(Color.TRANSPARENT, UiTokens.RADIUS_S, Vector4i(12, 4, 12, 4))
	var chosen: StyleBoxFlat = UiStyles.box(UiTokens.GOLD_500, UiTokens.RADIUS_S, Vector4i(12, 4, 12, 4))
	var hover: StyleBoxFlat = plain.duplicate()
	hover.bg_color = UiTokens.WOOD_BUTTON
	theme.set_stylebox(&"normal", name, plain)
	theme.set_stylebox(&"hover", name, hover)
	theme.set_stylebox(&"pressed", name, chosen)
	theme.set_stylebox(&"hover_pressed", name, chosen)
	theme.set_stylebox(&"disabled", name, UiStyles.disabled(plain))
	theme.set_stylebox(&"focus", name, UiStyles.focus_ring(UiTokens.RADIUS_S))
	theme.set_color(&"font_color", name, UiTokens.TEXT_SECONDARY)
	theme.set_color(&"font_hover_color", name, UiTokens.TEXT_PRIMARY)
	theme.set_color(&"font_focus_color", name, UiTokens.TEXT_SECONDARY)
	theme.set_color(&"font_pressed_color", name, UiTokens.TEXT_ON_GOLD)
	theme.set_color(&"font_hover_pressed_color", name, UiTokens.TEXT_ON_GOLD)
	theme.set_color(&"font_disabled_color", name, Color(UiTokens.TEXT_SECONDARY, UiStyles.DISABLED_ALPHA))
	theme.set_font(&"font", name, UiFonts.nunito(800))
	theme.set_font_size(&"font_size", name, UiTokens.LABEL)
	theme.set_type_variation(&"SegmentTrack", &"PanelContainer")
	theme.set_stylebox(
		&"panel", &"SegmentTrack", UiStyles.box(UiTokens.SURFACE_SUNKEN, UiTokens.RADIUS_M, UiStyles.even(4))
	)
	# A tab is a segment whose chosen state is wood instead of gold.
	theme.set_type_variation(&"TabButton", &"SegmentButton")
	var tab: StyleBoxFlat = chosen.duplicate()
	tab.bg_color = UiTokens.WOOD_BUTTON
	theme.set_stylebox(&"pressed", &"TabButton", tab)
	theme.set_stylebox(&"hover_pressed", &"TabButton", tab)
	theme.set_color(&"font_pressed_color", &"TabButton", UiTokens.TEXT_PRIMARY)
	theme.set_color(&"font_hover_pressed_color", &"TabButton", UiTokens.TEXT_PRIMARY)


## The pressed state looks like the normal one: press feedback is the scale
## tween of PressScaleFeedback.
static func _set_states(theme: Theme, type: StringName, style: StyleBoxFlat) -> void:
	theme.set_stylebox(&"normal", type, style)
	theme.set_stylebox(&"pressed", type, style)
	theme.set_stylebox(&"hover", type, UiStyles.hovered(style))
	theme.set_stylebox(&"hover_pressed", type, UiStyles.hovered(style))
	theme.set_stylebox(&"disabled", type, UiStyles.disabled(style))


static func _set_font_colours(theme: Theme, type: StringName, colour: Color) -> void:
	for state: StringName in FONT_COLOUR_STATES:
		theme.set_color(state, type, colour)
	theme.set_color(&"font_disabled_color", type, Color(colour, UiStyles.DISABLED_ALPHA))
	theme.set_color(&"icon_normal_color", type, colour)
	theme.set_color(&"icon_hover_color", type, colour)
	theme.set_color(&"icon_pressed_color", type, colour)
	theme.set_color(&"icon_focus_color", type, colour)
	theme.set_color(&"icon_hover_pressed_color", type, colour)
	theme.set_color(&"icon_disabled_color", type, Color(colour, UiStyles.DISABLED_ALPHA))


static func _add_line_edit(theme: Theme) -> void:
	var normal: StyleBoxFlat = UiStyles.box(
		UiTokens.SURFACE_SUNKEN, UiTokens.RADIUS_M, Vector4i(16, 8, 16, 8), UiTokens.BORDER_2, 2
	)
	var focus: StyleBoxFlat = normal.duplicate()
	focus.border_color = UiTokens.GOLD_500
	focus.draw_center = false
	theme.set_stylebox(&"normal", &"LineEdit", normal)
	theme.set_stylebox(&"focus", &"LineEdit", focus)
	theme.set_stylebox(&"read_only", &"LineEdit", UiStyles.disabled(normal))
	theme.set_font(&"font", &"LineEdit", UiFonts.nunito(800))
	theme.set_font_size(&"font_size", &"LineEdit", 18)
	theme.set_color(&"font_color", &"LineEdit", UiTokens.TEXT_PRIMARY)
	theme.set_color(&"font_placeholder_color", &"LineEdit", UiTokens.TEXT_FAINT)
	theme.set_color(&"caret_color", &"LineEdit", UiTokens.GOLD_TEXT)
	theme.set_color(&"selection_color", &"LineEdit", Color(UiTokens.GOLD_500, 0.35))
	theme.set_type_variation(&"LineEditInvalid", &"LineEdit")
	var invalid: StyleBoxFlat = normal.duplicate()
	invalid.border_color = UiTokens.RED_400
	theme.set_stylebox(&"normal", &"LineEditInvalid", invalid)
	theme.set_stylebox(&"focus", &"LineEditInvalid", invalid)


## Countdown and turn bars: a gold fill draining over a sunken track.
static func _add_bars(theme: Theme) -> void:
	var track: StyleBoxFlat = UiStyles.box(UiTokens.SURFACE_SUNKEN, UiTokens.RADIUS_PILL)
	var fill: StyleBoxFlat = UiStyles.box(UiTokens.GOLD_500, UiTokens.RADIUS_PILL)
	theme.set_stylebox(&"background", &"ProgressBar", track)
	theme.set_stylebox(&"fill", &"ProgressBar", fill)
	theme.set_type_variation(&"TurnBarGreen", &"ProgressBar")
	theme.set_stylebox(&"fill", &"TurnBarGreen", UiStyles.box(UiTokens.GREEN_400, UiTokens.RADIUS_PILL))
	theme.set_type_variation(&"TurnBarRed", &"ProgressBar")
	theme.set_stylebox(&"fill", &"TurnBarRed", UiStyles.box(UiTokens.RED_400, UiTokens.RADIUS_PILL))


static func _add_scroll(theme: Theme) -> void:
	var grabber: StyleBoxFlat = UiStyles.box(UiTokens.BORDER_3, UiTokens.RADIUS_PILL)
	grabber.content_margin_left = 3
	grabber.content_margin_right = 3
	var track: StyleBoxEmpty = UiStyles.empty(Vector4i(3, 0, 3, 0))
	theme.set_stylebox(&"scroll", &"VScrollBar", track)
	theme.set_stylebox(&"grabber", &"VScrollBar", grabber)
	theme.set_stylebox(&"grabber_highlight", &"VScrollBar", grabber)
	theme.set_stylebox(&"grabber_pressed", &"VScrollBar", grabber)
	theme.set_stylebox(&"scroll", &"HScrollBar", UiStyles.empty(Vector4i(0, 3, 0, 3)))
	theme.set_stylebox(&"grabber", &"HScrollBar", grabber)
	theme.set_stylebox(&"grabber_highlight", &"HScrollBar", grabber)
	theme.set_stylebox(&"grabber_pressed", &"HScrollBar", grabber)


static func _add_popups(theme: Theme) -> void:
	var panel: StyleBoxFlat = UiStyles.panel(UiTokens.SURFACE_1, UiTokens.BORDER_1, UiTokens.RADIUS_L, 8)
	theme.set_stylebox(&"panel", &"PopupMenu", panel)
	theme.set_stylebox(&"hover", &"PopupMenu", UiStyles.box(UiTokens.WOOD_BUTTON, UiTokens.RADIUS_S))
	theme.set_color(&"font_color", &"PopupMenu", UiTokens.TEXT_PRIMARY)
	theme.set_color(&"font_hover_color", &"PopupMenu", UiTokens.TEXT_PRIMARY)
	theme.set_font(&"font", &"PopupMenu", UiFonts.nunito(800))
	theme.set_font_size(&"font_size", &"PopupMenu", UiTokens.LABEL)
	theme.set_stylebox(&"panel", &"PopupPanel", panel)
	theme.set_stylebox(&"panel", &"AcceptDialog", panel)
	theme.set_color(&"title_color", &"Window", UiTokens.TEXT_PRIMARY)
	theme.set_stylebox(
		&"embedded_border", &"Window", UiStyles.panel(UiTokens.SURFACE_1, UiTokens.BORDER_1, UiTokens.RADIUS_L, 8)
	)


static func _add_separators(theme: Theme) -> void:
	for type: StringName in [&"VSeparator", &"HSeparator"]:
		var line: StyleBoxLine = StyleBoxLine.new()
		line.color = UiTokens.BORDER_1
		line.thickness = 1
		line.vertical = type == &"VSeparator"
		theme.set_stylebox(&"separator", type, line)
		theme.set_constant(&"separation", type, 1)

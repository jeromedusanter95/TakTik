class_name UiTokens
extends RefCounted
## Every colour and size of the walnut and gold look, defined once. Screens
## and styles read them from here instead of writing a colour or a size.

# Page.
const BG_TOP: Color = Color("2b1a10")
const BG_BOTTOM: Color = Color("1c110b")
const BG_GLOW: Color = Color(132.0 / 255.0, 80.0 / 255.0, 38.0 / 255.0, 0.35)

# Surfaces.
const SURFACE_1: Color = Color("34221a")
const SURFACE_2: Color = Color("3f2a1c")
const SURFACE_3: Color = Color("45301f")
const SURFACE_ROW: Color = Color("2c1c14")
const SURFACE_SUNKEN: Color = Color("24170f")
const WOOD_BUTTON: Color = Color("4a3020")
const WOOD_EDGE: Color = Color("22150d")

# Borders.
const BORDER_1: Color = Color("4e3424")
const BORDER_2: Color = Color("5a3c27")
const BORDER_3: Color = Color("6b4a30")

# Text.
const TEXT_PRIMARY: Color = Color("f6ead2")
const TEXT_SECONDARY: Color = Color("e3cfaa")
const TEXT_MUTED: Color = Color("c8b08c")
const TEXT_FAINT: Color = Color("a88e6c")
const TEXT_ON_GOLD: Color = Color("2a1a0e")

# Gold.
const GOLD_400: Color = Color("f6c866")
const GOLD_500: Color = Color("edb94f")
const GOLD_600: Color = Color("e5ac3e")
const GOLD_TEXT: Color = Color("f0be55")
const GOLD_SHADOW: Color = Color("9c6a1e")
const GOLD_DEEP: Color = Color("7a4e1a")
const GOLD_FOCUS: Color = Color("ffd98a")
const BOARD_TRIM: Color = Color("d9a84a")
const SELECT_RING: Color = Color("ffd36b")

# Red Army, the viewer's side in most games.
const RED_400: Color = Color("e0604a")
const RED_700: Color = Color("8e2a1c")
const RED_BUBBLE: Color = Color("6b2a1e")
const RED_TEXT: Color = Color("f29a85")

# Green Army.
const GREEN_400: Color = Color("6cc978")
const GREEN_500: Color = Color("4c9f57")
const GREEN_700: Color = Color("2f6b3a")
const GREEN_TEXT: Color = Color("8fd39a")

# Adapted colours: the green Army drawn blue for colour-blind players.
const BLUE_400: Color = Color("3e7cc9")
const BLUE_TEXT: Color = Color("8fb8ea")

# Defense and statuses.
const DEF_400: Color = Color("7dbde8")
const DEF_TEXT: Color = Color("9fd3ee")
const AMBER_400: Color = Color("e59a4b")

# Board.
const CELL_LIGHT: Color = Color("ead6ac")
const CELL_DARK: Color = Color("c39865")
const LANE_A: Color = Color("3b2517")
const LANE_B: Color = Color("2f1d10")
const FRAME_TOP: Color = Color("5c3b24")
const FRAME_BOTTOM: Color = Color("3e2616")

## Lobby avatar fills, picked by hashing the Guest id.
const NEUTRAL_AVATARS: Array[Color] = [
	Color("6a3f7a"),
	Color("355e78"),
	Color("7a4e26"),
	Color("2f6b3a"),
	Color("8e2a1c"),
]

# Font sizes.
const DISPLAY_XL: int = 136
const DISPLAY_L: int = 80
const DISPLAY_M: int = 34
## The home logo on phones and on narrow screens.
const DISPLAY_PHONE: int = 72
const DISPLAY_TABLET: int = 96
const TITLE_L: int = 30
const TITLE_M: int = 26
const TITLE_S: int = 22
const BODY_L: int = 19
const BODY: int = 15
const LABEL: int = 15
const CAPTION: int = 13
const OVERLINE: int = 13

# Spacing.
const SPACE_XS: int = 4
const SPACE_S: int = 8
const SPACE_M: int = 12
const SPACE_L: int = 16
const SPACE_XL: int = 24
const SPACE_2XL: int = 32
const SPACE_3XL: int = 48
const GAP_COLUMNS: int = 28

# Radii.
const RADIUS_S: int = 10
const RADIUS_M: int = 12
const RADIUS_L: int = 16
const RADIUS_XL: int = 20
const RADIUS_2XL: int = 24
const RADIUS_MODAL: int = 30
const RADIUS_PILL: int = 999

# Sizes.
const TOUCH_MIN: int = 44
const TOPBAR_DESKTOP: int = 76
const TOPBAR_PHONE: int = 56
const COL_LEFT: int = 300
const COL_RIGHT: int = 360
const LOBBY_PANEL: int = 420
const CELL_MATCH: int = 78
const CELL_PLACEMENT: int = 76
const CELL_PHONE: int = 56

## The reference screens the layouts are drawn for.
const DESKTOP_SIZE: Vector2i = Vector2i(1440, 900)
const PHONE_SIZE: Vector2i = Vector2i(390, 844)


## The colour that stands for [param side] on rings, outlines and avatars.
static func army_colour(side: Side.Id, adapted: bool = false) -> Color:
	if side == Side.Id.RED:
		return RED_400
	return BLUE_400 if adapted else GREEN_400


## The avatar fill for [param side] during a game.
static func army_fill(side: Side.Id, adapted: bool = false) -> Color:
	if side == Side.Id.RED:
		return RED_700
	return BLUE_400.darkened(0.35) if adapted else GREEN_700


## The text colour that names [param side], as in "Vert a perdu".
static func army_text(side: Side.Id, adapted: bool = false) -> Color:
	if side == Side.Id.RED:
		return RED_TEXT
	return BLUE_TEXT if adapted else GREEN_TEXT


## A lobby avatar fill that never changes for [param guest_id].
static func neutral_avatar(guest_id: String) -> Color:
	return NEUTRAL_AVATARS[absi(guest_id.hash()) % NEUTRAL_AVATARS.size()]

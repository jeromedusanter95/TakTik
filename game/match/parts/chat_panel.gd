class_name ChatPanel
extends PanelContainer
## The right column of an online game. Discussion holds the Quick Chats both
## players sent, system lines and a pill for each Fight; Journal lists every
## Move, newest highlighted. Quick Chats are sent with the chips at the
## bottom.

signal quick_chat_chosen(message: String)
## A message arrived in the Discussion, from [param is_from_opponent].
signal message_added(is_from_opponent: bool)

enum Tab {
	DISCUSSION,
	JOURNAL,
}

@onready var _tabs: SegmentedControl = %Tabs
@onready var _discussion: ScrollContainer = %Discussion
@onready var _messages: VBoxContainer = %Messages
@onready var _journal: ScrollContainer = %Journal
@onready var _journal_rows: VBoxContainer = %JournalRows
@onready var _chips: HFlowContainer = %Chips


func _ready() -> void:
	_tabs.show_options(["CHAT_TAB_DISCUSSION", "CHAT_TAB_JOURNAL"], Tab.DISCUSSION)
	_tabs.option_chosen.connect(_on_tab_chosen)
	for message: String in QuickChat.MESSAGES:
		var chip: Button = Button.new()
		chip.theme_type_variation = &"Chip"
		chip.custom_minimum_size = Vector2(0, 34)
		chip.text = QuickChat.key(message)
		chip.pressed.connect(_on_chip_pressed.bind(message))
		chip.add_child(PressScaleFeedback.new())
		_chips.add_child(chip)
	_show_tab(Tab.DISCUSSION)


## Empties both tabs for a new game.
func clear() -> void:
	for list: VBoxContainer in [_messages, _journal_rows]:
		for child: Node in list.get_children():
			list.remove_child(child)
			child.queue_free()


## A Quick Chat bubble: the opponent's on the left, the player's own on the
## right.
func add_chat(author: String, text: String, is_you: bool) -> void:
	var block: VBoxContainer = VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	block.size_flags_horizontal = Control.SIZE_SHRINK_END if is_you else Control.SIZE_SHRINK_BEGIN
	var author_label: Label = _label(author, &"CaptionStrong")
	author_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	author_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if is_you else HORIZONTAL_ALIGNMENT_LEFT
	block.add_child(author_label)
	var bubble: PanelContainer = PanelContainer.new()
	bubble.theme_type_variation = &"BubbleYou" if is_you else &"BubbleThem"
	# Quick Chats are short, so a bubble never wraps; a wrapping label in a
	# shrinking box would collapse to nothing.
	var words: Label = _label(text, &"Body")
	words.autowrap_mode = TextServer.AUTOWRAP_OFF
	bubble.add_child(words)
	block.add_child(bubble)
	_append_message(block)
	message_added.emit(not is_you)


## A centred line from the game, such as "3 minutes to place your Pieces".
func add_system(text: String) -> void:
	var label: Label = _label(text, &"CaptionFaint")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_append_message(label)


## A centred gold pill for a Fight.
func add_fight(text: String) -> void:
	var pill: PanelContainer = PanelContainer.new()
	pill.theme_type_variation = &"PillGold"
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon: UiIcon = UiIcon.new()
	icon.texture = preload("res://game/ui/icons/swords.svg")
	icon.tone = UiIcon.Tone.GOLD
	icon.custom_minimum_size = Vector2(16, 16)
	row.add_child(icon)
	var label: Label = _label(text, &"CaptionGold")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	pill.add_child(row)
	_append_message(pill)


## Every Move so far, oldest first; the newest is highlighted.
func show_journal(lines: PackedStringArray) -> void:
	for child: Node in _journal_rows.get_children():
		_journal_rows.remove_child(child)
		child.queue_free()
	for index: int in lines.size():
		var row: PanelContainer = PanelContainer.new()
		row.theme_type_variation = &"RowNewest" if index == lines.size() - 1 else &"RowJournal"
		var label: Label = _label("%d. %s" % [index + 1, lines[index]], &"BodySecondary")
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		_journal_rows.add_child(row)
	_scroll_to_end(_journal)


func set_chips_enabled(enabled: bool) -> void:
	for chip: Node in _chips.get_children():
		if chip is Button:
			var button: Button = chip
			button.disabled = not enabled


func message_count() -> int:
	return _messages.get_child_count()


func _append_message(node: Control) -> void:
	_messages.add_child(node)
	_scroll_to_end(_discussion)


func _label(text: String, look: StringName) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = look
	label.text = text
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _scroll_to_end(scroll: ScrollContainer) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _show_tab(tab: Tab) -> void:
	_discussion.visible = tab == Tab.DISCUSSION
	_journal.visible = tab == Tab.JOURNAL


func _on_tab_chosen(index: int) -> void:
	_show_tab(Tab.JOURNAL if index == Tab.JOURNAL else Tab.DISCUSSION)


func _on_chip_pressed(message: String) -> void:
	quick_chat_chosen.emit(message)

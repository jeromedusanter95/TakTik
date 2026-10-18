extends GutTest
## Every text exists in every language, with the same placeholders, so no
## player ever reads a raw key or a broken sentence.

const CSV_PATH: String = "res://game/locale/translations.csv"


func test_every_language_column_is_supported() -> void:
	for code: String in _language_codes():
		assert_true(Languages.is_supported(code), code)


func test_every_key_is_translated_in_every_language() -> void:
	var codes: PackedStringArray = _language_codes()
	for row: PackedStringArray in _rows():
		for column: int in codes.size():
			assert_ne(row[column + 1], "", "%s in %s" % [row[0], codes[column]])


func test_every_translation_uses_the_same_placeholders() -> void:
	var codes: PackedStringArray = _language_codes()
	for row: PackedStringArray in _rows():
		var english: Array[String] = _placeholders(row[1])
		for column: int in range(1, codes.size()):
			assert_eq(_placeholders(row[column + 1]), english, "%s in %s" % [row[0], codes[column]])


func test_the_translations_are_loaded_by_the_project() -> void:
	TranslationServer.set_locale("fr")
	assert_eq(Translated.text(&"PIECE_KING"), "Roi")
	TranslationServer.set_locale(Languages.ENGLISH)
	assert_eq(Translated.text(&"PIECE_KING"), "King")


func test_placeholders_are_filled_by_name() -> void:
	TranslationServer.set_locale(Languages.ENGLISH)
	assert_eq(Translated.text(&"STATUS_TO_MOVE", {"side": "Red"}), "Red to move")


func _language_codes() -> PackedStringArray:
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	var header: PackedStringArray = file.get_csv_line()
	return header.slice(1)


func _rows() -> Array[PackedStringArray]:
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	file.get_csv_line()
	var rows: Array[PackedStringArray] = []
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() > 1:
			rows.append(row)
	return rows


func _placeholders(text: String) -> Array[String]:
	var regex: RegEx = RegEx.create_from_string("\\{(\\w+)\\}")
	var names: Array[String] = []
	for found: RegExMatch in regex.search_all(text):
		names.append(found.get_string(1))
	names.sort()
	return names

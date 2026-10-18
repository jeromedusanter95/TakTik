class_name WireJson
extends RefCounted
## Quiet, type-checked reading of the JSON the online server sends.


## The JSON object [param text] holds, or an empty one. Parses quietly:
## JSON.parse_string would log an engine error for every bad message.
static func parsed_object(text: String) -> Dictionary:
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {}
	return object(json.data)


## [param value] when it is an object, or an empty one.
static func object(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


## [param value] when it is text, or an empty String.
static func text(value: Variant) -> String:
	if value is String:
		return value
	return ""


## A whole number of zero or more, or -1. JSON numbers arrive as floats.
static func count(value: Variant) -> int:
	if value is not float and value is not int:
		return -1
	var number: float = value
	if number < 0.0 or number != floorf(number):
		return -1
	return int(number)

class_name QuickChat
extends RefCounted
## The fixed set of messages a player can send during an online game, as the
## server names them, with the text each shows.

const MESSAGES: Array[String] = [
	"hello",
	"good_luck",
	"well_played",
	"thanks",
	"oops",
	"good_game",
]

const _KEYS: Dictionary[String, StringName] = {
	"hello": &"CHAT_HELLO",
	"good_luck": &"CHAT_GOOD_LUCK",
	"well_played": &"CHAT_WELL_PLAYED",
	"thanks": &"CHAT_THANKS",
	"oops": &"CHAT_OOPS",
	"good_game": &"CHAT_GOOD_GAME",
}


static func is_message(name: String) -> bool:
	return _KEYS.has(name)


## The words of [param name], which must be one of [constant MESSAGES].
static func text(name: String) -> String:
	return Translated.text(_KEYS[name])


## The translation key of [param name], for controls that translate their own
## text when the language changes.
static func key(name: String) -> StringName:
	return _KEYS[name]

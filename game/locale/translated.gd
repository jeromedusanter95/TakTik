class_name Translated
extends RefCounted
## Reads the words players see in the current language, from
## game/locale/translations.csv.


## The text of [param key] with each {name} placeholder filled from
## [param values], for example [code]{"side": "Red"}[/code].
static func text(key: StringName, values: Dictionary[String, Variant] = {}) -> String:
	var template: String = TranslationServer.translate(key)
	return template.format(values) if not values.is_empty() else template

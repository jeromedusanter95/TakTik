@abstract
class_name LanguageStore
extends RefCounted
## Remembers which language the player chose between two visits.


## The saved locale code, or an empty String when none was saved.
@abstract func load_language() -> String


@abstract func save_language(code: String) -> void
